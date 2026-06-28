package main

import (
	"encoding/json"
	"fmt"
	"io"
	"log"
	"net/http"
	"net/url"
	"strconv"
	"strings"
	"time"

	"github.com/gofiber/fiber/v3"
)

// --- MyAnimeList OAuth (Authorization Code + PKCE, "plain" challenge — MAL doesn't support S256) ---

const (
	malAuthURL        = "https://myanimelist.net/v1/oauth2/authorize"
	malTokenURL       = "https://myanimelist.net/v1/oauth2/token"
	malStateCookie    = "lumiverse_mal_state"
	malVerifierCookie = "lumiverse_mal_verifier"
)

// malLoginHandler — see the comment on anilistLoginHandler; same reasoning
// applies (called via authenticated fetch, hands back a URL to navigate to,
// records identity server-side against the state token).
func malLoginHandler(c fiber.Ctx) error {
	if malClientID == "" {
		return c.Status(fiber.StatusServiceUnavailable).JSON(fiber.Map{"error": "myanimelist is not configured"})
	}
	account := c.Locals("account").(*KavitaAccount)
	state := randomURLSafeString()
	verifier := randomURLSafeString()
	setShortLivedCookie(c, malStateCookie, state)
	setShortLivedCookie(c, malVerifierCookie, verifier)
	storeOAuthState(state, account.Username)

	redirectURI := redirectURIFor(c, "/api/lumiverse/scrobble/mal/callback")
	loc := malAuthURL + "?" + url.Values{
		"response_type":         {"code"},
		"client_id":             {malClientID},
		"code_challenge":        {verifier},
		"code_challenge_method": {"plain"},
		"state":                 {state},
		"redirect_uri":          {redirectURI},
	}.Encode()
	return c.JSON(fiber.Map{"url": loc})
}

// malCallbackHandler — see the comment on anilistCallbackHandler; not behind
// authRequired, identity comes from oauthStates instead.
func malCallbackHandler(c fiber.Ctx) error {
	state := c.Query("state")
	cookieState := c.Cookies(malStateCookie)
	verifier := c.Cookies(malVerifierCookie)
	c.ClearCookie(malStateCookie, malVerifierCookie)
	if state == "" || cookieState == "" || state != cookieState || verifier == "" {
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

	redirectURI := redirectURIFor(c, "/api/lumiverse/scrobble/mal/callback")
	form := url.Values{}
	form.Set("client_id", malClientID)
	if malClientSecret != "" {
		form.Set("client_secret", malClientSecret)
	}
	form.Set("grant_type", "authorization_code")
	form.Set("code", code)
	form.Set("code_verifier", verifier)
	form.Set("redirect_uri", redirectURI)

	tok, err := exchangeMALForm(form)
	if err != nil {
		log.Printf("mal token exchange: %v", err)
		return c.Status(fiber.StatusBadGateway).SendString("myanimelist token exchange failed")
	}

	var pref UserPreference
	db.FirstOrCreate(&pref, UserPreference{Username: username})
	pref.MALAccessToken = tok.AccessToken
	pref.MALRefreshToken = tok.RefreshToken
	pref.MALTokenExpiresAt = time.Now().Add(time.Duration(tok.ExpiresIn) * time.Second).Unix()
	if err := db.Save(&pref).Error; err != nil {
		log.Printf("save mal tokens: %v", err)
	}

	c.Set("Location", "/integrations")
	return c.SendStatus(fiber.StatusFound)
}

func malDisconnectHandler(c fiber.Ctx) error {
	account := c.Locals("account").(*KavitaAccount)
	db.Model(&UserPreference{}).Where("username = ?", account.Username).Updates(map[string]any{
		"mal_access_token":     "",
		"mal_refresh_token":    "",
		"mal_token_expires_at": 0,
	})
	return c.SendStatus(fiber.StatusNoContent)
}

type malTokenResponse struct {
	AccessToken  string `json:"access_token"`
	RefreshToken string `json:"refresh_token"`
	ExpiresIn    int64  `json:"expires_in"`
}

func exchangeMALForm(form url.Values) (*malTokenResponse, error) {
	req, err := http.NewRequest(http.MethodPost, malTokenURL, strings.NewReader(form.Encode()))
	if err != nil {
		return nil, err
	}
	req.Header.Set("Content-Type", "application/x-www-form-urlencoded")
	resp, err := httpClient.Do(req)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		body, _ := io.ReadAll(resp.Body)
		return nil, fmt.Errorf("mal returned %d: %s", resp.StatusCode, body)
	}
	var tok malTokenResponse
	if err := json.NewDecoder(resp.Body).Decode(&tok); err != nil {
		return nil, err
	}
	return &tok, nil
}

// ensureMALToken refreshes the access token in-place if it's expired (or about to).
func ensureMALToken(pref *UserPreference) error {
	if pref.MALAccessToken == "" {
		return fmt.Errorf("myanimelist not connected")
	}
	if time.Now().Unix() < pref.MALTokenExpiresAt-60 {
		return nil
	}
	form := url.Values{}
	form.Set("client_id", malClientID)
	if malClientSecret != "" {
		form.Set("client_secret", malClientSecret)
	}
	form.Set("grant_type", "refresh_token")
	form.Set("refresh_token", pref.MALRefreshToken)

	tok, err := exchangeMALForm(form)
	if err != nil {
		return fmt.Errorf("refresh: %w", err)
	}
	pref.MALAccessToken = tok.AccessToken
	pref.MALRefreshToken = tok.RefreshToken
	pref.MALTokenExpiresAt = time.Now().Add(time.Duration(tok.ExpiresIn) * time.Second).Unix()
	return db.Save(pref).Error
}

type malListStatusDto struct {
	Status          string `json:"status"`
	IsRereading     bool   `json:"is_rereading"`
	NumChaptersRead int    `json:"num_chapters_read"`
	NumVolumesRead  int    `json:"num_volumes_read"`
}

// scrobbleMAL mirrors scrobbleAniList's merge rules using MAL's vocabulary:
// status strings ("reading"/"completed"/"plan_to_read"/"dropped"/"on_hold") plus
// a separate is_rereading flag instead of a dedicated REPEATING status.
//
// chapterNum/volumeNum are 0 when not meaningful (see findChapterAndVolume)
// and are left out of the form entirely in that case, rather than sending 0
// and clobbering whatever's already there.
func scrobbleMAL(pref *UserPreference, malID int64, chapterNum, volumeNum int, isComplete bool) error {
	if err := ensureMALToken(pref); err != nil {
		return fmt.Errorf("refresh token: %w", err)
	}

	getReq, err := http.NewRequest(http.MethodGet, fmt.Sprintf("https://api.myanimelist.net/v2/manga/%d?fields=my_list_status", malID), nil)
	if err != nil {
		return err
	}
	getReq.Header.Set("Authorization", "Bearer "+pref.MALAccessToken)
	getResp, err := httpClient.Do(getReq)
	if err != nil {
		return fmt.Errorf("get manga: %w", err)
	}
	defer getResp.Body.Close()
	if getResp.StatusCode != http.StatusOK {
		body, _ := io.ReadAll(getResp.Body)
		return fmt.Errorf("mal get manga %d returned %d: %s", malID, getResp.StatusCode, body)
	}
	var existing struct {
		MyListStatus *malListStatusDto `json:"my_list_status"`
	}
	if err := json.NewDecoder(getResp.Body).Decode(&existing); err != nil {
		return err
	}

	var entryStatus string
	var entryChaptersRead, entryVolumesRead int
	var entryIsRereading bool
	if existing.MyListStatus != nil {
		entryStatus = existing.MyListStatus.Status
		entryChaptersRead = existing.MyListStatus.NumChaptersRead
		entryVolumesRead = existing.MyListStatus.NumVolumesRead
		entryIsRereading = existing.MyListStatus.IsRereading
	}

	if entryStatus == "dropped" || entryStatus == "on_hold" {
		return nil
	}

	status := "reading"
	chaptersRead := chapterNum
	volumesRead := volumeNum
	rereading := false

	switch entryStatus {
	case "completed":
		if !pref.ScrobbleRereadEnabled {
			return nil
		}
		rereading = true
		if isComplete {
			status = "completed"
			rereading = false
		}
	case "reading":
		chaptersRead = entryChaptersRead
		if chapterNum > chaptersRead {
			chaptersRead = chapterNum
		}
		volumesRead = entryVolumesRead
		if volumeNum > volumesRead {
			volumesRead = volumeNum
		}
		rereading = entryIsRereading
		if isComplete {
			status = "completed"
			rereading = false
		}
	default: // "" (no entry yet) or plan_to_read
		if isComplete {
			status = "completed"
		}
	}

	form := url.Values{}
	form.Set("status", status)
	if chaptersRead > 0 {
		form.Set("num_chapters_read", strconv.Itoa(chaptersRead))
	}
	if volumesRead > 0 {
		form.Set("num_volumes_read", strconv.Itoa(volumesRead))
	}
	form.Set("is_rereading", strconv.FormatBool(rereading))

	patchReq, err := http.NewRequest(http.MethodPatch, fmt.Sprintf("https://api.myanimelist.net/v2/manga/%d/my_list_status", malID), strings.NewReader(form.Encode()))
	if err != nil {
		return err
	}
	patchReq.Header.Set("Authorization", "Bearer "+pref.MALAccessToken)
	patchReq.Header.Set("Content-Type", "application/x-www-form-urlencoded")
	patchResp, err := httpClient.Do(patchReq)
	if err != nil {
		return fmt.Errorf("update manga: %w", err)
	}
	defer patchResp.Body.Close()
	if patchResp.StatusCode != http.StatusOK {
		body, _ := io.ReadAll(patchResp.Body)
		return fmt.Errorf("mal update manga %d returned %d: %s", malID, patchResp.StatusCode, body)
	}
	return nil
}
