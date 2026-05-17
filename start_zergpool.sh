#!/bin/bash
set -euo pipefail

ALGO=${ALGO:-"kheavyhash"}
POOL_ADDRESS=${POOL_ADDRESS:-"stratum+tcp://heavyhash.eu.mine.zergpool.com:5137"}
WALLET_USER=${WALLET_USER:-""}
WORKER_NAME=${WORKER_NAME:-""}
POOL_PASSWORD=${POOL_PASSWORD:-"c=BTC"}
EXTRAS=${EXTRAS:-"--disable-gpu --api-enable --api-port 21550 --extended-log"}
LOG_LEVEL=${LOG_LEVEL:-"info"}

log_debug() { [[ "$LOG_LEVEL" == "debug" ]] && echo "[$(date '+%Y-%m-%d %H:%M:%S')] [DEBUG] $*" | tee /dev/stderr; }
log_info()  { [[ "$LOG_LEVEL" =~ ^(debug|info)$ ]] && echo "[$(date '+%Y-%m-%d %H:%M:%S')] [INFO]  $*" | tee /dev/stderr; }
log_warn()  { [[ "$LOG_LEVEL" =~ ^(debug|info|warn)$ ]] && echo "[$(date '+%Y-%m-%d %H:%M:%S')] [WARN]  $*" | tee /dev/stderr; }
log_error() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] [ERROR] $*" | tee /dev/stderr; }

echo ""
echo "===== SRBMINER ENTRYPOINT DEBUG ====="
echo "WALLET_USER: '${WALLET_USER}' (length=${#WALLET_USER})"
echo "ALGO:         '${ALGO}'"
echo "POOL_ADDRESS: '${POOL_ADDRESS}'"
echo "WORKER_NAME:  '${WORKER_NAME}'"
echo "POOL_PASSWORD:'${POOL_PASSWORD}'"
echo "EXTRAS:       '${EXTRAS}'"
echo "LOG_LEVEL:    '${LOG_LEVEL}'"
echo "DRY_RUN:      '${DRY_RUN:-false}'"
echo "VERSION_TAG:  '${VERSION_TAG:-not set}'"
echo "====================================="
echo ""

if [[ -z "$WALLET_USER" ]]; then
    log_error "WALLET_USER is required but not set - check BTC_ADDRESS in Portainer stack environment"
    log_error "Run: Stacks -> your-stack -> Environment variables -> add BTC_ADDRESS=your_wallet"
    sleep 3
    exit 1
fi

MINER_VERSION=${MINER_VERSION:-"$VERSION_TAG"}
log_info "Using version: ${MINER_VERSION:-unknown}"

log_debug "Resolved ALGO=$ALGO"
log_debug "Resolved POOL_ADDRESS=$POOL_ADDRESS"
log_debug "Resolved POOL_PASSWORD=$POOL_PASSWORD"
log_debug "Resolved EXTRAS=$EXTRAS"
log_debug "Resolved LOG_LEVEL=$LOG_LEVEL"

GPU_ENABLED=true
if [[ "$EXTRAS" == *"--disable-gpu"* ]]; then
    GPU_ENABLED=false
fi

log_info "----------------------------------------"
log_info "  Starting SRBMiner-MULTI v${MINER_VERSION:-unknown}"
log_info "  Algorithm:  $ALGO"
log_info "  Pool:       $POOL_ADDRESS"
log_info "  Wallet:     $WALLET_USER"
log_info "  Password:   $POOL_PASSWORD"
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

if [[ "${DRY_RUN,,}" == "true" ]]; then
    log_info "  DRY RUN — validating only, not mining"
    log_info "----------------------------------------"

    if [[ ! -x ./SRBMiner-MULTI ]]; then
        log_error "SRBMiner-MULTI binary not found or not executable"
        exit 1
    fi

    log_info "Binary:    $(file ./SRBMiner-MULTI | cut -d: -f2-)"
    log_info "Version:   ${MINER_VERSION:-unknown}"
    log_info "Algorithm: $ALGO list:"
    ./SRBMiner-MULTI --list-algorithms 2>/dev/null | grep -i "$ALGO" || log_warn "  Algorithm '$ALGO' not found in supported list"

    log_info "Dry run complete — all checks passed."
    exit 0
fi

if [[ $GPU_ENABLED == true ]]; then
    set +e
    ./SRBMiner-MULTI --algorithm "$ALGO" --pool "$POOL_ADDRESS" --wallet "$WALLET_USER" --password "$POOL_PASSWORD" $WORKER_FLAG $EXTRAS
    EXIT_CODE=$?
    set -e
    if [[ $EXIT_CODE -ne 0 ]]; then
        log_error "GPU miner exited with code $EXIT_CODE — retrying CPU-only"
        log_info "----------------------------------------"
        log_info "  Retrying SRBMiner-MULTI v${MINER_VERSION:-unknown}"
        log_info "  GPU mode:   disabled (failover)"
        log_info "----------------------------------------"
        exec ./SRBMiner-MULTI --algorithm "$ALGO" --pool "$POOL_ADDRESS" --wallet "$WALLET_USER" --password "$POOL_PASSWORD" $WORKER_FLAG $EXTRAS --disable-gpu
    fi
    exit $EXIT_CODE
fi

exec ./SRBMiner-MULTI --algorithm "$ALGO" --pool "$POOL_ADDRESS" --wallet "$WALLET_USER" --password "$POOL_PASSWORD" $WORKER_FLAG $EXTRAS
