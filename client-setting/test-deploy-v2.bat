@echo off
setlocal
chcp 65001 >nul

echo ========================================
echo     Running Test (test-v2.ps1)
echo ========================================
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0test-v2.ps1"

echo.
echo ========================================
echo     Installing NTUT Code Tester Client
echo ========================================
set "INSTALLER="
if exist "%~dp0ntut-code-tester.exe" (
    for %%F in ("%~dp0ntut-code-tester.exe") do if %%~zF GTR 0 set "INSTALLER=%%~fF"
)
if not defined INSTALLER (
    for %%F in ("%~dp0ntut-code-tester-*-setup.exe") do (
        if exist "%%~fF" if not "%%~zF"=="" if not "%%~zF"=="0" set "INSTALLER=%%~fF"
    )
)
if not defined INSTALLER goto installer_missing

echo Installing: "%INSTALLER%"
start /wait "" "%INSTALLER%"
set "INSTALL_EXIT=%ERRORLEVEL%"
if not "%INSTALL_EXIT%"=="0" goto install_failed

set "TARGET_DIR=%LOCALAPPDATA%\Programs\ntut-code-tester"
if exist "%TARGET_DIR%\NTUTOnMachineTest.exe" goto deploy_settings
set "TARGET_DIR=%LOCALAPPDATA%\Programs\NTUT On Machine Test"
if exist "%TARGET_DIR%\NTUTOnMachineTest.exe" goto deploy_settings
echo [Error] Cannot find NTUTOnMachineTest.exe after installation in:
echo   "%LOCALAPPDATA%\Programs\ntut-code-tester"
echo   "%LOCALAPPDATA%\Programs\NTUT On Machine Test"
exit /b 1

:deploy_settings
echo.
echo ========================================
echo     Deploying pre_settings.json
echo ========================================
if not exist "%~dp0pre_settings.json" (
    echo [Error] pre_settings.json not found in "%~dp0"
    exit /b 1
)
if not exist "%TARGET_DIR%\resources" mkdir "%TARGET_DIR%\resources"
copy /Y "%~dp0pre_settings.json" "%TARGET_DIR%\resources\pre_settings.json"
if errorlevel 1 exit /b 1
echo [OK] pre_settings.json deployed.


echo.
echo ========================================
echo      Starting ntut-code-tester
echo ========================================

set "TARGET_EXE=%TARGET_DIR%\NTUTOnMachineTest.exe"

echo [OK] Starting application: "%TARGET_EXE%"

powershell -NoProfile -ExecutionPolicy Bypass -Command "Start-Process -FilePath $env:TARGET_EXE -WorkingDirectory $env:TARGET_DIR"

exit /b 0


@REM  echo.
@REM  echo ========================================
@REM  echo      Starting ntut-code-tester
@REM  echo ========================================
@REM  set "TARGET_EXE=%TARGET_DIR%\NTUTOnMachineTest.exe"
@REM  echo [OK] Starting application: "%TARGET_EXE%"
@REM  start "" "%TARGET_EXE%"
@REM  exit /b %ERRORLEVEL%

:installer_missing
echo [Error] No non-empty ntut-code-tester installer found in "%~dp0"
echo Replace the 0-byte placeholder with the real installer built by build-desktop.sh.
exit /b 1

:install_failed
echo [Error] Installer failed or was cancelled. Exit code: %INSTALL_EXIT%
exit /b %INSTALL_EXIT%
