# SRBMiner-Multi Docker — Solar Mining Stack

High-performance CPU & AMD GPU miner paired with a Home Assistant solar controller and Kraken auto-sell bot. Mines only when your solar panels produce excess power and your battery is full. Sells the earned BTC automatically on Kraken.

[![Docker Publish](https://github.com/M8477/srbminer-multi-docker/actions/workflows/docker-publish.yml/badge.svg)](https://github.com/M8477/srbminer-multi-docker/actions/workflows/docker-publish.yml)

## Stack Overview

| Service | Image | Role |
|---------|-------|------|
| `srbminer` | `ghcr.io/m8477/srbminer-multi-docker:latest` | CPU/GPU miner (kheavyhash → BTC) |
| `solar-controller` | `ghcr.io/m8477/solar-controller:latest` | Queries Home Assistant; starts/stops miner based on battery % and solar W |
| `kraken-sell-bot` | `ghcr.io/m8477/kraken-sell-bot:latest` | Monitors Kraken BTC balance; auto-sells when above threshold |

[Browse packages](https://github.com/M8477?tab=packages&repo_name=srbminer-multi-docker)

## Quick Start

```bash
cp .env.example .env
# Edit .env with your BTC address, HA details, and Kraken API keys
docker compose up -d
```

## Prerequisites

- **AMD GPU mining:** ROCm kernel driver installed on host. The `video` group in the container must match the host's GID (usually `44` but verify with `getent group video`).
- **Home Assistant** accessible from the Docker host for solar/battery sensors.
- **Kraken API keys** with trading permissions to auto-sell.

## Environment Variables

Copy `.env.example` to `.env` and fill in:

| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| `BTC_ADDRESS` | **Yes** | — | Your BTC wallet for mining payouts |
| `WORKER_NAME` | No | — | Optional miner worker name |
| `HA_URL` | **Yes** | `http://homeassistant.local:8123` | Home Assistant URL |
| `HA_TOKEN` | **Yes** | — | Long-lived access token from HA |
| `BATTERY_ENTITY` | No | `sensor.my_home_percentage_charged` | HA entity for battery % |
| `SOLAR_ENTITY` | No | `sensor.my_home_solar_power` | HA entity for solar power (W) |
| `BATTERY_MIN` | No | `90` | Battery % required before mining starts |
| `SOLAR_MIN` | No | `800` | Solar watts required before mining starts |
| `CHECK_SECS` | No | `120` | How often the controller polls HA |
| `KRAKEN_KEY` | **Yes** | — | Kraken API key |
| `KRAKEN_SECRET` | **Yes** | — | Kraken API secret |
| `MIN_BTC_SELL` | No | `0.0005` | BTC balance threshold to trigger a sell |
| `LOG_LEVEL` | No | `info` | `debug` \| `info` \| `warn` \| `error` \| `quiet` |
| `DRY_RUN` | No | `false` | Set `true` to validate config without mining |
| `EXTRAS` | No | `--disable-gpu --api-enable --api-port 21550` | Miner flags. See [PARAMETERS.md](./PARAMETERS.md) |

### Log Levels

| Level | Output |
|-------|--------|
| `debug` | Timestamps, all resolved vars, version detection, full startup banner |
| `info` | Timestamped startup banner with config summary |
| `warn` | Warnings only |
| `error` | Only on failure |
| `quiet` | No wrapper output — raw miner output only |

Miner output always passes through regardless of `LOG_LEVEL`.

## How It Works

```
Solar panels → Home Assistant sensors
                        ↓
               solar-controller (poll every CHECK_SECS)
                        ↓
          battery ≥ 90% AND solar ≥ 800W ?
             ↓ YES                   ↓ NO
        start srbminer          stop srbminer
             ↓
        mine kheavyhash → zergpool (BTC)
             ↓
    BTC paid to your wallet → Kraken
             ↓
      kraken-sell-bot auto-sells BTC → GBP
```

## Advanced Parameters

See [PARAMETERS.md](./PARAMETERS.md) for the full SRBMiner-MULTI parameter reference. All miner flags can be passed via the `EXTRAS` env var.

## GPU Mining vs CPU Mining

**CPU mining (default):** `EXTRAS` includes `--disable-gpu`. Works everywhere.

**GPU mining:** Remove `--disable-gpu` from `EXTRAS`. Requires:
- ROCm kernel driver on host
- Matching `renderD*` device path (check with `ls /dev/dri/renderD*`)

```diff
- EXTRAS=--disable-gpu --api-enable --api-port 21550
+ EXTRAS=--api-enable --api-port 21550
```

## Version Updates

A [scheduled GitHub Action](.github/workflows/version-check.yml) checks daily for new [SRBMiner-Multi releases](https://github.com/doktor83/SRBMiner-Multi/releases). When a new version is detected, it automatically opens a PR updating `VERSION_TAG` and `EXPECTED_MD5`.

**Manual bump:** Update these two lines in `Dockerfile`, then push:
```diff
-ARG VERSION_TAG=2.9.8
-ARG EXPECTED_MD5=4c3976d4f846d700b44331919bc4d7a7
+ARG VERSION_TAG=2.9.9
+ARG EXPECTED_MD5=<md5 from release notes>
```

## Portainer Deployment

The stack is designed for Portainer with all images pre-built on GHCR — no `build:` directives, no local file mounts needed (except `docker.sock` for the controller).

1. **Add a stack** in Portainer
2. **Paste** the contents of `docker-compose.yml`
3. Add your [environment variables](#environment-variables) under **Environment variables** or create a `.env` file
4. **Deploy the stack**

> The `HSA_ENABLE_SDMA`, `ROCR_VISIBLE_DEVICES`, and `HIP_VISIBLE_DEVICES` vars are only needed for AMD GPU mining. Remove them for CPU-only setups.

## Local Build

Build the miner image locally:

```bash
docker build --build-arg VERSION_TAG=3.2.8 -t srbminer-multi:local .
docker run -e WALLET_USER="your_wallet" srbminer-multi:local
```

Or use the helper script:

```bash
./build.sh
```

## Standalone Miner Usage

Run just the miner without the solar stack:

```bash
docker run \
  -e WALLET_USER="1Fyq3JegvpKDrfcEgyxJdQGfgZZjhDJ18P" \
  ghcr.io/m8477/srbminer-multi-docker:latest
```

## License

MIT — see [LICENSE](./LICENSE)
