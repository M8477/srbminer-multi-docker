#!/bin/bash

# Default fallbacks if not provided
ALGO=${ALGO:-"kheavyhash"}
POOL_ADDRESS=${POOL_ADDRESS:-"stratum+tcp://heavyhash.eu.mine.zergpool.com:5137"}
WALLET_USER=${WALLET_USER:-""}
PASSWORD=${PASSWORD:-"c=BTC"}
EXTRAS=${EXTRAS:-"--disable-gpu --api-enable --api-port 21550"}

echo "Starting SRBMiner-MULTI v2.9.8..."
echo "Algorithm: $ALGO"
echo "Pool: $POOL_ADDRESS"
echo "Wallet: $WALLET_USER"
echo "Password: $PASSWORD"
echo "Extras: $EXTRAS"

./SRBMiner-MULTI --algorithm "$ALGO" --pool "$POOL_ADDRESS" --wallet "$WALLET_USER" --password "$PASSWORD" $EXTRAS
