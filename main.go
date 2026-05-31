package main

import (
	"bytes"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"log"
	"net/http"
	"os"
	"strings"
	"time"

	"github.com/davidbyttow/govips/v2/vips"
	"github.com/glebarez/sqlite"
	"github.com/gofiber/fiber/v3"
	"github.com/gofiber/fiber/v3/middleware/cors"
	"github.com/gofiber/fiber/v3/middleware/logger"
	"github.com/gofiber/fiber/v3/middleware/proxy"
	"github.com/gofiber/fiber/v3/middleware/static"
	"gorm.io/gorm"
	gormlog "gorm.io/gorm/logger"
)

var (
	db           *gorm.DB
	httpClient   = &http.Client{Timeout: 10 * time.Second}
	kavitaURL    string
	kavitaAPIKey string
	serverURL    string
)

type UserPreference struct {
	Username string `gorm:"primaryKey"`
}

type AgeRestriction struct {
	AgeRating       int  `json:"ageRating"`
	IncludeUnknowns bool `json:"includeUnknowns"`
}

type KavitaAccount struct {
	UserID           int      `json:"id"`
	Username         string   `json:"username"`
	Roles            []string `json:"roles"`
	Email            string   `json:"email"`
	IdentityProvider int      `json:"identityProvider"`
}

type KavitaLibrary struct {
	ID   int    `json:"id"`
	Name string `json:"name"`
}

type KavitaUser struct {
	ID               int             `json:"id"`
	Username         string          `json:"username"`
	Roles            []string        `json:"roles"`
	Libraries        []KavitaLibrary `json:"libraries"`
	AgeRestriction   AgeRestriction  `json:"ageRestriction"`
	Email            string          `json:"email"`
	IdentityProvider int             `json:"identityProvider"`
}

type UpdateAccountRequest struct {
	UserID           int            `json:"userId"`
	Username         string         `json:"username"`
	Roles            []string       `json:"roles"`
	Libraries        []int          `json:"libraries"`
	AgeRestriction   AgeRestriction `json:"ageRestriction"`
	Email            string         `json:"email"`
	IdentityProvider int            `json:"identityProvider"`
}

func kavitaDo(method, path string, body io.Reader) (*http.Response, error) {
	req, err := http.NewRequest(method, kavitaURL+path, body)
	if err != nil {
		return nil, err
	}
	req.Header.Set("x-api-key", kavitaAPIKey)
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Accept", "application/json")
	return httpClient.Do(req)
}

func getUserByUsername(username string) (*KavitaUser, error) {
	resp, err := kavitaDo(http.MethodGet, "/api/users", nil)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()

	var users []KavitaUser
	if err := json.NewDecoder(resp.Body).Decode(&users); err != nil {
		return nil, err
	}
	for _, u := range users {
		if u.Username == username {
			return &u, nil
		}
	}
	return nil, fmt.Errorf("user %q not found in kavita", username)
}

func validateToken(authHeader string) (*KavitaAccount, error) {
	req, err := http.NewRequest(http.MethodGet, kavitaURL+"/api/account", nil)
	if err != nil {
		return nil, err
	}
	req.Header.Set("Authorization", authHeader)
	req.Header.Set("Accept", "application/json")

	resp, err := httpClient.Do(req)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return nil, errors.New("unauthorized")
	}

	var account KavitaAccount
	json.NewDecoder(resp.Body).Decode(&account)
	if account.Username == "" {
		return nil, errors.New("empty username from kavita")
	}
	return &account, nil
}

func authRequired(c fiber.Ctx) error {
	auth := c.Get("Authorization")
	if auth == "" {
		return c.Status(fiber.StatusUnauthorized).JSON(fiber.Map{"error": "unauthorized"})
	}
	account, err := validateToken(auth)
	if err != nil {
		log.Printf("auth: %v", err)
		return c.Status(fiber.StatusUnauthorized).JSON(fiber.Map{"error": "invalid token"})
	}
	c.Locals("account", account)
	return c.Next()
}

func getPreferences(c fiber.Ctx) error {
	account := c.Locals("account").(*KavitaAccount)
	user, err := getUserByUsername(account.Username)
	if err != nil {
		log.Printf("get user: %v", err)
		return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{"error": "failed to fetch preferences"})
	}
	return c.JSON(fiber.Map{"maxAgeRating": user.AgeRestriction.AgeRating})
}

func updatePreferences(c fiber.Ctx) error {
	account := c.Locals("account").(*KavitaAccount)

	var body struct {
		MaxAgeRating int `json:"maxAgeRating"`
	}
	if err := c.Bind().JSON(&body); err != nil {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{"error": "invalid body"})
	}

	if kavitaAPIKey == "" {
		return c.Status(fiber.StatusServiceUnavailable).JSON(fiber.Map{"error": "preference updates are not available"})
	}

	user, err := getUserByUsername(account.Username)
	if err != nil {
		log.Printf("get user: %v", err)
		return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{"error": "failed to fetch user"})
	}

	libraries := make([]int, len(user.Libraries))
	for i, lib := range user.Libraries {
		libraries[i] = lib.ID
	}

	update := UpdateAccountRequest{
		UserID:           user.ID,
		Username:         user.Username,
		Roles:            user.Roles,
		Libraries:        libraries,
		AgeRestriction:   AgeRestriction{AgeRating: body.MaxAgeRating, IncludeUnknowns: false},
		Email:            user.Email,
		IdentityProvider: user.IdentityProvider,
	}

	payload, _ := json.Marshal(update)
	fmt.Println(string(payload))
	resp, err := kavitaDo(http.MethodPost, "/api/Account/update", bytes.NewReader(payload))
	if err != nil {
		return c.Status(fiber.StatusBadGateway).JSON(fiber.Map{"error": "kavita update failed"})
	}
	defer resp.Body.Close()
	if resp.StatusCode >= 300 {
		respBody, _ := io.ReadAll(resp.Body)
		log.Printf("kavita update failed (%d): %s", resp.StatusCode, respBody)
		return c.Status(fiber.StatusBadGateway).JSON(fiber.Map{"error": "kavita update failed"})
	}

	return c.JSON(fiber.Map{"maxAgeRating": body.MaxAgeRating})
}

func serveIndex(c fiber.Ctx) error {
	data, err := os.ReadFile("./dist/index.html")
	if err != nil {
		return c.Status(fiber.StatusNotFound).SendString("not found")
	}
	html := string(data)
	if serverURL != "" {
		html = strings.Replace(html, "</head>",
			"<script>window.config = { SERVER_URL: '"+serverURL+"' }</script></head>", 1)
	}
	c.Set("Content-Type", "text/html; charset=utf-8")
	return c.SendString(html)
}

func main() {
	if err := vips.Startup(nil); err != nil {
		log.Printf("WARNING: libvips startup failed: %v — image proxy will be unavailable", err)
	} else {
		defer vips.Shutdown()
	}
	initImageProxy()

	kavitaURL = os.Getenv("KAVITA_URL")
	kavitaAPIKey = os.Getenv("KAVITA_API_KEY")
	serverURL = os.Getenv("SERVER_URL")

	if kavitaURL == "" {
		log.Println("WARNING: KAVITA_URL not set")
	}

	dbPath := os.Getenv("DB_PATH")
	if dbPath == "" {
		dbPath = "lumiverse.db"
	}

	var err error
	db, err = gorm.Open(sqlite.Open(dbPath), &gorm.Config{
		Logger: gormlog.Default.LogMode(gormlog.Silent),
	})
	if err != nil {
		log.Fatal("open db:", err)
	}
	db.AutoMigrate(&UserPreference{})

	app := fiber.New()
	app.Use(logger.New())
	app.Use(cors.New())

	lumiverse := app.Group("/api/lumiverse", authRequired)
	lumiverse.Get("/preferences", getPreferences)
	lumiverse.Put("/preferences", updatePreferences)

	if kavitaURL != "" {
		imgCache := newImageCache()
		app.Get("/api/reader/image", imgCache, imageHandler)
		app.Get("/api/image/series-cover", imgCache, imageHandler)
		app.Get("/api/image/volume-cover", imgCache, imageHandler)
		app.Get("/api/image/chapter-cover", imgCache, imageHandler)

		app.All("/api/*", func(c fiber.Ctx) error {
			return proxy.Do(c, kavitaURL+c.OriginalURL())
		})
		app.All("/signin-oidc", func(c fiber.Ctx) error {
			return proxy.Do(c, kavitaURL+c.OriginalURL())
		})
		app.All("/oidc/*", func(c fiber.Ctx) error {
			return proxy.Do(c, kavitaURL+c.OriginalURL())
		})
	}

	app.Get("/lumiverse.css", static.New("./dist/lumiverse.css"))
	app.Get("/lumiverse.js", static.New("./dist/lumiverse.js"))
	app.Get("/lumiverse.mjs", static.New("./dist/lumiverse.mjs"))
	app.Get("/*", serveIndex)

	port := os.Getenv("PORT")
	if port == "" {
		port = "8000"
	}

	log.Fatal(app.Listen(":" + port))
}
