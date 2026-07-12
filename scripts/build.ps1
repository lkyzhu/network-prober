<#
.SYNOPSIS
    NetworkTools build script
.DESCRIPTION
    Build Go backend + Flutter desktop client, cross-platform.
.PARAMETER Platform
    Target platform: windows, linux, macos (default: windows)
.PARAMETER Arch
    Target architecture: amd64, arm64 (default: amd64)
.PARAMETER Release
    Release mode (flutter build --release)
.PARAMETER SkipFlutter
    Skip Flutter build, only build backend
.PARAMETER SkipBackend
    Skip backend build
.EXAMPLE
    .\scripts\build.ps1 -Platform windows
    .\scripts\build.ps1 -Platform linux -Release
    .\scripts\build.ps1 -Platform macos -Arch arm64 -Release
#>

param(
    [ValidateSet('windows','linux','macos')]
    [string]$Platform = 'windows',
    [ValidateSet('amd64','arm64')]
    [string]$Arch = 'amd64',
    [switch]$Release,
    [switch]$SkipFlutter,
    [switch]$SkipBackend
)

$ErrorActionPreference = 'Stop'
$RootDir = Split-Path -Parent $PSScriptRoot
$BackendDir = Join-Path $RootDir 'backend'
$DesktopDir = $RootDir
$FlutterDir = Join-Path $RootDir 'desktop'

function Write-Step {
    param([string]$Message)
    Write-Host ">>> $Message" -ForegroundColor Cyan
}

function Write-Err {
    param([string]$Message)
    Write-Host "ERROR: $Message" -ForegroundColor Red
    exit 1
}

function Get-GoOS {
    param([string]$Platform)
    switch ($Platform) {
        'windows' { return 'windows' }
        'linux'   { return 'linux' }
        'macos'   { return 'darwin' }
    }
}

function Get-BackendExt {
    param([string]$Platform)
    if ($Platform -eq 'windows') { return '.exe' } else { return '' }
}

function Get-FlutterPlatform {
    param([string]$Platform)
    switch ($Platform) {
        'windows' { return 'windows' }
        'linux'   { return 'linux' }
        'macos'   { return 'macos' }
    }
}

# ============================================================
# Step 1: Detect environment
# ============================================================
Write-Step "Environment check"

$goOK = $null
try { $goOK = (go version 2>$null) } catch {}
if (-not $goOK) { Write-Err "Go not installed or not in PATH" }
Write-Host "  Go: $goOK"

$flutterOK = $null
try { $flutterOK = (flutter --version 2>$null | Select-Object -First 1) } catch {}
if (-not $flutterOK) { Write-Err "Flutter not installed or not in PATH" }
Write-Host "  Flutter: $flutterOK"

$goOS = Get-GoOS $Platform
$backendExt = Get-BackendExt $Platform
$backendOutput = "network-prober$backendExt"

# ============================================================
# Step 2: Build Go backend
# ============================================================
if (-not $SkipBackend) {
    Write-Step "Building Go backend [$Platform/$Arch]"

    $env:GOOS = $goOS
    $env:GOARCH = $Arch
    $env:CGO_ENABLED = '0'

    $destDir = $DesktopDir
    $destPath = Join-Path $destDir $backendOutput

    Push-Location $BackendDir
    try {
        & go build -ldflags "-s -w" -o $destPath .
        if ($LASTEXITCODE -ne 0) { Write-Err "Go build failed" }
        Write-Host "  Output: $destPath ($((Get-Item $destPath).Length / 1KB) KB)"
    } finally {
        Pop-Location
    }

    $flutterBuildDir = Join-Path $FlutterDir 'build\windows\runner\Release'
    if ($Platform -eq 'windows' -and (Test-Path $flutterBuildDir)) {
        Copy-Item $destPath (Join-Path $flutterBuildDir $backendOutput) -Force
        Write-Host "  Copied to: $flutterBuildDir"
    }
} else {
    Write-Host "  Skipping backend build"
}

# ============================================================
# Step 3: Build Flutter desktop
# ============================================================
if (-not $SkipFlutter) {
    $flutterPlatform = Get-FlutterPlatform $Platform

    Write-Step "Building Flutter desktop [$flutterPlatform]"

    Push-Location $FlutterDir
    try {
        & flutter pub get
        if ($LASTEXITCODE -ne 0) { Write-Err "flutter pub get failed" }

        if ($Release) {
            & flutter build $flutterPlatform --release
        } else {
            & flutter build $flutterPlatform --debug
        }
        if ($LASTEXITCODE -ne 0) { Write-Err "Flutter build failed" }

        $buildDir = Join-Path $FlutterDir "build\$flutterPlatform\runner\Release"
        if ($Platform -eq 'macos') {
            $buildDir = Join-Path $FlutterDir "build\macos\Build\Products\Release"
            if (-not $Release) { $buildDir = $buildDir.Replace('Release', 'Debug') }
        }
        if (Test-Path $buildDir) {
            Copy-Item (Join-Path $DesktopDir $backendOutput) (Join-Path $buildDir $backendOutput) -Force -ErrorAction SilentlyContinue
            Write-Host "  Backend copied to: $buildDir"
        }
    } finally {
        Pop-Location
    }

    Write-Host ""
    Write-Host "====== Build complete ======" -ForegroundColor Green
    if ($Release) {
        Write-Host "Output: $FlutterDir\build\$flutterPlatform\" -ForegroundColor Yellow
    }
} else {
    Write-Host "  Skipping Flutter build"
}

Write-Host ""
Write-Host "====== $Platform/$Arch build complete ======" -ForegroundColor Green
