@echo off
REM ============================================================
REM   Zapret-Menu.cmd - double-click to open interactive menu
REM   Some menu actions (Start/Install/Remove) re-elevate to admin
REM   via UAC themselves when needed.
REM ============================================================
cd /d "%~dp0"
pwsh -NoExit -ExecutionPolicy Bypass -File "%~dp0zapret.ps1"
