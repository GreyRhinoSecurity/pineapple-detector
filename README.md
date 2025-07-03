# Pineapple Chaser WiFi Detector

**Detect rogue WiFi APs (Pineapples, Evil Twins) and generate a dashboard.**

## Features
- Auto-detect or specify interface
- CSV capture → JSON scoring → HTML dashboard
- Cleanup trap restores your interface to managed mode
- Optional wifite “attack” mode

## Installation
```bash
git clone https://github.com/GreyRhinoSecurity/pineapple-detector.git
cd pineapple-detector
chmod +x pineapple-detector.sh
```

## Usage
```bash
sudo ./pineapple-detector.sh --interface wlan1
sudo ./pineapple-detector.sh --no-open
```

## Install Script
You can quickly install/update via:

```bash
bash <(curl -s https://raw.githubusercontent.com/GreyRhinoSecurity/pineapple-detector/main/install.sh)
```

## License
MIT © 2025 GreyRhinoSecurity
