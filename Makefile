.PHONY: help build-backend build-desktop build build-all package release clean install uninstall version

VERSION ?= 1.0.0

help:
	@echo "NetworkTools - 网络探测工具"
	@echo ""
	@echo "用法: make <target>"
	@echo ""
	@echo "构建目标:"
	@echo "  make build-backend             编译当前平台后端 (scripts/build.sh)"
	@echo "  make build-backend-all         编译所有平台后端"
	@echo "  make build-desktop             编译当前平台桌面端 + 后端 (scripts/build-desktop.sh)"
	@echo "  make build                     编译当前平台 (后端 + desktop)"
	@echo "  make build-all                 编译所有平台 (后端 + desktop)"
	@echo ""
	@echo "打包目标:"
	@echo "  make package                   编译+打包当前平台"
	@echo "  make release                   编译+打包所有平台"
	@echo ""
	@echo "其他目标:"
	@echo "  make clean                     清理构建目录"
	@echo "  make install                   编译并安装到本机"
	@echo "  make uninstall                 卸载本机安装"
	@echo "  make version                   显示版本信息"
	@echo ""
	@echo "环境变量:"
	@echo "  VERSION=1.0.1                  设置版本号"
	@echo "  PLATFORM=linux                 指定平台 (linux/windows/macos)"
	@echo "  ARCH=arm64                     指定架构 (amd64/arm64)"

build-backend:
	@echo "编译后端 ($(shell go env GOOS)/$(shell go env GOARCH))..."
	scripts/build.sh

build-backend-all:
	@echo "编译所有平台后端..."
	scripts/build.sh all

build-desktop:
	@echo "编译桌面端 + 后端..."
	scripts/build-desktop.sh $(or $(PLATFORM),$(shell go env GOOS)) flutter

build:
	@echo "编译后端..."
	scripts/build.sh
	@echo ""
	@echo "编译桌面端..."
	scripts/build-desktop.sh $(or $(PLATFORM),$(shell go env GOOS)) flutter

build-all:
	@echo "编译所有平台..."
	scripts/build.sh all
	scripts/build-desktop.sh all flutter

package:
	@echo "编译并打包..."
	scripts/build.sh
	scripts/build-desktop.sh $(or $(PLATFORM),$(shell go env GOOS)) flutter
	scripts/build.sh release

release:
	@echo "编译并打包所有平台..."
	scripts/build.sh all
	scripts/build-desktop.sh all flutter
	scripts/build.sh release

clean:
	@echo "清理构建目录..."
	scripts/build.sh clean
	rm -rf build dist

install:
	@echo "编译并安装..."
	scripts/build.sh
	cd build/$(shell go env GOOS)-$(shell go env GOARCH) && ./install.sh

uninstall:
	@echo "卸载..."
	@if [ -f /opt/network-prober/uninstall.sh ]; then \
		/opt/network-prober/uninstall.sh; \
	else \
		echo "未找到安装目录"; \
	fi

version:
	@echo "NetworkTools v$(VERSION)"
	@echo "Go: $(shell go version)"
	@echo "支持平台:"
	@echo "  linux/amd64   linux/arm64"
	@echo "  windows/amd64"
	@echo "  darwin/amd64  darwin/arm64"

.DEFAULT_GOAL := help