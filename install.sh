#!/usr/bin/env bash
set -euo pipefail

REPO="https://github.com/GreyRhinoSecurity/pineapple-detector.git"
DEST="$HOME/pineapple-detector"

echo "🔽 Installing/updating Pineapple Chaser to $DEST …"

if [[ -d "$DEST/.git" ]]; then
  echo "➡️  Existing install detected. Pulling latest changes…"
  git -C "$DEST" pull --rebase
else
  echo "➡️  Cloning repository…"
  git clone "$REPO" "$DEST"
fi

echo "🔧 Setting executable bit…"
chmod +x "$DEST/pineapple-detector.sh"

cat <<EOF

✅ Pineapple Chaser installed at:
     $DEST/pineapple-detector.sh

▶️  To run:
     sudo $DEST/pineapple-detector.sh --interface wlan1

(Optional) Add to your PATH:
  ln -sfn "$DEST/pineapple-detector.sh" ~/.local/bin/pineapple-detector
  echo 'export PATH=\$HOME/.local/bin:\$PATH' >> ~/.bashrc

EOF
