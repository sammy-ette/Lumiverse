package main

import (
	"bytes"
	"image"
	"image/color"
	"image/jpeg"
	"testing"

	"github.com/davidbyttow/govips/v2/vips"
)

// grayJPEG encodes a w×h solid-gray JPEG (R=G=B=val) and returns the bytes.
// JPEG has no alpha, which matches how Kavita serves manga pages.
func grayJPEG(w, h, val int) []byte {
	rgba := image.NewNRGBA(image.Rect(0, 0, w, h))
	c := color.NRGBA{R: uint8(val), G: uint8(val), B: uint8(val), A: 255}
	for y := 0; y < h; y++ {
		for x := 0; x < w; x++ {
			rgba.SetNRGBA(x, y, c)
		}
	}
	var buf bytes.Buffer
	jpeg.Encode(&buf, rgba, &jpeg.Options{Quality: 95}) //nolint
	return buf.Bytes()
}

func TestGrayscaleConversion(t *testing.T) {
	if err := vips.Startup(nil); err != nil {
		t.Skipf("libvips not available: %v", err)
	}
	defer vips.Shutdown()

	// Load a gray JPEG (no alpha, sRGB). This exercises the pixel-sampling
	// detection path since a JPEG loaded into govips has InterpretationSRGB.
	img, err := vips.NewImageFromBuffer(grayJPEG(64, 64, 128))
	if err != nil {
		t.Fatalf("load gray jpeg: %v", err)
	}
	defer img.Close()

	if !detectGrayscale(img) {
		t.Fatal("expected gray sRGB JPEG to be detected as grayscale")
	}

	// Flatten (no-op for JPEG, but mirrors proxy logic) then convert
	if img.HasAlpha() {
		img.Flatten(&vips.Color{R: 255, G: 255, B: 255}) //nolint
	}
	if err := img.ToColorSpace(vips.InterpretationBW); err != nil {
		t.Fatalf("ToColorSpace: %v", err)
	}
	if img.Bands() != 1 {
		t.Fatalf("expected 1 band after BW conversion, got %d", img.Bands())
	}

	// JPEG round-trip: encode → decode, verify still 1 band
	jpegBuf, _, err := img.ExportJpeg(&vips.JpegExportParams{Quality: 80, StripMetadata: true})
	if err != nil {
		t.Fatalf("JPEG encode: %v", err)
	}
	decodedJ, err := vips.NewImageFromBuffer(jpegBuf)
	if err != nil {
		t.Fatalf("JPEG decode: %v", err)
	}
	defer decodedJ.Close()
	if decodedJ.Bands() != 1 {
		t.Fatalf("JPEG output has %d bands, expected 1 (grayscale JPEG)", decodedJ.Bands())
	}

	// AVIF round-trip — monochrome AVIF (YUV 4:0:0) requires libheif support
	// which varies by platform. Log the result but don't hard-fail; AVIF still
	// compresses grayscale content well even as a nominal 3-band image.
	avifBuf, _, err := img.ExportAvif(&vips.AvifExportParams{Quality: 80, StripMetadata: true})
	if err != nil {
		t.Logf("AVIF encode skipped (plugin may be missing): %v", err)
	} else {
		decodedA, err := vips.NewImageFromBuffer(avifBuf)
		if err != nil {
			t.Fatalf("AVIF decode: %v", err)
		}
		defer decodedA.Close()
		if decodedA.Bands() == 1 {
			t.Logf("AVIF: true monochrome output (1 band) — libheif supports YUV 4:0:0")
		} else {
			t.Logf("AVIF: %d-band output — libheif does not produce monochrome AVIF on this platform (still correct, just not single-channel)", decodedA.Bands())
		}
	}
}

func TestColorImageNotDetectedAsGrayscale(t *testing.T) {
	if err := vips.Startup(nil); err != nil {
		t.Skipf("libvips not available: %v", err)
	}
	defer vips.Shutdown()

	bounds := image.Rect(0, 0, 64, 64)
	rgba := image.NewNRGBA(bounds)
	for y := 0; y < 64; y++ {
		for x := 0; x < 64; x++ {
			rgba.SetNRGBA(x, y, color.NRGBA{R: 200, G: 50, B: 100, A: 255})
		}
	}

	img, err := vips.NewImageFromGoImage(rgba)
	if err != nil {
		t.Fatalf("create image: %v", err)
	}
	defer img.Close()

	if detectGrayscale(img) {
		t.Fatal("color image should not be detected as grayscale")
	}
}
