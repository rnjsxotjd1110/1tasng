#!/usr/bin/env bash
# Cross-compile release binaries into dist/.
set -euo pipefail
cd "$(dirname "$0")"
VERSION="${VERSION:-1.0.0}"
mkdir -p dist
build() {
  local goos=$1 goarch=$2 out=$3
  echo "building $out"
  CGO_ENABLED=0 GOOS=$goos GOARCH=$goarch \
    go build -trimpath -ldflags "-s -w -X main.version=$VERSION" -o "dist/$out" .
}
build windows amd64 ember-bridge-windows-amd64.exe
build windows arm64 ember-bridge-windows-arm64.exe
build darwin  arm64 ember-bridge-macos-arm64
build linux   amd64 ember-bridge-linux-amd64
(cd dist && sha256sum ember-bridge-* > SHA256SUMS.txt)
