"""Fetch the CC0 Kenney character once; every file is checked against a pinned SHA-256."""
from pathlib import Path
from io import BytesIO
import hashlib
import json
import urllib.request
import zipfile

ROOT = Path(__file__).resolve().parents[1]
DEST = ROOT / "assets" / "character"
URL = "https://kenney.nl/media/pages/assets/animated-characters-protagonists/608191acc4-1774773108/kenney_animated-characters-protagonists.zip"

def main():
    manifest = json.loads((DEST / "manifest.json").read_text())
    missing = {name: item for name, item in manifest.items()
               if not (DEST / name).exists() or hashlib.sha256((DEST / name).read_bytes()).hexdigest() != item["sha256"]}
    if not missing:
        print("Verified character assets already present.")
        return
    print("Downloading Kenney Animated Characters Protagonists (CC0)...")
    request = urllib.request.Request(URL, headers={"User-Agent": "Shmovement-asset-setup/1.0"})
    with urllib.request.urlopen(request, timeout=60) as response:
        archive = zipfile.ZipFile(BytesIO(response.read()))
    for name, item in missing.items():
        data = archive.read(item["source"])
        if hashlib.sha256(data).hexdigest() != item["sha256"]:
            raise RuntimeError("Character asset checksum mismatch: " + name)
        (DEST / name).write_bytes(data)
    print("Character assets downloaded and verified.")

if __name__ == "__main__":
    main()
