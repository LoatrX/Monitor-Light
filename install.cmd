@echo off
setlocal EnableExtensions EnableDelayedExpansion
chcp 65001 >nul
title Monitor-Light - Installation
color 0A

set "SOURCE=%~dp0"
set "APPROOT=%LOCALAPPDATA%\Monitor-Light"
set "APPDIR=%APPROOT%\app"
set "ASSETDIR=%APPROOT%\assets\img"
set "PROFILEDIR=%APPROOT%\user_profil"
set "STARTUPDIR=%APPDATA%\Microsoft\Windows\Start Menu\Programs\Startup"
set "STARTUPLINK=%STARTUPDIR%\Monitor-Light.lnk"
set "POWERSHELL=%WINDIR%\System32\WindowsPowerShell\v1.0\powershell.exe"
set "WSCRIPT=%WINDIR%\System32\wscript.exe"
set "READY=%PROFILEDIR%\ready.flag"
set "LOG=%PROFILEDIR%\Monitor-Light.log"
set "ZIPNAME=Monitor-Light-v2.4.2.zip"

cls
echo ============================================================
echo                 INSTALLATION MONITOR-LIGHT
echo ============================================================
echo.
echo Utilisateur : %USERNAME%
echo Installation : %APPROOT%
echo Demarrage automatique : %STARTUPLINK%
echo.

if not exist "%SOURCE%app\Monitor-Light.ps1" goto :missing
if not exist "%SOURCE%app\Monitor-Light-Launcher.vbs" goto :missing
if not exist "%SOURCE%assets\img\icon.svg" goto :missing
if not exist "%SOURCE%assets\img\display.svg" goto :missing
if not exist "%SOURCE%assets\img\laptop.svg" goto :missing

 echo [1/8] Arret de l'ancienne version...
"%POWERSHELL%" -NoLogo -NoProfile -ExecutionPolicy Bypass -Command "$ErrorActionPreference='SilentlyContinue'; Get-CimInstance Win32_Process -Filter \"Name='powershell.exe'\" | Where-Object { $_.CommandLine -like '*Monitor-Light.ps1*' } | ForEach-Object { Invoke-CimMethod -InputObject $_ -MethodName Terminate | Out-Null }" >nul 2>&1

 echo [2/8] Creation des dossiers...
if not exist "%APPDIR%" mkdir "%APPDIR%" >nul 2>&1
if not exist "%ASSETDIR%" mkdir "%ASSETDIR%" >nul 2>&1
if not exist "%PROFILEDIR%" mkdir "%PROFILEDIR%" >nul 2>&1
if not exist "%STARTUPDIR%" mkdir "%STARTUPDIR%" >nul 2>&1
if errorlevel 1 goto :error

 echo [3/8] Copie des fichiers...
copy /Y "%SOURCE%app\Monitor-Light.ps1" "%APPDIR%\Monitor-Light.ps1" >nul || goto :error
copy /Y "%SOURCE%app\Monitor-Light-Launcher.vbs" "%APPDIR%\Monitor-Light-Launcher.vbs" >nul || goto :error
xcopy /E /I /Y "%SOURCE%assets" "%APPROOT%\assets" >nul || goto :error
copy /Y "%SOURCE%install.cmd" "%APPROOT%\install.cmd" >nul || goto :error
copy /Y "%SOURCE%uninstall.cmd" "%APPROOT%\uninstall.cmd" >nul || goto :error
if not exist "%PROFILEDIR%\settings.json" (
    copy /Y "%SOURCE%user_profil\settings.json" "%PROFILEDIR%\settings.json" >nul || goto :error
)

 echo [4/8] Deblocage des fichiers telecharges...
"%POWERSHELL%" -NoLogo -NoProfile -ExecutionPolicy Bypass -Command "Get-ChildItem -LiteralPath '%APPROOT%' -Recurse -File -ErrorAction SilentlyContinue | Unblock-File -ErrorAction SilentlyContinue" >nul 2>&1

 echo [5/8] Creation du raccourci de demarrage...
"%POWERSHELL%" -NoLogo -NoProfile -ExecutionPolicy Bypass -Command "$ws=New-Object -ComObject WScript.Shell; $shortcut=$ws.CreateShortcut('%STARTUPLINK%'); $shortcut.TargetPath='%WSCRIPT%'; $shortcut.Arguments='\"%APPDIR%\Monitor-Light-Launcher.vbs\"'; $shortcut.WorkingDirectory='%APPDIR%'; $shortcut.Description='Monitor-Light'; $shortcut.Save()" >nul 2>&1
if errorlevel 1 goto :error

 echo [6/8] Verification du raccourci...
if not exist "%STARTUPLINK%" goto :error

 echo [7/8] Lancement de Monitor-Light...
if exist "%READY%" del /F /Q "%READY%" >nul 2>&1
if exist "%LOG%" del /F /Q "%LOG%" >nul 2>&1
start "" "%WSCRIPT%" "%APPDIR%\Monitor-Light-Launcher.vbs"

 echo [8/8] Verification du demarrage...
set /A WAITCOUNT=0
:wait_ready
if exist "%READY%" goto :success
set /A WAITCOUNT+=1
if !WAITCOUNT! GEQ 20 goto :not_ready
timeout /t 1 /nobreak >nul
goto :wait_ready

:success
echo.
echo ============================================================
echo Installation terminee avec succes.
echo Monitor-Light est actif et demarrera avec Windows.
echo ============================================================
echo.
echo Nettoyage automatique des fichiers telecharges...

rem Le nettoyage est execute depuis TEMP apres la fermeture de cet installateur.
set "CLEANUP=%TEMP%\Monitor-Light-Install-Cleanup-%RANDOM%.cmd"
set "EXTRACTED=%SOURCE:~0,-1%"
for %%I in ("%SOURCE%..") do set "DOWNLOADDIR=%%~fI"

>"%CLEANUP%" echo @echo off
>>"%CLEANUP%" echo timeout /t 5 /nobreak ^>nul
>>"%CLEANUP%" echo if /I not "!EXTRACTED!"=="%APPROOT%" if exist "!EXTRACTED!\app\Monitor-Light.ps1" rmdir /S /Q "!EXTRACTED!" ^>nul 2^>^&1
>>"%CLEANUP%" echo if exist "!DOWNLOADDIR!\%ZIPNAME%" del /F /Q "!DOWNLOADDIR!\%ZIPNAME%" ^>nul 2^>^&1
>>"%CLEANUP%" echo del /F /Q "%%~f0" ^>nul 2^>^&1

start "" /min "%WINDIR%\System32\cmd.exe" /c ""%CLEANUP%""
timeout /t 3 /nobreak >nul
exit /b 0

:missing
color 0C
echo.
echo ERREUR : le package est incomplet.
echo Decompressez entierement %ZIPNAME% avant de lancer install.cmd.
echo.
pause
exit /b 1

:not_ready
color 0C
echo.
echo ERREUR : Monitor-Light n'a pas confirme son demarrage.
echo Journal : %LOG%
echo Le ZIP et le dossier extrait ne sont pas supprimes pour permettre le diagnostic.
echo.
pause
exit /b 2

:error
color 0C
echo.
echo ERREUR : l'installation a echoue.
echo Le ZIP et le dossier extrait ne sont pas supprimes.
echo.
pause
exit /b 1
