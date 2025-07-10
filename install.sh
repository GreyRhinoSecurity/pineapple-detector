#!/bin/bash

echo "[*] Installing Pineapple Detector..."

INSTALL_DIR="$HOME/.pineapple-detector"
BIN_LINK="/usr/local/bin/pineapple-detector"

mkdir -p "$INSTALL_DIR"
curl -sLo "$INSTALL_DIR/pineapple-detector.sh" "https://raw.githubusercontent.com/GreyRhinoSecurity/ChubbyCat-NG-Pineapple_Chasser/main/pineapple-detector.sh"
chmod +x "$INSTALL_DIR/pineapple-detector.sh"

sudo ln -sf "$INSTALL_DIR/pineapple-detector.sh" "$BIN_LINK"

echo "[+] Installed! You can now run: pineapple-detector"
