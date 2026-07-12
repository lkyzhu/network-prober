@echo off
setlocal enabledelayedexpansion

:: 网络探测工具 - Windows 卸载脚本
:: 需要管理员权限运行

set "INSTALL_DIR=C:\network-prober"
set "TASK_NAME=NetworkProber"
set "BINARY=network-prober.exe"

echo [INFO] 网络探测工具 - 卸载脚本
echo.

:: 检查管理员权限
net session >nul 2>&1
if %errorLevel% neq 0 (
    echo [ERROR] 需要管理员权限运行此脚本
    echo 请右键选择"以管理员身份运行"
    pause
    exit /b 1
)

:: 停止计划任务
echo [INFO] 停止计划任务...
schtasks /end /tn "%TASK_NAME%" >nul 2>&1
schtasks /delete /tn "%TASK_NAME%" /f >nul 2>&1

:: 停止进程
echo [INFO] 停止进程...
taskkill /F /IM %BINARY% >nul 2>&1

:: 询问是否保留数据
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