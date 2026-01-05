package config

import (
	"os"
	"gopkg.in/yaml.v3"
)

type Config struct {
	Cloudflare struct {
		ZoneID   string `yaml:"zone_id"`
		APIToken string `yaml:"api_token"`
	} `yaml:"cloudflare"`
	Options struct {
		Proxied   bool   `yaml:"proxied"`
		TTL       int    `yaml:"ttl"`
		Interface string `yaml:"interface"`
	} `yaml:"options"`
	Domains []Domain `yaml:"domains"`
	Notifications struct {
		Telegram struct {
			Enabled  bool   `yaml:"enabled"`
			BotToken string `yaml:"bot_token"`
			ChatID   string `yaml:"chat_id"`
		} `yaml:"telegram"`
		Discord struct {
			Enabled    bool   `yaml:"enabled"`
			WebhookURL string `yaml:"webhook_url"`
		} `yaml:"discord"`
	} `yaml:"notifications"`
}

type Domain struct {
	Name    string `yaml:"name"`
	Proxied *bool  `yaml:"proxied,omitempty"`
	IPv4    *bool  `yaml:"ipv4,omitempty"`
	IPv6    *bool  `yaml:"ipv6,omitempty"`
	IPType  string `yaml:"ip_type,omitempty"`
	TTL     *int   `yaml:"ttl,omitempty"`
}

func LoadConfig(path string) (*Config, error) {
	file, err := os.ReadFile(path)
	if err != nil {
		return nil, err
	}
	var cfg Config
	err = yaml.Unmarshal(file, &cfg)
	if err != nil {
		return nil, err
	}
	return &cfg, nil
}
