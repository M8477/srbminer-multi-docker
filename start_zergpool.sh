#!/bin/bash
set -euo pipefail

ALGO=${ALGO:-"kheavyhash"}
POOL_ADDRESS=${POOL_ADDRESS:-"stratum+tcp://heavyhash.eu.mine.zergpool.com:5137"}
WALLET_USER=${WALLET_USER:-""}
WORKER_NAME=${WORKER_NAME:-""}
PASSWORD=${PASSWORD:-"c=BTC"}
EXTRAS=${EXTRAS:-"--disable-gpu --api-enable --api-port 21550"}
LOG_LEVEL=${LOG_LEVEL:-"info"}

log_debug() { [[ "$LOG_LEVEL" == "debug" ]] && echo "[$(date '+%Y-%m-%d %H:%M:%S')] [DEBUG] $*"; }
log_info()  { [[ "$LOG_LEVEL" =~ ^(debug|info)$ ]] && echo "[$(date '+%Y-%m-%d %H:%M:%S')] [INFO]  $*"; }
log_warn()  { [[ "$LOG_LEVEL" =~ ^(debug|info|warn)$ ]] && echo "[$(date '+%Y-%m-%d %H:%M:%S')] [WARN]  $*" >&2; }
log_error() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] [ERROR] $*" >&2; }

if [[ -z "$WALLET_USER" ]]; then
    log_error "WALLET_USER is required but not set"
    exit 1
fi

MINER_VERSION=$(./SRBMiner-MULTI --version 2>/dev/null | grep -oP 'SRBMiner-MULTI \K[0-9\.]+' || true)
log_debug "Detected binary version: ${MINER_VERSION:-unknown}"

log_debug "Resolved ALGO=$ALGO"
log_debug "Resolved POOL_ADDRESS=$POOL_ADDRESS"
log_debug "Resolved PASSWORD=$PASSWORD"
log_debug "Resolved EXTRAS=$EXTRAS"
log_debug "Resolved LOG_LEVEL=$LOG_LEVEL"

GPU_ENABLED=true
if [[ "$EXTRAS" == *"--disable-gpu"* ]]; then
    GPU_ENABLED=false
fi

log_info "----------------------------------------"
log_info "  Starting SRBMiner-MULTI v${MINER_VERSION:-Unknown}"
log_info "  Algorithm:  $ALGO"
log_info "  Pool:       $POOL_ADDRESS"
log_info "  Wallet:     $WALLET_USER"
log_info "  Password:   $PASSWORD"
log_info "  Extras:     $EXTRAS"
log_info "  GPU mode:   $($GPU_ENABLED && echo "enabled" || echo "disabled")"
log_info "  Log level:  $LOG_LEVEL"
log_info "  Worker:     ${WORKER_NAME:-(auto)}"
if [[ -n "$WORKER_NAME" ]]; then
    WORKER_FLAG="--worker $WORKER_NAME"
else
    WORKER_FLAG=""
fi
log_info "----------------------------------------"

./SRBMiner-MULTI --algorithm "$ALGO" --pool "$POOL_ADDRESS" --wallet "$WALLET_USER" --password "$PASSWORD" $WORKER_FLAG $EXTRAS
EXIT_CODE=$?

if [[ $EXIT_CODE -ne 0 ]] && $GPU_ENABLED; then
    log_error "GPU miner exited with code $EXIT_CODE — retrying CPU-only"
    log_info "----------------------------------------"
    log_info "  Retrying SRBMiner-MULTI v${MINER_VERSION:-Unknown}"
    log_info "  GPU mode:   disabled (failover)"
    log_info "----------------------------------------"
    exec ./SRBMiner-MULTI --algorithm "$ALGO" --pool "$POOL_ADDRESS" --wallet "$WALLET_USER" --password "$PASSWORD" $WORKER_FLAG $EXTRAS --disable-gpu
fi

exit $EXIT_CODE
