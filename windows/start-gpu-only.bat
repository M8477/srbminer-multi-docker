@echo off
title SRBMiner - GPU Only (Autolykos2)
cd /d "%~dp0"

set BMPATH=SRBMiner-Multi-3-2-8
set POOL=stratum+tcp://autolykos.unmineable.com:3333
set WALLET=BTC:1Fyq3JegvpKDrfcEgyxJdQGfgZZjhDJ18P
set WORKER=server2
set PASS=x

echo ========================================
echo   SRBMiner-MULTI GPU Only
echo   Algorithm: autolykos2
echo   Pool: %POOL%
echo   Wallet: %WALLET%
echo ========================================

%BMPATH%\SRBMiner-MULTI.exe ^
    --algorithm autolykos2 ^
    --pool %POOL% ^
    --wallet %WALLET%.%WORKER% ^
    --password %PASS% ^
    --disable-cpu ^
    --api-enable ^
    --api-port 21550 ^
    --extended-log ^
    --worker %WORKER%

echo.
echo Miner exited. Press any key to restart or close this window.
pause
goto :EOF