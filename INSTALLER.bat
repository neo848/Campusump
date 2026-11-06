@echo off
setlocal DisableDelayedExpansion
title Installation - Campus Connecte
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Installer_Campus.ps1"
if errorlevel 1 (
    echo.
    echo Installation echouee. Gardez ce dossier complet et reessayez.
    pause
    exit /b 1
)
echo.
echo Vous pouvez fermer cette fenetre et utiliser Campus Connecte sur le Bureau.
pause
