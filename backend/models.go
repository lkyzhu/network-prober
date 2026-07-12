package main

import "time"

const (
	StatusSucc       = 0
	StatusFail       = -1
	ProbeTypeFull    = "full"
	ProbeTypeRegular = "regular"
	ProtocolTCP      = "tcp"
	ProtocolHTTP     = "http"
	ProtocolUDP      = "udp"
)

type Module struct {
	ID          int       `json:"id"`
	ParentID    int       `json:"parent_id"`
	Name        string    `json:"name"`
	Description string    `json:"description"`
	Order       int       `json:"order"`
	CreatedAt   time.Time `json:"created_at"`
}

type ProbeItem struct {
	ID        int       `json:"id"`
	ModuleID  int       `json:"module_id"`
	Address   string    `json:"address"`
	Protocol  string    `json:"protocol"`
	ProbeType string    `json:"probe_type"`
	CertName  string    `json:"cert_name,omitempty"`
	CertData  string    `json:"cert_data,omitempty"`
	CreatedAt time.Time `json:"created_at"`
}

type SingleProbeResult struct {
	IP                string    `json:"ip"`
	DNSCostMs         float64   `json:"dns_cost_ms"`
	ConnectCostMs     float64   `json:"connect_cost_ms"`
	FirstPacketCostMs float64   `json:"first_packet_cost_ms"`
	TotalCostMs       float64   `json:"total_cost_ms"`
	Status            int       `json:"status"`
	ErrorMessage      string    `json:"error_message,omitempty"`
	Details           string    `json:"details,omitempty"`
	StatusCode        int       `json:"status_code"`
	CertSubject       string    `json:"cert_subject,omitempty"`
	CertIssuer        string    `json:"cert_issuer,omitempty"`
	CertNotBefore     time.Time `json:"cert_not_before,omitempty"`
	CertNotAfter      time.Time `json:"cert_not_after,omitempty"`
	CertVerified      bool      `json:"cert_verified"`
	CertFingerprint   string    `json:"cert_fingerprint,omitempty"`
}

type ProbeResult struct {
	ItemID    int                 `json:"item_id"`
	Address   string              `json:"address"`
	Protocol  string              `json:"protocol"`
	ProbeType string              `json:"probe_type"`
	Results   []SingleProbeResult `json:"results"`
	Status    int                 `json:"status"`
	Error     string              `json:"error,omitempty"`
	CreatedAt time.Time           `json:"created_at"`
}

type ProbeTaskRequest struct {
	ItemIDs []int `json:"item_ids"`
}

type ImportItem struct {
	Address  string `json:"address"`
	CertName string `json:"cert_name,omitempty"`
	CertData string `json:"cert_data,omitempty"`
}

type ImportRequest struct {
	ModuleID  int          `json:"module_id"`
	Protocol  string       `json:"protocol"`
	ProbeType string       `json:"probe_type"`
	Addresses []string     `json:"addresses,omitempty"`
	Items     []ImportItem `json:"items,omitempty"`
}

type DataStore struct {
	Modules      []Module      `json:"modules"`
	ProbeItems   []ProbeItem   `json:"probe_items"`
	Results      []ProbeResult `json:"results"`
	NextModuleID int           `json:"next_module_id"`
	NextItemID   int           `json:"next_item_id"`
	NextResultID int           `json:"next_result_id"`
}

type CreateModuleReq struct {
	Name        string `json:"name"`
	Description string `json:"description"`
	ParentID    int    `json:"parent_id"`
}

type CreateItemReq struct {
	ModuleID  int    `json:"module_id"`
	Address   string `json:"address"`
	Protocol  string `json:"protocol"`
	ProbeType string `json:"probe_type"`
	CertName  string `json:"cert_name,omitempty"`
	CertData  string `json:"cert_data,omitempty"`
}

type MoveModuleReq struct {
	ParentID int `json:"parent_id"`
}

type MoveItemReq struct {
	ModuleID int `json:"module_id"`
}

type UpdateItemReq struct {
	Address    string `json:"address"`
	Protocol   string `json:"protocol"`
	ProbeType  string `json:"probe_type"`
	CertName   string `json:"cert_name,omitempty"`
	CertData   string `json:"cert_data,omitempty"`
	ClearCert  bool   `json:"clear_cert"`
}
