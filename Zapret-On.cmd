@echo off
REM ============================================================
REM   Zapret-On.cmd - double-click to start zapret (visible cmd-window)
REM   UAC will prompt. winws will run in its own cmd-window.
REM   For TRUE headless / autostart use:  zapret.ps1 install (service).
REM ============================================================
cd /d "%~dp0"
powershell -ExecutionPolicy Bypass -Command "Start-Process '%~dp0my-zapret-alt3.cmd' -Verb RunAs"
