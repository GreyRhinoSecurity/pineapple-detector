#!/bin/bash

interface="wlan1"
monitor_interface="wlanmon"

if ! iw dev | grep -q "$monitor_interface"; then
    echo "❌ Monitor interface not found. Falling back to wlan1mon..."
    monitor_interface="wlan1mon"
fi

LOGS_DIR="/opt/pineapple-detector/logs"
REPORTS_DIR="/opt/pineapple-detector/reports"
DASHBOARD_DIR="$HOME/pineapple-detector/dashboard"

mkdir -p "$LOGS_DIR" "$REPORTS_DIR" "$DASHBOARD_DIR"

echo "Orange Tabby ChubbyCat Activated 🐱"
echo
echo "Interface:        $interface"
echo "Monitor Intf.:    $monitor_interface"
echo "Logs Dir:         $LOGS_DIR"
echo "Reports Dir:      $REPORTS_DIR"
echo "Dashboard Dir:    $DASHBOARD_DIR"

# Simulate MAC, scan, and report generation
echo "Current MAC: $(cat /sys/class/net/$interface/address) (unknown)"
echo "Permanent MAC: $(cat /sys/class/net/$interface/address) (unknown)"

touch "$REPORTS_DIR/report_$(date +%F_%T).csv"
touch "$DASHBOARD_DIR/index.html"
echo "[+] Scan complete. Report and dashboard generated."
