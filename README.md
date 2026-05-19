# SRBMiner-Multi Docker — Solar Mining Stack

High-performance CPU & AMD GPU miner paired with a Home Assistant solar controller and Kraken auto-sell bot. Mines only when your solar panels produce excess power and your battery is full. Sells the earned BTC automatically on Kraken.

## Stack Overview

| Service | Image | Role |
|---------|-------|------|
| `srbminer` | `ghcr.io/m8477/srbminer-multi-docker:latest` | Dual GPU+CPU miner (autolykos2 GPU + randomx CPU) via Unmineable → BTC |
| `solar-controller` | `ghcr.io/m8477/solar-controller:latest` | Queries Home Assistant; starts/stops miner based on battery % and solar W |
| `kraken-sell-bot` | `ghcr.io/m8477/kraken-sell-bot:latest` | Monitors Kraken BTC balance; auto-sells when above threshold (optional) |

[Browse packages](https://github.com/M8477?tab=packages&repo_name=srbminer-multi-docker)

## Quick Start

```bash
cp .env.example .env
# Edit .env with your BTC address, HA details, and Kraken API keys
docker compose up -d
```

## Prerequisites

- **Huge pages** (recommended for RandomX performance): `sudo sysctl -w vm.nr_hugepages=1280` and persist with `echo "vm.nr_hugepages=1280" | sudo tee /etc/sysctl.d/99-hugepages.conf`
- **AMD GPU mining** (optional): ROCm kernel driver installed on host. Verify with `ls /dev/dri/renderD*`
- **Home Assistant** accessible from the Docker host for solar/battery sensors
- **Kraken API keys** (optional — if not set, kraken-sell-bot exits gracefully)

## Architecture

```
Solar panels → Home Assistant sensors
                        ↓
               solar-controller (polls every CHECK_SECS)
                        ↓
          battery ≥ BATTERY_MIN% OR solar ≥ SOLAR_MINW ?
             ↓ YES                    ↓ NO
        start srbminer          stop srbminer
             ↓
    GPU: autolykos2 + CPU: randomx → Unmineable (BTC payout)
             ↓
    BTC paid to your wallet → Kraken
             ↓
      kraken-sell-bot auto-sells BTC → GBP
```

### Mining Modes

| Mode | `ALGO` | `EXTRAS` | Description |
|------|--------|----------|-------------|
| CPU only | `randomx` | `--disable-gpu --api-enable --api-port 21550 --extended-log` | RandomX on all CPU threads |
| GPU only | `autolykos2` | `--disable-cpu --api-enable --api-port 21550 --extended-log` | Autolykos2 (Ergo) on AMD GPU |
| GPU + CPU (default) | `autolykos2;randomx` | `--api-enable --api-port 21550 --extended-log` | Dual mining: autolykos2 GPU + randomx CPU |

The `ALGO` variable uses semicolons for dual mining. `autolykos2;randomx` means GPU mines autolykos2 (Ergo) and CPU mines randomx simultaneously.

**Important for dual mining:** Each algorithm needs its own pool. Set `POOL_ADDRESS` for the GPU algorithm and `POOL_ADDRESS_CPU` for the CPU algorithm:
- GPU (autolykos2): `stratum+tcp://autolykos.unmineable.com:3333` (ERG → BTC)
- CPU (randomx): `stratum+tcp://rx.unmineable.com:3333` (BTC direct)

### Failover

When GPU mining is enabled and the GPU fails, the start script automatically retries in CPU-only mode (randomx with `--disable-gpu`).

## Environment Variables

Copy `.env.example` to `.env` and fill in:

### Miner

| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| `BTC_ADDRESS` | **Yes** | — | Your BTC wallet address for mining payouts |
| `ALGO` | No | `autolykos2;randomx` | Algorithm(s). Use `;` for dual mining (GPU;CPU) |
| `POOL_ADDRESS` | No | `stratum+tcp://autolykos.unmineable.com:3333` | GPU mining pool (used as primary pool) |
| `POOL_ADDRESS_CPU` | No | `stratum+tcp://rx.unmineable.com:3333` | CPU mining pool (dual mining only; falls back to POOL_ADDRESS) |
| `WALLET_USER` | No | `BTC:${BTC_ADDRESS}` | Pool wallet (auto-generated from BTC_ADDRESS) |
| `WORKER_NAME` | No | — | Miner worker name |
| `POOL_PASSWORD` | No | `x` | Pool password |
| `EXTRAS` | No | `--api-enable --api-port 21550 --extended-log` | Extra SRBMiner flags. See [PARAMETERS.md](./PARAMETERS.md) |
| `LOG_LEVEL` | No | `info` | `debug` \| `info` \| `warn` \| `error` |
| `DRY_RUN` | No | `false` | Set `true` to validate config without mining |
| `VERSION_TAG` | No | `3.2.8` | SRBMiner version (must match Dockerfile) |

### Solar Controller

| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| `HA_URL` | **Yes** | — | Home Assistant URL (e.g. `http://192.168.0.115:8123`) |
| `HA_TOKEN` | **Yes** | — | Long-lived access token from HA |
| `BATTERY_ENTITY` | No | `sensor.battery_state_of_charge` | HA entity for battery % |
| `SOLAR_ENTITY` | No | `sensor.solar_power` | HA entity for solar power (W) |
| `BATTERY_MIN` | No | `90` | Battery % threshold to start mining |
| `SOLAR_MIN` | No | `800` | Solar W threshold to start mining (set to `0` to ignore solar) |
| `CHECK_SECS` | No | `120` | How often to poll HA (seconds) |
| `FORCE_MINE` | No | — | Set `Y` to force mining for `FORCE_MINE_MINS` minutes |
| `FORCE_MINE_MINS` | No | `30` | Duration of forced mining (minutes) |
| `HEARTBEAT_SECS` | No | `60` | How often to log miner status |
| `API_PORT` | No | `21550` | Miner API port |

### Kraken Sell Bot

| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| `KRAKEN_KEY` | No | — | Kraken API key. If not set, bot exits gracefully (disabled) |
| `KRAKEN_SECRET` | No | — | Kraken API secret. If not set, bot exits gracefully (disabled) |
| `MIN_BTC_SELL` | No | `0.0005` | BTC balance threshold to trigger a sell |

> **Note:** Only one kraken-sell-bot is needed for the entire stack. On additional machines, leave `KRAKEN_KEY`/`KRAKEN_SECRET` empty and the container will exit cleanly with "kraken-sell-bot disabled".

## GPU Mining Setup

GPU mining requires AMD ROCm drivers on the host and device mappings in docker-compose. The container includes OpenCL ICD registration and required libraries (`libdrm2`, `libdrm-amdgpu1`, `libnuma1`, `ocl-icd-opencl-dev`) for AMD GPU detection.

```yaml
devices:
  - /dev/kfd:/dev/kfd
  - /dev/dri              # Pass all DRI devices (includes renderD128, renderD129, etc.)
```

Find your renderD devices: `ls /dev/dri/renderD*`

The container runs privileged for MSR tweaks and huge pages (significant RandomX performance boost). If you prefer lower privileges, set huge pages on the host instead.

### RDNA4 / gfx1201 GPUs (Radeon AI PRO R9700, RX 9070 series)

SRBMiner 3.2.8+ supports RDNA4 GPUs. If GPU detection fails, ensure:
1. `/dev/dri` and `/dev/kfd` are passed through to the container
2. ROCm is mounted at `/opt/rocm` (via volume)
3. The OpenCL ICD is registered (container does this automatically at build time)
4. `HSA_OVERRIDE_GFX_VERSION` can be set if needed (e.g. `11.0.0` for gfx1201)

## Portainer Deployment

1. **Add a stack** in Portainer
2. **Paste** the contents of `docker-compose.yml`
3. Add your [environment variables](#environment-variables) under **Environment variables**
4. **Deploy the stack**

The `ALGO` env var supports semicolons for dual mining: `ALGO=autolykos2;randomx`

For CPU-only machines, set:
```
ALGO=randomx
POOL_ADDRESS=stratum+tcp://rx.unmineable.com:3333
EXTRAS=--disable-gpu --api-enable --api-port 21550 --extended-log
```

Remove GPU device mappings (`/dev/kfd`, `/dev/dri/renderD129`) for CPU-only setups.

## API Dashboard

Access miner stats at `http://<host>:21550/stats` (GUI) or `http://<host>:21550` (JSON).

## Health Monitoring

- **Docker HEALTHCHECK**: `pgrep -x SRBMiner-MULTI` — marks container unhealthy if miner process dies
- **solar-controller**: Detects unhealthy containers and restarts them automatically
- **Crash trap**: On non-zero exit, container stays alive for inspection (`docker exec -it srbminer bash`)

## Version Updates

A [scheduled GitHub Action](.github/workflows/version-check.yml) checks daily for new [SRBMiner-Multi releases](https://github.com/doktor83/SRBMiner-Multi/releases). When detected, it opens a PR updating `VERSION_TAG` and `EXPECTED_MD5`.

**Manual bump:** Update in `Dockerfile`, then push:
```diff
-ARG VERSION_TAG=3.2.8
-ARG EXPECTED_MD5=cc11aac80688bd6b42e382ab02127a0e
+ARG VERSION_TAG=3.2.9
+ARG EXPECTED_MD5=<md5 from release notes>
```

## Local Build

```bash
docker build --build-arg VERSION_TAG=3.2.8 -t srbminer-multi:local .
docker run -e WALLET_USER="BTC:your_wallet" srbminer-multi:local
```

## Standalone Miner Usage

Run just the miner without the solar stack:

```bash
# CPU only
docker run \
  -e ALGO=randomx \
  -e POOL_ADDRESS=stratum+tcp://rx.unmineable.com:3333 \
  -e WALLET_USER="BTC:your_wallet" \
  -e EXTRAS="--disable-gpu --api-enable --api-port 21550 --extended-log" \
  ghcr.io/m8477/srbminer-multi-docker:latest
```

## Troubleshooting

| Problem | Solution |
|---------|----------|
| "Unknown algorithm" | Algorithm name is wrong. Use `randomx` for CPU, `autolykos2` for GPU. `kheavyhash`/`heavyhash` need Kaspa pool (not Unmineable). |
| Container exits code 0 instantly | Miner detects invalid algorithm or missing mining devices. Check `EXTRAS` and `ALGO`. |
| "Huge-pages 2MB: disabled" | Set huge pages on host: `sudo sysctl -w vm.nr_hugepages=1280` |
| "Run miner as administrator/root" | Container needs `privileged: true` for MSR tweaks |
| DNS error connecting to pool | Verify pool URL. Zergpool is defunct — use Unmineable or another pool |
| Miner container stays "exited" | Crash trap holds container alive. `docker logs srbminer` and `docker exec -it srbminer bash` |
| "No GPU devices" or "0 OpenCL platforms" | Missing ROCm libs or OpenCL ICD inside container. Ensure `/opt/rocm` volume mount and check `docker exec srbminer clinfo` |
| SOLAR_MIN showing 0W in logs | Environment variable was set to empty string. Remove it or set explicit value |
| GPU not detected (gfx1201/RDNA4) | Add `HSA_OVERRIDE_GFX_VERSION=11.0.0` env var. Ensure `/dev/dri` and `/dev/kfd` device passthrough |

## License

MIT — see [LICENSE](./LICENSE)