@echo off
setlocal DisableDelayedExpansion
title Campus Connecte - Assistant Wi-Fi
:: Le script PowerShell gere lui-meme la demande administrateur.
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0campus_wifi.ps1"
if errorlevel 1 (
    echo.
    echo Impossible de lancer Campus Connecte. Verifiez les fichiers ou relancez INSTALLER.bat.
    pause
    exit /b 1
)
