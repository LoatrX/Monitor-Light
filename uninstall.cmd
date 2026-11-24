@echo off
setlocal EnableExtensions
chcp 65001 >nul
title Monitor-Light - Desinstallation
color 0E

set "MONITORLIGHT=%LOCALAPPDATA%\Monitor-Light"
set "MONITORSCREEN=%LOCALAPPDATA%\Monitor-Screen"
set "STARTUPLINK=%APPDATA%\Microsoft\Windows\Start Menu\Programs\Startup\Monitor-Light.lnk"
set "POWERSHELL=%WINDIR%\System32\WindowsPowerShell\v1.0\powershell.exe"

cls
echo ============================================================
echo                DESINSTALLATION MONITOR-LIGHT
echo ============================================================
echo.
echo Les dossiers suivants seront supprimes s'ils existent :
echo %MONITORLIGHT%
echo %MONITORSCREEN%
echo.
choice /C ON /N /M "Continuer ? [O/N] "
if errorlevel 2 exit /b 0

echo.
echo [1/3] Arret de l'application...
"%POWERSHELL%" -NoLogo -NoProfile -ExecutionPolicy Bypass -Command "$ErrorActionPreference='SilentlyContinue'; Get-CimInstance Win32_Process -Filter \"Name='powershell.exe'\" | Where-Object { $_.CommandLine -like '*Monitor-Light.ps1*' -or $_.CommandLine -like '*Monitor-Screen*' } | ForEach-Object { Invoke-CimMethod -InputObject $_ -MethodName Terminate | Out-Null }" >nul 2>&1

echo [2/3] Suppression du demarrage automatique...
if exist "%STARTUPLINK%" del /F /Q "%STARTUPLINK%" >nul 2>&1

echo [3/3] Suppression complete des dossiers...
set "CLEANUP=%TEMP%\Monitor-Light-Uninstall-Cleanup-%RANDOM%.cmd"
>"%CLEANUP%" echo @echo off
>>"%CLEANUP%" echo timeout /t 4 /nobreak ^>nul
>>"%CLEANUP%" echo if exist "%MONITORLIGHT%" rmdir /S /Q "%MONITORLIGHT%" ^>nul 2^>^&1
>>"%CLEANUP%" echo if exist "%MONITORSCREEN%" rmdir /S /Q "%MONITORSCREEN%" ^>nul 2^>^&1
>>"%CLEANUP%" echo del /F /Q "%%~f0" ^>nul 2^>^&1
start "" /min "%WINDIR%\System32\cmd.exe" /c ""%CLEANUP%""

echo.
echo Desinstallation lancee. Les dossiers seront supprimes dans quelques secondes.
timeout /t 3 /nobreak >nul
exit /b 0
