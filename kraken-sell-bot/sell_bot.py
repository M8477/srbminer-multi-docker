import os, sys, time, krakenex

KRAKEN_KEY = os.environ.get("KRAKEN_KEY", "")
KRAKEN_SECRET = os.environ.get("KRAKEN_SECRET", "")

if not KRAKEN_KEY or not KRAKEN_SECRET:
    print("KRAKEN_KEY and/or KRAKEN_SECRET not set — kraken-sell-bot disabled.")
    sys.exit(0)

api = krakenex.API(key=KRAKEN_KEY, secret=KRAKEN_SECRET)
MIN_BTC_SELL = float(os.environ.get("MIN_BTC_SELL") or 0.0005)
print(f"Sell bot started. Selling when BTC balance > {MIN_BTC_SELL}")

while True:
    try:
        resp = api.query_private("Balance")
        if resp.get("error"):
            print(f"⚠  {resp['error']}")
        else:
            btc = float(resp["result"].get("XXBT", 0))
            print(f"BTC balance: {btc:.8f}")
            if btc >= MIN_BTC_SELL:
                order = api.query_private("AddOrder", {
                    "pair": "XBTGBP", "type": "sell",
                    "ordertype": "market",
                    "volume": str(round(btc * 0.99, 8))
                })
                print(f"✅ Sold! {order['result'].get('txid')}")
            else:
                print("   Below threshold, not selling yet.")
    except Exception as e:
        print(f"⚠  Error: {e}")
    time.sleep(3600)
