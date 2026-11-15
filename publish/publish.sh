#!/usr/bin/env bash
set -euo pipefail
version=0.2.9.16
asset="firmware-$version.bin"
release="https://github.com/$GH_REPO/releases/download"
profiles=(apartment lyceum-mobil)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
verify_package() {
 local dir=$1 channel=$2
 python3 - "$dir" "$release/$channel/$asset" "$tmp" <<'PY'
import hashlib, json, sys
from pathlib import Path
directory, expected, scratch = Path(sys.argv[1]), sys.argv[2], Path(sys.argv[3])
manifest = json.loads((directory / "manifest.json").read_bytes())
binary = (directory / "firmware-0.2.9.16.bin").read_bytes()
assert manifest["board"] == "esp32c3"
assert manifest["url"] == expected and manifest["version"] == "TOX Reliability 0.2.9.16"
assert manifest["size"] == len(binary) and 70000 <= len(binary) <= 0x140000
assert manifest["sha256"] == hashlib.sha256(binary).hexdigest()
assert binary[0] == 0xE9 and int.from_bytes(binary[12:14], "little") == 5
payload = "TOX-OTA-v1\nesp32c3\n{version}\n{size}\n{sha256}\n{url}\n".format(**manifest)
(scratch / "payload").write_bytes(payload.encode())
(scratch / "signature").write_bytes(bytes.fromhex(manifest["signature"]))
PY
 openssl dgst -sha256 -verify "publish/${channel:4:-3}/public.pem" -signature "$tmp/signature" "$tmp/payload"
}
for profile in "${profiles[@]}"; do
 dir="publish/$profile"
 tag="ota-$profile-v2"
 cat "$dir"/firmware.gz.* | gzip -dc > "$dir/$asset"
 verify_package "$dir" "$tag"
done
for profile in "${profiles[@]}"; do
 dir="publish/$profile"
 tag="ota-$profile-v2"
 case "$profile" in apartment) title="квартира";; lyceum-mobil) title="ліцей Мобіль";; esac
 if ! gh release view "$tag" >/dev/null 2>&1; then
  gh release create "$tag" "$dir/$asset" "$dir/manifest.json" --target main --prerelease \
    --title "ECM Reliability $version — $title (OTA v2)" --notes "ESP32-C3. Requires the USB transition build with the new public key for this channel."
 fi
 mkdir -p "$tmp/$tag"
 for file in "$asset" manifest.json; do
  curl -fsSL --retry 4 --retry-all-errors "$release/$tag/$file" -o "$tmp/$tag/$file"
  cmp "$dir/$file" "$tmp/$tag/$file"
 done
 verify_package "$tmp/$tag" "$tag"
done
