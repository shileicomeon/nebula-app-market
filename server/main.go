package main

import (
	"bytes"
	"encoding/json"
	"errors"
	"fmt"
	"log"
	"net/http"
	"os"
	"os/exec"
	"path/filepath"
	"sort"
	"strconv"
	"strings"
	"time"
)

const defaultUserID = 1

type app struct {
	ID          int      `json:"id"`
	Name        string   `json:"name"`
	Category    string   `json:"category"`
	Summary     string   `json:"summary"`
	Description string   `json:"description"`
	Rating      float64  `json:"rating"`
	Size        string   `json:"size"`
	Downloads   int      `json:"downloads"`
	Verified    bool     `json:"verified"`
	Tags        []string `json:"tags"`
	Screenshots []string `json:"screenshots"`
	Developer   string   `json:"developer"`
	Version     string   `json:"version"`
}

type appRow struct {
	ID          int     `json:"id"`
	Name        string  `json:"name"`
	Category    string  `json:"category"`
	Summary     string  `json:"summary"`
	Description string  `json:"description"`
	Rating      float64 `json:"rating"`
	Size        string  `json:"size"`
	Downloads   int     `json:"downloads"`
	Verified    int     `json:"verified"`
	Tags        string  `json:"tags"`
	Screenshots string  `json:"screenshots"`
	Developer   string  `json:"developer"`
	Version     string  `json:"version"`
}

type category struct {
	Name  string `json:"name"`
	Count int    `json:"count"`
}

type settings struct {
	AutoUpdate    bool `json:"auto_update"`
	WifiOnly      bool `json:"wifi_only"`
	Notifications bool `json:"notifications"`
}

type user struct {
	ID        int    `json:"id"`
	Phone     string `json:"phone"`
	Nickname  string `json:"nickname"`
	Token     string `json:"token"`
	CreatedAt string `json:"created_at"`
}

type downloadTask struct {
	ID       int     `json:"id"`
	App      app     `json:"app"`
	Progress float64 `json:"progress"`
	Paused   bool    `json:"paused"`
	Status   string  `json:"status"`
}

type downloadRow struct {
	ID       int     `json:"id"`
	Progress float64 `json:"progress"`
	Paused   int     `json:"paused"`
	Status   string  `json:"status"`
	ID2      int     `json:"app_id"`
	Name     string  `json:"name"`
	Category string  `json:"category"`
	Summary  string  `json:"summary"`
	Rating   float64 `json:"rating"`
	Size     string  `json:"size"`
}

type sqliteStore struct {
	path string
}

type apiServer struct {
	store *sqliteStore
}

func main() {
	store, err := openStore(defaultDBPath())
	if err != nil {
		log.Fatal(err)
	}

	server := &apiServer{store: store}
	mux := http.NewServeMux()
	mux.HandleFunc("/api/health", server.health)
	mux.HandleFunc("/api/auth/login", server.login)
	mux.HandleFunc("/api/me", server.me)
	mux.HandleFunc("/api/me/settings", server.meSettings)
	mux.HandleFunc("/api/me/favorites/", server.favoriteItem)
	mux.HandleFunc("/api/me/favorites", server.favorites)
	mux.HandleFunc("/api/me/reservations/", server.reservationItem)
	mux.HandleFunc("/api/me/reservations", server.reservations)
	mux.HandleFunc("/api/me/updates", server.updates)
	mux.HandleFunc("/api/me/downloads", server.downloads)
	mux.HandleFunc("/api/apps", server.appsList)
	mux.HandleFunc("/api/apps/", server.appDetail)
	mux.HandleFunc("/api/categories", server.categories)
	mux.HandleFunc("/api/rankings", server.rankings)

	addr := ":8080"
	log.Printf("nebula app market api listening on http://127.0.0.1%s", addr)
	log.Printf("sqlite database: %s", store.path)
	if err := http.ListenAndServe(addr, withCORS(mux)); err != nil {
		log.Fatal(err)
	}
}

func defaultDBPath() string {
	if path := os.Getenv("NEBULA_DB_PATH"); path != "" {
		return path
	}
	return filepath.Join("data", "nebula_app_market.db")
}

func openStore(path string) (*sqliteStore, error) {
	if _, err := exec.LookPath("sqlite3"); err != nil {
		return nil, fmt.Errorf("sqlite3 command not found: %w", err)
	}
	if err := os.MkdirAll(filepath.Dir(path), 0o755); err != nil {
		return nil, err
	}
	store := &sqliteStore{path: path}
	if err := store.init(); err != nil {
		return nil, err
	}
	return store, nil
}

func (s *sqliteStore) init() error {
	schema := `
PRAGMA journal_mode=WAL;
CREATE TABLE IF NOT EXISTS apps (
  id INTEGER PRIMARY KEY,
  name TEXT NOT NULL UNIQUE,
  category TEXT NOT NULL,
  summary TEXT NOT NULL,
  description TEXT NOT NULL,
  rating REAL NOT NULL,
  size TEXT NOT NULL,
  downloads INTEGER NOT NULL,
  verified INTEGER NOT NULL,
  tags TEXT NOT NULL,
  screenshots TEXT NOT NULL,
  developer TEXT NOT NULL,
  version TEXT NOT NULL,
  created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
);
CREATE TABLE IF NOT EXISTS users (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  phone TEXT NOT NULL UNIQUE,
  nickname TEXT NOT NULL,
  token TEXT NOT NULL,
  created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
);
CREATE TABLE IF NOT EXISTS settings (
  user_id INTEGER PRIMARY KEY,
  auto_update INTEGER NOT NULL DEFAULT 1,
  wifi_only INTEGER NOT NULL DEFAULT 1,
  notifications INTEGER NOT NULL DEFAULT 1
);
CREATE TABLE IF NOT EXISTS favorites (
  user_id INTEGER NOT NULL,
  app_id INTEGER NOT NULL,
  created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (user_id, app_id)
);
CREATE TABLE IF NOT EXISTS reservations (
  user_id INTEGER NOT NULL,
  app_id INTEGER NOT NULL,
  created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (user_id, app_id)
);
CREATE TABLE IF NOT EXISTS downloads (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  user_id INTEGER NOT NULL,
  app_id INTEGER NOT NULL,
  progress REAL NOT NULL DEFAULT 0,
  paused INTEGER NOT NULL DEFAULT 0,
  status TEXT NOT NULL DEFAULT 'downloading',
  created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
);
`
	if err := s.exec(schema); err != nil {
		return err
	}
	if err := s.seedApps(); err != nil {
		return err
	}
	return s.ensureDefaultUser()
}

func (s *sqliteStore) seedApps() error {
	for _, item := range seedApps() {
		tags, _ := json.Marshal(item.Tags)
		screenshots, _ := json.Marshal(item.Screenshots)
		stmt := fmt.Sprintf(`INSERT OR IGNORE INTO apps (id,name,category,summary,description,rating,size,downloads,verified,tags,screenshots,developer,version) VALUES (%d,%s,%s,%s,%s,%s,%s,%d,%d,%s,%s,%s,%s);`,
			item.ID,
			quote(item.Name), quote(item.Category), quote(item.Summary), quote(item.Description), floatLiteral(item.Rating), quote(item.Size), item.Downloads, boolInt(item.Verified), quote(string(tags)), quote(string(screenshots)), quote(item.Developer), quote(item.Version),
		)
		if err := s.exec(stmt); err != nil {
			return err
		}
	}
	return nil
}

func (s *sqliteStore) ensureDefaultUser() error {
	return s.exec(`INSERT OR IGNORE INTO users (id, phone, nickname, token) VALUES (1, '13800000000', '体验用户', 'demo-token');
INSERT OR IGNORE INTO settings (user_id, auto_update, wifi_only, notifications) VALUES (1, 1, 1, 1);
INSERT OR IGNORE INTO favorites (user_id, app_id) VALUES (1, 1), (1, 3), (1, 5);
INSERT OR IGNORE INTO reservations (user_id, app_id) VALUES (1, 2);
INSERT OR IGNORE INTO downloads (user_id, app_id, progress, paused, status) VALUES (1, 2, 0.64, 0, 'downloading'), (1, 3, 0.32, 1, 'paused'), (1, 4, 1.0, 0, 'ready');`)
}

func (s *sqliteStore) exec(sql string) error {
	cmd := exec.Command("sqlite3", s.path)
	cmd.Stdin = strings.NewReader(sql)
	var stderr bytes.Buffer
	cmd.Stderr = &stderr
	if err := cmd.Run(); err != nil {
		return fmt.Errorf("sqlite exec: %w: %s", err, stderr.String())
	}
	return nil
}

func (s *sqliteStore) query(sql string, target any) error {
	cmd := exec.Command("sqlite3", "-json", s.path, sql)
	var stderr bytes.Buffer
	cmd.Stderr = &stderr
	output, err := cmd.Output()
	if err != nil {
		return fmt.Errorf("sqlite query: %w: %s", err, stderr.String())
	}
	if len(strings.TrimSpace(string(output))) == 0 {
		output = []byte("[]")
	}
	return json.Unmarshal(output, target)
}

func (s *sqliteStore) listApps(query, category string) ([]app, error) {
	where := []string{"1=1"}
	if query != "" {
		needle := quote("%" + query + "%")
		where = append(where, fmt.Sprintf("(name LIKE %s OR category LIKE %s OR summary LIKE %s OR developer LIKE %s OR tags LIKE %s)", needle, needle, needle, needle, needle))
	}
	if category != "" {
		where = append(where, "category = "+quote(category))
	}
	return s.queryApps("SELECT * FROM apps WHERE " + strings.Join(where, " AND ") + " ORDER BY downloads DESC, rating DESC")
}

func (s *sqliteStore) getApp(identifier string) (app, bool, error) {
	condition := "name = " + quote(identifier)
	if id, err := strconv.Atoi(identifier); err == nil {
		condition = fmt.Sprintf("id = %d", id)
	}
	items, err := s.queryApps("SELECT * FROM apps WHERE " + condition + " LIMIT 1")
	if err != nil || len(items) == 0 {
		return app{}, false, err
	}
	return items[0], true, nil
}

func (s *sqliteStore) queryApps(sql string) ([]app, error) {
	var rows []appRow
	if err := s.query(sql, &rows); err != nil {
		return nil, err
	}
	items := make([]app, 0, len(rows))
	for _, row := range rows {
		items = append(items, row.toApp())
	}
	return items, nil
}

func (r appRow) toApp() app {
	var tags []string
	var screenshots []string
	_ = json.Unmarshal([]byte(r.Tags), &tags)
	_ = json.Unmarshal([]byte(r.Screenshots), &screenshots)
	return app{ID: r.ID, Name: r.Name, Category: r.Category, Summary: r.Summary, Description: r.Description, Rating: r.Rating, Size: r.Size, Downloads: r.Downloads, Verified: r.Verified == 1, Tags: tags, Screenshots: screenshots, Developer: r.Developer, Version: r.Version}
}

func (s *sqliteStore) categories() ([]category, error) {
	var items []category
	err := s.query("SELECT category AS name, COUNT(*) AS count FROM apps GROUP BY category ORDER BY category", &items)
	return items, err
}

func (s *sqliteStore) rankings(kind string) ([]app, error) {
	order := "downloads DESC, rating DESC"
	switch kind {
	case "rating":
		order = "rating DESC, downloads DESC"
	case "new":
		order = "id DESC"
	case "game":
		return s.queryApps("SELECT * FROM apps WHERE category = '游戏' ORDER BY rating DESC, downloads DESC")
	case "rising":
		order = "(rating * downloads) DESC"
	}
	return s.queryApps("SELECT * FROM apps ORDER BY " + order)
}

func (s *sqliteStore) login(phone string) (user, error) {
	phone = strings.TrimSpace(phone)
	if phone == "" {
		return user{}, errors.New("phone is required")
	}
	token := "demo-" + phone
	nickname := "用户" + tail(phone, 4)
	if err := s.exec(fmt.Sprintf(`INSERT INTO users (phone,nickname,token) VALUES (%s,%s,%s) ON CONFLICT(phone) DO UPDATE SET token=excluded.token;`, quote(phone), quote(nickname), quote(token))); err != nil {
		return user{}, err
	}
	var rows []user
	if err := s.query("SELECT id, phone, nickname, token, created_at FROM users WHERE phone = "+quote(phone), &rows); err != nil {
		return user{}, err
	}
	if len(rows) == 0 {
		return user{}, errors.New("user not found")
	}
	if err := s.exec(fmt.Sprintf(`INSERT OR IGNORE INTO settings (user_id, auto_update, wifi_only, notifications) VALUES (%d, 1, 1, 1);`, rows[0].ID)); err != nil {
		return user{}, err
	}
	return rows[0], nil
}

func (s *sqliteStore) defaultUser() (user, error) {
	var rows []user
	if err := s.query("SELECT id, phone, nickname, token, created_at FROM users WHERE id = 1", &rows); err != nil {
		return user{}, err
	}
	if len(rows) == 0 {
		return user{}, errors.New("default user not found")
	}
	return rows[0], nil
}

func (s *sqliteStore) getSettings(userID int) (settings, error) {
	var rows []struct {
		AutoUpdate    int `json:"auto_update"`
		WifiOnly      int `json:"wifi_only"`
		Notifications int `json:"notifications"`
	}
	if err := s.query(fmt.Sprintf("SELECT auto_update, wifi_only, notifications FROM settings WHERE user_id = %d", userID), &rows); err != nil {
		return settings{}, err
	}
	if len(rows) == 0 {
		return settings{AutoUpdate: true, WifiOnly: true, Notifications: true}, nil
	}
	return settings{AutoUpdate: rows[0].AutoUpdate == 1, WifiOnly: rows[0].WifiOnly == 1, Notifications: rows[0].Notifications == 1}, nil
}

func (s *sqliteStore) updateSettings(userID int, item settings) error {
	return s.exec(fmt.Sprintf(`INSERT INTO settings (user_id, auto_update, wifi_only, notifications) VALUES (%d,%d,%d,%d) ON CONFLICT(user_id) DO UPDATE SET auto_update=excluded.auto_update, wifi_only=excluded.wifi_only, notifications=excluded.notifications;`, userID, boolInt(item.AutoUpdate), boolInt(item.WifiOnly), boolInt(item.Notifications)))
}

func (s *sqliteStore) relation(table string, userID int) ([]app, error) {
	if table != "favorites" && table != "reservations" {
		return nil, errors.New("invalid relation table")
	}
	return s.queryApps(fmt.Sprintf("SELECT apps.* FROM apps JOIN %s ON %s.app_id = apps.id WHERE %s.user_id = %d ORDER BY %s.created_at DESC", table, table, table, userID, table))
}

func (s *sqliteStore) addRelation(table string, userID, appID int) error {
	if table != "favorites" && table != "reservations" {
		return errors.New("invalid relation table")
	}
	return s.exec(fmt.Sprintf("INSERT OR IGNORE INTO %s (user_id, app_id) VALUES (%d, %d);", table, userID, appID))
}

func (s *sqliteStore) deleteRelation(table string, userID, appID int) error {
	if table != "favorites" && table != "reservations" {
		return errors.New("invalid relation table")
	}
	return s.exec(fmt.Sprintf("DELETE FROM %s WHERE user_id = %d AND app_id = %d;", table, userID, appID))
}

func (s *sqliteStore) updates() ([]app, error) {
	return s.queryApps("SELECT * FROM apps ORDER BY id LIMIT 3")
}

func (s *sqliteStore) listDownloads(userID int) ([]downloadTask, error) {
	var rows []downloadRow
	query := fmt.Sprintf(`SELECT downloads.id, downloads.progress, downloads.paused, downloads.status, apps.id AS app_id, apps.name, apps.category, apps.summary, apps.rating, apps.size FROM downloads JOIN apps ON apps.id = downloads.app_id WHERE downloads.user_id = %d ORDER BY downloads.updated_at DESC, downloads.id DESC`, userID)
	if err := s.query(query, &rows); err != nil {
		return nil, err
	}
	items := make([]downloadTask, 0, len(rows))
	for _, row := range rows {
		items = append(items, downloadTask{ID: row.ID, Progress: row.Progress, Paused: row.Paused == 1, Status: row.Status, App: app{ID: row.ID2, Name: row.Name, Category: row.Category, Summary: row.Summary, Rating: row.Rating, Size: row.Size, Verified: true, Tags: []string{}, Screenshots: []string{}}})
	}
	return items, nil
}

func (s *sqliteStore) addDownload(userID, appID int) error {
	return s.exec(fmt.Sprintf("INSERT INTO downloads (user_id, app_id, progress, paused, status) VALUES (%d, %d, 0, 0, 'downloading');", userID, appID))
}

func (s *sqliteStore) toggleDownload(id int) error {
	return s.exec(fmt.Sprintf("UPDATE downloads SET paused = CASE WHEN progress >= 1 THEN 0 WHEN paused = 1 THEN 0 ELSE 1 END, status = CASE WHEN progress >= 1 THEN 'installing' WHEN paused = 1 THEN 'downloading' ELSE 'paused' END, updated_at = CURRENT_TIMESTAMP WHERE id = %d;", id))
}

func (s *apiServer) health(w http.ResponseWriter, r *http.Request) {
	writeJSON(w, http.StatusOK, map[string]any{"ok": true, "service": "nebula-app-market", "database": s.store.path, "timestamp": time.Now().Format(time.RFC3339)})
}

func (s *apiServer) login(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		methodNotAllowed(w)
		return
	}
	var body struct {
		Phone string `json:"phone"`
	}
	if err := decodeJSON(r, &body); err != nil {
		writeError(w, http.StatusBadRequest, err.Error())
		return
	}
	item, err := s.store.login(body.Phone)
	if err != nil {
		writeError(w, http.StatusBadRequest, err.Error())
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"user": item, "token": item.Token})
}

func (s *apiServer) me(w http.ResponseWriter, r *http.Request) {
	item, err := s.store.defaultUser()
	if err != nil {
		writeError(w, http.StatusInternalServerError, err.Error())
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"user": item})
}

func (s *apiServer) meSettings(w http.ResponseWriter, r *http.Request) {
	switch r.Method {
	case http.MethodGet:
		item, err := s.store.getSettings(defaultUserID)
		if err != nil {
			writeError(w, http.StatusInternalServerError, err.Error())
			return
		}
		writeJSON(w, http.StatusOK, item)
	case http.MethodPut, http.MethodPost:
		var item settings
		if err := decodeJSON(r, &item); err != nil {
			writeError(w, http.StatusBadRequest, err.Error())
			return
		}
		if err := s.store.updateSettings(defaultUserID, item); err != nil {
			writeError(w, http.StatusInternalServerError, err.Error())
			return
		}
		writeJSON(w, http.StatusOK, item)
	default:
		methodNotAllowed(w)
	}
}

func (s *apiServer) favorites(w http.ResponseWriter, r *http.Request) {
	s.relationCollection(w, r, "favorites")
}

func (s *apiServer) favoriteItem(w http.ResponseWriter, r *http.Request) {
	s.relationItem(w, r, "favorites", "/api/me/favorites/")
}

func (s *apiServer) reservations(w http.ResponseWriter, r *http.Request) {
	s.relationCollection(w, r, "reservations")
}

func (s *apiServer) reservationItem(w http.ResponseWriter, r *http.Request) {
	s.relationItem(w, r, "reservations", "/api/me/reservations/")
}

func (s *apiServer) relationCollection(w http.ResponseWriter, r *http.Request, table string) {
	switch r.Method {
	case http.MethodGet:
		items, err := s.store.relation(table, defaultUserID)
		if err != nil {
			writeError(w, http.StatusInternalServerError, err.Error())
			return
		}
		writeJSON(w, http.StatusOK, map[string]any{"apps": items})
	case http.MethodPost:
		var body struct {
			AppID int `json:"app_id"`
		}
		if err := decodeJSON(r, &body); err != nil {
			writeError(w, http.StatusBadRequest, err.Error())
			return
		}
		if err := s.store.addRelation(table, defaultUserID, body.AppID); err != nil {
			writeError(w, http.StatusInternalServerError, err.Error())
			return
		}
		writeJSON(w, http.StatusCreated, map[string]any{"ok": true})
	default:
		methodNotAllowed(w)
	}
}

func (s *apiServer) relationItem(w http.ResponseWriter, r *http.Request, table, prefix string) {
	if r.Method != http.MethodDelete {
		methodNotAllowed(w)
		return
	}
	id, err := strconv.Atoi(strings.TrimPrefix(r.URL.Path, prefix))
	if err != nil {
		writeError(w, http.StatusBadRequest, "invalid app id")
		return
	}
	if err := s.store.deleteRelation(table, defaultUserID, id); err != nil {
		writeError(w, http.StatusInternalServerError, err.Error())
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"ok": true})
}

func (s *apiServer) updates(w http.ResponseWriter, r *http.Request) {
	items, err := s.store.updates()
	if err != nil {
		writeError(w, http.StatusInternalServerError, err.Error())
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"apps": items})
}

func (s *apiServer) downloads(w http.ResponseWriter, r *http.Request) {
	switch r.Method {
	case http.MethodGet:
		items, err := s.store.listDownloads(defaultUserID)
		if err != nil {
			writeError(w, http.StatusInternalServerError, err.Error())
			return
		}
		writeJSON(w, http.StatusOK, map[string]any{"downloads": items})
	case http.MethodPost:
		var body struct {
			AppID int `json:"app_id"`
			ID    int `json:"id"`
		}
		if err := decodeJSON(r, &body); err != nil {
			writeError(w, http.StatusBadRequest, err.Error())
			return
		}
		if body.ID > 0 {
			if err := s.store.toggleDownload(body.ID); err != nil {
				writeError(w, http.StatusInternalServerError, err.Error())
				return
			}
		} else if body.AppID > 0 {
			if err := s.store.addDownload(defaultUserID, body.AppID); err != nil {
				writeError(w, http.StatusInternalServerError, err.Error())
				return
			}
		}
		writeJSON(w, http.StatusOK, map[string]any{"ok": true})
	default:
		methodNotAllowed(w)
	}
}

func (s *apiServer) appsList(w http.ResponseWriter, r *http.Request) {
	items, err := s.store.listApps(strings.TrimSpace(r.URL.Query().Get("q")), strings.TrimSpace(r.URL.Query().Get("category")))
	if err != nil {
		writeError(w, http.StatusInternalServerError, err.Error())
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"apps": items})
}

func (s *apiServer) appDetail(w http.ResponseWriter, r *http.Request) {
	identifier := strings.TrimPrefix(r.URL.Path, "/api/apps/")
	item, ok, err := s.store.getApp(identifier)
	if err != nil {
		writeError(w, http.StatusInternalServerError, err.Error())
		return
	}
	if !ok {
		writeError(w, http.StatusNotFound, "app not found")
		return
	}
	writeJSON(w, http.StatusOK, item)
}

func (s *apiServer) categories(w http.ResponseWriter, r *http.Request) {
	items, err := s.store.categories()
	if err != nil {
		writeError(w, http.StatusInternalServerError, err.Error())
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"categories": items})
}

func (s *apiServer) rankings(w http.ResponseWriter, r *http.Request) {
	items, err := s.store.rankings(r.URL.Query().Get("type"))
	if err != nil {
		writeError(w, http.StatusInternalServerError, err.Error())
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"apps": items})
}

func decodeJSON(r *http.Request, target any) error {
	defer r.Body.Close()
	return json.NewDecoder(r.Body).Decode(target)
}

func withCORS(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Access-Control-Allow-Origin", "*")
		w.Header().Set("Access-Control-Allow-Methods", "GET, POST, PUT, DELETE, OPTIONS")
		w.Header().Set("Access-Control-Allow-Headers", "Content-Type, Authorization")
		if r.Method == http.MethodOptions {
			w.WriteHeader(http.StatusNoContent)
			return
		}
		next.ServeHTTP(w, r)
	})
}

func writeJSON(w http.ResponseWriter, status int, payload any) {
	w.Header().Set("Content-Type", "application/json; charset=utf-8")
	w.WriteHeader(status)
	if err := json.NewEncoder(w).Encode(payload); err != nil {
		log.Printf("encode response: %v", err)
	}
}

func writeError(w http.ResponseWriter, status int, message string) {
	writeJSON(w, status, map[string]any{"error": message})
}

func methodNotAllowed(w http.ResponseWriter) {
	writeError(w, http.StatusMethodNotAllowed, "method not allowed")
}

func quote(value string) string {
	return "'" + strings.ReplaceAll(value, "'", "''") + "'"
}

func boolInt(value bool) int {
	if value {
		return 1
	}
	return 0
}

func floatLiteral(value float64) string {
	return strconv.FormatFloat(value, 'f', -1, 64)
}

func tail(value string, count int) string {
	if len(value) <= count {
		return value
	}
	return value[len(value)-count:]
}

func seedApps() []app {
	items := []app{
		{ID: 1, Name: "云记笔记", Category: "办公", Summary: "多端同步的高效记录工具", Description: "云记笔记支持 Markdown、图片、语音和待办清单，适合会议记录、学习整理和项目协作。应用通过隐私合规检测，默认不开启敏感权限。", Rating: 4.9, Size: "86MB", Downloads: 1280, Verified: true, Tags: []string{"效率", "同步", "办公"}, Screenshots: []string{"智能编辑", "云端同步", "团队协作"}, Developer: "Blue Cloud Studio", Version: "3.8.2"},
		{ID: 2, Name: "星球旅人", Category: "游戏", Summary: "轻科幻放置冒险手游", Description: "星球旅人以低门槛放置玩法和精致星际美术为核心，支持离线收益、角色养成和好友互助。", Rating: 4.8, Size: "512MB", Downloads: 960, Verified: true, Tags: []string{"新游", "冒险", "预约"}, Screenshots: []string{"星际地图", "角色养成", "组队探索"}, Developer: "Nebula Games", Version: "1.4.0"},
		{ID: 3, Name: "轻剪辑", Category: "影音", Summary: "手机也能快速做大片", Description: "轻剪辑提供模板剪辑、字幕识别、封面设计和一键导出能力，适合短视频创作者快速完成内容生产。", Rating: 4.7, Size: "142MB", Downloads: 2280, Verified: true, Tags: []string{"视频", "模板", "创作"}, Screenshots: []string{"模板中心", "字幕识别", "高清导出"}, Developer: "Light Cut Team", Version: "6.2.1"},
		{ID: 4, Name: "隐私管家", Category: "工具", Summary: "权限检测与风险提醒", Description: "隐私管家帮助用户识别敏感权限、后台唤醒和风险行为，提供清晰的权限解释与关闭建议。", Rating: 4.6, Size: "34MB", Downloads: 1730, Verified: true, Tags: []string{"安全", "权限", "清理"}, Screenshots: []string{"权限雷达", "风险报告", "一键优化"}, Developer: "SafeLab", Version: "2.5.7"},
		{ID: 5, Name: "每日英语", Category: "学习", Summary: "碎片时间练听说读写", Description: "每日英语提供词汇计划、情景听力、AI 跟读评分和学习打卡，帮助用户保持稳定学习节奏。", Rating: 4.9, Size: "118MB", Downloads: 890, Verified: true, Tags: []string{"英语", "打卡", "口语"}, Screenshots: []string{"词汇计划", "口语评分", "学习日历"}, Developer: "Daily Learn Inc.", Version: "5.1.3"},
		{ID: 6, Name: "邻里圈", Category: "社交", Summary: "发现附近生活与兴趣小组", Description: "邻里圈聚合本地活动、二手交易和兴趣小组，支持实名认证与内容安全审核。", Rating: 4.5, Size: "76MB", Downloads: 740, Verified: true, Tags: []string{"社区", "本地", "兴趣"}, Screenshots: []string{"附近动态", "兴趣小组", "活动报名"}, Developer: "Local Link", Version: "2.9.0"},
	}
	sort.Slice(items, func(i, j int) bool { return items[i].ID < items[j].ID })
	return items
}
