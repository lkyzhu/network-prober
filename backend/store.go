package main

import (
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"sync"
	"time"
)

type Store struct {
	mu        sync.RWMutex
	data      DataStore
	storeFile string
}

func NewStore(storePath string) (*Store, error) {
	s := &Store{
		storeFile: storePath,
		data: DataStore{
			NextModuleID: 1,
			NextItemID:   1,
			NextResultID: 1,
		},
	}
	dir := filepath.Dir(s.storeFile)
	if err := os.MkdirAll(dir, 0755); err != nil {
		return nil, fmt.Errorf("create data dir: %w", err)
	}
	if _, err := os.Stat(s.storeFile); err == nil {
		b, err := os.ReadFile(s.storeFile)
		if err != nil {
			return nil, err
		}
		if len(b) > 0 {
			if err := json.Unmarshal(b, &s.data); err != nil {
				return nil, err
			}
		}
	}
	return s, nil
}

func (s *Store) save() error {
	b, err := json.MarshalIndent(s.data, "", "  ")
	if err != nil {
		return err
	}
	return os.WriteFile(s.storeFile, b, 0644)
}

func (s *Store) GetModules() []Module {
	s.mu.RLock()
	defer s.mu.RUnlock()
	res := make([]Module, len(s.data.Modules))
	copy(res, s.data.Modules)
	return res
}

func (s *Store) CreateModule(name, desc string, parentID int) (*Module, error) {
	s.mu.Lock()
	defer s.mu.Unlock()
	m := Module{
		ID:          s.data.NextModuleID,
		ParentID:    parentID,
		Name:        name,
		Description: desc,
		Order:       len(s.data.Modules),
		CreatedAt:   time.Now(),
	}
	s.data.NextModuleID++
	s.data.Modules = append(s.data.Modules, m)
	return &m, s.save()
}

func (s *Store) deleteModuleRecursive(id int) {
	children := []int{}
	for _, m := range s.data.Modules {
		if m.ParentID == id {
			children = append(children, m.ID)
		}
	}
	for _, cid := range children {
		s.deleteModuleRecursive(cid)
	}
	idx := -1
	for i, m := range s.data.Modules {
		if m.ID == id {
			idx = i
			break
		}
	}
	if idx != -1 {
		s.data.Modules = append(s.data.Modules[:idx], s.data.Modules[idx+1:]...)
	}
	var kept []ProbeItem
	for _, it := range s.data.ProbeItems {
		if it.ModuleID != id {
			kept = append(kept, it)
		}
	}
	s.data.ProbeItems = kept
}

func (s *Store) DeleteModule(id int) error {
	s.mu.Lock()
	defer s.mu.Unlock()
	s.deleteModuleRecursive(id)
	return s.save()
}

func (s *Store) MoveModule(id, newParentID int) error {
	s.mu.Lock()
	defer s.mu.Unlock()
	for i, m := range s.data.Modules {
		if m.ID == id {
			s.data.Modules[i].ParentID = newParentID
			break
		}
	}
	return s.save()
}

func (s *Store) MoveItem(id, newModuleID int) error {
	s.mu.Lock()
	defer s.mu.Unlock()
	for i, it := range s.data.ProbeItems {
		if it.ID == id {
			s.data.ProbeItems[i].ModuleID = newModuleID
			break
		}
	}
	return s.save()
}

func (s *Store) UpdateProbeItem(id int, req UpdateItemReq) (*ProbeItem, error) {
	s.mu.Lock()
	defer s.mu.Unlock()
	for i, it := range s.data.ProbeItems {
		if it.ID == id {
			if req.Address != "" {
				s.data.ProbeItems[i].Address = req.Address
			}
			if req.Protocol != "" {
				s.data.ProbeItems[i].Protocol = req.Protocol
			}
			if req.ProbeType != "" {
				s.data.ProbeItems[i].ProbeType = req.ProbeType
			}
			if req.ClearCert {
				s.data.ProbeItems[i].CertName = ""
				s.data.ProbeItems[i].CertData = ""
			} else if req.CertName != "" || req.CertData != "" {
				s.data.ProbeItems[i].CertName = req.CertName
				s.data.ProbeItems[i].CertData = req.CertData
			}
			if err := s.save(); err != nil {
				return nil, err
			}
			return &s.data.ProbeItems[i], nil
		}
	}
	return nil, fmt.Errorf("item %d not found", id)
}

func (s *Store) GetProbeItems(moduleID int) []ProbeItem {
	s.mu.RLock()
	defer s.mu.RUnlock()
	var res []ProbeItem
	for _, it := range s.data.ProbeItems {
		if it.ModuleID == moduleID {
			res = append(res, it)
		}
	}
	return res
}

func (s *Store) GetProbeItemsByIDs(ids []int) []ProbeItem {
	s.mu.RLock()
	defer s.mu.RUnlock()
	idSet := make(map[int]bool)
	for _, id := range ids {
		idSet[id] = true
	}
	var res []ProbeItem
	for _, it := range s.data.ProbeItems {
		if idSet[it.ID] {
			res = append(res, it)
		}
	}
	return res
}

func (s *Store) GetAllProbeItems() []ProbeItem {
	s.mu.RLock()
	defer s.mu.RUnlock()
	res := make([]ProbeItem, len(s.data.ProbeItems))
	copy(res, s.data.ProbeItems)
	return res
}

func (s *Store) CreateProbeItem(req CreateItemReq) (*ProbeItem, error) {
	s.mu.Lock()
	defer s.mu.Unlock()
	it := ProbeItem{
		ID:        s.data.NextItemID,
		ModuleID:  req.ModuleID,
		Address:   req.Address,
		Protocol:  req.Protocol,
		ProbeType: req.ProbeType,
		CertName:  req.CertName,
		CertData:  req.CertData,
		CreatedAt: time.Now(),
	}
	s.data.NextItemID++
	s.data.ProbeItems = append(s.data.ProbeItems, it)
	return &it, s.save()
}

func (s *Store) DeleteProbeItem(id int) error {
	s.mu.Lock()
	defer s.mu.Unlock()
	idx := -1
	for i, it := range s.data.ProbeItems {
		if it.ID == id {
			idx = i
			break
		}
	}
	if idx == -1 {
		return nil
	}
	s.data.ProbeItems = append(s.data.ProbeItems[:idx], s.data.ProbeItems[idx+1:]...)
	return s.save()
}

func (s *Store) ImportItems(req ImportRequest) ([]ProbeItem, error) {
	s.mu.Lock()
	defer s.mu.Unlock()
	var items []ProbeItem
	now := time.Now()

	src := req.Items
	if len(src) == 0 {
		for _, addr := range req.Addresses {
			src = append(src, ImportItem{Address: addr})
		}
	}

	for _, it := range src {
		pi := ProbeItem{
			ID:        s.data.NextItemID,
			ModuleID:  req.ModuleID,
			Address:   it.Address,
			Protocol:  req.Protocol,
			ProbeType: req.ProbeType,
			CreatedAt: now,
		}
		if it.CertData != "" {
			pi.CertName = it.CertName
			if pi.CertName == "" {
				pi.CertName = "custom.pem"
			}
			pi.CertData = it.CertData
		}
		s.data.NextItemID++
		s.data.ProbeItems = append(s.data.ProbeItems, pi)
		items = append(items, pi)
	}
	return items, s.save()
}

func (s *Store) SaveResult(r ProbeResult) error {
	s.mu.Lock()
	defer s.mu.Unlock()
	s.data.Results = append(s.data.Results, r)
	return s.save()
}
