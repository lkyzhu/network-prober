package main

import (
	"encoding/json"
	"flag"
	"fmt"
	"io"
	"log"
	"net/http"
	"os"
	"strconv"
	"strings"
)

const Version = "1.0.0"

var store *Store

type Config struct {
	Listen   string `json:"listen,omitempty"`
	Store    string `json:"store,omitempty"`
	LogLevel string `json:"log_level,omitempty"`
}

func loadConfig(path string) (*Config, error) {
	b, err := os.ReadFile(path)
	if err != nil {
		return nil, err
	}
	var cfg Config
	if err := json.Unmarshal(b, &cfg); err != nil {
		return nil, err
	}
	return &cfg, nil
}

func main() {
	listen := flag.String("listen", ":8080", "listen address (default :8080)")
	logLevel := flag.String("log-level", "info", "log level: debug, info, warn, error")
	storePath := flag.String("store", "data/store.json", "store file path")
	confPath := flag.String("conf", "", "path to config.json (overrides individual flags)")
	showVersion := flag.Bool("version", false, "show version and exit")
	showVersionV := flag.Bool("v", false, "show version and exit (shorthand)")
	flag.Parse()

	if *showVersion || *showVersionV {
		fmt.Printf("network-prober version %s\n", Version)
		os.Exit(0)
	}

	if *confPath != "" {
		cfg, err := loadConfig(*confPath)
		if err != nil {
			log.Fatalf("failed to load config %s: %v", *confPath, err)
		}
		if cfg.Listen != "" {
			*listen = cfg.Listen
		}
		if cfg.Store != "" {
			*storePath = cfg.Store
		}
		if cfg.LogLevel != "" {
			*logLevel = cfg.LogLevel
		}
	}

	setLogLevel(*logLevel)

	var err error
	store, err = NewStore(*storePath)
	if err != nil {
		log.Fatalf("failed to init store: %v", err)
	}

	http.Handle("/static/", http.StripPrefix("/static/", http.FileServer(http.Dir("static"))))
	http.HandleFunc("/", serveIndex)
	http.HandleFunc("/api/modules", handleModules)
	http.HandleFunc("/api/modules/", handleModuleByID)
	http.HandleFunc("/api/items", handleItems)
	http.HandleFunc("/api/items/", handleItemByID)
	http.HandleFunc("/api/items/import", handleImportItems)
	http.HandleFunc("/api/items/move", handleMoveItem)
	http.HandleFunc("/api/detect", handleDetect)
	http.HandleFunc("/api/modules/export", handleExportModule)
	http.HandleFunc("/api/modules/import", handleImportModule)
	http.HandleFunc("/api/cert/upload", handleCertUpload)

	log.Printf("network-prober v%s starting on %s", Version, *listen)
	fmt.Printf("Server started at http://localhost%s\n", *listen)
	log.Fatal(http.ListenAndServe(*listen, nil))
}

func setLogLevel(level string) {
	switch strings.ToLower(level) {
	case "debug":
		log.SetFlags(log.Ldate | log.Ltime | log.Lshortfile)
	case "warn", "error":
		log.SetFlags(0)
		log.SetOutput(os.Stderr)
	default:
		log.SetFlags(log.Ldate | log.Ltime)
	}
}

func serveIndex(w http.ResponseWriter, r *http.Request) {
	if r.URL.Path != "/" {
		http.NotFound(w, r)
		return
	}
	http.ServeFile(w, r, "static/index.html")
}

func jsonResp(w http.ResponseWriter, data interface{}) {
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(data)
}

func jsonErr(w http.ResponseWriter, msg string, code int) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(code)
	json.NewEncoder(w).Encode(map[string]string{"error": msg})
}

func handleModules(w http.ResponseWriter, r *http.Request) {
	switch r.Method {
	case http.MethodGet:
		modules := store.GetModules()
		if modules == nil {
			modules = []Module{}
		}
		jsonResp(w, modules)

	case http.MethodPost:
		var req CreateModuleReq
		if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
			jsonErr(w, "invalid request body", http.StatusBadRequest)
			return
		}
		if req.Name == "" {
			jsonErr(w, "name is required", http.StatusBadRequest)
			return
		}
		m, err := store.CreateModule(req.Name, req.Description, req.ParentID)
		if err != nil {
			jsonErr(w, err.Error(), http.StatusInternalServerError)
			return
		}
		jsonResp(w, m)

	default:
		jsonErr(w, "method not allowed", http.StatusMethodNotAllowed)
	}
}

func handleModuleByID(w http.ResponseWriter, r *http.Request) {
	idStr := strings.TrimPrefix(r.URL.Path, "/api/modules/")
	id, err := strconv.Atoi(idStr)
	if err != nil {
		jsonErr(w, "invalid module id", http.StatusBadRequest)
		return
	}

	switch r.Method {
	case http.MethodDelete:
		if err := store.DeleteModule(id); err != nil {
			jsonErr(w, err.Error(), http.StatusInternalServerError)
			return
		}
		jsonResp(w, map[string]string{"status": "deleted"})

	case http.MethodPut:
		var req MoveModuleReq
		if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
			jsonErr(w, "invalid request body", http.StatusBadRequest)
			return
		}
		if err := store.MoveModule(id, req.ParentID); err != nil {
			jsonErr(w, err.Error(), http.StatusInternalServerError)
			return
		}
		jsonResp(w, map[string]string{"status": "moved"})

	default:
		jsonErr(w, "method not allowed", http.StatusMethodNotAllowed)
	}
}

func handleItems(w http.ResponseWriter, r *http.Request) {
	switch r.Method {
	case http.MethodGet:
		moduleIDStr := r.URL.Query().Get("module_id")
		if moduleIDStr == "" {
			items := store.GetAllProbeItems()
			if items == nil {
				items = []ProbeItem{}
			}
			jsonResp(w, items)
			return
		}
		moduleID, err := strconv.Atoi(moduleIDStr)
		if err != nil {
			jsonErr(w, "invalid module_id", http.StatusBadRequest)
			return
		}
		items := store.GetProbeItems(moduleID)
		if items == nil {
			items = []ProbeItem{}
		}
		jsonResp(w, items)

	case http.MethodPost:
		var req CreateItemReq
		if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
			jsonErr(w, "invalid request body", http.StatusBadRequest)
			return
		}
		if req.Address == "" {
			jsonErr(w, "address is required", http.StatusBadRequest)
			return
		}
		if req.Protocol == "" {
			req.Protocol = ProtocolHTTP
		}
		if req.ProbeType == "" {
			req.ProbeType = ProbeTypeFull
		}
		it, err := store.CreateProbeItem(req)
		if err != nil {
			jsonErr(w, err.Error(), http.StatusInternalServerError)
			return
		}
		jsonResp(w, it)

	default:
		jsonErr(w, "method not allowed", http.StatusMethodNotAllowed)
	}
}

func handleItemByID(w http.ResponseWriter, r *http.Request) {
	idStr := strings.TrimPrefix(r.URL.Path, "/api/items/")
	id, err := strconv.Atoi(idStr)
	if err != nil {
		jsonErr(w, "invalid item id", http.StatusBadRequest)
		return
	}

	switch r.Method {
	case http.MethodDelete:
		if err := store.DeleteProbeItem(id); err != nil {
			jsonErr(w, err.Error(), http.StatusInternalServerError)
			return
		}
		jsonResp(w, map[string]string{"status": "deleted"})

	case http.MethodGet:
		items := store.GetAllProbeItems()
		for _, it := range items {
			if it.ID == id {
				jsonResp(w, it)
				return
			}
		}
		jsonErr(w, "not found", http.StatusNotFound)

	case http.MethodPut:
		var req UpdateItemReq
		if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
			jsonErr(w, "invalid request body", http.StatusBadRequest)
			return
		}
		updated, err := store.UpdateProbeItem(id, req)
		if err != nil {
			jsonErr(w, err.Error(), http.StatusInternalServerError)
			return
		}
		jsonResp(w, updated)

	default:
		jsonErr(w, "method not allowed", http.StatusMethodNotAllowed)
	}
}

func handleImportItems(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		jsonErr(w, "method not allowed", http.StatusMethodNotAllowed)
		return
	}
	var req ImportRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		jsonErr(w, "invalid request body", http.StatusBadRequest)
		return
	}
	if len(req.Addresses) == 0 && len(req.Items) == 0 {
		jsonErr(w, "addresses or items is required", http.StatusBadRequest)
		return
	}
	if req.Protocol == "" {
		req.Protocol = ProtocolHTTP
	}
	if req.ProbeType == "" {
		req.ProbeType = ProbeTypeFull
	}
	items, err := store.ImportItems(req)
	if err != nil {
		jsonErr(w, err.Error(), http.StatusInternalServerError)
		return
	}
	jsonResp(w, items)
}

func handleMoveItem(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost && r.Method != http.MethodPut {
		jsonErr(w, "method not allowed", http.StatusMethodNotAllowed)
		return
	}
	var req struct {
		ID          int `json:"id"`
		NewModuleID int `json:"new_module_id"`
		ModuleID    int `json:"module_id"`
		SortOrder   int `json:"sort_order"`
	}
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		jsonErr(w, "invalid request body", http.StatusBadRequest)
		return
	}
	id := req.ID
	if id == 0 {
		idStr := r.URL.Query().Get("id")
		if idStr != "" {
			id, _ = strconv.Atoi(idStr)
		}
	}
	if id == 0 {
		jsonErr(w, "item id is required", http.StatusBadRequest)
		return
	}
	targetModule := req.NewModuleID
	if targetModule == 0 {
		targetModule = req.ModuleID
	}
	if err := store.MoveItem(id, targetModule); err != nil {
		jsonErr(w, err.Error(), http.StatusInternalServerError)
		return
	}
	jsonResp(w, map[string]string{"status": "moved"})
}

func handleDetect(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		jsonErr(w, "method not allowed", http.StatusMethodNotAllowed)
		return
	}

	var req ProbeTaskRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		jsonErr(w, "invalid request body", http.StatusBadRequest)
		return
	}
	if len(req.ItemIDs) == 0 {
		jsonErr(w, "item_ids is required", http.StatusBadRequest)
		return
	}

	items := store.GetProbeItemsByIDs(req.ItemIDs)
	if len(items) == 0 {
		jsonErr(w, "no items found", http.StatusNotFound)
		return
	}

	var results []ProbeResult
	for _, item := range items {
		result := detectItem(item)
		store.SaveResult(result)
		results = append(results, result)
	}

	jsonResp(w, results)
}

func handleExportModule(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		jsonErr(w, "method not allowed", http.StatusMethodNotAllowed)
		return
	}
	idStr := r.URL.Query().Get("module_id")
	if idStr == "" {
		jsonErr(w, "module_id is required", http.StatusBadRequest)
		return
	}
	id, err := strconv.Atoi(idStr)
	if err != nil {
		jsonErr(w, "invalid module_id", http.StatusBadRequest)
		return
	}
	data := store.ExportModule(id)
	if data == nil {
		jsonErr(w, "module not found", http.StatusNotFound)
		return
	}
	jsonResp(w, data)
}

func handleImportModule(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		jsonErr(w, "method not allowed", http.StatusMethodNotAllowed)
		return
	}
	var req ImportModuleRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		jsonErr(w, "invalid request body", http.StatusBadRequest)
		return
	}
	if len(req.Modules) == 0 {
		jsonErr(w, "modules is required", http.StatusBadRequest)
		return
	}
	var created []int
	for _, mod := range req.Modules {
		id, err := store.ImportModuleTree(mod, req.ParentID)
		if err != nil {
			jsonErr(w, err.Error(), http.StatusInternalServerError)
			return
		}
		created = append(created, id)
	}
	jsonResp(w, map[string]interface{}{"created": created})
}

func handleCertUpload(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		jsonErr(w, "method not allowed", http.StatusMethodNotAllowed)
		return
	}

	r.ParseMultipartForm(10 << 20)
	file, _, err := r.FormFile("cert")
	if err != nil {
		jsonErr(w, "failed to read cert file", http.StatusBadRequest)
		return
	}
	defer file.Close()

	data, err := io.ReadAll(file)
	if err != nil {
		jsonErr(w, "failed to read cert data", http.StatusInternalServerError)
		return
	}

	jsonResp(w, map[string]string{
		"cert_name": r.FormValue("name"),
		"cert_data": string(data),
	})
}
