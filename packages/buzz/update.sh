#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEFAULT_NIX="${SCRIPT_DIR}/default.nix"
REPO="block/buzz"

if [[ -n "${1:-}" ]]; then
	VERSION="${1#v}"
	echo "==> Fetching Buzz release v${VERSION} from GitHub..."
	RELEASE_JSON="$(gh api "repos/${REPO}/releases/tags/v${VERSION}")"
else
	echo "==> Fetching latest Buzz version from GitHub..."
	RELEASE_JSON="$(gh api "repos/${REPO}/releases/latest")"
	VERSION="$(jq -r '.tag_name | ltrimstr("v")' <<<"${RELEASE_JSON}")"
fi

CURRENT_VERSION=$(grep 'version = "' "${DEFAULT_NIX}" | head -1 | sed 's/.*version = "\([^"]*\)".*/\1/')
if [[ "${VERSION}" == "${CURRENT_VERSION}" ]]; then
	echo "==> Already at version ${VERSION}, nothing to do"
	exit 0
fi

echo "==> Updating Buzz from ${CURRENT_VERSION} to ${VERSION}"

ASSET_NAME="Buzz_${VERSION}_amd64.AppImage"
DIGEST="$(jq -r --arg asset_name "${ASSET_NAME}" '.assets[] | select(.name == $asset_name) | .digest' <<<"${RELEASE_JSON}")"

if [[ -z "${DIGEST}" || "${DIGEST}" == "null" ]]; then
	echo "ERROR: Could not find digest for asset ${ASSET_NAME}" >&2
	exit 1
fi

HASH_SRI="$(nix hash convert --to sri --hash-algo sha256 "${DIGEST#sha256:}")"
echo "    Asset: ${ASSET_NAME}"
echo "    Hash:  ${HASH_SRI}"

sed -i "s/version = \"[0-9.]*\";/version = \"${VERSION}\";/" "${DEFAULT_NIX}"
sed -i "s|hash = \"sha256-[^\"]*\";|hash = \"${HASH_SRI}\";|" "${DEFAULT_NIX}"

echo "==> Done! Build to verify: nix build '.#buzz'"
