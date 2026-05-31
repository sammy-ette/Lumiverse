package main

import (
	"image"
	"io"
	"log"
	"net/http"
	"net/url"
	"os"
	"runtime"
	"sort"
	"strconv"
	"strings"
	"time"

	"github.com/davidbyttow/govips/v2/vips"
	"github.com/gofiber/fiber/v3"
	"github.com/gofiber/fiber/v3/middleware/cache"
)

var (
	imageClient       *http.Client
	processSem        chan struct{}
	imageEncodeEffort int
)

func initImageProxy() {
	imageClient = &http.Client{
		Timeout: 30 * time.Second,
		Transport: &http.Transport{
			MaxIdleConns:        100,
			MaxIdleConnsPerHost: 20,
			IdleConnTimeout:     90 * time.Second,
		},
	}

	processSem = make(chan struct{}, runtime.NumCPU()*2)

	imageEncodeEffort = 2
	if s := os.Getenv("IMAGE_ENCODE_EFFORT"); s != "" {
		if n, err := strconv.Atoi(s); err == nil && n >= 0 && n <= 10 {
			imageEncodeEffort = n
		}
	}
}

func imageCacheMaxBytes() uint {
	if s := os.Getenv("IMAGE_CACHE_MAX_MB"); s != "" {
		if n, err := strconv.Atoi(s); err == nil && n > 0 {
			return uint(n) * 1024 * 1024
		}
	}
	return 256 * 1024 * 1024
}

func newImageCache() fiber.Handler {
	return cache.New(cache.Config{
		ExpirationGenerator: func(c fiber.Ctx, cfg *cache.Config) time.Duration {
			if strings.HasPrefix(c.Path(), "/api/reader/") {
				return 5 * time.Minute
			}
			return 10 * time.Minute
		},
		KeyGenerator: func(c fiber.Ctx) string {
			params := c.Queries()
			delete(params, "apiKey")
			return c.Path() + "?" + sortedQueryString(params)
		},
		MaxBytes: imageCacheMaxBytes(),
	})
}

func sortedQueryString(params map[string]string) string {
	keys := make([]string, 0, len(params))
	for k := range params {
		keys = append(keys, k)
	}
	sort.Strings(keys)
	parts := make([]string, 0, len(keys))
	for _, k := range keys {
		parts = append(parts, url.QueryEscape(k)+"="+url.QueryEscape(params[k]))
	}
	return strings.Join(parts, "&")
}

func imageHandler(c fiber.Ctx) error {
	w := 0
	if ws := c.Query("w"); ws != "" {
		if n, err := strconv.Atoi(ws); err == nil && n > 0 && n <= 8000 {
			w = n
		}
	}
	q := 0
	if qs := c.Query("q"); qs != "" {
		if n, err := strconv.Atoi(qs); err == nil && n >= 1 && n <= 100 {
			q = n
		}
	}
	optimizeDelivery := c.Query("optimizeDelivery") == "1"

	upstreamURL := buildUpstreamURL(c)

	resp, err := imageClient.Get(upstreamURL)
	if err != nil {
		log.Printf("image proxy fetch error: %v", err)
		return c.Status(fiber.StatusBadGateway).SendString("upstream error")
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		c.Status(resp.StatusCode)
		body, _ := io.ReadAll(resp.Body)
		return c.Send(body)
	}

	sourceContentType := resp.Header.Get("Content-Type")

	// Passthrough — pipe Kavita's response body directly, no intermediate buffer.
	if w == 0 && q == 0 && !optimizeDelivery {
		c.Set("Content-Type", sourceContentType)
		c.Set("Cache-Control", "public, max-age=3600, stale-while-revalidate=86400")
		return c.SendStream(resp.Body)
	}

	body, err := io.ReadAll(resp.Body)
	if err != nil {
		return c.Status(fiber.StatusBadGateway).SendString("upstream read error")
	}

	// Acquire processing slot
	processSem <- struct{}{}
	defer func() { <-processSem }()

	img, err := vips.NewImageFromBuffer(body)
	if err != nil {
		log.Printf("image decode error: %v", err)
		return c.Status(fiber.StatusInternalServerError).SendString("image decode error")
	}
	defer img.Close()

	// Resize — always do before encode (operate on smaller image)
	if w > 0 && img.Width() > w {
		scale := float64(w) / float64(img.Width())
		if err := img.Resize(scale, vips.KernelLanczos3); err != nil {
			log.Printf("resize error: %v", err)
		}
	}

	// Grayscale detection and conversion
	if detectGrayscale(img) {
		// Flatten alpha before converting — BW conversion would otherwise keep
		// alpha as a second band, producing a 2-band image instead of 1.
		if img.HasAlpha() {
			if err := img.Flatten(&vips.Color{R: 255, G: 255, B: 255}); err != nil {
				log.Printf("flatten alpha error: %v", err)
			}
		}
		if err := img.ToColorSpace(vips.InterpretationBW); err != nil {
			log.Printf("grayscale conversion error: %v", err)
		}
	}

	quality := q
	if quality == 0 {
		quality = 90
	}

	var outBytes []byte
	var outContentType string

	if optimizeDelivery {
		outBytes, outContentType = encodeForAccept(img, c.Get("Accept"), quality)
		c.Set("Vary", "Accept")
	} else {
		outBytes, outContentType = encodeSourceFormat(img, sourceContentType, quality)
	}

	if outBytes == nil {
		return c.Status(fiber.StatusInternalServerError).SendString("encode error")
	}

	c.Set("Content-Type", outContentType)
	c.Set("Cache-Control", "public, max-age=3600, stale-while-revalidate=86400")
	return c.Send(outBytes)
}

func buildUpstreamURL(c fiber.Ctx) string {
	params := c.Queries()
	delete(params, "w")
	delete(params, "q")
	delete(params, "optimizeDelivery")
	qs := sortedQueryString(params)
	if qs != "" {
		return kavitaURL + c.Path() + "?" + qs
	}
	return kavitaURL + c.Path()
}

func detectGrayscale(img *vips.ImageRef) bool {
	interp := img.Interpretation()
	if interp == vips.InterpretationBW || interp == vips.InterpretationGrey16 {
		return true
	}
	if img.Bands() < 3 {
		return true
	}

	thumb, err := img.Copy()
	if err != nil {
		return false
	}
	defer thumb.Close()
	if err := thumb.Thumbnail(32, 32, vips.InterestingNone); err != nil {
		return false
	}
	goImg, err := thumb.ToGoImage()
	if err != nil {
		return false
	}
	return checkPixelsGrayscale(goImg)
}

func checkPixelsGrayscale(img image.Image) bool {
	bounds := img.Bounds()
	count, total := 0, 0
	for y := bounds.Min.Y; y < bounds.Max.Y; y++ {
		for x := bounds.Min.X; x < bounds.Max.X; x++ {
			r, g, b, _ := img.At(x, y).RGBA()
			r8, g8, b8 := int(r>>8), int(g>>8), int(b>>8)
			if absDiff(r8, g8)+absDiff(g8, b8) < 10 {
				count++
			}
			total++
		}
	}
	return total > 0 && count*100/total >= 97
}

func absDiff(a, b int) int {
	if a > b {
		return a - b
	}
	return b - a
}

func encodeForAccept(img *vips.ImageRef, accept string, quality int) ([]byte, string) {
	acceptsWebP := strings.Contains(accept, "image/webp") ||
		strings.Contains(accept, "image/*") ||
		strings.Contains(accept, "*/*")
	if acceptsWebP {
		buf, _, err := img.ExportWebp(&vips.WebpExportParams{
			Quality:         quality,
			Lossless:        quality == 0,
			ReductionEffort: imageEncodeEffort,
			StripMetadata:   true,
		})
		if err == nil {
			return buf, "image/webp"
		}
		log.Printf("webp encode failed, falling back to jpeg: %v", err)
	}
	return encodeJpeg(img, quality)
}

func encodeSourceFormat(img *vips.ImageRef, contentType string, quality int) ([]byte, string) {
	if strings.HasPrefix(contentType, "image/webp") {
		buf, _, err := img.ExportWebp(&vips.WebpExportParams{
			Quality:         quality,
			Lossless:        quality == 0,
			ReductionEffort: imageEncodeEffort,
			StripMetadata:   true,
		})
		if err == nil {
			return buf, "image/webp"
		}
		log.Printf("webp source re-encode failed, using jpeg: %v", err)
	}
	return encodeJpeg(img, quality)
}

func encodeJpeg(img *vips.ImageRef, quality int) ([]byte, string) {
	buf, _, err := img.ExportJpeg(&vips.JpegExportParams{
		Quality:       quality,
		Interlace:     true,
		StripMetadata: true,
	})
	if err != nil {
		log.Printf("jpeg encode error: %v", err)
		return nil, ""
	}
	return buf, "image/jpeg"
}
