#!/bin/bash
set -e

# 版本号 (优先从 git tag 获取，否则使用默认)
VERSION=${VERSION:-$(git describe --tags --abbrev=0 2>/dev/null || echo "1.0.0")}
BUILD_DIR="build"
BINARY_NAME="network-prober"
STATIC_FILES="web/static/index.html web/static/style.css web/static/app.js web/static/import_template.csv"

# 支持的平台列表
PLATFORMS=(
    "linux/amd64"
    "linux/arm64"
    "windows/amd64"
    "darwin/amd64"
    "darwin/arm64"
)

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 打印彩色信息
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
    if [ "$os" = "windows" ]; then
        cp install.bat "$output_dir/" 2>/dev/null || warn "install.bat 不存在，跳过"
        cp uninstall.bat "$output_dir/" 2>/dev/null || warn "uninstall.bat 不存在，跳过"
    else
        cp install.sh "$output_dir/"
        cp uninstall.sh "$output_dir/"
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

# 创建发布包
create_release() {
    info "创建发布包..."
    local dist_dir="dist"
    mkdir -p "$dist_dir"
    
    for platform in "${PLATFORMS[@]}"; do
        local os="${platform%%/*}"
        local arch="${platform##*/}"
        local src_dir="$BUILD_DIR/${os}-${arch}"
        local archive_name="network-prober-$VERSION-${os}-${arch}"
        
        if [ -d "$src_dir" ]; then
            info "打包: $archive_name"
            if [ "$os" = "windows" ]; then
                (cd "$BUILD_DIR" && zip -r "../$dist_dir/$archive_name.zip" "${os}-${arch}/")
            else
                (cd "$BUILD_DIR" && tar -czf "../$dist_dir/$archive_name.tar.gz" "${os}-${arch}/")
            fi
        else
            warn "目录不存在: $src_dir，跳过打包"
        fi
    done
    
    # 创建 SHA256 校验文件
    info "生成 SHA256 校验文件..."
    (cd "$dist_dir" && sha256sum * > "sha256sums.txt")
    
    info "发布包已创建到: $dist_dir"
}

# 显示帮助信息
show_help() {
    cat << EOF
网络探测工具 - 构建脚本

用法: $0 [命令]

命令:
  all          编译所有支持的平台
  clean        清理构建目录
  release      编译所有平台并打包
  help         显示此帮助信息
  <platform>   编译指定平台 (如: linux-amd64)

支持的平台:
  linux-amd64    Linux x86_64
  linux-arm64    Linux ARM64
  windows-amd64  Windows x86_64
  darwin-amd64   macOS Intel
  darwin-arm64   macOS Apple Silicon

示例:
  $0              # 编译当前平台
  $0 all          # 编译所有平台
  $0 linux-amd64  # 编译 Linux amd64
  $0 clean        # 清理构建目录
  $0 release      # 编译并打包

环境变量:
  VERSION        设置版本号 (默认: git tag 或 1.0.0)
EOF
}

# 主函数
main() {
    check_go
    
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
        help|--help|-h)
            show_help
            ;;
        "")
            clean
            build_current
            ;;
        *)
            # 检查是否为有效平台
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
                error "无效的平台: $1"
                echo
                show_help
                exit 1
            fi
            ;;
    esac
}

# 执行主函数
main "$@"