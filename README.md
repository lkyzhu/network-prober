# NetworkTools - 网络探测工具

基于 Go 后端 + Flutter 桌面端的网络探测工具，支持 TCP/HTTP/UDP 协议探测、证书验证、模块化管理。

## 项目结构

```
network-prober/
├── backend/                 # Go 后端
│   ├── main.go              # 入口，HTTP 路由
│   ├── models.go            # 数据模型
│   ├── store.go             # 数据持久化 (JSON 文件)
│   ├── detector.go          # 探测逻辑 (TCP/HTTP/UDP)
│   └── go.mod
├── desktop/                 # Flutter 桌面端
│   ├── lib/
│   │   ├── main.dart              # 入口
│   │   ├── screens/               # 页面
│   │   ├── widgets/               # 组件
│   │   │   ├── sidebar/           # 模块树
│   │   │   ├── item_list/         # 检测项列表
│   │   │   └── modals/            # 弹窗
│   │   ├── models/                # 数据模型
│   │   ├── providers/             # 全局状态 (Riverpod)
│   │   └── services/              # 后端通信
│   ├── windows/                   # Windows 平台配置
│   └── pubspec.yaml
├── scripts/                 # 编译脚本
│   ├── build.sh             # 后端跨平台编译
│   ├── build-desktop.sh     # 桌面端 + 后端联合编译 (Linux/macOS)
│   ├── build.ps1            # 桌面端 + 后端一键编译 (Windows)
│   ├── build.bat            # 批处理包装
│   ├── install.sh           # 安装脚本
│   └── uninstall.sh         # 卸载脚本
├── web/                     # Web 静态页面
│   ├── index.html
│   ├── style.css
│   ├── app.js
│   └── import_template.csv
├── build/                   # 编译输出目录
├── data/                    # 数据存储目录
├── Makefile                 # 顶层构建入口
└── README.md
```

## 快速开始

### 前提条件

- Go 1.21+
- Flutter 3.16+ / Dart 3.2+
- (桌面端) Flutter 桌面环境: Windows `flutter config --enable-windows-desktop`

### 编译运行

```bash
# 方法一: Makefile 一键编译 (推荐)
make build                    # 编译当前平台后端 + Flutter 桌面端
make package                  # 编译当前平台并打包
make release                  # 编译所有平台并打包

# 方法二: 脚本编译
# Windows
.\scripts\build.ps1 -Platform windows

# Linux/macOS
./scripts/build-desktop.sh linux flutter

# 方法三: 分步编译
cd backend
go build -o ../build/network-prober .
cd ../desktop/flutter
flutter run
```

## 功能

- **多协议探测**: TCP 连接检测、HTTP 请求检测 (含状态码/证书)、UDP 端口检测
- **模块化管理**: 树形模块结构，支持拖拽移动检测项到目标模块
- **证书验证**: TLS 证书链验证，展示证书详情（主题、颁发者、有效期、指纹）
- **批量导入**: 通过 CSV 文件或粘贴地址列表批量导入检测项
- **结果展示**: 实时探测结果，DNS/连接/首包/总耗时统计
- **持久化存储**: JSON 文件存储，支持自定义绝对路径
- **随机端口**: 后端默认随机端口启动，避免端口冲突
- **跨平台**: Windows / Linux / macOS 三端支持

## 配置

通过 Flutter 桌面端"设置"对话框可配置：

- **后端监听端口**: 留空=随机端口，输入=固定端口号
- **数据文件路径**: 自定义 store.json 存储位置（绝对路径或相对路径）

## 构建

### Makefile (全平台通用)

```bash
# 构建
make build-backend            # 仅编译后端 (当前平台)
make build-backend-all        # 编译所有平台后端
make build-desktop            # 编译桌面端 + 后端 (当前平台)
make build                    # 编译后端 + 桌面端
make build-all                # 编译所有平台

# 打包
make package                  # 编译当前平台并打包为发布包
make release                  # 全部平台编译 + 打包
```

### Windows (PowerShell)

```powershell
.\scripts\build.ps1 -Platform windows              # Windows 默认
.\scripts\build.ps1 -Platform linux -Release       # 交叉编译 Linux 发布版
.\scripts\build.ps1 -Platform macos -Arch arm64    # macOS Apple Silicon
.\scripts\build.ps1 -SkipFlutter                   # 仅编译后端
```

### Linux / macOS

```bash
# 桌面端 + 后端联合编译
./scripts/build-desktop.sh linux flutter            # Linux Flutter 桌面端
./scripts/build-desktop.sh macos flutter             # macOS Flutter 桌面端

# 仅后端跨平台编译
./scripts/build.sh                                   # 编译当前平台
./scripts/build.sh all                               # 编译所有平台
./scripts/build.sh release                           # 编译+打包
```

### 打包输出

编译产物位于 `build/` 目录，打包文件位于 `dist/` 目录：

```
build/
├── linux-amd64/          # 后端 + web 页面
├── linux-arm64/          # 后端 + web 页面
├── windows-amd64/        # 后端 + web 页面
├── darwin-amd64/         # 后端 + web 页面
├── darwin-arm64/         # 后端 + web 页面
└── desktop/              # 桌面端 + 后端
dist/
├── network-prober-1.0.0-linux-amd64.tar.gz
├── network-prober-1.0.0-windows-amd64.zip
├── network-prober-1.0.0-darwin-amd64.tar.gz
└── sha256sums.txt
```

### 支持的目标平台

| 平台 | 架构 | 后端 | 桌面端 |
|---|---|---|---|
| Windows | amd64 | ✓ | Flutter |
| Linux | amd64 / arm64 | ✓ | Flutter |
| macOS | amd64 / arm64 | ✓ | Flutter |

## 技术栈

- **后端**: Go, net/http, crypto/tls
- **桌面端**: Flutter, Riverpod, Material Design 3
- **Web**: 原生 HTML/CSS/JS
- **存储**: JSON 文件

## 许可

MIT
