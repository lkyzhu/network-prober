#!/bin/bash
set -e

VERSION=${VERSION:-$(git describe --tags --abbrev=0 2>/dev/null || echo "1.0.0")}
PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BACKEND_DIR="$PROJECT_ROOT/backend"
FLUTTER_DIR="$PROJECT_ROOT/desktop"
DIST_DIR="$PROJECT_ROOT/dist"
BUILD_DIR="$PROJECT_ROOT/build"

export PATH="$PATH:/opt/flutter/bin:$HOME/flutter/bin:$HOME/.flutter/bin"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'
info()  { echo -e "${GREEN}[INFO]${NC} $1"; }
warn()  { echo -e "${YELLOW}[WARN]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; }
step()  { echo -e "${BLUE}[STEP]${NC} $1"; }

usage() {
    cat <<EOF
Usage: $(basename "$0") <command> [options]

Commands:
  linux               Build for Linux (Flutter + backend)
  windows             Build for Windows (Flutter + backend)
  macos               Build for macOS (Flutter + backend)
  all                 Build for all platforms
  package-linux       Build + create .deb package
  package-windows     Build + create .zip package
  package-macos       Build + create .pkg package
  package-all         Build + package for all platforms
  clean               Clean build artifacts
  help                Show this help

Options:
  --arch <arch>       Target architecture: amd64 (default) or arm64
  --no-backend        Skip backend build (use existing binary)

Examples:
  $(basename "$0") linux
  $(basename "$0") package-linux
  $(basename "$0") package-all --arch arm64
EOF
    exit 1
}

detect_os() {
    case "$(uname -s)" in
        Linux)  echo "linux" ;;
        Darwin) echo "macos" ;;
        MINGW*|MSYS*) echo "windows" ;;
        *)      echo "unknown" ;;
    esac
}

flutter_arch() {
    local arch=$1
    case "$arch" in
        amd64) echo "x64" ;;
        arm64) echo "arm64" ;;
        *)     echo "x64" ;;
    esac
}

build_backend() {
    local os=$1 arch=$2
    local ext=""; [ "$os" = "windows" ] && ext=".exe"
    local backend_dir="$BUILD_DIR/backend/${os}-${arch}/backend"
    local output="$backend_dir/network-prober${ext}"

    info "Building backend: ${os}/${arch}"
    mkdir -p "$backend_dir"

    GOOS=$os GOARCH=$arch CGO_ENABLED=0 \
        go build -ldflags "-s -w -X main.Version=$VERSION" \
        -o "$output" "$BACKEND_DIR"

    mkdir -p "$backend_dir/static"
    cp "$PROJECT_ROOT/web/static/index.html" "$backend_dir/static/"
    cp "$PROJECT_ROOT/web/static/style.css" "$backend_dir/static/"
    cp "$PROJECT_ROOT/web/static/app.js" "$backend_dir/static/"
    cp "$PROJECT_ROOT/web/static/import_template.csv" "$backend_dir/static/"
    info "Backend built: $output"
}

build_flutter() {
    local platform=$1 arch=$2
    local farch=$(flutter_arch "$arch")

    info "Building Flutter desktop: $platform ($farch)" >&2

    cd "$FLUTTER_DIR"

    export PUB_HOSTED_URL=${PUB_HOSTED_URL:-https://mirrors.tencent.com/dart-pub/}
    export FLUTTER_STORAGE_BASE_URL=${FLUTTER_STORAGE_BASE_URL:-https://mirrors.tencent.com/flutter/}

    case "$platform" in
        linux)
            flutter build linux --release >&2
            local bundle_dir="build/linux/$farch/release/bundle"
            ;;
        windows)
            flutter build windows --release >&2
            local bundle_dir="build/windows/$farch/runner/Release"
            ;;
        macos)
            flutter build macos --release >&2
            local bundle_dir="build/macos/Build/Products/Release"
            ;;
    esac

    local release_dir="$FLUTTER_DIR/$bundle_dir"
    local ext=""; [ "$platform" = "windows" ] && ext=".exe"
    local backend_binary="$BUILD_DIR/backend/${platform}-${arch}/backend/network-prober${ext}"
    local backend_static="$BUILD_DIR/backend/${platform}-${arch}/backend/static"

    mkdir -p "$release_dir/backend/static"

    if [ -f "$backend_binary" ]; then
        cp "$backend_binary" "$release_dir/backend/"
        cp -r "$backend_static/"* "$release_dir/backend/static/"
    fi

    info "Flutter release ready: $release_dir" >&2
    echo "$release_dir"
}

build_all() {
    local arch=${1:-amd64}
    for platform in linux windows macos; do
        echo ""
        step "=== Building $platform ($arch) ==="
        build_backend "$platform" "$arch"
        build_flutter "$platform" "$arch"
    done
}

package_linux() {
    local arch=${1:-amd64}
    local host_os=$(detect_os)
    if [ "$host_os" != "linux" ]; then
        error "Linux packaging (deb) is only supported on Linux hosts"
        exit 1
    fi

    step "Building Linux package..."
    build_backend "linux" "$arch"
    local bundle_dir=$(build_flutter "linux" "$arch")

    local pkg_name="network-prober"
    local pkg_version="$VERSION"
    local pkg_dir="/tmp/${pkg_name}_deb"
    local deb_name="${DIST_DIR}/${pkg_name}_${pkg_version}_linux_${arch}.deb"

    rm -rf "$pkg_dir"
    mkdir -p "$pkg_dir/DEBIAN"
    mkdir -p "$pkg_dir/opt/network-prober/backend/static"
    mkdir -p "$pkg_dir/usr/share/applications"
    mkdir -p "$pkg_dir/usr/share/icons/hicolor/256x256/apps"
    mkdir -p "$pkg_dir/lib/systemd/system"

    cp -r "$bundle_dir/"* "$pkg_dir/opt/network-prober/"

    cp "$BUILD_DIR/backend/linux-${arch}/backend/network-prober" "$pkg_dir/opt/network-prober/backend/"
    cp -r "$BUILD_DIR/backend/linux-${arch}/backend/static/"* "$pkg_dir/opt/network-prober/backend/static/"

    chmod 755 "$pkg_dir/opt/network-prober/backend/network-prober"
    chmod 755 "$pkg_dir/opt/network-prober/prober-ui" 2>/dev/null || true

    local deb_arch="amd64"; [ "$arch" = "arm64" ] && deb_arch="arm64"
    cat > "$pkg_dir/DEBIAN/control" <<EOF
Package: network-prober
Version: $pkg_version
Section: net
Priority: optional
Architecture: $deb_arch
Maintainer: Network Prober Team
Description: Network Prober - Service Availability Detection Tool
 A comprehensive network probing tool with desktop GUI
 and web interface for monitoring service availability.
EOF

    cat > "$pkg_dir/lib/systemd/system/network-prober.service" <<EOF
[Unit]
Description=Network Prober - Backend Service
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/opt/network-prober/backend
ExecStart=/opt/network-prober/backend/network-prober -conf /etc/network-prober/config.json
Restart=on-failure
RestartSec=5
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target
EOF

    cat > "$pkg_dir/usr/share/applications/network-prober.desktop" <<EOF
[Desktop Entry]
Name=Network Prober
Comment=Service Availability Detection Tool
Exec=/opt/network-prober/prober-ui
Icon=network-prober
Terminal=false
Type=Application
Categories=Network;Utility;
EOF

    cat > "$pkg_dir/DEBIAN/postinst" <<'EOF'
#!/bin/bash
set -e
chmod 755 /opt/network-prober/prober-ui 2>/dev/null || true
chmod 755 /opt/network-prober/backend/network-prober 2>/dev/null || true
mkdir -p /opt/network-prober/backend/data
chmod 777 /opt/network-prober/backend/data
mkdir -p /etc/network-prober
chmod 755 /etc/network-prober
if [ ! -f /etc/network-prober/config.json ]; then
    cat > /etc/network-prober/config.json <<'CFG'
{
  "listen": ":8080",
  "store": "data/store.json",
  "log_level": "warn"
}
CFG
fi
chmod 644 /etc/network-prober/config.json
if command -v systemctl &>/dev/null; then
    systemctl daemon-reload
    systemctl enable network-prober.service 2>/dev/null || true
    systemctl start network-prober.service 2>/dev/null || true
fi
exit 0
EOF
    chmod 755 "$pkg_dir/DEBIAN/postinst"

    cat > "$pkg_dir/DEBIAN/prerm" <<'EOF'
#!/bin/bash
set -e
if command -v systemctl &>/dev/null; then
    systemctl stop network-prober.service 2>/dev/null || true
    systemctl disable network-prober.service 2>/dev/null || true
fi
exit 0
EOF
    chmod 755 "$pkg_dir/DEBIAN/prerm"

    find "$pkg_dir/opt/network-prober" -type f -not -name "network-prober" -not -name "prober-ui" -exec chmod 644 {} \; 2>/dev/null || true

    mkdir -p "$DIST_DIR"
    dpkg-deb --build "$pkg_dir" "$deb_name"
    rm -rf "$pkg_dir"
    info "Debian package created: $deb_name"
}

package_windows() {
    local arch=${1:-amd64}
    build_backend "windows" "$arch"
    local bundle_dir=$(build_flutter "windows" "$arch")

    local pkg_name="network-prober-$VERSION-windows-$arch"
    local win_dir="$BUILD_DIR/windows-pkg/$pkg_name"
    rm -rf "$win_dir"
    mkdir -p "$win_dir/backend/static"

    cp -r "$bundle_dir/"* "$win_dir/"
    cp "$BUILD_DIR/backend/windows-${arch}/backend/network-prober.exe" "$win_dir/backend/"
    cp -r "$BUILD_DIR/backend/windows-${arch}/backend/static/"* "$win_dir/backend/static/"

    cat > "$win_dir/README.txt" <<EOF
Network Prober v$VERSION - Windows Package

Run prober-ui.exe to start the desktop application.
The backend will be started automatically.

For standalone backend:
  backend\network-prober.exe -listen :8080

Default web interface: http://localhost:8080
EOF

    mkdir -p "$DIST_DIR"
    cd "$BUILD_DIR/windows-pkg"
    zip -r "$DIST_DIR/$pkg_name.zip" "$pkg_name/"
    cd "$PROJECT_ROOT"
    rm -rf "$win_dir"

    info "Windows package created: $DIST_DIR/$pkg_name.zip"
}

package_macos() {
    local arch=${1:-amd64}
    local host_os=$(detect_os)

    build_backend "darwin" "$arch"
    local bundle_dir=$(build_flutter "macos" "$arch")

    local app_bundle="$bundle_dir/Runner.app"
    local macos_dir="$app_bundle/Contents/MacOS"
    local resources_dir="$app_bundle/Contents/Resources"

    mkdir -p "$macos_dir/backend/static"

    cp "$BUILD_DIR/backend/darwin-${arch}/backend/network-prober" "$macos_dir/backend/"
    cp -r "$BUILD_DIR/backend/darwin-${arch}/backend/static/"* "$macos_dir/backend/static/"

    mkdir -p "$DIST_DIR"

    if [ "$host_os" = "macos" ]; then
        pkgbuild \
            --root "$app_bundle" \
            --identifier "com.networkprober.prober_ui" \
            --version "$VERSION" \
            --install-location "/Applications/Prober UI.app" \
            "$DIST_DIR/network-prober-$VERSION-darwin-$arch.pkg" 2>/dev/null || {
                warn "pkgbuild not available, creating .tar.gz instead"
                tar -czf "$DIST_DIR/network-prober-$VERSION-darwin-$arch.tar.gz" \
                    -C "$(dirname "$app_bundle")" "Runner.app"
            }
    else
        tar -czf "$DIST_DIR/network-prober-$VERSION-darwin-$arch.tar.gz" \
            -C "$(dirname "$app_bundle")" "Runner.app"
        info "macOS app bundle tar.gz: $DIST_DIR/network-prober-$VERSION-darwin-$arch.tar.gz"
    fi
}

clean() {
    info "Cleaning build artifacts..."
    rm -rf "$BUILD_DIR"
    rm -rf "$DIST_DIR"
    cd "$FLUTTER_DIR"
    flutter clean 2>/dev/null || true
    info "Clean complete"
}

[[ $# -lt 1 ]] && usage

CMD=$1; shift

ARCH="amd64"
while [[ $# -gt 0 ]]; do
    case $1 in
        --arch) ARCH="$2"; shift 2 ;;
        *) error "Unknown option: $1"; usage ;;
    esac
done

case "$CMD" in
    linux)
        build_backend "linux" "$ARCH"
        build_flutter "linux" "$ARCH"
        ;;
    windows)
        build_backend "windows" "$ARCH"
        build_flutter "windows" "$ARCH"
        ;;
    macos)
        build_backend "darwin" "$ARCH"
        build_flutter "macos" "$ARCH"
        ;;
    all)
        build_all "$ARCH"
        ;;
    package-linux)
        package_linux "$ARCH"
        ;;
    package-windows)
        package_windows "$ARCH"
        ;;
    package-macos)
        package_macos "$ARCH"
        ;;
    package-all)
        package_linux "$ARCH"
        package_windows "$ARCH"
        package_macos "$ARCH" 2>/dev/null || warn "macOS packaging skipped (requires macOS host)"
        ;;
    clean)
        clean
        ;;
    help|--help|-h)
        usage
        ;;
    *)
        error "Unknown command: $CMD"; usage ;;
esac
