@echo off
setlocal EnableDelayedExpansion

if "%1"=="" goto help
if "%1"=="help" goto help
if "%1"=="build" goto build
if "%1"=="build-backend" goto build-backend
if "%1"=="build-desktop" goto build-desktop
if "%1"=="clean" goto clean
if "%1"=="version" goto version

echo Unknown target: %1
echo Run "make help" for available targets.
exit /b 1

:help
echo NetworkTools - Build Wrapper for Windows
echo.
echo Usage: make <target>
echo.
echo Targets:
echo   make build-backend    Compile backend only
echo   make build-desktop    Compile desktop + backend
echo   make build            Compile backend + desktop
echo   make clean            Clean build directories
echo   make version          Show version
echo.
echo Environment:
echo   PLATFORM=windows      Set platform (windows/linux/macos)
echo.
echo Example:
echo   make build-desktop
echo   set PLATFORM=linux ^& make build
echo   scripts\build.ps1 -Platform windows -Release
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

:clean
echo Cleaning...
if exist build rmdir /s /q build
if exist dist rmdir /s /q dist
echo Done.
exit /b 0

:version
go version
exit /b %ERRORLEVEL%
