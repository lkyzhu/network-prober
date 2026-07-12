package main

import (
	"context"
	"crypto/sha256"
	"crypto/tls"
	"crypto/x509"
	"fmt"
	"net"
	"net/http"
	"net/url"
	"time"
)

func detectItem(item ProbeItem) ProbeResult {
	res := ProbeResult{
		ItemID:    item.ID,
		Address:   item.Address,
		Protocol:  item.Protocol,
		ProbeType: item.ProbeType,
		Status:    StatusSucc,
		CreatedAt: time.Now(),
	}

	switch item.Protocol {
	case ProtocolTCP:
		res.Results = detectTCP(item)
	case ProtocolHTTP:
		res.Results = detectHTTP(item)
	case ProtocolUDP:
		res.Results = detectUDP(item)
	default:
		res.Status = StatusFail
		res.Error = fmt.Sprintf("unsupported protocol: %s", item.Protocol)
		return res
	}

	for _, r := range res.Results {
		if r.Status == StatusFail {
			res.Status = StatusFail
			break
		}
	}
	return res
}

func getIPs(hostname string, probeType string) ([]string, error) {
	ips, err := net.LookupIP(hostname)
	if err != nil {
		return nil, err
	}
	var result []string
	for _, ip := range ips {
		if ipv4 := ip.To4(); ipv4 != nil {
			result = append(result, ipv4.String())
		}
	}
	if len(result) == 0 {
		for _, ip := range ips {
			result = append(result, ip.String())
		}
	}
	if probeType == ProbeTypeRegular && len(result) > 0 {
		result = result[:1]
	}
	return result, nil
}

func detectTCP(item ProbeItem) []SingleProbeResult {
	host, port, err := net.SplitHostPort(item.Address)
	if err != nil {
		return []SingleProbeResult{{
			Status:       StatusFail,
			ErrorMessage: fmt.Sprintf("invalid address: %v", err),
		}}
	}

	ips, err := getIPs(host, item.ProbeType)
	if err != nil {
		return []SingleProbeResult{{
			Status:       StatusFail,
			ErrorMessage: fmt.Sprintf("dns lookup failed: %v", err),
		}}
	}

	var certPool *x509.CertPool
	if item.CertData != "" {
		certPool = x509.NewCertPool()
		certPool.AppendCertsFromPEM([]byte(item.CertData))
	}

	var results []SingleProbeResult
	for _, ip := range ips {
		sr := SingleProbeResult{IP: ip}

		target := fmt.Sprintf("%s:%s", ip, port)
		dnsStart := time.Now()
		_, _ = net.LookupIP(host)
		sr.DNSCostMs = float64(time.Since(dnsStart).Microseconds()) / 1000.0

		start := time.Now()
		dialer := &net.Dialer{Timeout: 5 * time.Second}
		conn, err := dialer.DialContext(context.Background(), "tcp", target)
		if err != nil {
			sr.Status = StatusFail
			sr.ErrorMessage = fmt.Sprintf("tcp dial failed: %v", err)
			sr.TotalCostMs = float64(time.Since(start).Microseconds()) / 1000.0
			results = append(results, sr)
			continue
		}
		sr.ConnectCostMs = float64(time.Since(start).Microseconds()) / 1000.0
		sr.FirstPacketCostMs = sr.ConnectCostMs

		tlsConfig := &tls.Config{
			ServerName: host,
		}
		if certPool != nil {
			tlsConfig.RootCAs = certPool
		}
		tlsConn := tls.Client(conn, tlsConfig)
		tlsStart := time.Now()
		err = tlsConn.Handshake()
		if err == nil {
			sr.FirstPacketCostMs = float64(time.Since(tlsStart).Microseconds()) / 1000.0
			connState := tlsConn.ConnectionState()
			sr.CertSubject, sr.CertIssuer, sr.CertNotBefore, sr.CertNotAfter, sr.CertFingerprint, sr.CertVerified = extractCertInfo(connState)
			tlsConn.Close()
			sr.Status = StatusSucc
			sr.StatusCode = 0
			sr.TotalCostMs = float64(time.Since(start).Microseconds()) / 1000.0
			results = append(results, sr)
			continue
		}

		tlsConn.Close()
		sr.FirstPacketCostMs = sr.ConnectCostMs
		sr.Status = StatusSucc
		sr.StatusCode = 0
		sr.TotalCostMs = float64(time.Since(start).Microseconds()) / 1000.0
		results = append(results, sr)
	}
	return results
}

func detectHTTP(item ProbeItem) []SingleProbeResult {
	reqURL, err := url.Parse(item.Address)
	if err != nil {
		return []SingleProbeResult{{
			Status:       StatusFail,
			ErrorMessage: fmt.Sprintf("invalid url: %v", err),
		}}
	}

	hostname := reqURL.Hostname()
	port := reqURL.Port()
	if port == "" {
		if reqURL.Scheme == "https" {
			port = "443"
		} else {
			port = "80"
		}
	}

	ips, err := getIPs(hostname, item.ProbeType)
	if err != nil {
		return []SingleProbeResult{{
			Status:       StatusFail,
			ErrorMessage: fmt.Sprintf("dns lookup failed: %v", err),
		}}
	}

	var certPool *x509.CertPool
	if item.CertData != "" {
		certPool = x509.NewCertPool()
		certPool.AppendCertsFromPEM([]byte(item.CertData))
	}

	var results []SingleProbeResult
	for _, ip := range ips {
		sr := SingleProbeResult{IP: ip}

		dnsStart := time.Now()
		ips2, _ := net.LookupIP(hostname)
		sr.DNSCostMs = float64(time.Since(dnsStart).Microseconds()) / 1000.0
		_ = ips2

		totalStart := time.Now()

		dialStart := time.Now()
		conn, err := net.DialTimeout("tcp", fmt.Sprintf("%s:%s", ip, port), 5*time.Second)
		if err != nil {
			sr.Status = StatusFail
			sr.ErrorMessage = fmt.Sprintf("tcp dial failed: %v", err)
			sr.TotalCostMs = float64(time.Since(totalStart).Microseconds()) / 1000.0
			results = append(results, sr)
			continue
		}
		sr.ConnectCostMs = float64(time.Since(dialStart).Microseconds()) / 1000.0
		conn.Close()

		transport := &http.Transport{
			TLSClientConfig: &tls.Config{
				RootCAs:            certPool,
				ServerName:         hostname,
				InsecureSkipVerify: false,
			},
			DialContext: func(ctx context.Context, network, addr string) (net.Conn, error) {
				return net.DialTimeout("tcp", fmt.Sprintf("%s:%s", ip, port), 5*time.Second)
			},
		}

		client := http.Client{
			Transport: transport,
			Timeout:   10 * time.Second,
		}

		httpStart := time.Now()
		req, _ := http.NewRequestWithContext(context.Background(), http.MethodGet, item.Address, nil)
		resp, err := client.Do(req)
		if err != nil {
			sr.Status = StatusFail
			sr.ErrorMessage = fmt.Sprintf("http request failed: %v", err)
			sr.TotalCostMs = float64(time.Since(totalStart).Microseconds()) / 1000.0
			results = append(results, sr)
			continue
		}
		sr.FirstPacketCostMs = float64(time.Since(httpStart).Microseconds()) / 1000.0
		sr.StatusCode = resp.StatusCode
		
		// 从 resp.TLS 获取证书信息
		if resp.TLS != nil {
			sr.CertSubject, sr.CertIssuer, sr.CertNotBefore, sr.CertNotAfter, sr.CertFingerprint, sr.CertVerified = extractCertInfo(*resp.TLS)
		}
		
		resp.Body.Close()

		sr.Status = StatusSucc
		sr.Details = fmt.Sprintf("HTTP %d %s", resp.StatusCode, resp.Status)
		sr.TotalCostMs = float64(time.Since(totalStart).Microseconds()) / 1000.0
		results = append(results, sr)
	}
	return results
}

func detectUDP(item ProbeItem) []SingleProbeResult {
	host, port, err := net.SplitHostPort(item.Address)
	if err != nil {
		return []SingleProbeResult{{
			Status:       StatusFail,
			ErrorMessage: fmt.Sprintf("invalid address: %v", err),
		}}
	}

	ips, err := getIPs(host, item.ProbeType)
	if err != nil {
		return []SingleProbeResult{{
			Status:       StatusFail,
			ErrorMessage: fmt.Sprintf("dns lookup failed: %v", err),
		}}
	}

	var results []SingleProbeResult
	for _, ip := range ips {
		sr := SingleProbeResult{IP: ip}

		dnsStart := time.Now()
		_, _ = net.LookupIP(host)
		sr.DNSCostMs = float64(time.Since(dnsStart).Microseconds()) / 1000.0

		start := time.Now()
		target := fmt.Sprintf("%s:%s", ip, port)
		conn, err := net.DialTimeout("udp", target, 5*time.Second)
		if err != nil {
			sr.Status = StatusFail
			sr.ErrorMessage = fmt.Sprintf("udp dial failed: %v", err)
			sr.TotalCostMs = float64(time.Since(start).Microseconds()) / 1000.0
			results = append(results, sr)
			continue
		}
		sr.ConnectCostMs = float64(time.Since(start).Microseconds()) / 1000.0
		sr.FirstPacketCostMs = sr.ConnectCostMs
		conn.Close()

		sr.Status = StatusSucc
		sr.TotalCostMs = float64(time.Since(start).Microseconds()) / 1000.0
		results = append(results, sr)
	}
	return results
}

func extractCertInfo(connState tls.ConnectionState) (subject, issuer string, notBefore, notAfter time.Time, fingerprint string, verified bool) {
	if len(connState.PeerCertificates) == 0 {
		return
	}
	cert := connState.PeerCertificates[0]
	subject = cert.Subject.CommonName
	issuer = cert.Issuer.CommonName
	notBefore = cert.NotBefore
	notAfter = cert.NotAfter
	fingerprint = fmt.Sprintf("%x", sha256.Sum256(cert.Raw))
	verified = connState.VerifiedChains != nil && len(connState.VerifiedChains) > 0
	return
}
