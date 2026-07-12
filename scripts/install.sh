#!/bin/bash
set -e

# 网络探测工具 - 智能安装脚本
# 支持: Linux (systemd/nohup)

# 默认配置
INSTALL_DIR="/opt/network-prober"
SERVICE_NAME="network-prober"
LISTEN_PORT="8080"
BINARY="network-prober"
KEEP_DATA=0

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# 打印函数
info() { echo -e "${GREEN}[INFO]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; }
step() { echo -e "${BLUE}[STEP]${NC} $1"; }

# 显示帮助
show_help() {
    cat << EOF
网络探测工具 - 安装脚本

用法: $0 [选项]

选项:
  --prefix <目录>    安装目录 (默认: /opt/network-prober)
  --port <端口>      监听端口 (默认: 8080)
  --uninstall        卸载
  --keep-data        卸载时保留数据
  --help             显示此帮助

示例:
  $0                          # 默认安装
  $0 --prefix /usr/local      # 安装到 /usr/local/network-prober
  $0 --port 9090              # 使用端口 9090
  $0 --uninstall              # 卸载
  $0 --uninstall --keep-data  # 卸载但保留数据

EOF
}

# 解析参数
while [[ $# -gt 0 ]]; do
    case $1 in
        --prefix)
            INSTALL_DIR="$2"
            shift 2
            ;;
        --port)
            LISTEN_PORT="$2"
            shift 2
            ;;
        --uninstall)
            uninstall
            exit 0
            ;;
        --keep-data)
            KEEP_DATA=1
            shift
            ;;
        --help)
            show_help
            exit 0
            ;;
        *)
            error "未知参数: $1"
            show_help
            exit 1
            ;;
    esac
done

# 检测系统架构
detect_arch() {
    local arch=$(uname -m)
    case $arch in
        x86_64|amd64)
            echo "amd64"
            ;;
        aarch64|arm64)
            echo "arm64"
            ;;
        *)
            error "不支持的架构: $arch"
            exit 1
            ;;
    esac
}

# 检测服务管理器
detect_service_manager() {
    if command -v systemctl &> /dev/null && systemctl --version &> /dev/null; then
        echo "systemd"
    elif command -v service &> /dev/null; then
        echo "initv"
    else
        echo "none"
    fi
}

# 检查端口是否被占用
check_port() {
    local port=$1
    if command -v ss &> /dev/null; then
        if ss -tuln | grep -q ":$port "; then
            return 1
        fi
    elif command -v netstat &> /dev/null; then
        if netstat -tuln 2>/dev/null | grep -q ":$port "; then
            return 1
        fi
    fi
    return 0
}

# 卸载函数
uninstall() {
    step "开始卸载..."
    
    # 检测服务管理器
    local service_manager=$(detect_service_manager)
    
    if [ "$service_manager" = "systemd" ]; then
        info "停止 systemd 服务..."
        sudo systemctl stop $SERVICE_NAME 2>/dev/null || true
        sudo systemctl disable $SERVICE_NAME 2>/dev/null || true
        sudo rm -f /etc/systemd/system/$SERVICE_NAME.service
        sudo systemctl daemon-reload
    elif [ "$service_manager" = "initv" ]; then
        info "停止 init.d 服务..."
        sudo service $SERVICE_NAME stop 2>/dev/null || true
        sudo rm -f /etc/init.d/$SERVICE_NAME
    fi
    
    # 停止可能正在运行的进程
    if pgrep -x "$BINARY" > /dev/null; then
        info "停止运行中的进程..."
        pkill -x "$BINARY" 2>/dev/null || true
        sleep 1
    fi
    
    # 备份数据
    if [ -d "$INSTALL_DIR/data" ] && [ $KEEP_DATA -eq 1 ]; then
        local backup_dir="${INSTALL_DIR}_backup_$(date +%Y%m%d_%H%M%S)"
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
}

# 安装函数
install() {
    step "开始安装..."
    
    # 检查二进制文件
    if [ ! -f "$BINARY" ]; then
        error "未找到二进制文件: $BINARY"
        error "请从正确的构建目录运行此脚本"
        exit 1
    fi
    
    # 获取版本
    local version=$(./$BINARY -version 2>&1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' || echo '?')
    info "安装版本: v$version"
    
    # 检测架构
    local arch=$(detect_arch)
    info "系统架构: $arch"
    
    # 检测服务管理器
    local service_manager=$(detect_service_manager)
    info "服务管理器: $service_manager"
    
    # 检查端口
    if ! check_port "$LISTEN_PORT"; then
        warn "端口 $LISTEN_PORT 已被占用"
        read -p "是否继续使用此端口? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            error "安装中止"
            exit 1
        fi
    fi
    
    # 检查是否已安装
    if [ -d "$INSTALL_DIR" ]; then
        warn "检测到已存在的安装: $INSTALL_DIR"
        read -p "是否覆盖安装? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            # 备份数据
            if [ -f "$INSTALL_DIR/data/store.json" ]; then
                local backup_file="/tmp/network-prober-backup-$(date +%Y%m%d_%H%M%S).json"
                info "备份现有数据到: $backup_file"
                sudo cp "$INSTALL_DIR/data/store.json" "$backup_file"
            fi
            # 卸载旧版本
            KEEP_DATA=1 uninstall
        else
            info "安装取消"
            exit 0
        fi
    fi
    
    # 创建目录
    step "创建安装目录..."
    sudo mkdir -p "$INSTALL_DIR/data"
    sudo mkdir -p "$INSTALL_DIR/web"
    
    # 复制文件
    step "复制文件..."
    sudo cp "$BINARY" "$INSTALL_DIR/"
    
    # 复制静态文件
    for file in web/index.html web/style.css web/app.js web/import_template.csv; do
        if [ -f "$file" ]; then
            sudo cp "$file" "$INSTALL_DIR/web/"
        else
            warn "静态文件不存在: $file"
        fi
    done
    
    # 恢复数据备份
    if [ -f "$backup_file" ]; then
        info "恢复数据备份..."
        sudo cp "$backup_file" "$INSTALL_DIR/data/store.json"
    fi
    
    # 创建服务
    step "创建服务..."
    if [ "$service_manager" = "systemd" ]; then
        # 创建 systemd 服务
        sudo tee /etc/systemd/system/$SERVICE_NAME.service > /dev/null <<EOF
[Unit]
Description=Network Prober - Service Availability Detection Tool
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=$INSTALL_DIR
ExecStart=$INSTALL_DIR/$BINARY -listen :$LISTEN_PORT
Restart=on-failure
RestartSec=5
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target
EOF
        sudo systemctl daemon-reload
        sudo systemctl enable $SERVICE_NAME
        sudo systemctl start $SERVICE_NAME
        
    elif [ "$service_manager" = "initv" ]; then
        # 创建 init.d 服务
        sudo tee /etc/init.d/$SERVICE_NAME > /dev/null <<'EOF'
#!/bin/bash
### BEGIN INIT INFO
# Provides:          network-prober
# Required-Start:    $network $remote_fs
# Required-Stop:     $network $remote_fs
# Default-Start:     2 3 4 5
# Default-Stop:      0 1 6
# Short-Description: Network Prober
### END INIT INFO

INSTALL_DIR="/opt/network-prober"
BINARY="network-prober"
PIDFILE="/var/run/network-prober.pid"

case "$1" in
    start)
        echo "Starting network-prober..."
        cd "$INSTALL_DIR"
        nohup "$INSTALL_DIR/$BINARY" -listen :8080 > /dev/null 2>&1 &
        echo $! > "$PIDFILE"
        ;;
    stop)
        echo "Stopping network-prober..."
        if [ -f "$PIDFILE" ]; then
            kill $(cat "$PIDFILE") 2>/dev/null || true
            rm -f "$PIDFILE"
        fi
        pkill -x "$BINARY" 2>/dev/null || true
        ;;
    restart)
        $0 stop
        sleep 1
        $0 start
        ;;
    status)
        if [ -f "$PIDFILE" ] && kill -0 $(cat "$PIDFILE") 2>/dev/null; then
            echo "network-prober is running"
            exit 0
        else
            echo "network-prober is not running"
            exit 1
        fi
        ;;
    *)
        echo "Usage: $0 {start|stop|restart|status}"
        exit 1
        ;;
esac
EOF
        sudo chmod +x /etc/init.d/$SERVICE_NAME
        sudo update-rc.d $SERVICE_NAME defaults
        sudo service $SERVICE_NAME start
        
    else
        # 无服务管理器，创建启动脚本
        warn "未检测到服务管理器，创建启动脚本..."
        sudo tee "$INSTALL_DIR/start.sh" > /dev/null <<EOF
#!/bin/bash
cd "$INSTALL_DIR"
nohup ./$BINARY -listen :$LISTEN_PORT > /dev/null 2>&1 &
echo "Started on http://localhost:$LISTEN_PORT"
echo "PID: \$!"
echo "\$!" > /tmp/network-prober.pid
EOF
        sudo chmod +x "$INSTALL_DIR/start.sh"
        
        sudo tee "$INSTALL_DIR/stop.sh" > /dev/null <<EOF
#!/bin/bash
if [ -f /tmp/network-prober.pid ]; then
    kill \$(cat /tmp/network-prober.pid) 2>/dev/null || true
    rm -f /tmp/network-prober.pid
fi
pkill -x "$BINARY" 2>/dev/null || true
echo "Stopped"
EOF
        sudo chmod +x "$INSTALL_DIR/stop.sh"
        
        # 启动
        sudo "$INSTALL_DIR/start.sh"
    fi
    
    # 完成
    step "安装完成!"
    echo ""
    echo "========================================"
    echo "  网络探测工具 v$version"
    echo "========================================"
    echo ""
    echo "安装目录: $INSTALL_DIR"
    echo "访问地址: http://localhost:$LISTEN_PORT"
    echo ""
    echo "管理命令:"
    if [ "$service_manager" = "systemd" ]; then
        echo "  sudo systemctl status $SERVICE_NAME"
        echo "  sudo systemctl restart $SERVICE_NAME"
        echo "  sudo systemctl stop $SERVICE_NAME"
        echo "  sudo journalctl -u $SERVICE_NAME -f"
    elif [ "$service_manager" = "initv" ]; then
        echo "  sudo service $SERVICE_NAME status"
        echo "  sudo service $SERVICE_NAME restart"
        echo "  sudo service $SERVICE_NAME stop"
    else
        echo "  $INSTALL_DIR/start.sh"
        echo "  $INSTALL_DIR/stop.sh"
    fi
    echo ""
    echo "卸载: $0 --uninstall"
    echo "========================================"
}

# 主程序
if [ "${1:-}" = "--uninstall" ]; then
    uninstall
else
    install
fi