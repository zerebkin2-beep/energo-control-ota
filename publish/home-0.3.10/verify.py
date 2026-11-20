import hashlib
import json
import subprocess
import sys
import tempfile
from pathlib import Path

manifest_path, firmware_path, key_path = map(Path, sys.argv[1:])
manifest = json.loads(manifest_path.read_text())
firmware = firmware_path.read_bytes()
expected_url = "https://github.com/zerebkin2-beep/energo-control-ota/releases/download/ota-apartment-v2/firmware-0.3.10.bin"
assert manifest["board"] == "esp32c3"
assert manifest["version"] == "TOX Reliability 0.3.10"
assert manifest["url"] == expected_url
assert manifest["size"] == len(firmware) and 70000 <= len(firmware) <= 0x140000
assert firmware[0] == 0xE9 and int.from_bytes(firmware[12:14], "little") == 5
assert manifest["sha256"] == hashlib.sha256(firmware).hexdigest()
payload = "TOX-OTA-v1\nesp32c3\n{version}\n{size}\n{sha256}\n{url}\n".format(**manifest)
with tempfile.TemporaryDirectory() as temp:
    signature = Path(temp) / "signature.der"
    signature.write_bytes(bytes.fromhex(manifest["signature"]))
    subprocess.run(
        ["openssl", "dgst", "-sha256", "-verify", key_path, "-signature", signature],
        input=payload.encode(),
        check=True,
    )
