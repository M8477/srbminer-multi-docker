@echo off
cd %~dp0
cls

SRBMiner-MULTI.exe --algorithm-gpu sha256mem --pool fair.suprnova.cc:3833,fair.luckypool.io:4138 --wallet fairchain-wallet
pause
