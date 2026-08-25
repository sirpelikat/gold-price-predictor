import os
import json
import requests
from datetime import datetime

CACHE_DIR = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "data")
BNM_CACHE_FILE = os.path.join(CACHE_DIR, "bnm_cache.json")

def ensure_cache_dir():
    os.makedirs(CACHE_DIR, exist_ok=True)

def load_cache():
    if os.path.exists(BNM_CACHE_FILE):
        try:
            with open(BNM_CACHE_FILE, "r") as f:
                return json.load(f)
        except Exception:
            return {}
    return {}

def save_cache(cache_data):
    ensure_cache_dir()
    try:
        with open(BNM_CACHE_FILE, "w") as f:
            json.dump(cache_data, f, indent=2)
    except Exception as e:
        print(f"Error saving BNM cache: {e}")

def get_bnm_headers():
    return {
        "Accept": "application/vnd.BNM.API.v1+json",
        "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36"
    }

def get_latest_kijang_emas():
    """
    Fetches the latest official BNM Kijang Emas gold bullion buying and selling prices.
    Returns 1 oz, 1/2 oz, 1/4 oz prices and effective date.
    """
    cache = load_cache()
    today_str = datetime.now().strftime("%Y-%m-%d")
    
    if "kijang_emas_latest" in cache:
        cached_entry = cache["kijang_emas_latest"]
        if cached_entry.get("cached_date") == today_str:
            return cached_entry["data"]

    url = "https://api.bnm.gov.my/public/kijang-emas"
    try:
        r = requests.get(url, headers=get_bnm_headers(), timeout=5)
        if r.status_code == 200:
            res_json = r.json()
            data = res_json.get("data", {})
            cache["kijang_emas_latest"] = {
                "cached_date": today_str,
                "data": data
            }
            save_cache(cache)
            return data
    except Exception as e:
        print(f"Error fetching live BNM Kijang Emas: {e}")

    # Fallback to cached data or standard defaults
    if "kijang_emas_latest" in cache:
        return cache["kijang_emas_latest"].get("data", {})
        
    return {
        "effective_date": today_str,
        "one_oz": {"buying": 18624, "selling": 19387},
        "half_oz": {"buying": 9312, "selling": 9877},
        "quarter_oz": {"buying": 4656, "selling": 5030}
    }

def get_historical_kijang_emas_month(year: int, month: int):
    """Fetches daily Kijang Emas prices for a given month."""
    url = f"https://api.bnm.gov.my/public/kijang-emas/year/{year}/month/{month:02d}"
    try:
        r = requests.get(url, headers=get_bnm_headers(), timeout=5)
        if r.status_code == 200:
            return r.json().get("data", [])
    except Exception as e:
        print(f"Error fetching historical Kijang Emas for {year}-{month}: {e}")
    return []

def get_latest_opr():
    """
    Fetches the current Overnight Policy Rate (OPR) from Bank Negara Malaysia.
    """
    cache = load_cache()
    current_year = datetime.now().year
    
    if "opr_history" in cache:
        history = cache["opr_history"]
        if history:
            latest = history[0]
            return float(latest.get("new_opr_level", 2.75))

    url = f"https://api.bnm.gov.my/public/opr/year/{current_year}"
    try:
        r = requests.get(url, headers=get_bnm_headers(), timeout=5)
        if r.status_code == 200:
            data = r.json().get("data", [])
            if data:
                cache["opr_history"] = data
                save_cache(cache)
                return float(data[0].get("new_opr_level", 2.75))
    except Exception as e:
        print(f"Error fetching BNM OPR: {e}")

    return 2.75

if __name__ == "__main__":
    print("Testing BNM Client...")
    kijang = get_latest_kijang_emas()
    print("Latest Kijang Emas:", kijang)
    opr = get_latest_opr()
    print(f"Current BNM OPR: {opr}%")
