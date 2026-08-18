#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEFAULT_NIX="${SCRIPT_DIR}/default.nix"
REPO="block/buzz"

if [[ -n "${1:-}" ]]; then
	VERSION="${1#desktop-v}"
	VERSION="${VERSION#v}"
	if [[ ! "${VERSION}" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
		echo "ERROR: Expected version X.Y.Z, vX.Y.Z, or desktop-vX.Y.Z; got ${1}" >&2
		exit 1
	fi
	RELEASE_TAG="desktop-v${VERSION}"
	echo "==> Fetching Buzz release ${RELEASE_TAG} from GitHub..."
	RELEASE_JSON="$(gh api "repos/${REPO}/releases/tags/${RELEASE_TAG}")"
else
	echo "==> Fetching latest Buzz version from GitHub..."
	RELEASE_JSON="$(gh api "repos/${REPO}/releases/latest")"
	RELEASE_TAG="$(jq -r '.tag_name // empty' <<<"${RELEASE_JSON}")"
	if [[ ! "${RELEASE_TAG}" =~ ^desktop-v([0-9]+\.[0-9]+\.[0-9]+)$ ]]; then
		echo "ERROR: Latest release tag must match desktop-vX.Y.Z; got ${RELEASE_TAG:-<empty>}" >&2
		exit 1
	fi
	VERSION="${BASH_REMATCH[1]}"
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
