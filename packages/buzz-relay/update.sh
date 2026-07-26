#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEFAULT_NIX="${SCRIPT_DIR}/default.nix"
REPO="block/buzz"

if [[ -n "${1:-}" ]]; then
	VERSION="${1#v}"
else
	VERSION="$(curl --fail --silent --show-error --location \
		-H "Accept: application/vnd.github+json" \
		"https://api.github.com/repos/${REPO}/releases/latest" | jq -r '.tag_name | ltrimstr("v")')"
fi

if [[ -z "${VERSION}" || "${VERSION}" == "null" ]]; then
	echo "Failed to determine Buzz version" >&2
	exit 1
fi

CURRENT_VERSION="$(sed -n 's/^[[:space:]]*version = "\([^"]*\)";.*/\1/p' "${DEFAULT_NIX}" | head -n1)"
if [[ "${CURRENT_VERSION}" == "${VERSION}" ]]; then
	echo "buzz-relay is already at ${VERSION}"
	exit 0
fi

SOURCE_URL="https://github.com/${REPO}/archive/refs/tags/v${VERSION}.tar.gz"
SOURCE_HASH="$(nix-prefetch-url --unpack "${SOURCE_URL}" 2>/dev/null | tail -n1)"
SOURCE_HASH="$(nix hash convert --hash-algo sha256 --to sri "${SOURCE_HASH}")"

sed -i \
	-e "s|version = \"${CURRENT_VERSION}\";|version = \"${VERSION}\";|" \
	-e "s|hash = \"sha256-[^\"]*\";|hash = \"${SOURCE_HASH}\";|" \
	-e 's|cargoHash = "sha256-[^"]*";|cargoHash = lib.fakeHash;|' \
	"${DEFAULT_NIX}"

set +e
BUILD_OUTPUT="$(nix build "${SCRIPT_DIR}/../..#buzz-relay" --no-link 2>&1)"
BUILD_STATUS=$?
set -e

CARGO_HASH="$(printf '%s\n' "${BUILD_OUTPUT}" | sed -n 's/.*got:[[:space:]]*\(sha256-[A-Za-z0-9+/=]*\).*/\1/p' | tail -n1)"
if [[ -z "${CARGO_HASH}" ]]; then
	printf '%s\n' "${BUILD_OUTPUT}" >&2
	echo "Failed to determine cargoHash (build status ${BUILD_STATUS})" >&2
	exit 1
fi

sed -i "s|cargoHash = lib.fakeHash;|cargoHash = \"${CARGO_HASH}\";|" "${DEFAULT_NIX}"

echo "Updated buzz-relay ${CURRENT_VERSION} -> ${VERSION}"
echo "Run: nix build .#buzz-relay"
