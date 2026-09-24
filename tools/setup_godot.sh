#!/usr/bin/env bash
# 클라우드(Linux) 컨테이너용: Godot 4.3 이 없으면 내려받아 /opt/godot 에 두고 `godot` 명령을 만든 뒤 임포트한다.
# 사용: bash tools/setup_godot.sh
set -euo pipefail
VERSION="4.3-stable"
DIR="/opt/godot"
BIN="$DIR/Godot_v${VERSION}_linux.x86_64"
if [ ! -x "$BIN" ]; then
  mkdir -p "$DIR"
  curl -sSL -o "$DIR/godot.zip" "https://github.com/godotengine/godot/releases/download/${VERSION}/Godot_v${VERSION}_linux.x86_64.zip"
  unzip -o -q "$DIR/godot.zip" -d "$DIR"
  rm -f "$DIR/godot.zip"
fi
ln -sf "$BIN" /usr/local/bin/godot
godot --version
cd "$(dirname "$0")/.."
godot --headless --import >/dev/null 2>&1 || true
echo "Godot 준비 완료: $(command -v godot)"
