@echo off
REM ============================================================
REM   Zapret-Status.cmd - double-click for read-only status check
REM   No UAC required, no admin needed.
REM ============================================================
cd /d "%~dp0"
pwsh -NoExit -ExecutionPolicy Bypass -File "%~dp0zapret.ps1" status
