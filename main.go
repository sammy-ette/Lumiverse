package main

import (
	"encoding/json"
	"errors"
	"log"
	"net/http"
	"os"
	"strings"
	"time"

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
	Username     string `gorm:"primaryKey"`
	MaxAgeRating int    `gorm:"not null;default:8"`
}

func validateToken(authHeader string) (string, error) {
	req, err := http.NewRequest(http.MethodGet, kavitaURL+"/api/account", nil)
	if err != nil {
		return "", err
	}
	req.Header.Set("Authorization", authHeader)
	req.Header.Set("Accept", "application/json")

	resp, err := httpClient.Do(req)
	if err != nil {
		return "", err
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return "", errors.New("unauthorized")
	}

	var info struct {
		Username string `json:"username"`
	}
	json.NewDecoder(resp.Body).Decode(&info)
	if info.Username == "" {
		return "", errors.New("empty username from kavita")
	}
	return info.Username, nil
}

func authRequired(c fiber.Ctx) error {
	auth := c.Get("Authorization")
	if auth == "" {
		return c.Status(fiber.StatusUnauthorized).JSON(fiber.Map{"error": "unauthorized"})
	}
	username, err := validateToken(auth)
	if err != nil {
		log.Printf("auth: %v", err)
		return c.Status(fiber.StatusUnauthorized).JSON(fiber.Map{"error": "invalid token"})
	}
	c.Locals("username", username)
	return c.Next()
}

func getPreferences(c fiber.Ctx) error {
	username := c.Locals("username").(string)

	var pref UserPreference
	err := db.Where("username = ?", username).First(&pref).Error
	if errors.Is(err, gorm.ErrRecordNotFound) {
		return c.JSON(fiber.Map{"maxAgeRating": 8})
	} else if err != nil {
		return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{"error": "db error"})
	}
	return c.JSON(fiber.Map{"maxAgeRating": pref.MaxAgeRating})
}

func updatePreferences(c fiber.Ctx) error {
	username := c.Locals("username").(string)

	var body struct {
		MaxAgeRating int `json:"maxAgeRating"`
	}
	if err := c.Bind().JSON(&body); err != nil {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{"error": "invalid body"})
	}

	var pref UserPreference
	db.Where(UserPreference{Username: username}).FirstOrCreate(&pref)
	pref.MaxAgeRating = body.MaxAgeRating
	db.Save(&pref)

	return c.JSON(fiber.Map{"maxAgeRating": pref.MaxAgeRating})
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
