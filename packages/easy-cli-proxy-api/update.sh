#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEFAULT_NIX="${SCRIPT_DIR}/default.nix"
REPO="router-for-me/EasyCLIProxyAPI"

if [[ -n "${1:-}" ]]; then
	VERSION="${1#v}"
	if [[ ! "${VERSION}" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
		echo "ERROR: Expected version X.Y.Z or vX.Y.Z; got ${1}" >&2
		exit 1
	fi
	RELEASE_JSON="$(curl --fail --silent --show-error --location \
		-H "Accept: application/vnd.github+json" \
		"https://api.github.com/repos/${REPO}/releases/tags/v${VERSION}")"
else
	RELEASE_JSON="$(curl --fail --silent --show-error --location \
		-H "Accept: application/vnd.github+json" \
		"https://api.github.com/repos/${REPO}/releases/latest")"
	RELEASE_TAG="$(jq -r '.tag_name // empty' <<<"${RELEASE_JSON}")"
	if [[ ! "${RELEASE_TAG}" =~ ^v([0-9]+\.[0-9]+\.[0-9]+)$ ]]; then
		echo "ERROR: Latest release tag must match vX.Y.Z; got ${RELEASE_TAG:-<empty>}" >&2
		exit 1
	fi
	VERSION="${BASH_REMATCH[1]}"
fi

CURRENT_VERSION="$(grep 'version = "' "${DEFAULT_NIX}" | head -1 | sed 's/.*version = "\([^"]*\)".*/\1/')"
if [[ "${VERSION}" == "${CURRENT_VERSION}" ]]; then
	echo "==> Already at version ${VERSION}, nothing to do"
	exit 0
fi

echo "==> Updating EasyCLIProxyAPI from ${CURRENT_VERSION} to ${VERSION}"

ASSET_NAME="EasyCLIProxyAPI-v${VERSION}-Linux-amd64.tar.gz"
DIGEST="$(jq -r --arg asset_name "${ASSET_NAME}" '.assets[] | select(.name == $asset_name) | .digest' <<<"${RELEASE_JSON}")"
if [[ -z "${DIGEST}" || "${DIGEST}" == "null" ]]; then
	echo "ERROR: Could not find digest for asset ${ASSET_NAME}" >&2
	exit 1
fi

SRC_HASH="$(nix hash convert --to sri --hash-algo sha256 "${DIGEST#sha256:}")"
ICON_URL="https://raw.githubusercontent.com/${REPO}/v${VERSION}/src-tauri/icons/icon.png"
ICON_HASH="$(nix store prefetch-file --json "${ICON_URL}" | jq -r .hash)"

sed -i "s/version = \"[0-9.]*\";/version = \"${VERSION}\";/" "${DEFAULT_NIX}"
sed -i "s|srcHash = \"sha256-[^\"]*\";|srcHash = \"${SRC_HASH}\";|" "${DEFAULT_NIX}"
sed -i "s|iconHash = \"sha256-[^\"]*\";|iconHash = \"${ICON_HASH}\";|" "${DEFAULT_NIX}"

echo "==> Done! Build to verify: nix build '.#easy-cli-proxy-api'"
