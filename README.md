# SRBMiner-Multi Docker

High-performance CPU & AMD GPU miner in a clean Docker image. Downloads the latest SRBMiner-Multi binary directly from [doktor83/SRBMiner-Multi](https://github.com/doktor83/SRBMiner-Multi) at build time — no stale third-party images.

[![Docker Publish](https://github.com/M8477/srbminer-multi-docker/actions/workflows/docker-publish.yml/badge.svg)](https://github.com/M8477/srbminer-multi-docker/actions/workflows/docker-publish.yml)

## Image

```
ghcr.io/m8477/srbminer-multi-docker:latest
```

[Browse packages](https://github.com/M8477/srbminer-multi-docker/pkgs/container/srbminer-multi-docker)

## Quick Start

```bash
docker run \
  -e WALLET_USER="1Fyq3JegvpKDrfcEgyxJdQGfgZZjhDJ18P" \
  ghcr.io/m8477/srbminer-multi-docker:latest
```

## Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `WALLET_USER` | *(required)* | Your wallet address |
| `ALGO` | `kheavyhash` | Mining algorithm |
| `POOL_ADDRESS` | `stratum+tcp://heavyhash.eu.mine.zergpool.com:5137` | Pool URL |
| `PASSWORD` | `c=BTC` | Pool password / payout currency |
| `EXTRAS` | `--disable-gpu --api-enable --api-port 21550` | Extra flags passed to the miner |
| `LOG_LEVEL` | `info` | `debug` \| `info` \| `warn` \| `error` \| `quiet` |

### Log Levels

| Level | Output |
|-------|--------|
| `debug` | Timestamps, all resolved vars, version detection, full startup banner |
| `info` | Timestamped startup banner with config summary |
| `warn` | Warnings only (e.g. unknown version) if applicable |
| `error` | Only on failure (e.g. missing wallet) |
| `quiet` | No wrapper output — raw miner output only |

Miner output always passes through regardless of `LOG_LEVEL`.

## docker-compose

```yaml
version: "3.8"
services:
  srbminer:
    image: ghcr.io/m8477/srbminer-multi-docker:latest
    environment:
      - WALLET_USER=1Fyq3JegvpKDrfcEgyxJdQGfgZZjhDJ18P
      - ALGO=kheavyhash
      - POOL_ADDRESS=stratum+tcp://heavyhash.eu.mine.zergpool.com:5137
      - PASSWORD=c=BTC
      - LOG_LEVEL=info
    ports:
      - "21550:21550"
    restart: unless-stopped
```

## Local Build

```bash
docker build --build-arg VERSION_TAG=2.9.8 -t srbminer-multi:local .
docker run -e WALLET_USER="your_wallet" srbminer-multi:local
```

Or use the helper script:

```bash
./build.sh
```

## License

MIT — see [LICENSE](./LICENSE)
