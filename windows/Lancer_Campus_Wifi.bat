@echo off
setlocal EnableDelayedExpansion
title Campus Connecte - Assistant IP Statique UMP

:: ============================================================================
:: Verification et Elevation des droits Administrateur (UAC)
:: ============================================================================
net session >nul 2>&1
if %errorLevel% neq 0 (
    echo.
    echo ====================================================================
    echo   DEMANDE D'ELEVATION DES PRIVILEGES ADMINISTRATEUR
    echo ====================================================================
    echo  Ce script a besoin des droits administrateur pour modifier
    echo  les parametres reseau de votre carte Wi-Fi.
    echo  Une fenetre de confirmation UAC va apparaitre...
    echo.
    powershell.exe -NoProfile -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
    exit /b
)

:: ============================================================================
:: Lancement du script PowerShell avec contournement de politique d'execution
:: ============================================================================
cd /d "%~dp0"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0campus_wifi.ps1"

if %errorLevel% neq 0 (
    echo.
    echo [ERREUR] Le script s'est termine avec une erreur (Code: %errorLevel%).
    echo.
    pause
)
