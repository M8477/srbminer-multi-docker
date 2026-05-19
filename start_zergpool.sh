#!/bin/bash

ALGO=${ALGO:-"kheavyhash"}
POOL_ADDRESS=${POOL_ADDRESS:-"stratum+tcp://heavyhash.eu.mine.zergpool.com:5137"}
WALLET_USER=${WALLET_USER:-""}
WORKER_NAME=${WORKER_NAME:-""}
POOL_PASSWORD=${POOL_PASSWORD:-"c=BTC"}
EXTRAS=${EXTRAS:-"--disable-gpu --api-enable --api-port 21550 --extended-log"}
LOG_LEVEL=${LOG_LEVEL:-"info"}
MINER_VERSION=${VERSION_TAG:-unknown}

log_debug() { [[ "$LOG_LEVEL" == "debug" ]] && echo "[$(date '+%Y-%m-%d %H:%M:%S')] [DEBUG] $*"; }
log_info()  { [[ "$LOG_LEVEL" =~ ^(debug|info)$ ]] && echo "[$(date '+%Y-%m-%d %H:%M:%S')] [INFO]  $*"; }
log_warn()  { [[ "$LOG_LEVEL" =~ ^(debug|info|warn)$ ]] && echo "[$(date '+%Y-%m-%d %H:%M:%S')] [WARN]  $*"; }
log_error() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] [ERROR] $*"; }

crash_trap() {
    local code=$?
    if [[ $code -ne 0 ]] && [[ "${DRY_RUN:-false}" != "true" ]]; then
        log_error ""
        log_error "========================================"
        log_error "  MINER CRASHED (exit code: $code)"
        log_error "  Container staying alive for inspection."
        log_error "  Connect: docker exec -it srbminer bash"
        log_error "========================================"
        log_error ""
        while true; do sleep 60; done
    fi
    exit $code
}
trap crash_trap EXIT

log_info "Starting SRBMiner-MULTI v${MINER_VERSION}"
log_debug "WALLET_USER=${WALLET_USER} ALGO=${ALGO} WORKER_NAME=${WORKER_NAME} DRY_RUN=${DRY_RUN:-false}"

if [[ -z "$WALLET_USER" ]]; then
    log_error "WALLET_USER is required but not set"
    exit 1
fi

GPU_ENABLED=true
if [[ "$EXTRAS" == *"--disable-gpu"* ]]; then
    GPU_ENABLED=false
fi

if [[ -n "$WORKER_NAME" ]]; then
    WORKER_FLAG="--worker $WORKER_NAME"
else
    WORKER_FLAG=""
fi

log_info "----------------------------------------"
log_info "  Starting SRBMiner-MULTI v${MINER_VERSION}"
log_info "  Algorithm:  $ALGO"
log_info "  Pool:       $POOL_ADDRESS"
log_info "  Wallet:     $WALLET_USER"
log_info "  Password:   $POOL_PASSWORD"
log_info "  Extras:     $EXTRAS"
log_info "  GPU mode:   $($GPU_ENABLED && echo "enabled" || echo "disabled")"
log_info "  Log level:  $LOG_LEVEL"
log_info "  Worker:     ${WORKER_NAME:-(auto)}"
log_info "----------------------------------------"

if [[ "${DRY_RUN,,}" == "true" ]]; then
    log_info "  DRY RUN — validating only, not mining"
    log_info "----------------------------------------"

    if [[ ! -x ./SRBMiner-MULTI ]]; then
        log_error "SRBMiner-MULTI binary not found or not executable"
        exit 1
    fi

    log_info "Binary:    $(file ./SRBMiner-MULTI 2>/dev/null | cut -d: -f2-)"
    log_info "Version:   ${MINER_VERSION}"
    log_info "Algorithm: $ALGO list:"
    ./SRBMiner-MULTI --list-algorithms 2>/dev/null | grep -i "$ALGO" || log_warn "  Algorithm '$ALGO' not found in supported list"

    log_info "Dry run complete — all checks passed."
    exit 0
fi

log_info "Launching miner..."

if [[ $GPU_ENABLED == true ]]; then
    ./SRBMiner-MULTI --algorithm "$ALGO" --pool "$POOL_ADDRESS" --wallet "$WALLET_USER" --password "$POOL_PASSWORD" $WORKER_FLAG $EXTRAS
    GPU_EXIT=$?
    if [[ $GPU_EXIT -ne 0 ]]; then
        log_error "GPU miner exited with code $GPU_EXIT — retrying CPU-only"
        log_info "----------------------------------------"
        log_info "  Retrying SRBMiner-MULTI v${MINER_VERSION}"
        log_info "  GPU mode:   disabled (failover)"
        log_info "----------------------------------------"
        ./SRBMiner-MULTI --algorithm "$ALGO" --pool "$POOL_ADDRESS" --wallet "$WALLET_USER" --password "$POOL_PASSWORD" $WORKER_FLAG $EXTRAS --disable-gpu
        GPU_EXIT=$?
    fi
    exit $GPU_EXIT
fi

./SRBMiner-MULTI --algorithm "$ALGO" --pool "$POOL_ADDRESS" --wallet "$WALLET_USER" --password "$POOL_PASSWORD" $WORKER_FLAG $EXTRAS
