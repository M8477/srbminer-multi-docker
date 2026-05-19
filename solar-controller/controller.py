import os, sys, time, docker, requests, json

HA_URL         = os.environ["HA_URL"]
HA_TOKEN       = os.environ["HA_TOKEN"]
BATTERY_ENTITY = os.environ.get("BATTERY_ENTITY") or "sensor.battery_state_of_charge"
SOLAR_ENTITY   = os.environ.get("SOLAR_ENTITY")   or "sensor.solar_power"
BATTERY_MIN    = float(os.environ.get("BATTERY_MIN") or 90)
SOLAR_MIN      = float(os.environ.get("SOLAR_MIN") or 800)
CHECK_SECS     = int(os.environ.get("CHECK_SECS") or 120)
MINER_NAME     = "srbminer"
FORCE_MINE     = (os.environ.get("FORCE_MINE") or "").upper() in ("Y", "YES", "TRUE", "1")
FORCE_MINS     = int(os.environ.get("FORCE_MINE_MINS") or 30)
HEARTBEAT_SECS = int(os.environ.get("HEARTBEAT_SECS") or 60)
API_PORT       = int(os.environ.get("API_PORT") or 21550)

sys.stdout.reconfigure(line_buffering=True) if hasattr(sys.stdout, "reconfigure") else None

def log(msg):
    print(f"[{time.strftime('%H:%M:%S')}] {msg}", flush=True)

def ha_state(entity_id):
    r = requests.get(f"{HA_URL}/api/states/{entity_id}", headers={"Authorization": f"Bearer {HA_TOKEN}"}, timeout=10)
    r.raise_for_status()
    return float(r.json()["state"])

def miner_api(container_id):
    try:
        r = requests.get(f"http://127.0.0.1:{API_PORT}/", timeout=5)
        if r.status_code == 200:
            data = r.json()
            return data
    except:
        pass
    return None

client = docker.from_env()

log("=" * 56)
log("  SOLAR MINING CONTROLLER — STARTUP")
log("=" * 56)
log(f"  HA URL:         {HA_URL}")
log(f"  Battery entity: {BATTERY_ENTITY}")
log(f"  Solar entity:   {SOLAR_ENTITY}")
log(f"  Logic:         mine when battery >= {BATTERY_MIN}% OR solar >= {SOLAR_MIN}W")
log(f"  Poll interval:  {CHECK_SECS}s")
log(f"  Heartbeat:      {HEARTBEAT_SECS}s")
log(f"  Miner name:     {MINER_NAME}")
log(f"  API port:       {API_PORT}")
log(f"  Force mine:     {FORCE_MINE}")
if FORCE_MINE:
    log(f"  Force duration: {FORCE_MINS} min")
log(f"  API dashboard:  http://<host>:{API_PORT}/stats")
log("=" * 56)

force_start_time = time.time() if FORCE_MINE else None
last_heartbeat = time.time()
last_api_ok = None
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
                log("FORCED: period ended - resuming normal control")
        else:
            battery = ha_state(BATTERY_ENTITY)
            solar   = ha_state(SOLAR_ENTITY)
            should_mine = battery >= BATTERY_MIN or solar >= SOLAR_MIN
            log(f"Battery: {battery:.1f}% | Solar: {solar:.0f}W | Mine: {should_mine} (battery{' >=' if battery >= BATTERY_MIN else ' <'}{BATTERY_MIN}% {'||' if should_mine else '&&'} solar{' >=' if solar >= SOLAR_MIN else ' <'}{SOLAR_MIN}W)")

        try:
            miner = client.containers.get(MINER_NAME)
            miner_status = miner.status
            miner_health = "none"
            try:
                miner_health = miner.attrs.get("State", {}).get("Health", {}).get("Status", "none")
            except:
                pass
            miner_running = (miner_status == "running")
            miner_unhealthy = miner_running and miner_health == "unhealthy"

            if miner_unhealthy:
                log("    Miner CRASHED (unhealthy) — restarting container")
                miner.restart()
                miner_running = True
                last_heartbeat = time.time()
                last_api_ok = None
                time.sleep(10)

            miner_status = miner.status
            miner_running = (miner_status == "running")

            if should_mine and miner_status != "running":
                miner.start()
                miner_running = True
                last_heartbeat = time.time()
                last_api_ok = None
                log(">>> Miner STARTED - waiting for API...")
            elif not should_mine and miner_status == "running":
                miner.stop()
                miner_running = False
                last_api_ok = None
                log("<<< Miner STOPPED")
            else:
                log(f"    Miner {'running' if miner_running else 'stopped'} (no change)")

            if miner_running:
                miner_health_now = "none"
                try:
                    miner_health_now = miner.attrs.get("State", {}).get("Health", {}).get("Status", "none")
                except:
                    pass
                api = miner_api(MINER_NAME)
                if api:
                    if last_api_ok is None:
                        log(f"    API ONLINE - v{api.get('version','?')} | {api.get('algorithm','?')}")
                    last_api_ok = time.time()
                    hr = api.get("hashrate", api.get("hashrate_total", 0))
                    shares = api.get("total_shares", api.get("shares", {}).get("accepted", 0))
                    uptime_secs = api.get("uptime", 0)
                    uptime_str = f"{int(uptime_secs//3600)}h{int((uptime_secs%3600)//60)}m" if uptime_secs else "0m"
                    log(f"    HR: {hr} h/s | Shares: {shares} | Uptime: {uptime_str}")
                else:
                    if last_api_ok is not None and time.time() - last_api_ok > 60:
                        log(f"    API unresponsive for {int(time.time() - last_api_ok)}s | health={miner_health_now}")
        except docker.errors.NotFound:
            log("WARN: srbminer container not found - check stack deployment")
            miner_running = False
    except Exception as e:
        log(f"ERR: {e}")

    deadline = time.time() + CHECK_SECS
    while time.time() < deadline:
        time.sleep(min(10, deadline - time.time()))
        if miner_running and (time.time() - last_heartbeat) >= HEARTBEAT_SECS:
            last_heartbeat = time.time()
            miner_h = "unknown"
            try:
                m = client.containers.get(MINER_NAME)
                miner_h = m.attrs.get("State", {}).get("Health", {}).get("Status", "unknown")
            except:
                pass
            if last_api_ok and time.time() - last_api_ok < 120:
                log(f"Heartbeat: API responding, miner healthy")
            else:
                log(f"Heartbeat: waiting for miner API (may need --api-enable in EXTRAS) | health={miner_h}")
