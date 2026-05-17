import os, sys, time, docker, requests

HA_URL         = os.environ["HA_URL"]
HA_TOKEN       = os.environ["HA_TOKEN"]
BATTERY_ENTITY = os.environ.get("BATTERY_ENTITY", "sensor.battery_state_of_charge")
SOLAR_ENTITY   = os.environ.get("SOLAR_ENTITY",   "sensor.solar_power")
BATTERY_MIN    = float(os.environ.get("BATTERY_MIN", 90))
SOLAR_MIN      = float(os.environ.get("SOLAR_MIN",   800))
CHECK_SECS     = int(os.environ.get("CHECK_SECS",    120))
MINER_NAME     = "srbminer"
FORCE_MINE     = os.environ.get("FORCE_MINE", "").upper() in ("Y", "YES", "TRUE", "1")
FORCE_MINS     = int(os.environ.get("FORCE_MINE_MINS", 30))
HEARTBEAT_SECS = int(os.environ.get("HEARTBEAT_SECS", 60))

sys.stdout.reconfigure(line_buffering=True) if hasattr(sys.stdout, "reconfigure") else None

def log(msg):
    print(f"[{time.strftime('%H:%M:%S')}] {msg}", flush=True)

def ha_state(entity_id):
    r = requests.get(f"{HA_URL}/api/states/{entity_id}", headers={"Authorization": f"Bearer {HA_TOKEN}"}, timeout=10)
    r.raise_for_status()
    return float(r.json()["state"])

client = docker.from_env()

log("=" * 56)
log("  SOLAR MINING CONTROLLER — STARTUP")
log("=" * 56)
log(f"  HA URL:         {HA_URL}")
log(f"  Battery entity: {BATTERY_ENTITY}")
log(f"  Solar entity:   {SOLAR_ENTITY}")
log(f"  Logic:         mine when battery ≥ {BATTERY_MIN}% OR solar ≥ {SOLAR_MIN}W")
log(f"  Poll interval:  {CHECK_SECS}s")
log(f"  Heartbeat:      {HEARTBEAT_SECS}s")
log(f"  Miner name:     {MINER_NAME}")
log(f"  Force mine:     {FORCE_MINE}")
if FORCE_MINE:
    log(f"  Force duration: {FORCE_MINS} min")
log("=" * 56)

force_start_time = time.time() if FORCE_MINE else None
last_heartbeat = time.time()
miner_running = False

while True:
    try:
        if force_start_time is not None:
            elapsed = (time.time() - force_start_time) / 60
            if elapsed < FORCE_MINS:
                should_mine = True
                log(f"FORCED: mining {FORCE_MINS - elapsed:.0f}min remaining")
            else:
                force_start_time = None
                should_mine = False
                log("FORCED: period ended — resuming normal control")
        else:
            battery = ha_state(BATTERY_ENTITY)
            solar   = ha_state(SOLAR_ENTITY)
            should_mine = battery >= BATTERY_MIN or solar >= SOLAR_MIN
            log(f"Battery: {battery:.1f}% | Solar: {solar:.0f}W | Mine: {should_mine} (battery{'≥' if battery >= BATTERY_MIN else '<'}{BATTERY_MIN}% {'OR' if should_mine else 'NOR'} solar{'≥' if solar >= SOLAR_MIN else '<'}{SOLAR_MIN}W)")

        try:
            miner = client.containers.get(MINER_NAME)
            if should_mine and miner.status != "running":
                miner.start()
                miner_running = True
                last_heartbeat = time.time()
                log("▶  Miner STARTED")
            elif not should_mine and miner.status == "running":
                miner.stop()
                miner_running = False
                log("⏹  Miner STOPPED")
            else:
                miner_running = (miner.status == "running")
                log(f"   Miner {'running' if miner_running else 'stopped'} (no change)")
        except docker.errors.NotFound:
            log("⚠  srbminer container not found")
            miner_running = False
    except Exception as e:
        log(f"⚠  Error: {e}")

    deadline = time.time() + CHECK_SECS
    while time.time() < deadline:
        time.sleep(min(10, deadline - time.time()))
        if miner_running and (time.time() - last_heartbeat) >= HEARTBEAT_SECS:
            last_heartbeat = time.time()
            log(f"♥  Miner active — uptime: {last_heartbeat - (last_heartbeat - HEARTBEAT_SECS):.0f}s+ (heartbeat every {HEARTBEAT_SECS}s)")
