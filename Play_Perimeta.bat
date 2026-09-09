@echo off
:: =====================================================
::  Perimeta Game Launcher
:: =====================================================
title Perimeta
chcp 65001 >nul
cd /d "%~dp0"

:: First try direct exported executable
if exist "Perimeta.exe" (
    start "" "Perimeta.exe"
    exit /b 0
)

:: Fallback to Godot engine runner
if exist "..\Godot\Godot_v4.7.2-stable_win64.exe" (
    start "" "..\Godot\Godot_v4.7.2-stable_win64.exe" --path "%~dp0."
    exit /b 0
)

echo [!] Error: Neither Perimeta.exe nor Godot engine executable found.
pause
