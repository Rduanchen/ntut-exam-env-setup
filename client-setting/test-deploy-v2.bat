@echo off
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
if exist "%~dp0ntut-code-tester.exe" set "INSTALLER=%~dp0ntut-code-tester.exe"
if not defined INSTALLER (
    for %%f in ("%~dp0ntut-code-tester*.exe") do set "INSTALLER=%%f"
)

if defined INSTALLER (
    for %%F in ("%INSTALLER%") do (
        if %%~zF EQU 0 (
            echo [Error] Installer "%%~nxF" is an empty (0 byte) placeholder file!
            echo Please build the desktop application (npm run build:win) and place the real installer here.
        ) else (
            echo Found installer: %%~nxF
            echo Installing, please wait...
            start /wait "" "%INSTALLER%"
        )
    )
) else (
    echo [Error] Cannot find ntut-code-tester installer in %~dp0
)

echo.
echo ========================================
echo     Deploying pre_settings.json
echo ========================================
if not exist "%LOCALAPPDATA%\Programs\ntut-code-tester\resources" (
    mkdir "%LOCALAPPDATA%\Programs\ntut-code-tester\resources" 2>nul
)
if not exist "%LOCALAPPDATA%\Programs\NTUT On Machine Test\resources" (
    mkdir "%LOCALAPPDATA%\Programs\NTUT On Machine Test\resources" 2>nul
)

if exist "%~dp0pre_settings.json" (
    copy /Y "%~dp0pre_settings.json" "%LOCALAPPDATA%\Programs\ntut-code-tester\resources\pre_settings.json" >nul 2>&1
    copy /Y "%~dp0pre_settings.json" "%LOCALAPPDATA%\Programs\NTUT On Machine Test\resources\pre_settings.json" >nul 2>&1
    echo [OK] pre_settings.json deployed.
) else (
    echo [Warning] pre_settings.json not found in %~dp0
)

echo.
echo ========================================
echo      Starting ntut-code-tester
echo ========================================
set "TARGET_EXE=%LOCALAPPDATA%\Programs\ntut-code-tester\NTUTOnMachineTest.exe"
if not exist "%TARGET_EXE%" (
    set "TARGET_EXE=%LOCALAPPDATA%\Programs\NTUT On Machine Test\NTUTOnMachineTest.exe"
)

if exist "%TARGET_EXE%" (
    echo [OK] Starting application: %TARGET_EXE%
    start "" "%TARGET_EXE%"
    exit
) else (
    echo [Error] Cannot find NTUTOnMachineTest.exe in:
    echo   %LOCALAPPDATA%\Programs\ntut-code-tester\
    echo   %LOCALAPPDATA%\Programs\NTUT On Machine Test\
)
