# SRBMiner-MULTI Parameters Reference

Full official reference: [doktor83/SRBMiner-Multi/Parameters](https://github.com/doktor83/SRBMiner-Multi/blob/master/Parameters)

Any parameter below can be added to the `EXTRAS` environment variable in your `.env` file or `docker-compose.yml`.

## Commonly Used Parameters

### Pool & Wallet

| Parameter | Example | Description |
|-----------|---------|-------------|
| `--algorithm` / `-a` | `--algorithm kheavyhash` | Mining algorithm |
| `--pool` / `-o` | `--pool stratum+tcp://pool:port` | Pool address |
| `--wallet` / `-u` | `--wallet 1Fyq...` | Wallet address |
| `--password` / `-p` | `--password c=BTC` | Pool password |
| `--worker` | `--worker my-rig` | Worker name / rig ID |
| `--tls` | `--tls true` | Enable TLS for pool connection |
| `--diff-factor` | `--diff-factor 16384` | Custom difficulty multiplier |

### API

| Parameter | Example | Description |
|-----------|---------|-------------|
| `--api-enable` | — | Enable statistics API |
| `--api-port` | `--api-port 21550` | API port (default: 21550) |
| `--api-rig-name` | `--api-rig-name garage-rig` | Rig identifier in API |
| `--api-rig-restart-url` | `--api-rig-restart-url abc123` | URL to restart computer |
| `--api-miner-restart-url` | `--api-miner-restart-url def456` | URL to restart miner |

### CPU Mining

| Parameter | Example | Description |
|-----------|---------|-------------|
| `--disable-cpu` | — | Disable CPU mining entirely |
| `--cpu-threads` / `-t` | `--cpu-threads 8` | Number of CPU threads to use |
| `--cpu-threads-intensity` | `--cpu-threads-intensity 4` | Hashes per thread (1, 2, or 4) |
| `--cpu-threads-priority` | `--cpu-threads-priority 3` | Thread priority (1-5) |
| `--disable-auto-affinity` | — | Disable auto CPU affinity |
| `--disable-huge-pages` | — | Disable huge pages |

### GPU Mining

| Parameter | Example | Description |
|-----------|---------|-------------|
| `--disable-gpu` | — | Disable all GPU mining |
| `--gpu-id` | `--gpu-id 0,1` | Select GPU devices |
| `--gpu-intensity` | `--gpu-intensity 30,30` | GPU intensity per device |
| `--gpu-off-temperature` | `--gpu-off-temperature 80` | GPU shutdown temperature |
| `--shutdown-temperature` | `--shutdown-temperature 85` | System shutdown temperature |

### Logging & Debugging

| Parameter | Example | Description |
|-----------|---------|-------------|
| `--extended-log` | — | More verbose miner logging |
| `--log-file` | `--log-file miner.log` | Log to file |
| `--log-file-mode` | `--log-file-mode 2` | 0=truncate, 1=append, 2=timestamped |
| `--background` | — | Run in background (no console) |

### Behavior

| Parameter | Example | Description |
|-----------|---------|-------------|
| `--disable-worker-watchdog` | — | Disable crash detection |
| `--enable-restart-on-rejected` | — | Auto restart on rejected shares |
| `--max-rejected-shares` | `--max-rejected-shares 10` | Max rejected before restart |
| `--give-up-limit` | `--give-up-limit 5` | Pool connection retries |
| `--retry-time` | `--retry-time 30` | Seconds before reconnect attempt |
| `--max-no-share-sent` | `--max-no-share-sent 300` | Restart if no share in N seconds |

## Docker Usage

All parameters go in `EXTRAS`. Multi-word values must be quoted.

### Examples

```bash
# CPU-only, 8 threads, extended logging
docker run -e WALLET_USER=abc -e "EXTRAS=--disable-gpu --cpu-threads 8 --extended-log" ghcr.io/m8477/srbminer-multi-docker:latest

# GPU mining, specific devices, log to file
docker run -e WALLET_USER=abc -e "EXTRAS=--gpu-id 0 --gpu-intensity 30 --log-file /tmp/miner.log" ghcr.io/m8477/srbminer-multi-docker:latest

# Multi-algorithm (GPU: kheavyhash, CPU: randomx)
docker run -e WALLET_USER=abc -e "EXTRAS=--algorithm kheavyhash;randomx --cpu-threads 4" ghcr.io/m8477/srbminer-multi-docker:latest
```

### docker-compose Example

```yaml
services:
  srbminer:
    image: ghcr.io/m8477/srbminer-multi-docker:latest
    environment:
      - WALLET_USER=1Fyq3JegvpKDrfcEgyxJdQGfgZZjhDJ18P
      - "EXTRAS=--disable-gpu --cpu-threads 8 --extended-log --api-enable --api-port 21550"
```

### Multi-value Parameters

Parameters that accept per-device values use comma delimiters:

```bash
EXTRAS="--gpu-id 0,1,2 --gpu-intensity 30,28,30 --gpu-off-temperature 75,75,80"
```

Algorithm separation uses semicolons:

```bash
EXTRAS="--algorithm kheavyhash;verushash --cpu-threads 4;2"
```
