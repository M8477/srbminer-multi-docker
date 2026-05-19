#!/bin/bash

rm -f /.dockerenv 2>/dev/null || true

ALGO=${ALGO:-"randomx"}
POOL_ADDRESS=${POOL_ADDRESS:-"stratum+tcp://rx.unmineable.com:3333"}
WALLET_USER=${WALLET_USER:-""}
WORKER_NAME=${WORKER_NAME:-""}
POOL_PASSWORD=${POOL_PASSWORD:-"x"}
EXTRAS=${EXTRAS:-"--disable-gpu --api-enable --api-port 21550 --extended-log"}
LOG_LEVEL=${LOG_LEVEL:-"info"}
MINER_VERSION=${VERSION_TAG:-unknown}

ALGO_GPU=""
ALGO_CPU=""
if [[ "$ALGO" == *";"* ]]; then
    ALGO_GPU=$(echo "$ALGO" | cut -d';' -f1)
    ALGO_CPU=$(echo "$ALGO" | cut -d';' -f2)
fi

log_debug() { [[ "$LOG_LEVEL" == "debug" ]] && echo "[$(date '+%Y-%m-%d %H:%M:%S')] [DEBUG] $*"; }
log_info()  { [[ "$LOG_LEVEL" =~ ^(debug|info)$ ]] && echo "[$(date '+%Y-%m-%d %H:%M:%S')] [INFO]  $*"; }
log_warn()  { [[ "$LOG_LEVEL" =~ ^(debug|info|warn)$ ]] && echo "[$(date '+%Y-%m-%d %H:%M:%S')] [WARN]  $*"; }
log_error() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] [ERROR] $*"; }

if [[ "$(id -u)" == "0" ]]; then
    HP_CURRENT=$(cat /proc/sys/vm/nr_hugepages 2>/dev/null || echo "0")
    HP_NEEDED=2560
    if [[ "$HP_CURRENT" -lt "$HP_NEEDED" ]]; then
        log_info "Setting hugepages: $HP_CURRENT -> $HP_NEEDED"
        echo "$HP_NEEDED" > /proc/sys/vm/nr_hugepages 2>/dev/null \
            && log_info "Hugepages set to $HP_NEEDED" \
            || log_warn "Failed to set hugepages (need privileged mode)"
    else
        log_info "Hugepages already configured: $HP_CURRENT"
    fi
else
    log_warn "Not running as root — MSR tweaks and hugepages unavailable"
fi

crash_trap() {
    local code=$?
    log_error ""
    log_error "========================================"
    log_error "  CONTAINER EXITING (exit code: $code)"
    log_error "========================================"
    log_error "Checking process list:"
    ps aux 2>/dev/null || echo "  (ps not available)"
    log_error "Miner binary:"
    ls -la ./SRBMiner-MULTI 2>/dev/null || log_error "  NOT FOUND"
    log_error "Any .log files in working dir:"
    for f in *.log SRBMiner*.log; do
        if [[ -f "$f" ]]; then
            log_error "--- $f (last 20 lines) ---"
            tail -20 "$f" 2>/dev/null || true
        fi
    done
    log_error "Finished diagnostics."
    if [[ "${DRY_RUN:-false}" != "true" ]]; then
        log_error "Holding container alive for inspection..."
        log_error "Connect: docker exec -it srbminer bash"
        while true; do sleep 60; done
    fi
    exit $code
}
trap crash_trap EXIT

log_info "Starting SRBMiner-MULTI v${MINER_VERSION}"
log_debug "WALLET_USER=${WALLET_USER} ALGO=${ALGO} ALGO_GPU=${ALGO_GPU} ALGO_CPU=${ALGO_CPU} WORKER_NAME=${WORKER_NAME} DRY_RUN=${DRY_RUN:-false}"

if [[ -z "$WALLET_USER" ]]; then
    log_error "WALLET_USER is required but not set"
    exit 1
fi

GPU_ENABLED=true
if [[ "$EXTRAS" == *"--disable-gpu"* ]]; then
    GPU_ENABLED=false
fi
if [[ -n "$ALGO_GPU" ]]; then
    GPU_ENABLED=true
fi

if [[ -n "$WORKER_NAME" ]]; then
    WORKER_FLAG="--worker $WORKER_NAME"
else
    WORKER_FLAG=""
fi

if [[ -n "$ALGO_GPU" ]]; then
    DUAL_MINING=true
    log_info "Dual mining: GPU=$ALGO_GPU CPU=$ALGO_CPU"
else
    DUAL_MINING=false
fi

log_info "----------------------------------------"
log_info "  Starting SRBMiner-MULTI v${MINER_VERSION}"
if [[ -n "$ALGO_GPU" ]]; then
    log_info "  GPU algo:   $ALGO_GPU"
    log_info "  CPU algo:   $ALGO_CPU"
else
    log_info "  Algorithm:  $ALGO"
fi
log_info "  Pool:       $POOL_ADDRESS"
log_info "  Wallet:     $(echo "$WALLET_USER" | cut -d',' -f1)"
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
    log_info "Dry run complete — all checks passed."
    exit 0
fi

log_info "Launching miner..."

if [[ ! -x ./SRBMiner-MULTI ]]; then
    log_error "SRBMiner-MULTI binary not found or not executable!"
    log_error "Contents of working directory:"
    ls -la 2>/dev/null || true
    exit 1
fi

log_debug "Binary: $(file ./SRBMiner-MULTI 2>/dev/null | cut -d: -f2-)"
log_info "Checking shared library dependencies..."
ldd ./SRBMiner-MULTI 2>/dev/null | grep -i "not found" && log_error "MISSING LIBRARIES ABOVE" || log_info "All libs OK"

run_miner() {
    local extra_args="$EXTRAS $WORKER_FLAG $*"
    local cmd="./SRBMiner-MULTI"
    if [[ -n "$ALGO_GPU" ]]; then
        cmd="$cmd --algorithm-gpu $ALGO_GPU --algorithm-cpu $ALGO_CPU"
        cmd="$cmd --pool $POOL_ADDRESS --pool $POOL_ADDRESS"
        cmd="$cmd --wallet $WALLET_USER --wallet $WALLET_USER"
        cmd="$cmd --password $POOL_PASSWORD --password $POOL_PASSWORD"
    else
        cmd="$cmd --algorithm $ALGO"
        cmd="$cmd --pool $POOL_ADDRESS --wallet $WALLET_USER --password $POOL_PASSWORD"
    fi
    cmd="$cmd $extra_args --log-file /tmp/srbminer.log --log-file-mode 1"
    log_info "Command: $cmd"
    $cmd 2>&1
    local exit_code=$?
    local end_time=$(date +%s)
    local elapsed=$((end_time - MINER_START_TIME))
    if [[ $exit_code -ne 0 ]]; then
        log_error "Miner process exited with code $exit_code after ${elapsed}s"
    else
        log_info "Miner process exited with code $exit_code after ${elapsed}s"
        if [[ $elapsed -lt 10 ]]; then
            log_error "Miner exited too quickly (${elapsed}s) — possible environment detection issue"
        fi
    fi
    if [[ -f /tmp/srbminer.log ]]; then
        log_info "=== Last 30 lines of miner log ==="
        tail -30 /tmp/srbminer.log 2>/dev/null || true
        log_info "=== End miner log ==="
    else
        log_warn "No miner log file found at /tmp/srbminer.log"
    fi
    return $exit_code
}

if [[ $GPU_ENABLED == true ]]; then
    MINER_START_TIME=$(date +%s)
    run_miner
    GPU_EXIT=$?
    if [[ $GPU_EXIT -ne 0 ]]; then
        log_error "GPU miner exited with code $GPU_EXIT — retrying CPU-only"
        log_info "----------------------------------------"
        log_info "  Retrying SRBMiner-MULTI v${MINER_VERSION}"
        log_info "  GPU mode:   disabled (failover)"
        log_info "----------------------------------------"
        MINER_START_TIME=$(date +%s)
        ALGO_GPU=""
        ALGO_CPU=""
        ALGO="randomx"
        DUAL_MINING=false
        run_miner --disable-gpu
        GPU_EXIT=$?
    fi
    exit $GPU_EXIT
else
    MINER_START_TIME=$(date +%s)
    run_miner
    exit $?
fi