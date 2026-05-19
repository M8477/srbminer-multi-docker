@echo off
title SRBMiner - CPU Only (RandomX)
cd /d "%~dp0"

set BMPATH=SRBMiner-Multi-3-2-8
set POOL=stratum+tcp://rx.unmineable.com:3333
set WALLET=BTC:3L6VrRrrvMmNiX3BHBrgvK9R8rmYkvYak7
set WORKER=server1
set PASS=x

echo ========================================
echo   SRBMiner-MULTI CPU Only
echo   Algorithm: randomx
echo   Pool: %POOL%
echo   Wallet: %WALLET%
echo ========================================

%BMPATH%\SRBMiner-MULTI.exe ^
    --algorithm randomx ^
    --pool %POOL% ^
    --wallet %WALLET%.%WORKER% ^
    --password %PASS% ^
    --disable-gpu ^
    --api-enable ^
    --api-port 21550 ^
    --extended-log ^
    --worker %WORKER%

echo.
echo Miner exited. Press any key to restart or close this window.
pause
goto :EOF