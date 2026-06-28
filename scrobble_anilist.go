package main

import (
	"bytes"
	"encoding/json"
	"fmt"
	"io"
	"log"
	"net/http"
	"net/url"
	"time"

	"github.com/gofiber/fiber/v3"
)

// --- AniList OAuth ---

const (
	anilistAuthURL     = "https://anilist.co/api/v2/oauth/authorize"
	anilistTokenURL    = "https://anilist.co/api/v2/oauth/token"
	anilistGraphQLURL  = "https://graphql.anilist.co"
	anilistStateCookie = "lumiverse_anilist_state"
)

// anilistLoginHandler is called via an authenticated fetch (so it still sits
// behind authRequired), not a plain link — the eventual redirect to AniList,
// and AniList's redirect back to our callback, are both plain browser
// navigations with no Authorization header. So we hand back the URL for the
// frontend to navigate to, and record who's connecting server-side against
// the state token (see oauthStates) for the callback to pick back up — the
// username itself never goes into a cookie, so there's nothing for the
// client to tamper with to attribute the connection to a different account.
func anilistLoginHandler(c fiber.Ctx) error {
	if anilistClientID == "" {
		return c.Status(fiber.StatusServiceUnavailable).JSON(fiber.Map{"error": "anilist is not configured"})
	}
	account := c.Locals("account").(*KavitaAccount)
	state := randomURLSafeString()
	setShortLivedCookie(c, anilistStateCookie, state)
	storeOAuthState(state, account.Username)

	redirectURI := redirectURIFor(c, "/api/lumiverse/scrobble/anilist/callback")
	loc := anilistAuthURL + "?" + url.Values{
		"client_id":     {anilistClientID},
		"redirect_uri":  {redirectURI},
		"response_type": {"code"},
		"state":         {state},
	}.Encode()
	return c.JSON(fiber.Map{"url": loc})
}

// anilistCallbackHandler is hit by the browser navigating back from AniList,
// not by our frontend — it deliberately is NOT behind authRequired (there's
// no Authorization header to check). Identity comes from oauthStates instead,
// keyed by the state token set in anilistLoginHandler.
func anilistCallbackHandler(c fiber.Ctx) error {
	state := c.Query("state")
	cookieState := c.Cookies(anilistStateCookie)
	c.ClearCookie(anilistStateCookie)
	if state == "" || cookieState == "" || state != cookieState {
		return c.Status(fiber.StatusBadRequest).SendString("invalid oauth state")
	}
	username, ok := consumeOAuthState(state)
	if !ok {
		return c.Status(fiber.StatusBadRequest).SendString("expired oauth state")
	}

	code := c.Query("code")
	if code == "" {
		return c.Status(fiber.StatusBadRequest).SendString("missing code")
	}

	redirectURI := redirectURIFor(c, "/api/lumiverse/scrobble/anilist/callback")
	payload, _ := json.Marshal(map[string]string{
		"grant_type":    "authorization_code",
		"client_id":     anilistClientID,
		"client_secret": anilistClientSecret,
		"redirect_uri":  redirectURI,
		"code":          code,
	})
	req, err := http.NewRequest(http.MethodPost, anilistTokenURL, bytes.NewReader(payload))
	if err != nil {
		return c.Status(fiber.StatusInternalServerError).SendString("oauth error")
	}
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Accept", "application/json")
	resp, err := httpClient.Do(req)
	if err != nil {
		log.Printf("anilist token exchange: %v", err)
		return c.Status(fiber.StatusBadGateway).SendString("anilist token exchange failed")
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		body, _ := io.ReadAll(resp.Body)
		log.Printf("anilist token exchange (%d): %s", resp.StatusCode, body)
		return c.Status(fiber.StatusBadGateway).SendString("anilist token exchange failed")
	}

	var tok struct {
		AccessToken  string `json:"access_token"`
		RefreshToken string `json:"refresh_token"`
		ExpiresIn    int64  `json:"expires_in"`
	}
	if err := json.NewDecoder(resp.Body).Decode(&tok); err != nil {
		return c.Status(fiber.StatusBadGateway).SendString("anilist token exchange failed")
	}

	var pref UserPreference
	db.FirstOrCreate(&pref, UserPreference{Username: username})
	pref.AniListAccessToken = tok.AccessToken
	pref.AniListRefreshToken = tok.RefreshToken
	pref.AniListTokenExpiresAt = time.Now().Add(time.Duration(tok.ExpiresIn) * time.Second).Unix()
	if err := db.Save(&pref).Error; err != nil {
		log.Printf("save anilist tokens: %v", err)
	}

	c.Set("Location", "/integrations")
	return c.SendStatus(fiber.StatusFound)
}

func anilistDisconnectHandler(c fiber.Ctx) error {
	account := c.Locals("account").(*KavitaAccount)
	db.Model(&UserPreference{}).Where("username = ?", account.Username).Updates(map[string]any{
		"ani_list_access_token":     "",
		"ani_list_refresh_token":    "",
		"ani_list_token_expires_at": 0,
	})
	return c.SendStatus(fiber.StatusNoContent)
}

func anilistGraphQL(token, query string, variables map[string]any, out any) error {
	payload, err := json.Marshal(map[string]any{"query": query, "variables": variables})
	if err != nil {
		return err
	}
	req, err := http.NewRequest(http.MethodPost, anilistGraphQLURL, bytes.NewReader(payload))
	if err != nil {
		return err
	}
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Accept", "application/json")
	req.Header.Set("Authorization", "Bearer "+token)
	resp, err := httpClient.Do(req)
	if err != nil {
		return err
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		body, _ := io.ReadAll(resp.Body)
		return fmt.Errorf("anilist returned %d: %s", resp.StatusCode, body)
	}
	return json.NewDecoder(resp.Body).Decode(out)
}

type anilistMediaListEntry struct {
	Status          string `json:"status"`
	Progress        int    `json:"progress"`
	ProgressVolumes int    `json:"progressVolumes"`
	Repeat          int    `json:"repeat"`
}

// scrobbleAniList pushes chapter/volume progress to AniList, merging with
// whatever is already on the user's list rather than blindly overwriting it:
//   - DROPPED/PAUSED entries are never touched.
//   - COMPLETED entries are only touched if the user opted into reread tracking.
//   - Progress only ever moves forward; status only advances towards COMPLETED.
//
// chapterNum/volumeNum are 0 when not meaningful (see findChapterAndVolume)
// and are omitted from the mutation entirely in that case, rather than
// sending 0 and clobbering whatever's already there.
func scrobbleAniList(pref *UserPreference, mediaID, chapterNum, volumeNum int, isComplete bool) error {
	var queryResp struct {
		Data struct {
			Media struct {
				MediaListEntry *anilistMediaListEntry `json:"mediaListEntry"`
			} `json:"Media"`
		} `json:"data"`
	}
	if err := anilistGraphQL(pref.AniListAccessToken,
		`query ($id: Int) { Media(id: $id) { mediaListEntry { status progress progressVolumes repeat } } }`,
		map[string]any{"id": mediaID}, &queryResp); err != nil {
		return fmt.Errorf("query existing entry: %w", err)
	}

	var entryStatus string
	var entryProgress, entryProgressVolumes, entryRepeat int
	if entry := queryResp.Data.Media.MediaListEntry; entry != nil {
		entryStatus = entry.Status
		entryProgress = entry.Progress
		entryProgressVolumes = entry.ProgressVolumes
		entryRepeat = entry.Repeat
	}

	if entryStatus == "DROPPED" || entryStatus == "PAUSED" {
		return nil
	}

	status := "CURRENT"
	progress := chapterNum
	progressVolumes := volumeNum
	repeat := -1 // sentinel: omit from mutation

	switch entryStatus {
	case "COMPLETED":
		if !pref.ScrobbleRereadEnabled {
			return nil
		}
		status = "REPEATING"
		if isComplete {
			status = "COMPLETED"
			repeat = entryRepeat + 1
		}
	case "CURRENT", "REPEATING":
		status = entryStatus
		progress = entryProgress
		if chapterNum > progress {
			progress = chapterNum
		}
		progressVolumes = entryProgressVolumes
		if volumeNum > progressVolumes {
			progressVolumes = volumeNum
		}
		if isComplete {
			status = "COMPLETED"
			if entryStatus == "REPEATING" {
				repeat = entryRepeat + 1
			}
		}
	default: // "" (no entry yet) or PLANNING
		if isComplete {
			status = "COMPLETED"
		}
	}

	variables := map[string]any{"mediaId": mediaID, "status": status}
	if progress > 0 {
		variables["progress"] = progress
	}
	if progressVolumes > 0 {
		variables["progressVolumes"] = progressVolumes
	}
	if repeat >= 0 {
		variables["repeat"] = repeat
	}

	var mutResp struct {
		Data struct {
			SaveMediaListEntry anilistMediaListEntry `json:"SaveMediaListEntry"`
		} `json:"data"`
	}
	return anilistGraphQL(pref.AniListAccessToken,
		`mutation ($mediaId: Int, $status: MediaListStatus, $progress: Int, $progressVolumes: Int, $repeat: Int) {
			SaveMediaListEntry(mediaId: $mediaId, status: $status, progress: $progress, progressVolumes: $progressVolumes, repeat: $repeat) { status }
		}`, variables, &mutResp)
}
