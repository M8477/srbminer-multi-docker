#!/bin/bash

# Default fallbacks if not provided
ALGO=${ALGO:-"kheavyhash"}
POOL_ADDRESS=${POOL_ADDRESS:-"stratum+tcp://heavyhash.eu.mine.zergpool.com:5137"}
WALLET_USER=${WALLET_USER:-""}
PASSWORD=${PASSWORD:-"c=BTC"}
EXTRAS=${EXTRAS:-"--disable-gpu --api-enable --api-port 21550"}

# Dynamically get the exact version of the miner binary
MINER_VERSION=$(./SRBMiner-MULTI --version | grep -oP 'SRBMiner-MULTI \K[0-9\.]+')

echo "----------------------------------------"
echo "Starting SRBMiner-MULTI v${MINER_VERSION:-Unknown}"
echo "Algorithm: $ALGO"
echo "Pool:      $POOL_ADDRESS"
echo "Wallet:    $WALLET_USER"
echo "Password:  $PASSWORD"
echo "Extras:    $EXTRAS"
echo "----------------------------------------"

./SRBMiner-MULTI --algorithm "$ALGO" --pool "$POOL_ADDRESS" --wallet "$WALLET_USER" --password "$PASSWORD" $EXTRAS
