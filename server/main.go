package main

import (
	"encoding/json"
	"log"
	"net/http"
	"slices"
	"sort"
	"strings"
	"time"
)

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

type apiServer struct {
	apps []app
}

func main() {
	server := &apiServer{apps: seedApps()}
	mux := http.NewServeMux()
	mux.HandleFunc("/api/health", server.health)
	mux.HandleFunc("/api/apps", server.appsList)
	mux.HandleFunc("/api/apps/", server.appDetail)
	mux.HandleFunc("/api/categories", server.categories)
	mux.HandleFunc("/api/rankings", server.rankings)

	addr := ":8080"
	log.Printf("app store api listening on http://127.0.0.1%s", addr)
	if err := http.ListenAndServe(addr, withCORS(mux)); err != nil {
		log.Fatal(err)
	}
}

func (s *apiServer) health(w http.ResponseWriter, r *http.Request) {
	writeJSON(w, http.StatusOK, map[string]any{
		"ok":        true,
		"service":   "app-store-demo",
		"timestamp": time.Now().Format(time.RFC3339),
	})
}

func (s *apiServer) appsList(w http.ResponseWriter, r *http.Request) {
	query := strings.TrimSpace(r.URL.Query().Get("q"))
	category := strings.TrimSpace(r.URL.Query().Get("category"))

	items := make([]app, 0, len(s.apps))
	for _, item := range s.apps {
		if query != "" && !containsAny(item, query) {
			continue
		}
		if category != "" && item.Category != category {
			continue
		}
		items = append(items, item)
	}

	writeJSON(w, http.StatusOK, map[string]any{"apps": items})
}

func (s *apiServer) appDetail(w http.ResponseWriter, r *http.Request) {
	name := strings.TrimPrefix(r.URL.Path, "/api/apps/")
	for _, item := range s.apps {
		if strings.EqualFold(name, item.Name) {
			writeJSON(w, http.StatusOK, item)
			return
		}
	}
	writeJSON(w, http.StatusNotFound, map[string]any{"error": "app not found"})
}

func (s *apiServer) categories(w http.ResponseWriter, r *http.Request) {
	counts := map[string]int{}
	for _, item := range s.apps {
		counts[item.Category]++
	}

	type category struct {
		Name  string `json:"name"`
		Count int    `json:"count"`
	}

	items := make([]category, 0, len(counts))
	for name, count := range counts {
		items = append(items, category{Name: name, Count: count})
	}
	sort.Slice(items, func(i, j int) bool { return items[i].Name < items[j].Name })
	writeJSON(w, http.StatusOK, map[string]any{"categories": items})
}

func (s *apiServer) rankings(w http.ResponseWriter, r *http.Request) {
	typeName := r.URL.Query().Get("type")
	items := slices.Clone(s.apps)

	switch typeName {
	case "rating":
		sort.Slice(items, func(i, j int) bool { return items[i].Rating > items[j].Rating })
	case "new":
		sort.Slice(items, func(i, j int) bool { return items[i].ID > items[j].ID })
	default:
		sort.Slice(items, func(i, j int) bool { return items[i].Downloads > items[j].Downloads })
	}

	writeJSON(w, http.StatusOK, map[string]any{"apps": items})
}

func containsAny(item app, query string) bool {
	query = strings.ToLower(query)
	fields := []string{item.Name, item.Category, item.Summary, item.Developer}
	fields = append(fields, item.Tags...)
	for _, field := range fields {
		if strings.Contains(strings.ToLower(field), query) {
			return true
		}
	}
	return false
}

func withCORS(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Access-Control-Allow-Origin", "*")
		w.Header().Set("Access-Control-Allow-Methods", "GET, OPTIONS")
		w.Header().Set("Access-Control-Allow-Headers", "Content-Type")
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

func seedApps() []app {
	return []app{
		{
			ID:          1,
			Name:        "云记笔记",
			Category:    "办公",
			Summary:     "多端同步的高效记录工具",
			Description: "云记笔记支持 Markdown、图片、语音和待办清单，适合会议记录、学习整理和项目协作。应用通过隐私合规检测，默认不开启敏感权限。",
			Rating:      4.9,
			Size:        "86MB",
			Downloads:   1280,
			Verified:    true,
			Tags:        []string{"效率", "同步", "办公"},
			Screenshots: []string{"智能编辑", "云端同步", "团队协作"},
			Developer:   "Blue Cloud Studio",
			Version:     "3.8.2",
		},
		{
			ID:          2,
			Name:        "星球旅人",
			Category:    "游戏",
			Summary:     "轻科幻放置冒险手游",
			Description: "星球旅人以低门槛放置玩法和精致星际美术为核心，支持离线收益、角色养成和好友互助。",
			Rating:      4.8,
			Size:        "512MB",
			Downloads:   960,
			Verified:    true,
			Tags:        []string{"新游", "冒险", "预约"},
			Screenshots: []string{"星际地图", "角色养成", "组队探索"},
			Developer:   "Nebula Games",
			Version:     "1.4.0",
		},
		{
			ID:          3,
			Name:        "轻剪辑",
			Category:    "影音",
			Summary:     "手机也能快速做大片",
			Description: "轻剪辑提供模板剪辑、字幕识别、封面设计和一键导出能力，适合短视频创作者快速完成内容生产。",
			Rating:      4.7,
			Size:        "142MB",
			Downloads:   2280,
			Verified:    true,
			Tags:        []string{"视频", "模板", "创作"},
			Screenshots: []string{"模板中心", "字幕识别", "高清导出"},
			Developer:   "Light Cut Team",
			Version:     "6.2.1",
		},
		{
			ID:          4,
			Name:        "隐私管家",
			Category:    "工具",
			Summary:     "权限检测与风险提醒",
			Description: "隐私管家帮助用户识别敏感权限、后台唤醒和风险行为，提供清晰的权限解释与关闭建议。",
			Rating:      4.6,
			Size:        "34MB",
			Downloads:   1730,
			Verified:    true,
			Tags:        []string{"安全", "权限", "清理"},
			Screenshots: []string{"权限雷达", "风险报告", "一键优化"},
			Developer:   "SafeLab",
			Version:     "2.5.7",
		},
		{
			ID:          5,
			Name:        "每日英语",
			Category:    "学习",
			Summary:     "碎片时间练听说读写",
			Description: "每日英语提供词汇计划、情景听力、AI 跟读评分和学习打卡，帮助用户保持稳定学习节奏。",
			Rating:      4.9,
			Size:        "118MB",
			Downloads:   890,
			Verified:    true,
			Tags:        []string{"英语", "打卡", "口语"},
			Screenshots: []string{"词汇计划", "口语评分", "学习日历"},
			Developer:   "Daily Learn Inc.",
			Version:     "5.1.3",
		},
		{
			ID:          6,
			Name:        "邻里圈",
			Category:    "社交",
			Summary:     "发现附近生活与兴趣小组",
			Description: "邻里圈聚合本地活动、二手交易和兴趣小组，支持实名认证与内容安全审核。",
			Rating:      4.5,
			Size:        "76MB",
			Downloads:   740,
			Verified:    true,
			Tags:        []string{"社区", "本地", "兴趣"},
			Screenshots: []string{"附近动态", "兴趣小组", "活动报名"},
			Developer:   "Local Link",
			Version:     "2.9.0",
		},
	}
}
