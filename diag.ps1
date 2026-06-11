#requires -Version 7
# diag.ps1 - Discord/zapret deploy diagnostics
# Run from PowerShell: & "C:\Users\Danatos\Downloads\1\bol-van\zapret-win-bundle-master\diag.ps1"
# No admin required for any of these checks.

$ErrorActionPreference = 'Continue'

Write-Host ""
Write-Host "=== 1. Running winws / winws2 processes ===" -ForegroundColor Cyan
$winws = Get-CimInstance Win32_Process -Filter "Name='winws.exe' OR Name='winws2.exe'"
if ($null -eq $winws) {
    Write-Host "Neither winws.exe nor winws2.exe is running" -ForegroundColor Red
} else {
    foreach ($p in $winws) {
        Write-Host ("Binary:       {0}" -f $p.Name)
        Write-Host ("PID:          {0}" -f $p.ProcessId)
        Write-Host ("Started:      {0}" -f $p.CreationDate)
        $age = (Get-Date) - $p.CreationDate
        Write-Host ("Age:          {0:N0}h {1:N0}m" -f $age.TotalHours, $age.Minutes)
        Write-Host "CommandLine:"
        Write-Host ("  " + $p.CommandLine)
        Write-Host ""
    }
}

Write-Host "=== 2. TCP/443 reachability ===" -ForegroundColor Cyan
$hosts = @('discord.com','gateway.discord.gg','cdn.discordapp.com','dl.discordapp.net','media.discordapp.net','update.discord.com')
$results = foreach ($h in $hosts) {
    $r = Test-NetConnection -ComputerName $h -Port 443 -WarningAction SilentlyContinue
    [pscustomobject]@{
        Host          = $h
        TcpSucceeded  = $r.TcpTestSucceeded
        RemoteAddress = $r.RemoteAddress
        PingSucceeded = $r.PingSucceeded
    }
}
$results | Format-Table -AutoSize

Write-Host "=== 3. DNS resolution ===" -ForegroundColor Cyan
$dnsRows = foreach ($h in $hosts) {
    try {
        $ans = Resolve-DnsName -Name $h -Type A -ErrorAction Stop |
            Where-Object { $_.IPAddress } |
            Select-Object -First 1
        [pscustomobject]@{ Host = $h; IPAddress = $ans.IPAddress; Source = "DNS" }
    } catch {
        [pscustomobject]@{ Host = $h; IPAddress = "FAIL"; Source = $_.Exception.Message }
    }
}
$dnsRows | Format-Table -AutoSize

Write-Host "=== 4. debug log tail ===" -ForegroundColor Cyan
$logCandidates = @(
    "$PSScriptRoot\winws2-debug.log",
    "$PSScriptRoot\winws-debug.log"
)
$logPath = $logCandidates | Where-Object { Test-Path $_ } |
    Sort-Object { (Get-Item $_).LastWriteTime } -Descending |
    Select-Object -First 1

if ($null -eq $logPath) {
    Write-Host "No debug log found. Start my-zapret-2.cmd (zapret2) or my-zapret-v4.cmd (zapret1) as admin, open Discord, then re-run this script."
} else {
    $info = Get-Item $logPath
    Write-Host ("Log path:    {0}" -f $logPath)
    Write-Host ("Size:        {0:N0} bytes" -f $info.Length)
    Write-Host ("Last write:  {0}" -f $info.LastWriteTime)
    Write-Host "--- Last 40 lines ---"
    Get-Content $logPath -Tail 40
    Write-Host ""
    Write-Host "--- Hostnames seen in profile search (top 20) ---"
    Select-String -Path $logPath -Pattern "hostname='([^']+)'" -AllMatches |
        ForEach-Object { $_.Matches } |
        ForEach-Object { $_.Groups[1].Value } |
        Where-Object { $_ -ne '' } |
        Group-Object |
        Sort-Object Count -Descending |
        Select-Object -First 20 Count, Name |
        Format-Table -AutoSize
    Write-Host "--- 'not applying tampering' count (high = bad, low = good) ---"
    $skipped = (Select-String -Path $logPath -Pattern 'not applying tampering' -AllMatches | Measure-Object).Count
    $matched = (Select-String -Path $logPath -Pattern 'desync profile 0 matches' -AllMatches | Measure-Object).Count
    Write-Host ("  skipped (no tampering): {0}" -f $skipped)
    Write-Host ("  desync matched:         {0}" -f $matched)
}

Write-Host "=== 5. Conflicting tools ===" -ForegroundColor Cyan
$bad = Get-Process | Where-Object { $_.Name -match 'xray|warp|amnezia|wireguard|ovpn|tun2socks|sing-?box|hysteria|v2ray|clash|outline|happ|psiphon|hiddify' }
if ($null -eq $bad) {
    Write-Host "OK - no competing VPN/proxy processes"
} else {
    $bad | Format-Table Name, Id, StartTime -AutoSize
}
Write-Host ""
