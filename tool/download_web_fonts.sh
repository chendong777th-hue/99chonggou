#!/usr/bin/env bash
# 下载 Web 内置 Noto Sans SC 简中子集（fontsource，约 2.4MB/字重）。
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DEST="$ROOT/assets/fonts"
BASE="https://cdn.jsdelivr.net/fontsource/fonts/noto-sans-sc@5.2.5"
mkdir -p "$DEST"
for spec in "400:NotoSansSC-Regular.ttf" "600:NotoSansSC-SemiBold.ttf" "700:NotoSansSC-Bold.ttf"; do
  weight="${spec%%:*}"
  file="${spec##*:}"
  echo "Downloading $file ..."
  curl -fsSL "$BASE/chinese-simplified-${weight}-normal.ttf" -o "$DEST/$file"
done
echo "Done. Files in $DEST:"
ls -lh "$DEST"
