@echo off
title SRBMiner - Dual Mining (Autolykos2 GPU + RandomX CPU)
cd /d "%~dp0"

set BMPATH=SRBMiner-Multi-3-2-8
set ALGO_GPU=autolykos2
set ALGO_CPU=randomx
set POOL_GPU=stratum+tcp://autolykos.unmineable.com:3333
set POOL_CPU=stratum+tcp://rx.unmineable.com:3333
set WALLET=BTC:3L6VrRrrvMmNiX3BHBrgvK9R8rmYkvYak7
set WORKER=server1
set PASS=x

echo ========================================
echo   SRBMiner-MULTI Dual Mining
echo   GPU: %ALGO_GPU% - %POOL_GPU%
echo   CPU: %ALGO_CPU% - %POOL_CPU%
echo   Wallet: %WALLET%
echo ========================================

%BMPATH%\SRBMiner-MULTI.exe ^
    --algorithm-gpu %ALGO_GPU% ^
    --algorithm-cpu %ALGO_CPU% ^
    --pool %POOL_GPU% ^
    --pool %POOL_CPU% ^
    --wallet %WALLET%.%WORKER% ^
    --wallet %WALLET% ^
    --password %PASS% ^
    --password %PASS% ^
    --api-enable ^
    --api-port 21550 ^
    --extended-log ^
    --worker %WORKER%

echo.
echo Miner exited. Press any key to restart or close this window.
pause
goto :EOF