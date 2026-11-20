#!/usr/bin/env bash
set -euo pipefail
stage=publish/home-0.3.9
tag=ota-apartment-v2
firmware=firmware-0.3.9.bin
manifest=manifest-0.3.9.json
url="https://github.com/$GH_REPO/releases/download/$tag"
temp=$(mktemp -d)
trap 'rm -rf "$temp"' EXIT
cat "$stage"/firmware.gz.* | gzip -dc > "$temp/$firmware"
python3 "$stage/verify.py" "$stage/$manifest" "$temp/$firmware" "$stage/public.pem"

publish_asset() {
    local file=$1 name=${1##*/} digest expected
    expected=$(sha256sum "$file" | cut -d ' ' -f 1)
    digest=$(gh api "repos/$GH_REPO/releases/tags/$tag" --jq ".assets[] | select(.name == \"$name\") | .digest")
    if [[ -z "$digest" ]]; then
        gh release upload "$tag" "$file"
    else
        [[ "$digest" == "sha256:$expected" ]]
    fi
    curl -fsSL --retry 5 --retry-all-errors "$url/$name" -o "$temp/public-$name"
    cmp "$file" "$temp/public-$name"
}

publish_asset "$temp/$firmware"
publish_asset "$stage/$manifest"
python3 "$stage/verify.py" "$temp/public-$manifest" "$temp/public-$firmware" "$stage/public.pem"
