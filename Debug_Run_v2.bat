@echo off
chcp 65001 >nul 2>&1

:: ============================================================================
:: Zhiyuan Debug Launcher v2 - Captures stderr to file
:: ============================================================================

set "ZHIYUAN_DIR=%~dp0r\Zhiyuan-build\bin\Release"
set "ERROR_LOG=%~dp0Zhiyuan_error.log"

echo ============================================
echo   Zhiyuan Debug Mode Launcher v2
echo ============================================
echo.
echo Starting ZhiyuanApp-real.exe directly...
echo This will capture any startup errors to:
echo %ERROR_LOG%
echo.

cd /d "%ZHIYUAN_DIR%"
if %errorlevel% neq 0 (
    echo [ERROR] Failed to change directory to %ZHIYUAN_DIR%
    echo Check if the directory exists.
    pause
    exit /b 1
)

:: Set Qt plugin path so platform plugins can be found when running directly
set "QT_PLUGIN_PATH=%~dp0r\Zhiyuan-build\bin\Release"
echo QT_PLUGIN_PATH=%QT_PLUGIN_PATH%

:: Set Python environment variables (normally set by launcher)
set "PYTHONHOME=%~dp0r\Zhiyuan-build\lib\Python"
set "PYTHONPATH=%~dp0r\Zhiyuan-build\lib\Python\Lib;%~dp0r\Zhiyuan-build\lib\Python\Lib\site-packages"
echo PYTHONHOME=%PYTHONHOME%

echo Running ZhiyuanApp-real.exe with error capture...
echo Started at: %date% %time% > "%ERROR_LOG%"
echo QT_PLUGIN_PATH=%QT_PLUGIN_PATH% >> "%ERROR_LOG%"
echo Directory: %CD% >> "%ERROR_LOG%"
echo Command: ZhiyuanApp-real.exe >> "%ERROR_LOG%"
echo ---------------------------------------- >> "%ERROR_LOG%"

ZhiyuanApp-real.exe >> "%ERROR_LOG%" 2>&1

echo ---------------------------------------- >> "%ERROR_LOG%"
echo Exit code: %errorlevel% >> "%ERROR_LOG%"
echo Finished at: %date% %time% >> "%ERROR_LOG%"

echo.
echo Program exited with code: %errorlevel%
echo.
echo If window closed immediately, check error log at:
echo %ERROR_LOG%
echo.
echo Press any key to view error log...
pause >nul

if exist "%ERROR_LOG%" (
    echo.
    echo === Error Log Contents ===
    type "%ERROR_LOG%"
) else (
    echo.
    echo No error log file found.
)

echo.
echo Press any key to exit...
pause >nul
