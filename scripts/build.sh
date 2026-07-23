#!/bin/bash
set -e

VERSION=${VERSION:-$(git describe --tags --abbrev=0 2>/dev/null || echo "1.0.0")}
BUILD_DIR="build"
BINARY_NAME="network-prober"
STATIC_FILES="web/static/index.html web/static/style.css web/static/app.js web/static/import_template.csv"

PLATFORMS=(
    "linux/amd64"
    "linux/arm64"
    "windows/amd64"
    "darwin/amd64"
    "darwin/arm64"
)

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
info() { echo -e "${GREEN}[INFO]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; }

# 检查 Go 环境
check_go() {
    if ! command -v go &> /dev/null; then
        error "Go 未安装，请先安装 Go (https://golang.org/dl/)"
        exit 1
    fi
    
    GO_VERSION=$(go version | awk '{print $3}' | sed 's/go//')
    if [ "$(printf '%s\n' "1.18" "$GO_VERSION" | sort -V | head -n1)" != "1.18" ]; then
        warn "Go 版本 $GO_VERSION 可能过低，建议使用 Go 1.18+"
    fi
    
    info "Go 版本: $(go version)"
}

# 清理构建目录
clean() {
    info "清理构建目录: $BUILD_DIR"
    rm -rf "$BUILD_DIR"
}

# 编译单个平台
build_platform() {
    local platform=$1
    local os="${platform%%/*}"
    local arch="${platform##*/}"
    local output_dir="$BUILD_DIR/${os}-${arch}"
    local binary_name="$BINARY_NAME"
    
    if [ "$os" = "windows" ]; then
        binary_name="$BINARY_NAME.exe"
    fi
    
    info "编译: $os/$arch -> $output_dir/$binary_name"
    
    # 创建输出目录
    mkdir -p "$output_dir"
    
    # 复制静态文件
    mkdir -p "$output_dir/static"
    for static_file in $STATIC_FILES; do
        if [ -f "$static_file" ]; then
            cp "$static_file" "$output_dir/static/"
        else
            warn "静态文件 $static_file 不存在"
        fi
    done
    
    # 编译二进制
    GOOS=$os GOARCH=$arch CGO_ENABLED=0 \
        go build -ldflags "-s -w -X main.Version=$VERSION" \
        -o "$output_dir/$binary_name" ./backend
    
    # 复制安装脚本
    local script_dir="$(cd "$(dirname "$0")" && pwd)"
    if [ "$os" = "windows" ]; then
        cp "$script_dir/../build/windows-amd64/install.bat" "$output_dir/" 2>/dev/null || warn "install.bat 不存在，跳过"
        cp "$script_dir/../build/windows-amd64/uninstall.bat" "$output_dir/" 2>/dev/null || warn "uninstall.bat 不存在，跳过"
    else
        cp "$script_dir/install.sh" "$output_dir/"
        cp "$script_dir/uninstall.sh" "$output_dir/"
        chmod +x "$output_dir/install.sh" "$output_dir/uninstall.sh"
    fi
    
    # 生成 README
    cat > "$output_dir/README.txt" << EOF
网络探测工具 v$VERSION - $os/$arch

启动方式:
$([[ "$os" = "windows" ]] && echo "network-prober.exe -listen :8080" || echo "./network-prober -listen :8080")

参数说明:
  -listen string    监听地址 (默认 ":8080")
  -log-level string 日志级别: debug, info, warn, error (默认 "info")
  -version / -v     显示版本信息

安装:
$([[ "$os" = "windows" ]] && echo "install.bat" || echo "./install.sh")

卸载:
$([[ "$os" = "windows" ]] && echo "uninstall.bat" || echo "./uninstall.sh")

默认访问地址: http://localhost:8080
EOF
    
    info "✓ $os/$arch 编译完成"
}

# 编译当前平台
build_current() {
    info "编译当前平台..."
    local os=$(go env GOOS)
    local arch=$(go env GOARCH)
    build_platform "$os/$arch"
}

# 编译所有平台
build_all() {
    info "编译所有平台 (${#PLATFORMS[@]}个)..."
    for platform in "${PLATFORMS[@]}"; do
        build_platform "$platform"
    done
    info "全部平台编译完成"
}

create_release() {
    info "Creating release archives..."
    local dist_dir="dist"
    mkdir -p "$dist_dir"

    for platform in "${PLATFORMS[@]}"; do
        local os="${platform%%/*}"
        local arch="${platform##*/}"
        local src_dir="$BUILD_DIR/${os}-${arch}"
        local archive_name="network-prober-$VERSION-${os}-${arch}"

        if [ -d "$src_dir" ]; then
            info "Packaging: $archive_name"
            if [ "$os" = "windows" ]; then
                (cd "$BUILD_DIR" && zip -r "../$dist_dir/$archive_name.zip" "${os}-${arch}/")
            else
                (cd "$BUILD_DIR" && tar -czf "../$dist_dir/$archive_name.tar.gz" "${os}-${arch}/")
            fi
        else
            warn "Directory not found: $src_dir, skipping"
        fi
    done

    info "Generating SHA256 checksums..."
    (cd "$dist_dir" && sha256sum * > "sha256sums.txt")

    info "Release packages created in: $dist_dir"
}

# Package: build backend + desktop + platform installer
package_current() {
    local os=$(go env GOOS)
    local arch=${1:-amd64}
    local platform=""
    case "$os" in
        linux)  platform="linux" ;;
        darwin) platform="macos" ;;
        windows) platform="windows" ;;
    esac
    info "Packaging for $platform/$arch..."
    local script_dir="$(cd "$(dirname "$0")" && pwd)"
    "$script_dir/build-desktop.sh" "package-${platform}" --arch "$arch"
}

package_all() {
    local arch=${1:-amd64}
    info "Packaging for all platforms ($arch)..."
    local script_dir="$(cd "$(dirname "$0")" && pwd)"
    VERSION=$VERSION "$script_dir/build-desktop.sh" package-all --arch "$arch"
}

# 显示帮助信息
show_help() {
    cat << EOF
Network Prober - Build Script

Usage: $0 [command] [--arch <arch>]

Commands:
  all                 Build all supported platforms (backend only)
  clean               Clean build directory
  release             Build all platforms + create archives
  package             Build + package current platform installer
  package-all         Build + package all platform installers
  help                Show this help
  <platform>          Build specific platform (e.g. linux-amd64)

Supported platforms:
  linux-amd64    linux-arm64
  windows-amd64
  darwin-amd64   darwin-arm64

Examples:
  $0                        # Build current platform (backend only)
  $0 all                    # Build all platforms (backend only)
  $0 package                # Build + package current platform
  $0 --arch arm64 package   # Build + package arm64
  $0 linux-amd64            # Build linux amd64 backend
  $0 clean                  # Clean build directory
  $0 release                # Build all + create archives

Environment:
  VERSION         Set version (default: git tag or 1.0.0)
  --arch <arch>   Target architecture: amd64 (default) or arm64
EOF
}

# 主函数
main() {
    check_go

    ARCH="amd64"
    ARGS=()
    for arg in "$@"; do
        case "$arg" in
            --arch=*) ARCH="${arg#*=}" ;;
            --arch) ;; # Handled below if followed by value
            *) ARGS+=("$arg") ;;
        esac
    done
    # Handle --arch <value> form (which doesn't have =)
    local passthrough_args=()
    local skip_next=0
    for ((i=0; i<${#ARGS[@]}; i++)); do
        if [ $skip_next -eq 1 ]; then skip_next=0; continue; fi
        if [ "${ARGS[$i]}" = "--arch" ] && [ $i -lt $((${#ARGS[@]}-1)) ]; then
            ARCH="${ARGS[$((i+1))]}"
            skip_next=1
        else
            passthrough_args+=("${ARGS[$i]}")
        fi
    done
    set -- "${passthrough_args[@]}"

    case "$1" in
        all)
            clean
            build_all
            ;;
        clean)
            clean
            ;;
        release)
            clean
            build_all
            create_release
            ;;
        package)
            package_current "$ARCH"
            ;;
        package-all)
            package_all "$ARCH"
            ;;
        help|--help|-h)
            show_help
            ;;
        "")
            clean
            build_current
            ;;
        *)
            local valid_platform=0
            for platform in "${PLATFORMS[@]}"; do
                local os="${platform%%/*}"
                local arch="${platform##*/}"
                if [ "$1" = "${os}-${arch}" ]; then
                    valid_platform=1
                    clean
                    build_platform "$platform"
                    break
                fi
            done

            if [ $valid_platform -eq 0 ]; then
                error "Invalid platform: $1"
                echo
                show_help
                exit 1
            fi
            ;;
    esac
}

main "$@"