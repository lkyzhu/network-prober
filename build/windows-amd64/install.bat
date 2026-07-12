@echo off
setlocal enabledelayedexpansion

:: 网络探测工具 - Windows 安装脚本
:: 需要管理员权限运行

set "INSTALL_DIR=C:\network-prober"
set "TASK_NAME=NetworkProber"
set "LISTEN_PORT=8080"
set "BINARY=network-prober.exe"
set "SCRIPT_DIR=%~dp0"

:: 解析参数
:parse_args
if "%~1"=="" goto :done_args
if /i "%~1"=="--uninstall" goto :uninstall
if /i "%~1"=="--port" (
    set "LISTEN_PORT=%~2"
    shift
    shift
    goto :parse_args
)
if /i "%~1"=="--prefix" (
    set "INSTALL_DIR=%~2\network-prober"
    shift
    shift
    goto :parse_args
)
if /i "%~1"=="/?" goto :help
if /i "%~1"=="-h" goto :help
if /i "%~1"=="--help" goto :help
shift
goto :parse_args
:done_args

echo [INFO] 网络探测工具 - 安装脚本
echo.

:: 检查管理员权限
net session >nul 2>&1
if %errorLevel% neq 0 (
    echo [ERROR] 需要管理员权限运行此脚本
    echo 请右键选择"以管理员身份运行"
    pause
    exit /b 1
)

:: 检查二进制文件
if not exist "%SCRIPT_DIR%%BINARY%" (
    if not exist "%BINARY%" (
        echo [ERROR] 未找到二进制文件: %BINARY%
        echo 请从正确的构建目录运行此脚本
        pause
        exit /b 1
    )
    set "BINARY_PATH=%BINARY%"
) else (
    set "BINARY_PATH=%SCRIPT_DIR%%BINARY%"
)

:: 获取版本号
set "VERSION=unknown"
for /f "tokens=3" %%v in ('"%BINARY_PATH%" -version 2^>nul ^| findstr "version"') do set "VERSION=%%v"
echo [INFO] 安装版本: v%VERSION%

:: 检查端口占用
netstat -ano | findstr "LISTENING" | findstr ":%LISTEN_PORT% " >nul 2>&1
if %errorLevel% equ 0 (
    echo [WARN] 端口 %LISTEN_PORT% 已被占用
    set /p confirm="是否继续? (y/N): "
    if /i not "!confirm!"=="y" (
        echo 安装取消
        exit /b 0
    )
)

:: 检查是否已安装
schtasks /query /tn "%TASK_NAME%" >nul 2>&1
if %errorLevel% equ 0 (
    echo [WARN] 检测到已存在的任务: %TASK_NAME%
    set /p confirm="是否覆盖安装? (y/N): "
    if /i not "!confirm!"=="y" (
        echo 安装取消
        exit /b 0
    )
    schtasks /end /tn "%TASK_NAME%" >nul 2>&1
    schtasks /delete /tn "%TASK_NAME%" /f >nul 2>&1
)

:: 备份已有数据
if exist "%INSTALL_DIR%\data\store.json" (
    for /f "tokens=2 delims==" %%i in ('wmic os get localdatetime /value 2^>nul') do set "dt=%%i"
    set "TIMESTAMP=!dt:~0,8!-!dt:~8,6!"
    set "BACKUP_FILE=%TEMP%\network-prober-backup-!TIMESTAMP!.json"
    echo [INFO] 备份数据到: !BACKUP_FILE!
    copy /Y "%INSTALL_DIR%\data\store.json" "!BACKUP_FILE!" >nul 2>&1
)

:: 停止已有进程
taskkill /F /IM %BINARY% >nul 2>&1

:: 创建安装目录
echo [INFO] 创建安装目录...
if not exist "%INSTALL_DIR%" mkdir "%INSTALL_DIR%"
if not exist "%INSTALL_DIR%\data" mkdir "%INSTALL_DIR%\data"
    if not exist "%INSTALL_DIR%\web" mkdir "%INSTALL_DIR%\web"

:: 复制二进制文件
echo [INFO] 复制文件...
copy /Y "%BINARY_PATH%" "%INSTALL_DIR%\%BINARY%" >nul

:: 复制静态文件
for %%f in (index.html style.css app.js import_template.csv) do (
    if exist "%SCRIPT_DIR%web\%%f" (
        copy /Y "%SCRIPT_DIR%web\%%f" "%INSTALL_DIR%\web\" >nul
    ) else if exist "web\%%f" (
        copy /Y "web\%%f" "%INSTALL_DIR%\web\" >nul
    )
)

:: 恢复数据备份
if defined BACKUP_FILE (
    if exist "!BACKUP_FILE!" (
        echo [INFO] 恢复数据备份...
        copy /Y "!BACKUP_FILE!" "%INSTALL_DIR%\data\store.json" >nul
    )
)

:: 创建启动脚本
echo [INFO] 创建启动脚本...
(
echo @echo off
echo cd /d "%INSTALL_DIR%"
echo "%INSTALL_DIR%\%BINARY%" -listen :%LISTEN_PORT%
echo pause
) > "%INSTALL_DIR%\start.bat"

(
echo @echo off
echo taskkill /F /IM %BINARY% >nul 2>&1
echo echo 已停止
echo pause
) > "%INSTALL_DIR%\stop.bat"

:: 创建 Windows 计划任务（开机自启 + 进程守护）
echo [INFO] 创建计划任务...
schtasks /create /tn "%TASK_NAME%" /tr "\"%INSTALL_DIR%\%BINARY%\" -listen :%LISTEN_PORT%" /sc onstart /rl highest /f >nul 2>&1
if %errorLevel% neq 0 (
    echo [ERROR] 创建计划任务失败
    echo 请尝试手动运行: schtasks /create /tn "%TASK_NAME%" /tr "\"%INSTALL_DIR%\%BINARY%\" -listen :%LISTEN_PORT%" /sc onstart /rl highest
    pause
    exit /b 1
)

:: 立即启动
echo [INFO] 启动服务...
schtasks /run /tn "%TASK_NAME%" >nul 2>&1

:: 等待启动
timeout /t 3 /nobreak >nul

:: 验证是否启动成功
tasklist /FI "IMAGENAME eq %BINARY%" 2>nul | findstr /i "%BINARY%" >nul
if %errorLevel% equ 0 (
    echo [INFO] 服务启动成功
) else (
    echo [WARN] 服务可能未启动成功，请检查
)

echo.
echo ========================================
echo   网络探测工具 v%VERSION%
echo ========================================
echo.
echo 安装目录: %INSTALL_DIR%
echo 访问地址: http://localhost:%LISTEN_PORT%
echo.
echo 管理命令:
echo   启动: schtasks /run /tn "%TASK_NAME%"
echo   停止: taskkill /F /IM %BINARY%
echo   删除: schtasks /delete /tn "%TASK_NAME%" /f
echo   状态: tasklist /FI "IMAGENAME eq %BINARY%"
echo.
echo 快捷脚本:
echo   %INSTALL_DIR%\start.bat  - 前台启动
echo   %INSTALL_DIR%\stop.bat   - 停止进程
echo.
echo 卸载: uninstall.bat
echo ========================================
echo.

pause
exit /b 0

:uninstall
echo [INFO] 卸载网络探测工具...
echo.

:: 检查管理员权限
net session >nul 2>&1
if %errorLevel% neq 0 (
    echo [ERROR] 需要管理员权限运行此脚本
    pause
    exit /b 1
)

:: 停止计划任务
schtasks /end /tn "%TASK_NAME%" >nul 2>&1
schtasks /delete /tn "%TASK_NAME%" /f >nul 2>&1

:: 停止进程
taskkill /F /IM %BINARY% >nul 2>&1

:: 处理数据
set "keep_data=N"
if exist "%INSTALL_DIR%\data" (
    set /p keep_data="是否保留数据目录? (y/N): "
)

if /i "!keep_data!"=="y" (
    for /f "tokens=2 delims==" %%i in ('wmic os get localdatetime /value 2^>nul') do set "dt=%%i"
    set "BACKUP_DIR=%USERPROFILE%\network-prober-backup-!dt:~0,8!"
    echo [INFO] 备份数据到: !BACKUP_DIR!
    if not exist "!BACKUP_DIR!" mkdir "!BACKUP_DIR!"
    xcopy /E /I /Y "%INSTALL_DIR%\data" "!BACKUP_DIR!\data" >nul 2>&1
    echo [INFO] 数据已备份
)

:: 删除安装目录
if exist "%INSTALL_DIR%" (
    echo [INFO] 删除安装目录: %INSTALL_DIR%
    rmdir /S /Q "%INSTALL_DIR%" 2>nul
)

echo.
echo [INFO] 卸载完成
echo.

if /i "!keep_data!"=="y" (
    echo 数据已备份到: !BACKUP_DIR!
)

pause
exit /b 0

:help
echo 用法: install.bat [选项]
echo.
echo 选项:
echo   --uninstall        卸载
echo   --port 端口         监听端口 (默认 8080)
echo   --prefix 目录       安装父目录 (默认 C:\)
echo   /?                 显示帮助
echo.
echo 示例:
echo   install.bat                          默认安装
echo   install.bat --port 9090              使用端口 9090
echo   install.bat --prefix D:\Software     安装到 D:\Software\network-prober
echo   install.bat --uninstall              卸载
pause
exit /b 0