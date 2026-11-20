#!/usr/bin/env bash
set -euo pipefail
stage=publish/lyceum-0.3.10
tag=ota-lyceum-mobil-v2
firmware=firmware-0.3.10.bin
manifest=manifest-0.3.10.json
previous=manifest-0.2.9.22.json
previous_sha=702e28e8230ec3b4aa047d13f1cd56a66c9812c448f325046db9571d73276ff5
url="https://github.com/$GH_REPO/releases/download/$tag"
release_endpoint="repos/$GH_REPO/releases/tags/$tag"
temp=$(mktemp -d)
trap 'rm -rf "$temp"' EXIT
cat "$stage"/firmware.gz.* | gzip -dc > "$temp/$firmware"
python3 "$stage/verify.py" "$stage/$manifest" "$temp/$firmware" "$stage/public.pem"

asset_field() {
    local name=$1 field=$2
    gh api "$release_endpoint" --jq ".assets[] | select(.name == \"$name\") | .$field"
}
verify_download() {
    local file=$1 name=${1##*/}
    curl -fsSL --retry 5 --retry-all-errors "$url/$name" -o "$temp/public-$name"
    cmp "$file" "$temp/public-$name"
}
publish_asset() {
    local file=$1 name=${1##*/} digest expected
    expected=$(sha256sum "$file" | cut -d ' ' -f 1)
    digest=$(asset_field "$name" digest)
    if [[ -z "$digest" ]]; then
        gh release upload "$tag" "$file"
    else
        [[ "$digest" == "sha256:$expected" ]]
    fi
    verify_download "$file"
}
rename_asset() {
    local asset=$1 name=$2
    gh api --method PATCH "repos/$GH_REPO/releases/assets/$asset" -f "name=$name" --jq .name
}

publish_asset "$temp/$firmware"
publish_asset "$stage/$manifest"
python3 "$stage/verify.py" "$temp/public-$manifest" "$temp/public-$firmware" "$stage/public.pem"

cp "$stage/$manifest" "$temp/manifest.json"
new_sha=$(sha256sum "$temp/manifest.json" | cut -d ' ' -f 1)
current=$(asset_field manifest.json digest)
if [[ "$current" == "sha256:$new_sha" ]]; then
    verify_download "$temp/manifest.json"
    gh release edit "$tag" --title "ECM Reliability 0.3.10 — ліцей Мобіль (OTA v2)"
    exit 0
fi

if [[ "$current" == "sha256:$previous_sha" ]]; then
    [[ -z "$(asset_field "$previous" id)" ]]
    previous_id=$(asset_field manifest.json id)
    [[ -n "$previous_id" ]]
    rename_asset "$previous_id" "$previous"
elif [[ -z "$current" && "$(asset_field "$previous" digest)" == "sha256:$previous_sha" ]]; then
    previous_id=$(asset_field "$previous" id)
else
    echo 'The lyceum manifest changed. The current default was left in place.' >&2
    exit 1
fi

if ! gh release upload "$tag" "$temp/manifest.json"; then
    current=$(asset_field manifest.json digest)
    if [[ "$current" != "sha256:$new_sha" ]]; then
        if [[ -z "$current" ]]; then rename_asset "$previous_id" manifest.json; fi
        exit 1
    fi
fi
verify_download "$temp/manifest.json"
gh release edit "$tag" --title "ECM Reliability 0.3.10 — ліцей Мобіль (OTA v2)"
