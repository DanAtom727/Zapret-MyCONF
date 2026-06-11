@echo off
chcp 65001 > nul
title zapret-my-alt3 [full multistage port of Flowseal general (ALT3).bat]

REM ============================================================
REM   my-zapret-alt3.cmd - full port of Flowseal general (ALT3).bat
REM ============================================================
REM   Place at: bol-van\zapret-win-bundle-master\
REM   Run AS ADMINISTRATOR.
REM
REM   Build date: 2026-05-13 (rev4)
REM   Source: flowseal\general (ALT3).bat (identical to ALT.bat).
REM     Trofi confirmed ALT3 WORKS for Discord voice on his ISP.
REM     This is a full byte-equivalent port to bol-van binaries.
REM
REM   Adaptations from Flowseal:
REM     - winws.exe         : flowseal/bin/ -> bol-van/zapret-winws/
REM     - tls_clienthello_max_ru.bin       -> bol-van's tls_clienthello_gosuslugi_ru.bin
REM     - quic_initial_dbankcloud_ru.bin   -> bol-van's quic_initial_vk_com.bin
REM     - quic_initial_www_google_com.bin  : same name, bol-van's copy
REM     - hostlists/ipsets : copied from flowseal/lists/ into bol-van/lists/
REM
REM   Game-filter blocks (ALT3 blocks 8-9) OMITTED - they require
REM   %GameFilterTCP%/%GameFilterUDP% vars from Flowseal's service.bat.
REM   Remaining 7 blocks cover Discord+web fully.
REM ============================================================

cd /d "%~dp0"

set "WINWS=%~dp0zapret-winws\winws.exe"
set "LISTS=%~dp0lists\"
set "BLOBS=%~dp0blockcheck\zapret\files\fake\"

if not exist "%WINWS%" (echo [ERROR] winws.exe missing & pause & exit /b 1)
if not exist "%LISTS%list-general.txt" (echo [ERROR] list-general.txt missing & pause & exit /b 1)
if not exist "%BLOBS%tls_clienthello_gosuslugi_ru.bin" (echo [ERROR] gosuslugi blob missing & pause & exit /b 1)
if not exist "%BLOBS%quic_initial_vk_com.bin" (echo [ERROR] vk QUIC blob missing & pause & exit /b 1)

echo Starting winws (Flowseal ALT3 port, 7 blocks)
echo Stop: taskkill /F /IM winws.exe  or close this window
echo.

start "zapret-alt3" /min "%WINWS%" ^
--wf-tcp=80,443,2053,2083,2087,2096,8443 ^
--wf-udp=443,19294-19344,50000-50100 ^
--filter-udp=443 --hostlist="%LISTS%list-general.txt" --hostlist="%LISTS%list-general-user.txt" --hostlist-exclude="%LISTS%list-exclude.txt" --hostlist-exclude="%LISTS%list-exclude-user.txt" --ipset-exclude="%LISTS%ipset-exclude.txt" --ipset-exclude="%LISTS%ipset-exclude-user.txt" --dpi-desync=fake --dpi-desync-repeats=6 --dpi-desync-fake-quic="%BLOBS%quic_initial_www_google_com.bin" --new ^
--filter-udp=19294-19344,50000-50100 --filter-l7=discord,stun --dpi-desync=fake --dpi-desync-fake-discord="%BLOBS%quic_initial_vk_com.bin" --dpi-desync-fake-stun="%BLOBS%quic_initial_vk_com.bin" --dpi-desync-repeats=6 --new ^
--filter-tcp=2053,2083,2087,2096,8443 --hostlist-domains=discord.media --dpi-desync=fake,hostfakesplit --dpi-desync-fake-tls-mod=rnd,dupsid,sni=www.google.com --dpi-desync-hostfakesplit-mod=host=www.google.com,altorder=1 --dpi-desync-fooling=ts --new ^
--filter-tcp=443 --hostlist="%LISTS%list-google.txt" --ip-id=zero --dpi-desync=fake,hostfakesplit --dpi-desync-fake-tls-mod=rnd,dupsid,sni=www.google.com --dpi-desync-hostfakesplit-mod=host=www.google.com,altorder=1 --dpi-desync-fooling=ts --new ^
--filter-tcp=80,443 --hostlist="%LISTS%list-general.txt" --hostlist="%LISTS%list-general-user.txt" --hostlist-exclude="%LISTS%list-exclude.txt" --hostlist-exclude="%LISTS%list-exclude-user.txt" --ipset-exclude="%LISTS%ipset-exclude.txt" --ipset-exclude="%LISTS%ipset-exclude-user.txt" --dpi-desync=fake,hostfakesplit --dpi-desync-fake-tls-mod=rnd,dupsid,sni=ya.ru --dpi-desync-hostfakesplit-mod=host=ya.ru,altorder=1 --dpi-desync-fooling=ts --dpi-desync-fake-http="%BLOBS%tls_clienthello_gosuslugi_ru.bin" --new ^
--filter-udp=443 --ipset="%LISTS%ipset-all.txt" --hostlist-exclude="%LISTS%list-exclude.txt" --hostlist-exclude="%LISTS%list-exclude-user.txt" --ipset-exclude="%LISTS%ipset-exclude.txt" --ipset-exclude="%LISTS%ipset-exclude-user.txt" --dpi-desync=fake --dpi-desync-repeats=6 --dpi-desync-fake-quic="%BLOBS%quic_initial_www_google_com.bin" --new ^
--filter-tcp=80,443,8443 --ipset="%LISTS%ipset-all.txt" --hostlist-exclude="%LISTS%list-exclude.txt" --hostlist-exclude="%LISTS%list-exclude-user.txt" --ipset-exclude="%LISTS%ipset-exclude.txt" --ipset-exclude="%LISTS%ipset-exclude-user.txt" --dpi-desync=fake,hostfakesplit --dpi-desync-fake-tls-mod=rnd,dupsid,sni=ya.ru --dpi-desync-hostfakesplit-mod=host=ya.ru,altorder=1 --dpi-desync-fooling=ts --dpi-desync-fake-http="%BLOBS%tls_clienthello_gosuslugi_ru.bin"

echo.
echo winws started in minimized window. Check Task Manager for winws.exe process.
echo To stop: run Zapret-Off.cmd or  taskkill /F /IM winws.exe
