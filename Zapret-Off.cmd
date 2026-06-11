@echo off
REM ============================================================
REM   Zapret-Off.cmd - double-click to stop zapret HEADLESS
REM   UAC will prompt, then winws is killed silently.
REM   This .cmd auto-closes after stop.
REM ============================================================
cd /d "%~dp0"
powershell -ExecutionPolicy Bypass -WindowStyle Hidden -Command "Start-Process pwsh -Verb RunAs -ArgumentList '-NoProfile','-WindowStyle','Hidden','-File','%~dp0zapret.ps1','stop'"
