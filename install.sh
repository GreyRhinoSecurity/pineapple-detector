#!/usr/bin/env bash
set -euo pipefail

REPO="https://github.com/GreyRhinoSecurity/pineapple-detector.git"
DEST="$HOME/pineapple-detector"

echo "🔽 Installing/updating Pineapple Chaser to $DEST …"

if [[ -d "$DEST/.git" ]]; then
  # Clean working tree?
  if git -C "$DEST" diff-index --quiet HEAD --; then
    echo "➡️  Clean repo – pulling latest…"
    git -C "$DEST" pull --rebase
  else
    echo "⚠️  Uncommitted changes detected – backing up and recloning"
    mv "$DEST" "${DEST}.backup.$(date +%Y%m%d%H%M%S)"
    git clone "$REPO" "$DEST"
  fi

elif [[ -d "$DEST" ]]; then
  echo "⚠️  $DEST exists but isn’t a Git repo – backing up and cloning fresh"
  mv "$DEST" "${DEST}.backup.$(date +%Y%m%d%H%M%S)"
  git clone "$REPO" "$DEST"
else
  echo "➡️  Cloning repository…"
  git clone "$REPO" "$DEST"
fi

echo "🔧 Setting executable bit…"
chmod +x "$DEST/pineapple-detector.sh"

cat <<EOF

✅ Pineapple Chaser is now at:
     $DEST/pineapple-detector.sh

▶️  To run:
     sudo $DEST/pineapple-detector.sh --interface wlan1

(Optional) Add to your PATH:
  ln -sfn "$DEST/pineapple-detector.sh" ~/.local/bin/pineapple-detector
  echo 'export PATH=\$HOME/.local/bin:\$PATH' >> ~/.bashrc

EOF
