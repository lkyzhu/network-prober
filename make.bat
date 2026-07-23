@echo off
setlocal EnableDelayedExpansion

if "%1"=="" goto help
if "%1"=="help" goto help
if "%1"=="build" goto build
if "%1"=="build-backend" goto build-backend
if "%1"=="build-desktop" goto build-desktop
if "%1"=="package-windows" goto package-windows
if "%1"=="exe" goto package-windows
if "%1"=="clean" goto clean
if "%1"=="version" goto version

echo Unknown target: %1
echo Run "make help" for available targets.
exit /b 1

:help
echo Network Prober - Build Wrapper for Windows
echo.
echo Usage: make.cmd ^<target^>
echo.
echo Targets:
echo   make build-backend        Build backend only
echo   make build-desktop        Build desktop + backend
echo   make build                Build backend + desktop
echo   make package-windows      Build + package Windows (.zip)
echo   make exe                  Alias for package-windows
echo   make clean                Clean build directories
echo   make version              Show version
echo.
echo Environment:
echo   PLATFORM=windows           Set platform (windows/linux/macos)
echo   ARCH=amd64                 Set architecture (amd64/arm64)
echo.
echo Examples:
echo   make.cmd build-desktop
echo   set ARCH=arm64 ^& make.cmd package-windows
exit /b 0

:build-backend
echo Building backend only...
powershell -ExecutionPolicy Bypass -File scripts\build.ps1 -SkipFlutter
exit /b %ERRORLEVEL%

:build-desktop
echo Building desktop + backend...
if not "%PLATFORM%"=="" (
    powershell -ExecutionPolicy Bypass -File scripts\build.ps1 -Platform %PLATFORM% -Release
) else (
    powershell -ExecutionPolicy Bypass -File scripts\build.ps1 -Release
)
exit /b %ERRORLEVEL%

:build
echo Building backend + desktop...
if not "%PLATFORM%"=="" (
    powershell -ExecutionPolicy Bypass -File scripts\build.ps1 -Platform %PLATFORM% -Release
) else (
    powershell -ExecutionPolicy Bypass -File scripts\build.ps1 -Release
)
exit /b %ERRORLEVEL%

:package-windows
echo Building Windows package...
if not "%ARCH%"=="" (
    powershell -ExecutionPolicy Bypass -File scripts\build.ps1 -Platform windows -Release -Arch %ARCH%
) else (
    powershell -ExecutionPolicy Bypass -File scripts\build.ps1 -Platform windows -Release
)
exit /b %ERRORLEVEL%

:clean
echo Cleaning...
if exist build rmdir /s /q build
if exist dist rmdir /s /q dist
echo Done.
exit /b 0

:version
go version
echo Flutter:
flutter --version 2>nul | findstr /v "^$" | head -1 || echo not found
exit /b %ERRORLEVEL%
