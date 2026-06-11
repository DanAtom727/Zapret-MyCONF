#requires -Version 7
<#
.SYNOPSIS
  zapret.ps1 - single-script control panel for my-zapret-final-v2 deployment.

.DESCRIPTION
  Trofi's zapret deploy. Manages winws.exe lifecycle (start/stop/status/reload)
  and optionally registers it as a Windows service for boot-time autostart.

  All actions assume my-zapret-final-v2.cmd lives next to this script with
  list-final.txt in lists\ and blobs in blockcheck\zapret\files\fake\.
  See CLAUDE.md for deployment principles.

  Build date: 2026-05-13
  Strategy:   Flowseal general (ALT).bat port - fake,hostfakesplit + sni=ya.ru
              + host=ya.ru,altorder=1 + fooling=ts (PROVEN working on this ISP)

.PARAMETER Action
  start    - run my-zapret-final-v2.cmd (auto-elevates UAC if needed)
  stop     - taskkill /F /IM winws.exe winws2.exe
  status   - show running winws process info + reachability check
  reload   - stop + start (use after editing list-final.txt or .cmd)
  install  - register as Windows service "zapret-my" (autostart at boot)
  remove   - stop and delete the service
  menu     - interactive console menu (default if no Action given)

.EXAMPLE
  .\zapret.ps1 start
  .\zapret.ps1 status
  .\zapret.ps1                # opens menu
#>
[CmdletBinding()]
param(
    [ValidateSet('start','stop','status','reload','install','remove','menu')]
    [string]$Action = 'menu'
)

$ErrorActionPreference = 'Stop'
$Root      = $PSScriptRoot
$CmdFile   = Join-Path $Root 'my-zapret-alt3.cmd'
$WinwsExe  = Join-Path $Root 'zapret-winws\winws.exe'
$Hostlist  = Join-Path $Root 'lists\list-final.txt'
$SvcName   = 'zapret-my'
$SvcDisp   = 'Zapret DPI Bypass (custom)'
$SvcDesc   = 'Custom zapret config: fake,hostfakesplit + sni=ya.ru + fooling=ts. Strategy from Flowseal general (ALT).bat, binaries from bol-van bundle.'

function Test-Admin {
    $id = [Security.Principal.WindowsIdentity]::GetCurrent()
    ([Security.Principal.WindowsPrincipal]::new($id)).IsInRole(
        [Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Get-Winws {
    Get-CimInstance Win32_Process -Filter "Name='winws.exe' OR Name='winws2.exe'" -ErrorAction SilentlyContinue
}

function Invoke-Start {
    $running = Get-Winws
    if ($running) {
        Write-Host "Already running:" -ForegroundColor Yellow
        $running | ForEach-Object {
            Write-Host ("  PID {0}  started {1}" -f $_.ProcessId, $_.CreationDate)
        }
        return
    }
    $conf = Join-Path $Root 'winws-final.conf'
    if (-not (Test-Path $WinwsExe)) { Write-Host "ERROR: $WinwsExe missing" -ForegroundColor Red; return }
    if (-not (Test-Path $conf))     { Write-Host "ERROR: $conf missing"     -ForegroundColor Red; return }

    # FOREGROUND START via .cmd - the proven working method.
    # Headless via [Process]::Start with Hidden WindowStyle from a PS session
    # does NOT work the same as service-mode (different session/access for the
    # WinDivert driver). For true headless use 'install' (service mode).
    if (-not (Test-Path $CmdFile)) {
        Write-Host "ERROR: $CmdFile not found" -ForegroundColor Red
        return
    }
    if (Test-Admin) {
        Write-Host "Starting my-zapret-final-v2.cmd (visible cmd-window)..." -ForegroundColor Cyan
        Start-Process -FilePath $CmdFile -WindowStyle Normal
        Start-Sleep -Seconds 2
        Invoke-Status
    } else {
        Write-Host "Elevating via UAC..." -ForegroundColor Cyan
        Start-Process -FilePath $CmdFile -Verb RunAs
        Start-Sleep -Seconds 3
        Invoke-Status
    }
}

function Invoke-Stop {
    $running = Get-Winws
    if (-not $running) {
        Write-Host "Already stopped - no winws/winws2 process running." -ForegroundColor Yellow
        return
    }
    foreach ($p in $running) {
        Write-Host ("Killing {0} PID {1}" -f $p.Name, $p.ProcessId) -ForegroundColor Cyan
        Stop-Process -Id $p.ProcessId -Force -ErrorAction SilentlyContinue
    }
    Start-Sleep -Seconds 1
    if (Get-Winws) {
        Write-Host "Something is still up - try elevated shell." -ForegroundColor Red
    } else {
        Write-Host "Stopped." -ForegroundColor Green
    }
}

function Invoke-Status {
    Write-Host ""
    Write-Host "=== zapret-my status ===" -ForegroundColor Cyan
    $running = Get-Winws
    if (-not $running) {
        Write-Host "winws/winws2: NOT running" -ForegroundColor Red
    } else {
        foreach ($p in $running) {
            $age = (Get-Date) - $p.CreationDate
            Write-Host ("Binary:   {0}" -f $p.Name)              -ForegroundColor Green
            Write-Host ("PID:      {0}" -f $p.ProcessId)
            Write-Host ("Started:  {0}  (age {1:N0}h {2:N0}m)" -f $p.CreationDate, $age.TotalHours, $age.Minutes)
        }
    }
    Write-Host ""
    Write-Host "Hostlist: $Hostlist" -ForegroundColor Cyan
    if (Test-Path $Hostlist) {
        $count = (Get-Content $Hostlist | Where-Object { $_ -and $_ -notmatch '^\s*#' }).Count
        Write-Host ("  {0} entries:" -f $count)
        Get-Content $Hostlist | Where-Object { $_ -and $_ -notmatch '^\s*#' } |
            ForEach-Object { Write-Host "    $_" }
    } else {
        Write-Host "  MISSING" -ForegroundColor Red
    }
    Write-Host ""
    Write-Host "TCP/443 reachability:" -ForegroundColor Cyan
    $hosts = @('discord.com','gateway.discord.gg','cdn.discordapp.com')
    foreach ($h in $hosts) {
        $r = Test-NetConnection $h -Port 443 -WarningAction SilentlyContinue
        $color = if ($r.TcpTestSucceeded) { 'Green' } else { 'Red' }
        Write-Host ("  {0,-25} TCP/443 = {1}  via {2}" -f $h, $r.TcpTestSucceeded, $r.RemoteAddress) -ForegroundColor $color
    }
    Write-Host ""
    Write-Host "Conflicting tunnels:" -ForegroundColor Cyan
    $bad = Get-Process | Where-Object { $_.Name -match 'xray|warp|amnezia|wireguard|ovpn|tun2socks|sing-?box|hysteria|v2ray|clash|outline|happ|psiphon|hiddify' } -ErrorAction SilentlyContinue
    if ($null -eq $bad) {
        Write-Host "  none (clean)" -ForegroundColor Green
    } else {
        Write-Host "  WARNING - these may intercept Discord traffic before WinDivert:" -ForegroundColor Yellow
        $bad | Format-Table Name, Id, StartTime -AutoSize | Out-String -Stream | ForEach-Object { Write-Host "  $_" }
        Write-Host "  (happ for claude.ai is fine if routed only for claude/anthropic domains)"
    }
    Write-Host ""
}

function Invoke-Reload {
    Invoke-Stop
    Start-Sleep -Seconds 1
    Invoke-Start
}

function Invoke-Install {
    if (-not (Test-Admin)) {
        Write-Host "Need admin to install service. Relaunching elevated..." -ForegroundColor Yellow
        Start-Process pwsh -Verb RunAs -ArgumentList "-NoExit","-File","`"$PSCommandPath`"","install"
        return
    }
    # Tear down any pre-existing service first (broken or otherwise)
    if (Get-Service $SvcName -ErrorAction SilentlyContinue) {
        Write-Host "Service '$SvcName' exists - removing first..." -ForegroundColor Yellow
        & sc.exe stop $SvcName 2>$null | Out-Null
        Start-Sleep -Seconds 1
        & sc.exe delete $SvcName | Out-Null
        Start-Sleep -Seconds 1
    }
    $conf = Join-Path $Root 'winws-final.conf'
    if (-not (Test-Path $WinwsExe)) { Write-Host "ERROR: $WinwsExe missing" -ForegroundColor Red; return }
    if (-not (Test-Path $conf))     { Write-Host "ERROR: $conf missing" -ForegroundColor Red; return }

    Write-Host "Creating service '$SvcName' (winws.exe with @config, SCM-mode)..." -ForegroundColor Cyan
    # CRITICAL: binPath= direct winws.exe @config (NO cmd /c wrapper) - winws.exe
    # has SCM-dispatcher built in (proven by bol-van's service_create.cmd line 28).
    # cmd-wrapper -> SCM gets no StartServiceCtrlDispatcher -> error 1053.
    $binPath = '"{0}" @"{1}"' -f $WinwsExe, $conf
    & sc.exe create $SvcName binPath= $binPath start= auto DisplayName= $SvcDisp | Out-Null
    & sc.exe description $SvcName $SvcDesc | Out-Null
    Write-Host "Done. Configuration:" -ForegroundColor Green
    & sc.exe qc $SvcName
    Write-Host ""
    Write-Host "Starting service..." -ForegroundColor Cyan
    & sc.exe start $SvcName
    Start-Sleep -Seconds 2
    & sc.exe query $SvcName
    Write-Host ""
    Write-Host "If state is RUNNING - autostart on boot is on, you can close this window." -ForegroundColor Green
    Write-Host "If service failed - check Event Viewer (Windows Logs -> System) for winws errors." -ForegroundColor Yellow
}

function Invoke-Remove {
    if (-not (Test-Admin)) {
        Write-Host "Need admin to remove service. Relaunching elevated..." -ForegroundColor Yellow
        Start-Process pwsh -Verb RunAs -ArgumentList "-NoExit","-File","`"$PSCommandPath`"","remove"
        return
    }
    if (-not (Get-Service $SvcName -ErrorAction SilentlyContinue)) {
        Write-Host "Service '$SvcName' does not exist." -ForegroundColor Yellow
    } else {
        Write-Host "Stopping & deleting service '$SvcName'..." -ForegroundColor Cyan
        & sc.exe stop $SvcName 2>$null | Out-Null
        Start-Sleep -Seconds 1
        & sc.exe delete $SvcName | Out-Null
    }
    Get-Winws | ForEach-Object {
        Write-Host ("Killing leftover {0} PID {1}" -f $_.Name, $_.ProcessId) -ForegroundColor Yellow
        Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue
    }
    Write-Host "Done." -ForegroundColor Green
}

function Invoke-Menu {
    while ($true) {
        Clear-Host
        Write-Host ""
        Write-Host "  +=========================================+" -ForegroundColor Cyan
        Write-Host "  |  zapret-my control panel                |" -ForegroundColor Cyan
        Write-Host "  |  fake,hostfakesplit + sni=ya.ru         |" -ForegroundColor DarkCyan
        Write-Host "  +=========================================+" -ForegroundColor Cyan
        $running = Get-Winws
        if ($running) {
            Write-Host "    state: RUNNING " -NoNewline -ForegroundColor Green
            Write-Host ("(PID {0})" -f ($running.ProcessId -join ','))
        } else {
            Write-Host "    state: stopped" -ForegroundColor DarkGray
        }
        Write-Host ""
        Write-Host "    [1] Start         [4] Reload (stop+start)"
        Write-Host "    [2] Stop          [5] Install as service (autostart)"
        Write-Host "    [3] Status        [6] Remove service"
        Write-Host "    [Q] Quit"
        Write-Host ""
        $choice = Read-Host "  Pick"
        switch ($choice) {
            '1' { Invoke-Start;   Pause }
            '2' { Invoke-Stop;    Pause }
            '3' { Invoke-Status;  Pause }
            '4' { Invoke-Reload;  Pause }
            '5' { Invoke-Install; Pause }
            '6' { Invoke-Remove;  Pause }
            'q' { return }
            'Q' { return }
            default { }
        }
    }
}

switch ($Action) {
    'start'   { Invoke-Start }
    'stop'    { Invoke-Stop }
    'status'  { Invoke-Status }
    'reload'  { Invoke-Reload }
    'install' { Invoke-Install }
    'remove'  { Invoke-Remove }
    'menu'    { Invoke-Menu }
}
