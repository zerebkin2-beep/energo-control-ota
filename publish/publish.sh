#!/usr/bin/env bash
set -euo pipefail

profiles=(apartment lyceum-mobil)
version=0.2.9.18
asset="firmware-$version.bin"
release="https://github.com/$GH_REPO/releases/download"

verify_package() {
    local manifest="$1" binary="$2" public_key="$3" expected_url="$4"
    local signed_data signature
    signed_data=$(mktemp)
    signature=$(mktemp)
    python3 - "$manifest" "$binary" "$expected_url" "$signed_data" "$signature" <<'PY'
import hashlib
import json
import sys
from pathlib import Path

manifest_path, binary_path, expected_url, signed_data, signature = sys.argv[1:]
manifest = json.loads(Path(manifest_path).read_bytes())
binary = Path(binary_path).read_bytes()
assert manifest["board"] == "esp32c3"
assert manifest["url"] == expected_url
assert manifest["version"] == "TOX Reliability 0.2.9.18"
assert manifest["size"] == len(binary) and 70000 <= len(binary) <= 0x140000
assert manifest["sha256"] == hashlib.sha256(binary).hexdigest()
assert binary[0] == 0xE9 and int.from_bytes(binary[12:14], "little") == 5
payload = "TOX-OTA-v1\nesp32c3\n{version}\n{size}\n{sha256}\n{url}\n".format(**manifest)
Path(signed_data).write_bytes(payload.encode())
Path(signature).write_bytes(bytes.fromhex(manifest["signature"]))
PY
    openssl dgst -sha256 -verify "$public_key" -signature "$signature" "$signed_data"
    rm -f "$signed_data" "$signature"
}

temp_dir=$(mktemp -d)
changed=()
rollback() {
    local status=$?
    if (( status != 0 )); then
        for tag in "${changed[@]}"; do
            echo "Restoring the previous manifest for $tag" >&2
            gh release upload "$tag" "$temp_dir/$tag/manifest.json" --clobber || true
        done
    fi
    rm -rf "$temp_dir"
}
trap rollback EXIT

for profile in "${profiles[@]}"; do
    dir="publish/$profile"
    tag="ota-$profile-v2"
    cat "$dir"/firmware.gz.* | gzip -dc > "$dir/$asset"
    verify_package "$dir/manifest.json" "$dir/$asset" "$dir/public.pem" "$release/$tag/$asset"
    mkdir -p "$temp_dir/$tag"
    gh release download "$tag" --pattern manifest.json --dir "$temp_dir/$tag"
    jq -e '.version == "TOX Reliability 0.2.9.17" or .version == "TOX Reliability 0.2.9.18"' "$temp_dir/$tag/manifest.json" >/dev/null
done

for profile in "${profiles[@]}"; do
    dir="publish/$profile"
    tag="ota-$profile-v2"
    expected=$(sha256sum "$dir/$asset" | cut -d ' ' -f 1)
    digest=$(gh api "repos/$GH_REPO/releases/tags/$tag" --jq ".assets[] | select(.name == \"$asset\") | .digest")
    if [[ -z "$digest" ]]; then
        gh release upload "$tag" "$dir/$asset"
    else
        [[ "$digest" == "sha256:$expected" ]]
    fi
    curl --fail --silent --show-error --location --retry 4 --retry-all-errors \
        "$release/$tag/$asset" --output "$temp_dir/$tag/$asset"
    verify_package "$dir/manifest.json" "$temp_dir/$tag/$asset" "$dir/public.pem" "$release/$tag/$asset"
done

for profile in "${profiles[@]}"; do
    dir="publish/$profile"
    tag="ota-$profile-v2"
    changed+=("$tag")
    gh release upload "$tag" "$dir/manifest.json" --clobber
    curl --fail --silent --show-error --location --retry 4 --retry-all-errors \
        "$release/$tag/manifest.json" --output "$temp_dir/$tag/published.json"
    verify_package "$temp_dir/$tag/published.json" "$temp_dir/$tag/$asset" "$dir/public.pem" "$release/$tag/$asset"
    echo "Verified public OTA $profile $version"
done
changed=()

gh release edit ota-apartment-v2 --title "ECM Reliability $version — квартира (OTA v2)"
gh release edit ota-lyceum-mobil-v2 --title "ECM Reliability $version — ліцей Мобіль (OTA v2)"
