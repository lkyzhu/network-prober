.PHONY: help build-backend build-backend-all build-desktop build build-all \
        package package-linux package-windows package-macos package-all \
        release deb pkg exe clean install uninstall version

VERSION ?= 1.0.0
PLATFORM ?= $(shell go env GOOS 2>/dev/null | sed 's/darwin/macos/' || echo linux)
ARCH ?= amd64

help:
	@echo "Network Prober - Build System"
	@echo ""
	@echo "Usage: make <target>"
	@echo ""
	@echo "Build targets:"
	@echo "  make build-backend              Build current platform backend"
	@echo "  make build-backend-all          Build all platform backends"
	@echo "  make build-desktop              Build desktop + backend"
	@echo "  make build                      Build current platform (backend + desktop)"
	@echo "  make build-all                  Build all platforms (backend + desktop)"
	@echo ""
	@echo "Package targets:"
	@echo "  make deb                        Build + create .deb package (Linux)"
	@echo "  make pkg                        Build + create .pkg package (macOS)"
	@echo "  make exe                        Build + create Windows package (.zip)"
	@echo "  make package-linux              Alias for make deb"
	@echo "  make package-windows            Alias for make exe"
	@echo "  make package-macos              Alias for make pkg"
	@echo "  make package                    Build + package current platform"
	@echo "  make package-all                Build + package all platforms"
	@echo ""
	@echo "Other targets:"
	@echo "  make clean                      Clean build directories"
	@echo "  make install                    Build and install locally"
	@echo "  make uninstall                  Uninstall local installation"
	@echo "  make version                    Show version info"
	@echo ""
	@echo "Environment variables:"
	@echo "  VERSION=1.0.1                   Set version"
	@echo "  PLATFORM=linux                  Set platform (linux/windows/macos)"
	@echo "  ARCH=arm64                      Set architecture (amd64/arm64)"

build-backend:
	@echo "Building backend..."
	scripts/build.sh

build-backend-all:
	@echo "Building all platform backends..."
	scripts/build.sh all

build-desktop:
	@echo "Building desktop + backend ($(PLATFORM)/$(ARCH))..."
	scripts/build-desktop.sh $(PLATFORM) --arch $(ARCH)

build:
	@echo "Building backend..."
	scripts/build.sh
	@echo ""
	@echo "Building desktop..."
	scripts/build-desktop.sh $(PLATFORM) --arch $(ARCH)

build-all:
	@echo "Building all platforms..."
	scripts/build.sh all
	scripts/build-desktop.sh all --arch $(ARCH)

package: deb pkg exe

package-linux: deb

package-windows: exe

package-macos: pkg

deb:
	@echo "Building Linux .deb package ($(ARCH))..."
	VERSION=$(VERSION) scripts/build-desktop.sh package-linux --arch $(ARCH)

pkg:
	@echo "Building macOS package ($(ARCH))..."
	VERSION=$(VERSION) scripts/build-desktop.sh package-macos --arch $(ARCH)

exe:
	@echo "Building Windows package ($(ARCH))..."
	VERSION=$(VERSION) scripts/build-desktop.sh package-windows --arch $(ARCH)

package-all:
	@echo "Building all platform packages..."
	VERSION=$(VERSION) scripts/build-desktop.sh package-all --arch $(ARCH)

release: package-all

clean:
	@echo "Cleaning build directories..."
	scripts/build.sh clean
	scripts/build-desktop.sh clean
	rm -rf build dist

install:
	@echo "Building and installing locally..."
	scripts/build.sh
	cd build/$(shell go env GOOS)-$(shell go env GOARCH) && ./install.sh

uninstall:
	@echo "Uninstalling..."
	@if [ -f /opt/network-prober/uninstall.sh ]; then \
		/opt/network-prober/uninstall.sh; \
	else \
		echo "Installation not found at /opt/network-prober"; \
	fi

version:
	@echo "Network Prober v$(VERSION)"
	@echo "Go: $(shell go version)"
	@echo "Flutter: $(shell flutter --version 2>/dev/null | head -1 || echo 'not found')"
	@echo "Supported platforms:"
	@echo "  linux/amd64   linux/arm64"
	@echo "  windows/amd64"
	@echo "  darwin/amd64  darwin/arm64"

.DEFAULT_GOAL := help
