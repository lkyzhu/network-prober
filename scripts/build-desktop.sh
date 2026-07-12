#!/bin/bash
set -e

VERSION=${VERSION:-$(git describe --tags --abbrev=0 2>/dev/null || echo "1.0.0")}
PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BACKEND_DIR="$PROJECT_ROOT/backend"
OUTPUT_DIR="$PROJECT_ROOT/build/desktop"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

info()  { echo -e "${GREEN}[INFO]${NC} $1"; }
warn()  { echo -e "${YELLOW}[WARN]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; }

usage() {
    prog=$(basename "$0")
    cat <<EOF
Usage: $prog <platform> <framework> [options]

Platform:
  linux|windows|macos

Framework:
  flutter    Flutter desktop client (desktop/flutter/)
  electron   Electron desktop client (desktop/electron/) reuses web/

Options:
  --arch     target architecture (default: amd64)

Examples:
  $prog linux flutter
  $prog linux electron
  $prog windows flutter
  $prog all flutter
EOF
    exit 1
}

build_backend() {
    local os=$1 arch=$2 ext=""
    [ "$os" = "windows" ] && ext=".exe"

    info "Compile backend: $os/$arch"
    GOOS=$os GOARCH=$arch CGO_ENABLED=0 \
        go build -ldflags "-s -w -X main.Version=$VERSION" \
        -o "$OUTPUT_DIR/backend/network-prober$ext" "$BACKEND_DIR"

    mkdir -p "$OUTPUT_DIR/backend/web"
    cp "$PROJECT_ROOT/web/index.html" "$OUTPUT_DIR/backend/web/"
    cp "$PROJECT_ROOT/web/style.css" "$OUTPUT_DIR/backend/web/"
    cp "$PROJECT_ROOT/web/app.js" "$OUTPUT_DIR/backend/web/"
    cp "$PROJECT_ROOT/web/import_template.csv" "$OUTPUT_DIR/backend/web/"
}

build_flutter() {
    local platform=$1 os=$2 arch=$3 ext=${4:-}
    local dir="$PROJECT_ROOT/desktop/flutter"

    info "Compile Flutter: $platform"

    cd "$dir"
    if [ "$platform" = "windows" ]; then
        flutter build windows --release
        local release_dir="build/windows/x64/runner/Release"
    elif [ "$platform" = "linux" ]; then
        flutter build linux --release
        local release_dir="build/linux/x64/release/bundle"
    elif [ "$platform" = "macos" ]; then
        flutter build macos --release
        local release_dir="build/macos/Build/Products/Release"
    fi

    mkdir -p "$release_dir/web"
    cp "$OUTPUT_DIR/backend/network-prober$ext" "$release_dir/"
    cp "$OUTPUT_DIR/backend/web/"* "$release_dir/web/"
    info "Flutter release: $dir/$release_dir"
}

build_electron() {
    local platform=$1 os=$2 arch=$3 ext=${4:-}
    local dir="$PROJECT_ROOT/desktop/electron"
    local release_dir="$dir/build/${os}-${arch}"

    info "Compile Electron: $platform"

    mkdir -p "$release_dir"

    cp "$OUTPUT_DIR/backend/network-prober$ext" "$release_dir/"

    cp "$dir/main.js" "$release_dir/"
    cp "$dir/preload.js" "$release_dir/"
    cp "$dir/package.json" "$release_dir/"

    mkdir -p "$release_dir/web"
    cp "$OUTPUT_DIR/backend/web/"* "$release_dir/web/"

    # Install deps and package
    cd "$dir"
    if [ ! -d "node_modules" ]; then
        info "Installing npm dependencies..."
        npm install 2>/dev/null || warn "npm install failed, run 'cd desktop/electron && npm install' manually"
    fi

    info "Electron release: $release_dir"
    echo ""
    echo "To run locally:"
    echo "  cd $release_dir"
    echo "  npx electron ."
}

clean() {
    info "Clean build directory"
    rm -rf "$OUTPUT_DIR"
}

[[ $# -lt 2 ]] && usage

PLATFORM=$1
FRAMEWORK=$2
shift 2

case "$PLATFORM" in
    linux)   OS="linux";   ARCH="amd64"; EXT="" ;;
    windows) OS="windows"; ARCH="amd64"; EXT=".exe" ;;
    macos)   OS="darwin";  ARCH="amd64"; EXT="" ;;
    all) ;;
    clean) clean; exit 0 ;;
    *) usage ;;
esac

if [ "$PLATFORM" = "all" ]; then
    for p in linux windows macos; do
        echo ""
        info "=== Building $p $FRAMEWORK ==="
        case $p in
            linux)   build_backend "linux" "amd64";;
            windows) build_backend "windows" "amd64" ".exe";;
            macos)   build_backend "darwin" "amd64";;
        esac
        case $FRAMEWORK in
            flutter)  build_flutter  "$p" "$OS" "$ARCH" "$EXT" ;;
            electron) build_electron "$p" "$OS" "$ARCH" "$EXT" ;;
            *) usage ;;
        esac
    done
    exit 0
fi

clean
build_backend "$OS" "$ARCH" "$EXT"

case "$FRAMEWORK" in
    flutter)  build_flutter  "$PLATFORM" "$OS" "$ARCH" "$EXT" ;;
    electron) build_electron "$PLATFORM" "$OS" "$ARCH" "$EXT" ;;
    *) usage ;;
esac
