@echo off
chcp 65001 >nul 2>&1

:: ============================================================================
:: Zhiyuan Post-Install Configuration Script (Ultra-Minimal)
:: This script must complete in SECONDS, not minutes
:: ============================================================================

set "ZHIYUAN_HOME=%~dp0"
set "ZHIYUAN_HOME=%ZHIYUAN_HOME:~0,-1%"

:: Write log immediately
echo [%date% %time%] Starting... > "%ZHIYUAN_HOME%\install_config.log"
echo [%date% %time%] Home: %ZHIYUAN_HOME% >> "%ZHIYUAN_HOME%\install_config.log"

:: Step 1: Quick verification
if not exist "%ZHIYUAN_HOME%\r\Zhiyuan-build\Zhiyuan.exe" (
    echo [%date% %time%] ERROR: Zhiyuan.exe not found >> "%ZHIYUAN_HOME%\install_config.log"
    exit /b 1
)
echo [%date% %time%] [OK] Verification passed >> "%ZHIYUAN_HOME%\install_config.log"

:: Step 2: Set environment variables
echo [%date% %time%] Setting environment variables... >> "%ZHIYUAN_HOME%\install_config.log"

:: TOTALSEG_WEIGHTS_PATH - for TotalSegmentator model loading
set "WEIGHTS_PATH=%ZHIYUAN_HOME%\r\Zhiyuan-build\lib\Zhiyuan-5.9\qt-scripted-modules\plans\seg\total\nnunet\results"
reg add "HKCU\Environment" /v "TOTALSEG_WEIGHTS_PATH" /t REG_SZ /d "%WEIGHTS_PATH%" /f >> "%ZHIYUAN_HOME%\install_config.log" 2>&1

:: SLICER_HOME - critical for Slicer engine initialization
reg add "HKCU\Environment" /v "SLICER_HOME" /t REG_SZ /d "%ZHIYUAN_HOME%\r\Zhiyuan-build" /f >> "%ZHIYUAN_HOME%\install_config.log" 2>&1

:: PYTHONHOME - critical for Python runtime
reg add "HKCU\Environment" /v "PYTHONHOME" /t REG_SZ /d "%ZHIYUAN_HOME%\r\python-install" /f >> "%ZHIYUAN_HOME%\install_config.log" 2>&1

echo [%date% %time%] [OK] Environment variables set >> "%ZHIYUAN_HOME%\install_config.log"

:: Step 3: Done
echo [%date% %time%] [OK] Complete! >> "%ZHIYUAN_HOME%\install_config.log"
exit /b 0
