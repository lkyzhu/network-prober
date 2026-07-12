#!/bin/bash
set -e

# 网络探测工具 - 卸载脚本

INSTALL_DIR="/opt/network-prober"
SERVICE_NAME="network-prober"
KEEP_DATA=0

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

info() { echo -e "${GREEN}[INFO]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; }

# 解析参数
while [[ $# -gt 0 ]]; do
    case $1 in
        --keep-data)
            KEEP_DATA=1
            shift
            ;;
        --help)
            echo "用法: $0 [--keep-data] [--help]"
            echo "  --keep-data  保留数据目录"
            echo "  --help       显示帮助"
            exit 0
            ;;
        *)
            error "未知参数: $1"
            exit 1
            ;;
    esac
done

echo "卸载网络探测工具..."

# 检测服务管理器
if command -v systemctl &> /dev/null && systemctl --version &> /dev/null; then
    info "停止 systemd 服务..."
    sudo systemctl stop $SERVICE_NAME 2>/dev/null || true
    sudo systemctl disable $SERVICE_NAME 2>/dev/null || true
    sudo rm -f /etc/systemd/system/$SERVICE_NAME.service
    sudo systemctl daemon-reload
elif command -v service &> /dev/null; then
    info "停止 init.d 服务..."
    sudo service $SERVICE_NAME stop 2>/dev/null || true
    sudo rm -f /etc/init.d/$SERVICE_NAME
fi

# 停止可能正在运行的进程
if pgrep -x "network-prober" > /dev/null; then
    info "停止运行中的进程..."
    pkill -x "network-prober" 2>/dev/null || true
    sleep 1
fi

# 处理数据
if [ -d "$INSTALL_DIR/data" ] && [ $KEEP_DATA -eq 1 ]; then
    backup_dir="${INSTALL_DIR}_data_backup_$(date +%Y%m%d_%H%M%S)"
    info "备份数据到: $backup_dir"
    sudo cp -r "$INSTALL_DIR/data" "$backup_dir/"
fi

# 删除安装目录
if [ -d "$INSTALL_DIR" ]; then
    info "删除安装目录: $INSTALL_DIR"
    sudo rm -rf "$INSTALL_DIR"
fi

info "卸载完成"

if [ $KEEP_DATA -eq 1 ] && [ -d "$backup_dir" ]; then
    echo ""
    echo "数据已备份到: $backup_dir"
fi