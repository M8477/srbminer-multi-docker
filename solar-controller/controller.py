import os, time, docker, requests

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

HEADERS = {"Authorization": f"Bearer {HA_TOKEN}"}

def ha_state(entity_id):
    r = requests.get(f"{HA_URL}/api/states/{entity_id}", headers=HEADERS, timeout=10)
    r.raise_for_status()
    return float(r.json()["state"])

client = docker.from_env()
force_start_time = None
if FORCE_MINE:
    print(f"FORCE_MINE enabled — ignoring solar/battery rules for {FORCE_MINS} minutes")
    force_start_time = time.time()
print(f"Controller started. Battery min: {BATTERY_MIN}% | Solar min: {SOLAR_MIN}W")

while True:
    try:
        if force_start_time is not None:
            elapsed = (time.time() - force_start_time) / 60
            if elapsed < FORCE_MINS:
                should_mine = True
                remaining = FORCE_MINS - elapsed
                print(f"Forced mining — {remaining:.0f} min remaining")
            else:
                force_start_time = None
                should_mine = False
                print("Forced mining period ended — resuming normal control")
        else:
            battery = ha_state(BATTERY_ENTITY)
            solar   = ha_state(SOLAR_ENTITY)
            should_mine = battery >= BATTERY_MIN and solar >= SOLAR_MIN
            print(f"Battery: {battery:.1f}% | Solar: {solar:.0f}W | Mining: {should_mine}")
        try:
            miner = client.containers.get(MINER_NAME)
            if should_mine and miner.status != "running":
                miner.start()
                print("▶  Miner STARTED")
            elif not should_mine and miner.status == "running":
                miner.stop()
                print("⏹  Miner STOPPED")
            else:
                print(f"   Miner already {'running ✓' if miner.status == 'running' else 'stopped ✓'}")
        except docker.errors.NotFound:
            print("⚠  srbminer container not found")
    except Exception as e:
        print(f"⚠  Error: {e}")
    time.sleep(CHECK_SECS)
