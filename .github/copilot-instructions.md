# SRBMiner-Multi Docker — Solar Mining Stack

This project packages SRBMiner-MULTI as a Docker container for CPU and AMD GPU mining with solar-aware automation.

Always reference these instructions first and fallback to search or bash commands only when you encounter unexpected information that does not match the info here.

## Key Facts

- **Algorithm**: Default is dual mining `heavyhash;randomx` (GPU+CPU). Use semicolons for dual mining.
- **Pool**: Unmineable (`rx.unmineable.com:3333`). Zergpool is defunct.
- **Wallet format**: `BTC:<your_btc_address>` for Unmineable
- **Pool password**: `x` for Unmineable
- **Container runs as root** (privileged mode) for huge pages and MSR tweaks
- **Crash trap**: Container stays alive on failure for `docker exec` inspection
- **SRBMiner `--version` and `--list-algorithms` trigger interactive guided setup — NEVER call them**
- **SRBMiner `kheavyhash` is NOT a valid algorithm name** — use `heavyhash` for GPU or `randomx` for CPU
- **Dual mining requires 2 pool addresses** (comma-separated) — the start script auto-duplicates the pool if only 1 is provided
- **Kraken sell bot exits gracefully if KRAKEN_KEY/KRAKEN_SECRET not set**
- **GPU detection requires OpenCL**: Container installs `libdrm2`, `libdrm-amdgpu1`, `libnuma1`, `ocl-icd-opencl-dev` and registers `/etc/OpenCL/vendors/amdocl64.icd` pointing to `/opt/rocm/lib/libamdocl64.so`
- **RDNA4/gfx1201 GPUs** (R9700, RX 9070): Supported by SRBMiner 2.8.0+ but need `/dev/dri` + `/dev/kfd` passthrough and ROCm volume mount. If GPU not detected, set `HSA_OVERRIDE_GFX_VERSION=11.0.0`

## Architecture

Three services in docker-compose:

1. **srbminer** — Miner container. `restart: "no"` because solar-controller manages starts/stops.
   - Dual mining: `--algorithm-gpu heavyhash --algorithm-cpu randomx` when ALGO contains semicolon
   - CPU failover: if GPU mining fails, retries with `--disable-gpu --algorithm randomx`
   - privileged: true for huge pages + MSR tweaks
   - HEALTHCHECK monitors SRBMiner-MULTI process

2. **solar-controller** — Polls Home Assistant, starts/stops miner container via Docker socket.
   - Logic: mine when battery >= BATTERY_MIN% OR solar >= SOLAR_MINW
   - FORCE_MINE=Y overrides for 30 minutes
   - Detects unhealthy containers and restarts them

3. **kraken-sell-bot** — Sells BTC on Kraken. Exits with code 0 if KRAKEN_KEY/KRAKEN_SECRET not set.

## Important Implementation Details

- `start_zergpool.sh`: Entry point that sets huge pages, detects dual mining, constructs proper SRBMiner command line
- `ALGO=heavyhash;randomx` is split into `ALGO_GPU=heavyhash` and `ALGO_CPU=randomx` by the start script
- For dual mining, POOL_ADDRESS, WALLET_USER, and POOL_PASSWORD are duplicated with commas (SRBMiner requires N pools for N algorithms)
- `rm -f /.dockerenv` at startup to counter SRBMiner container detection
- `tty: true` and `stdin_open: true` in compose for SRBMiner TTY check
- `init: true` in compose uses tini as PID 1 instead of bash
- Empty env vars (e.g. `SOLAR_MIN=`) use Python `or` pattern in controller to fall back to defaults
- The image is published to GHCR only: `ghcr.io/m8477/srbminer-multi-docker:latest`

## Build

```bash
docker build --build-arg VERSION_TAG=3.2.8 -t srbminer-multi:local .
```

VERSION_TAG and EXPECTED_MD5 must match the SRBMiner-Multi release.

## Environment Variables

Key vars (see README.md for full list):
- ALGO: `randomx` (CPU), `heavyhash` (GPU), or `heavyhash;randomx` (dual)
- POOL_ADDRESS: Mining pool URL
- WALLET_USER: Wallet address (format: `BTC:<address>` for Unmineable)
- EXTRAS: Additional SRBMiner flags