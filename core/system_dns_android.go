//go:build android && cgo

package main

import (
	"github.com/metacubex/mihomo/dns"
	"strings"
)

func updateSystemDns(value string) {
	dns.UpdateSystemDNS(strings.Split(value, ","))
}
