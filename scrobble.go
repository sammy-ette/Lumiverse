package main

import (
	"crypto/rand"
	"encoding/base64"
	"encoding/json"
	"fmt"
	"io"
	"log"
	"math"
	"net/http"
	"os"
	"regexp"
	"strconv"
	"strings"
	"sync"
	"time"

	"github.com/gofiber/fiber/v3"
)

var (
	anilistClientID     string
	anilistClientSecret string
	malClientID         string
	malClientSecret     string
)

// oauthStates maps a one-time OAuth state token to the username that
// initiated it. The state cookie that round-trips through the browser is
// only ever an opaque, unguessable token — the username itself never leaves
// the server, so there's nothing for a client to tamper with to redirect
// tokens onto a different account. Entries are single-use and expire quickly;
// an in-memory map is fine since this is a single-process server and the
// whole flow completes within minutes.
var (
	oauthStateMu sync.Mutex
	oauthStates  = map[string]oauthStateEntry{}
)

type oauthStateEntry struct {
	username string
	expires  time.Time
}

func storeOAuthState(state, username string) {
	oauthStateMu.Lock()
	defer oauthStateMu.Unlock()
	oauthStates[state] = oauthStateEntry{username: username, expires: time.Now().Add(10 * time.Minute)}
}

// consumeOAuthState looks up and removes a state token in one step, so it
// can't be replayed even if somehow intercepted.
func consumeOAuthState(state string) (string, bool) {
	oauthStateMu.Lock()
	defer oauthStateMu.Unlock()
	entry, ok := oauthStates[state]
	delete(oauthStates, state)
	if !ok || time.Now().After(entry.expires) {
		return "", false
	}
	return entry.username, true
}

func initScrobble() {
	anilistClientID = os.Getenv("ANILIST_CLIENT_ID")
	anilistClientSecret = os.Getenv("ANILIST_CLIENT_SECRET")
	malClientID = os.Getenv("MAL_CLIENT_ID")
	malClientSecret = os.Getenv("MAL_CLIENT_SECRET")
}

// SeriesMapping caches the AniList/MAL ids resolved for a Kavita series, so we
// don't have to hit Kavita + MangaBaka on every chapter completion. It also
// caches MangaBaka's authoritative chapter/volume totals for the real-world
// series — used instead of Kavita's own library contents to decide "is this
// the last chapter/volume", since Kavita only knows what's actually been
// scanned locally (e.g. a series with only "Chapter 8" on disk would
// otherwise look "complete" the moment that single chapter is read).
type SeriesMapping struct {
	SeriesID      int `gorm:"primaryKey"`
	MangaBakaID   int64
	AniListID     int
	MALID         int64
	TotalChapters int    // MangaBaka's total_chapters, 0 if unknown
	TotalVolumes  int    // MangaBaka's final_volume, 0 if unknown/volume-less
	Status        string // MangaBaka's publication status: "releasing", "completed", "cancelled", "hiatus", ...
	Resolved      bool   // false if no [mb-<id>] was found, or MangaBaka had no link for it
	ResolvedAt    time.Time
}

// canMarkComplete reports whether catching up to the known chapter/volume
// totals should be allowed to flip the AniList/MAL status to Completed.
// "releasing" totals are just "however much MangaBaka knows about so far",
// not the real final count, so catching up there isn't actually finishing
// the series. "hiatus" is ambiguous (could resume any time) so it's treated
// the same, conservatively. "completed" and "cancelled" are both genuinely
// finished — nothing more is ever coming — so they're allowed.
func (m *SeriesMapping) canMarkComplete() bool {
	return m.Status != "releasing" && m.Status != "hiatus"
}

type kavitaSeriesDto struct {
	ID               int    `json:"id"`
	FolderPath       string `json:"folderPath"`
	LowestFolderPath string `json:"lowestFolderPath"`
}

type kavitaChapterDto struct {
	ID        int     `json:"id"`
	MaxNumber float64 `json:"maxNumber"`
	IsSpecial bool    `json:"isSpecial"`
}

type kavitaVolumeDto struct {
	MaxNumber float64            `json:"maxNumber"`
	Chapters  []kavitaChapterDto `json:"chapters"`
}

type kavitaSeriesDetailDto struct {
	Chapters []kavitaChapterDto `json:"chapters"`
	Volumes  []kavitaVolumeDto  `json:"volumes"`
	Specials []kavitaChapterDto `json:"specials"`
}

var mbFolderIDPattern = regexp.MustCompile(`\[mb-(\d+)\]`)

func getKavitaSeries(seriesID int) (*kavitaSeriesDto, error) {
	resp, err := kavitaDo(http.MethodGet, fmt.Sprintf("/api/Series/%d", seriesID), nil)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		body, _ := io.ReadAll(resp.Body)
		return nil, fmt.Errorf("kavita series %d returned %d: %s", seriesID, resp.StatusCode, body)
	}
	var s kavitaSeriesDto
	if err := json.NewDecoder(resp.Body).Decode(&s); err != nil {
		return nil, err
	}
	return &s, nil
}

func getKavitaSeriesDetail(seriesID int) (*kavitaSeriesDetailDto, error) {
	resp, err := kavitaDo(http.MethodGet, fmt.Sprintf("/api/series/series-detail?seriesId=%d", seriesID), nil)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		body, _ := io.ReadAll(resp.Body)
		return nil, fmt.Errorf("kavita series-detail %d returned %d: %s", seriesID, resp.StatusCode, body)
	}
	var d kavitaSeriesDetailDto
	if err := json.NewDecoder(resp.Body).Decode(&d); err != nil {
		return nil, err
	}
	return &d, nil
}

// findChapterAndVolume locates chapterID within a series' chapters/volumes/specials
// and returns which volume (if any) it belongs to.
//
// Kavita gives volume-only content (e.g. the Evergreen sample library) a
// single synthetic chapter per volume whose number is 0 — a sentinel meaning
// "no real chapter, this represents the whole volume", not "chapter zero".
// So chapter and volume progress have to be tracked independently: a 0
// chapter number is never meaningful progress, only the volume number is.
//
// "Is this the last chapter/volume" is deliberately NOT computed from
// Kavita's own data here — Kavita only knows what's been scanned into the
// library, not the real-world total. That comparison uses MangaBaka's
// totals (SeriesMapping.TotalChapters/TotalVolumes) instead.
func findChapterAndVolume(
	detail *kavitaSeriesDetailDto,
	chapterID int,
) (chapter kavitaChapterDto, volumeNumber float64, found bool) {
	consider := func(ch kavitaChapterDto, volNumber float64) {
		if ch.ID == chapterID {
			chapter = ch
			volumeNumber = volNumber
			found = true
		}
	}
	for _, ch := range detail.Chapters {
		consider(ch, 0) // loose chapters, not inside any volume
	}
	for _, vol := range detail.Volumes {
		for _, ch := range vol.Chapters {
			consider(ch, vol.MaxNumber)
		}
	}
	for _, ch := range detail.Specials {
		if ch.ID == chapterID {
			chapter = ch
			found = true
		}
	}
	return chapter, volumeNumber, found
}

type mangaBakaSeriesResponse struct {
	Data struct {
		FinalVolume   string `json:"final_volume"`
		TotalChapters string `json:"total_chapters"`
		Status        string `json:"status"`
		Source        struct {
			AniList struct {
				ID int `json:"id"`
			} `json:"anilist"`
			MyAnimeList struct {
				ID int64 `json:"id"`
			} `json:"my_anime_list"`
		} `json:"source"`
	} `json:"data"`
}

// resolveSeriesMapping extracts the MangaBaka id from the series folder name
// (every series folder carries a "[mb-<id>]" suffix) and resolves it to AniList
// and MAL ids via MangaBaka's public API. Results are cached indefinitely —
// folder names and MangaBaka's links don't change.
func resolveSeriesMapping(seriesID int) (*SeriesMapping, error) {
	var cached SeriesMapping
	if err := db.First(&cached, seriesID).Error; err == nil {
		return &cached, nil
	}

	mapping := SeriesMapping{SeriesID: seriesID, ResolvedAt: time.Now()}

	series, err := getKavitaSeries(seriesID)
	if err != nil {
		return nil, err
	}

	folder := series.FolderPath
	if folder == "" {
		folder = series.LowestFolderPath
	}
	match := mbFolderIDPattern.FindStringSubmatch(folder)
	if match == nil {
		db.Create(&mapping)
		return &mapping, nil
	}
	mbID, _ := strconv.ParseInt(match[1], 10, 64)
	mapping.MangaBakaID = mbID

	resp, err := httpClient.Get(fmt.Sprintf("https://api.mangabaka.org/v1/series/%d", mbID))
	if err != nil {
		db.Create(&mapping)
		return &mapping, nil
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		db.Create(&mapping)
		return &mapping, nil
	}
	var mb mangaBakaSeriesResponse
	if err := json.NewDecoder(resp.Body).Decode(&mb); err != nil {
		db.Create(&mapping)
		return &mapping, nil
	}
	if mb.Data.Source.AniList.ID == 0 && mb.Data.Source.MyAnimeList.ID == 0 {
		db.Create(&mapping)
		return &mapping, nil
	}

	totalVolumes := 0
	if v := strings.TrimSpace(mb.Data.FinalVolume); v != "" {
		totalVolumes, _ = strconv.Atoi(v)
	}

	totalChapters := 0
	if v := strings.TrimSpace(mb.Data.TotalChapters); v != "" {
		totalChapters, _ = strconv.Atoi(v)
	}

	mapping.AniListID = mb.Data.Source.AniList.ID
	mapping.MALID = mb.Data.Source.MyAnimeList.ID
	mapping.TotalChapters = totalChapters
	mapping.TotalVolumes = totalVolumes
	mapping.Status = mb.Data.Status
	mapping.Resolved = true
	db.Create(&mapping)
	return &mapping, nil
}

func randomURLSafeString() string {
	b := make([]byte, 32)
	_, _ = rand.Read(b)
	return base64.RawURLEncoding.EncodeToString(b)
}

// redirectURIFor builds the external callback URL for an OAuth flow. It uses
// Host() (not Hostname()) because Hostname() strips the port — fine behind a
// reverse proxy on the default port, but wrong for local dev on e.g. :8000.
func redirectURIFor(c fiber.Ctx, path string) string {
	protocol := "http"
	if c.Secure() {
		protocol = "https"
	}

	return protocol + "://" + c.Host() + path
}

func setShortLivedCookie(c fiber.Ctx, name, value string) {
	c.Cookie(&fiber.Cookie{
		Name:     name,
		Value:    value,
		HTTPOnly: true,
		MaxAge:   600,
	})
}

// --- status + trigger endpoints ---

func scrobbleStatusHandler(c fiber.Ctx) error {
	account := c.Locals("account").(*KavitaAccount)
	var pref UserPreference
	db.First(&pref, "username = ?", account.Username)
	return c.JSON(fiber.Map{
		"anilistConnected": pref.AniListAccessToken != "",
		"malConnected":     pref.MALAccessToken != "",
	})
}

func scrobbleChapterReadHandler(c fiber.Ctx) error {
	account := c.Locals("account").(*KavitaAccount)

	var body struct {
		SeriesID  int `json:"seriesId"`
		ChapterID int `json:"chapterId"`
	}
	if err := c.Bind().JSON(&body); err != nil || body.SeriesID == 0 || body.ChapterID == 0 {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{"error": "invalid body"})
	}

	if err := processScrobble(account.Username, body.SeriesID, body.ChapterID); err != nil {
		log.Printf("scrobble series=%d chapter=%d: %v", body.SeriesID, body.ChapterID, err)
	}
	return c.SendStatus(fiber.StatusNoContent)
}

func processScrobble(username string, seriesID, chapterID int) error {
	mapping, err := resolveSeriesMapping(seriesID)
	if err != nil {
		return fmt.Errorf("resolve mapping: %w", err)
	}
	if !mapping.Resolved {
		return nil
	}

	detail, err := getKavitaSeriesDetail(seriesID)
	if err != nil {
		return fmt.Errorf("series detail: %w", err)
	}

	chapter, volumeNumber, found := findChapterAndVolume(detail, chapterID)
	if !found {
		return fmt.Errorf("chapter %d not found in series %d", chapterID, seriesID)
	}
	if chapter.IsSpecial {
		return nil
	}

	// 0 means "no real number here" (see findChapterAndVolume) — never report
	// it as progress, that's how a volume-only chapter looked stuck at 0.
	chapterNum := 0
	if chapter.MaxNumber > 0 {
		chapterNum = int(math.Floor(chapter.MaxNumber))
	}
	volumeNum := 0
	if volumeNumber > 0 {
		volumeNum = int(math.Floor(volumeNumber))
	}
	// Completion is checked against MangaBaka's totals, not Kavita's own
	// library contents — Kavita only knows what's been scanned in locally,
	// so a series with only "Chapter 8" on disk would otherwise look
	// "complete" the instant that one chapter is read.
	isLastChapter := chapterNum > 0 && mapping.TotalChapters > 0 && chapterNum >= mapping.TotalChapters
	isLastVolume := volumeNum > 0 && mapping.TotalVolumes > 0 && volumeNum >= mapping.TotalVolumes
	// Volume completion only counts on its own when chapters aren't tracked at
	// all (chapterNum == 0, e.g. Evergreen-style volume-only content) — otherwise
	// it'd fire on the *first* chapter of the last volume, not just the last one.
	// And regardless of catching up to the totals, only actually flip to
	// Completed if the real-world series is done (see canMarkComplete).
	isComplete := mapping.canMarkComplete() && (isLastChapter || (chapterNum == 0 && isLastVolume))

	// Volume-only libraries never have a real chapter number (chapterNum stays
	// 0 above), which would leave AniList/MAL's chapter-progress field stuck at
	// 0 forever even as volume progress advances. If MangaBaka knows both
	// totals, estimate one from the average chapters-per-volume — this is
	// reporting-only, computed after isComplete so it never affects the
	// volume-based completion check above.
	reportedChapterNum := chapterNum
	if chapterNum <= 0 && volumeNum > 0 && mapping.TotalVolumes > 0 && mapping.TotalChapters > 0 {
		reportedChapterNum = int(math.Round(float64(volumeNum) / float64(mapping.TotalVolumes) * float64(mapping.TotalChapters)))
	}

	var pref UserPreference
	if err := db.First(&pref, "username = ?", username).Error; err != nil {
		return nil // nothing connected yet
	}

	var firstErr error
	if mapping.AniListID != 0 && pref.AniListAccessToken != "" {
		if err := scrobbleAniList(&pref, mapping.AniListID, reportedChapterNum, volumeNum, isComplete); err != nil {
			firstErr = fmt.Errorf("anilist: %w", err)
		}
	}
	if mapping.MALID != 0 && pref.MALAccessToken != "" {
		if err := scrobbleMAL(&pref, mapping.MALID, reportedChapterNum, volumeNum, isComplete); err != nil && firstErr == nil {
			firstErr = fmt.Errorf("mal: %w", err)
		}
	}
	return firstErr
}
