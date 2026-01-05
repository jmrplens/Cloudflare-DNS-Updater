package main

import (
	"flag"
	"fmt"
	"os"

	"github.com/jmrplens/cloudflare-dns-updater/internal/cloudflare"
	"github.com/jmrplens/cloudflare-dns-updater/internal/config"
	"github.com/jmrplens/cloudflare-dns-updater/internal/ip"
)

var (
	silentFlag bool
	debugFlag  bool
	forceFlag  bool
)

func init() {
	flag.BoolVar(&silentFlag, "silent", false, "Suppress non-error output")
	flag.BoolVar(&silentFlag, "s", false, "Suppress non-error output")
	flag.BoolVar(&debugFlag, "debug", false, "Enable verbose logging")
	flag.BoolVar(&debugFlag, "d", false, "Enable verbose logging")
	flag.BoolVar(&forceFlag, "force", false, "Force update even if IPs match")
	flag.BoolVar(&forceFlag, "f", false, "Force update even if IPs match")
}

func logInfo(msg string) {
	if !silentFlag {
		fmt.Printf("[INFO] %s\n", msg)
	}
}

func logSuccess(msg string) {
	if !silentFlag {
		fmt.Printf("[OK] %s\n", msg)
	}
}

func logDebug(msg string) {
	if debugFlag {
		fmt.Printf("[DEBUG] %s\n", msg)
	}
}

func logError(msg string) {
	fmt.Fprintf(os.Stderr, "[ERROR] %s\n", msg)
}

func main() {
	flag.Parse()
	configPath := "cloudflare-dns.yaml"
	if flag.NArg() > 0 {
		configPath = flag.Arg(0)
	}

	logInfo("Starting Cloudflare DNS Updater (Go Edition)...")

	cfg, err := config.LoadConfig(configPath)
	if err != nil {
		logError(fmt.Sprintf("Failed to load config: %v", err))
		os.Exit(1)
	}

	// 1. Detect IPs
	ipv4, _ := ip.GetPublicIP(4)
	ipv6 := ""
	if cfg.Options.Interface != "" {
		ipv6, _ = ip.GetIPv6FromInterface(cfg.Options.Interface)
	}
	if ipv6 == "" {
		ipv6, _ = ip.GetPublicIP(6)
	}

	if ipv4 != "" { logSuccess("Detected IPv4: " + ipv4) }
	if ipv6 != "" { logSuccess("Detected IPv6: " + ipv6) }

	// 2. Fetch CF Records
	cfRecords, err := cloudflare.GetRecords(cfg.Cloudflare.ZoneID, cfg.Cloudflare.APIToken, "")
	if err != nil {
		logError(fmt.Sprintf("Failed to fetch records: %v", err))
		os.Exit(1)
	}
	logInfo(fmt.Sprintf("Parsed %d records from Cloudflare.", len(cfRecords)))

	// 3. Compare and Queue
	var updates []cloudflare.Record
	for _, d := range cfg.Domains {
		// Default values
		updateV4 := true
		updateV6 := true
		proxied := cfg.Options.Proxied
		ttl := cfg.Options.TTL

		if d.IPv4 != nil { updateV4 = *d.IPv4 }
		if d.IPv6 != nil { updateV6 = *d.IPv6 }
		if d.Proxied != nil { proxied = *d.Proxied }
		if d.TTL != nil { ttl = *d.TTL }
		if d.IPType == "ipv4" { updateV6 = false }
		if d.IPType == "ipv6" { updateV4 = false }

		for _, r := range cfRecords {
			if r.Name != d.Name { continue }
			
			isV4Match := r.Type == "A" && updateV4 && ipv4 != ""
			isV6Match := r.Type == "AAAA" && updateV6 && ipv6 != ""

			if isV4Match || isV6Match {
				targetIP := ipv4
				if r.Type == "AAAA" { targetIP = ipv6 }

				if forceFlag || r.Content != targetIP || r.Proxied != proxied {
					logInfo(fmt.Sprintf("Queuing update for %s (%s): %s -> %s", d.Name, r.Type, r.Content, targetIP))
					r.Content = targetIP
					r.Proxied = proxied
					r.TTL = ttl
					updates = append(updates, r)
				} else {
					logDebug(fmt.Sprintf("  - %s record OK (%s)", r.Type, r.Content))
				}
			}
		}
	}

	// 4. Batch Update
	if len(updates) > 0 {
		logInfo(fmt.Sprintf("Pushing %d updates to Cloudflare...", len(updates)))
		resp, err := cloudflare.BatchUpdate(cfg.Cloudflare.ZoneID, cfg.Cloudflare.APIToken, updates)
		if err != nil {
			logError(fmt.Sprintf("Batch update failed: %v", err))
		} else if resp.Success {
			logSuccess("Successfully updated records!")
			if debugFlag {
				for _, r := range resp.Result.Puts {
					logSuccess(fmt.Sprintf("API Verified: %s (%s) updated at %s", r.Name, r.Type, r.ModifiedOn))
				}
			}
		}
	} else {
		logSuccess("No changes needed.")
	}
}
