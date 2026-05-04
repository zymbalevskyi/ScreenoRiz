#!/usr/bin/env python3
"""
fetch_jars.py — scrape monobank jar pages and bundle data for ScreenoRiz.

Usage:
    python3 scripts/fetch_jars.py

Outputs:
    ScreenoRiz/jars.json                              — bundled metadata
    ScreenoRiz/Assets.xcassets/jar-cover-<id>.imageset/  — cover images
    ScreenoRiz/Assets.xcassets/jar-logo-<id>.imageset/   — fund logos

Re-run any time to refresh. Add/remove jar URLs from JAR_URLS below.
"""

import base64
import json
import sys
import time
from pathlib import Path
from urllib.parse import urlparse

import requests
from cryptography.hazmat.primitives.asymmetric import ec
from cryptography.hazmat.primitives.serialization import Encoding, PublicFormat

# ─── Configuration ────────────────────────────────────────────────────────────

JAR_URLS = [
    "https://send.monobank.ua/jar/2aZvCsmaXg",
    "https://send.monobank.ua/jar/7r7v7wVLJv",
    "https://send.monobank.ua/jar/6RLCTJtkYV",
    "https://send.monobank.ua/jar/2JbpBYkhMv",
    "https://send.monobank.ua/jar/A6ExTgYxLa",
    "https://send.monobank.ua/jar/7VuHWj7Eyx",
    "https://send.monobank.ua/jar/8VKoiC3p6q",
]

REPO_ROOT   = Path(__file__).parent.parent
ASSET_DIR   = REPO_ROOT / "ScreenoRiz" / "Assets.xcassets"
JARS_JSON   = REPO_ROOT / "ScreenoRiz" / "jars.json"
API_URL     = "https://send.monobank.ua/api/handler"

# ─── Helpers ──────────────────────────────────────────────────────────────────

def make_pc() -> str:
    """Generate a P-256 public key in the format monobank expects (hexToBase64)."""
    priv = ec.generate_private_key(ec.SECP256R1())
    pub_bytes = priv.public_key().public_bytes(Encoding.X962, PublicFormat.UncompressedPoint)
    return base64.b64encode(bytes.fromhex(pub_bytes.hex())).decode()


def imageset_contents(filename: str) -> dict:
    return {
        "images": [{"filename": filename, "idiom": "universal", "scale": "1x"}],
        "info": {"author": "xcode", "version": 1},
    }


def save_imageset(asset_name: str, image_url: str, session: requests.Session) -> bool:
    """Download image_url and write it as an Xcode imageset."""
    if not image_url:
        return False

    imageset_dir = ASSET_DIR / f"{asset_name}.imageset"
    imageset_dir.mkdir(parents=True, exist_ok=True)

    ext = Path(urlparse(image_url).path).suffix.lower()
    if ext not in (".png", ".jpg", ".jpeg", ".webp"):
        ext = ".png"
    filename = f"{asset_name}{ext}"

    try:
        r = session.get(image_url, timeout=20)
        r.raise_for_status()
        (imageset_dir / filename).write_bytes(r.content)
    except Exception as e:
        print(f"    ⚠  download failed: {e}")
        return False

    (imageset_dir / "Contents.json").write_text(
        json.dumps(imageset_contents(filename), indent=2)
    )
    return True


def fetch_jar(jar_id: str, session: requests.Session) -> dict | None:
    url = f"https://send.monobank.ua/jar/{jar_id}"
    print(f"\n→ {url}")

    try:
        r = session.post(
            API_URL,
            json={"c": "hello", "clientId": jar_id, "previousJar": "", "referer": "", "Pc": make_pc()},
            headers={"Referer": url},
            timeout=15,
        )
        r.raise_for_status()
        data = r.json()
    except Exception as e:
        print(f"  ✗ API error: {e}")
        return None

    if "errCode" in data:
        print(f"  ✗ API returned error {data['errCode']}: {data.get('errText','')}")
        return None

    name       = data.get("name", "").strip()
    owner_name = data.get("ownerName", "").strip()
    jar_type   = data.get("jarType", "gather")
    cover_url  = data.get("gatherIcon", "") or data.get("avatar", "")
    logo_url   = data.get("avatar", "")

    print(f"  name:      {name}")
    print(f"  ownerName: {owner_name}")
    print(f"  cover:     {cover_url}")
    print(f"  logo:      {logo_url}")

    cover_asset = f"jar-cover-{jar_id}"
    logo_asset  = f"jar-logo-{jar_id}"

    print("  Downloading cover...", end=" ", flush=True)
    ok = save_imageset(cover_asset, cover_url, session)
    print("✓" if ok else "✗")
    if not ok:
        cover_asset = ""

    print("  Downloading logo...", end=" ", flush=True)
    ok = save_imageset(logo_asset, logo_url, session)
    print("✓" if ok else "✗")
    if not ok:
        logo_asset = ""

    return {
        "id":          jar_id,
        "name":        name,
        "fundName":    owner_name,
        "jarType":     jar_type,
        "url":         url,
        "coverAsset":  cover_asset,
        "logoAsset":   logo_asset,
    }


# ─── Main ─────────────────────────────────────────────────────────────────────

def main() -> None:
    session = requests.Session()
    session.headers.update({
        "User-Agent":    "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X)",
        "Content-Type":  "application/json",
        "Origin":        "https://send.monobank.ua",
        "Accept":        "application/json",
    })

    jars = []
    for url in JAR_URLS:
        jar_id = url.rstrip("/").split("/")[-1]
        result = fetch_jar(jar_id, session)
        if result:
            jars.append(result)
        time.sleep(0.4)  # be polite

    JARS_JSON.write_text(json.dumps(jars, ensure_ascii=False, indent=2))
    print(f"\n✅  Saved {len(jars)} jars → {JARS_JSON.relative_to(REPO_ROOT)}")
    print("    Re-run any time to refresh. Edit JAR_URLS at the top to add/remove jars.")


if __name__ == "__main__":
    main()
