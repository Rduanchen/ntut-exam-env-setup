@echo off
chcp 65001 >nul

echo ========================================
echo     Running Test (test.ps1)
echo ========================================
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0test.ps1"

echo.
echo ========================================
echo     Installing ntut-code-tester.exe
echo ========================================
REM Assuming the installer is in the same directory as this batch file
if exist "%~dp0ntut-code-tester.exe" (
    start /wait "" "%~dp0ntut-code-tester.exe"
) else (
    echo [Error] Cannot find %~dp0ntut-code-tester.exe
)

echo.
echo ========================================
echo     Deploying pre_settings.json
echo ========================================
if not exist "%APPDATA%\Local\Programs\ntut-code-tester\resources" (
    mkdir "%APPDATA%\Local\Programs\ntut-code-tester\resources"
)
copy /Y "%~dp0pre_settings.json" "%APPDATA%\Local\Programs\ntut-code-tester\resources\pre_settings.json"


echo.
echo ========================================
echo     Starting ntut-code-tester
echo ========================================
REM Assuming the installed executable path is as follows
if exist "%APPDATA%\..\Local\Programs\ntut-code-tester\NTUTOnMachineTest.exe" (
    start "" "%APPDATA%\..\Local\Programs\ntut-code-tester\NTUTOnMachineTest.exe"
) else (
    echo [Error] Cannot find the installed ntut-code-tester.exe
)

echo.
echo Deployment finished.
pause
