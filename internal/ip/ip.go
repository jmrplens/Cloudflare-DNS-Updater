package ip

import (
	"context"
	"io"
	"net"
	"net/http"
	"strings"
	"time"
)

func GetPublicIP(version int) (string, error) {
	services := []string{
		"https://icanhazip.com",
		"https://ifconfig.co",
		"https://api.ipify.org",
	}
	if version == 6 {
		services = []string{
			"https://icanhazip.com",
			"https://ifconfig.co",
			"https://api6.ipify.org",
		}
	}

	client := &http.Client{
		Timeout: 5 * time.Second,
		Transport: &http.Transport{
			Proxy: http.ProxyFromEnvironment,
			DialContext: (&net.Dialer{
				Timeout:   5 * time.Second,
				KeepAlive: 30 * time.Second,
			}).DialContext,
		},
	}

	network := "tcp4"
	if version == 6 {
		network = "tcp6"
	}

	for _, svc := range services {
		req, _ := http.NewRequest("GET", svc, nil)
		// Force network version
		dialer := net.Dialer{Timeout: 5 * time.Second}
		client.Transport.(*http.Transport).DialContext = func(ctx context.Context, _, addr string) (net.Conn, error) {
			return dialer.DialContext(ctx, network, addr)
		}

		resp, err := client.Do(req)
		if err != nil {
			continue
		}
		defer resp.Body.Close()
		body, _ := io.ReadAll(resp.Body)
		ip := strings.TrimSpace(string(body))
		if net.ParseIP(ip) != nil {
			return ip, nil
		}
	}
	return "", io.EOF
}

func GetIPv6FromInterface(ifaceName string) (string, error) {
	ifaces, err := net.Interfaces()
	if err != nil {
		return "", err
	}

	for _, iface := range ifaces {
		if ifaceName != "" && iface.Name != ifaceName {
			continue
		}
		// If no ifaceName, we'll try to find a suitable global one
		addrs, err := iface.Addrs()
		if err != nil {
			continue
		}
		for _, addr := range addrs {
			ipnet, ok := addr.(*net.IPNet)
			if !ok {
				continue
			}
			ip := ipnet.IP
			if ip.To4() == nil && ip.IsGlobalUnicast() {
				return ip.String(), nil
			}
		}
	}
	return "", io.EOF
}
