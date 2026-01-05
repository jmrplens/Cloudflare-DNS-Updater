package cloudflare

import (
	"bytes"
	"encoding/json"
	"fmt"
	"net/http"
	"time"
)

const CF_API_URL = "https://api.cloudflare.com/client/v4"

type Record struct {
	ID      string `json:"id"`
	Type    string `json:"type"`
	Name    string `json:"name"`
	Content string `json:"content"`
	Proxied bool   `json:"proxied"`
	TTL     int    `json:"ttl"`
	ModifiedOn string `json:"modified_on"`
}

type Response struct {
	Success bool     `json:"success"`
	Errors  []any    `json:"errors"`
	Result  []Record `json:"result"`
}

type BatchResponse struct {
	Success bool `json:"success"`
	Result  struct {
		Puts []Record `json:"puts"`
	} `json:"result"`
}

func GetRecords(zoneID, token, recordType string) ([]Record, error) {
	url := fmt.Sprintf("%s/zones/%s/dns_records?per_page=500", CF_API_URL, zoneID)
	if recordType != "" {
		url += "&type=" + recordType
	}

	req, err := http.NewRequest("GET", url, nil)
	if err != nil {
		return nil, err
	}
	req.Header.Set("Authorization", "Bearer "+token)
	req.Header.Set("Content-Type", "application/json")

	client := &http.Client{Timeout: 10 * time.Second}
	resp, err := client.Do(req)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()

	var cfResp Response
	if err := json.NewDecoder(resp.Body).Decode(&cfResp); err != nil {
		return nil, err
	}
	if !cfResp.Success {
		return nil, fmt.Errorf("Cloudflare API error: %v", cfResp.Errors)
	}
	return cfResp.Result, nil
}

func BatchUpdate(zoneID, token string, records []Record) (*BatchResponse, error) {
	url := fmt.Sprintf("%s/zones/%s/dns_records/batch", CF_API_URL, zoneID)
	payload := map[string]any{"puts": records}
	data, _ := json.Marshal(payload)

	req, _ := http.NewRequest("POST", url, bytes.NewBuffer(data))
	req.Header.Set("Authorization", "Bearer "+token)
	req.Header.Set("Content-Type", "application/json")

	client := &http.Client{Timeout: 10 * time.Second}
	resp, err := client.Do(req)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()

	var batchResp BatchResponse
	if err := json.NewDecoder(resp.Body).Decode(&batchResp); err != nil {
		return nil, err
	}
	return &batchResp, nil
}
