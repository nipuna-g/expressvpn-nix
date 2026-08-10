#!/usr/bin/env bash
# Update package.nix to the latest ExpressVPN Linux "universal" (Qt) build.
#
# Source of truth is ExpressVPN's own installers API — the same endpoint the
# https://www.expressvpn.com/latest download page calls at runtime. It returns
# the full version (incl. build number), the download URL, and the sha256, so
# no HTML scraping or headless browser is needed.
#
# Writes `changed`/`version` to $GITHUB_OUTPUT when run in CI; safe to run
# locally too (it just prints what it would do).
set -euo pipefail

API_URL="https://main-kp-site-gateway-http.prodv2.pac.xvservice.net/api/v2/installers"
PACKAGE_NIX="$(cd "$(dirname "$0")" && pwd)/package.nix"

out() { echo "$1=$2" >> "${GITHUB_OUTPUT:-/dev/null}"; }

json="$(curl -fsSL "$API_URL")"

# .version looks like "14.2.0.13656_release"; strip the suffix.
version="$(jq -r '.installers.linux_qt.version' <<<"$json" | sed 's/_release$//')"
url="$(jq -r '.installers.linux_qt.locations.default' <<<"$json")"
sha256_hex="$(jq -r '.installers.linux_qt.checksums.sha256' <<<"$json")"

if ! [[ "$version" =~ ^[0-9]+(\.[0-9]+)+$ ]]; then
  echo "error: unexpected version from API: '$version'" >&2
  exit 1
fi

# package.nix constructs the URL from ${version}; bail if that pattern drifted
# so we never emit a bump that points at a non-existent file.
expected_url="https://www.expressvpn.works/clients/linux/expressvpn-linux-universal-${version}_release.run"
if [[ "$url" != "$expected_url" ]]; then
  echo "error: download URL pattern changed, update package.nix by hand" >&2
  echo "  api:      $url" >&2
  echo "  expected: $expected_url" >&2
  exit 1
fi

hash="$(nix hash convert --hash-algo sha256 --to sri "$sha256_hex")"

current="$(grep -oP 'version = "\K[^"]+' "$PACKAGE_NIX")"
echo "current: $current"
echo "latest:  $version"
echo "hash:    $hash"

if [[ "$version" == "$current" ]]; then
  echo "already up to date"
  out changed false
  exit 0
fi

sed -i -E "s|version = \"[^\"]+\";|version = \"$version\";|" "$PACKAGE_NIX"
sed -i -E "s|hash = \"[^\"]+\";|hash = \"$hash\";|" "$PACKAGE_NIX"

echo "updated package.nix: $current -> $version"
out changed true
out version "$version"
