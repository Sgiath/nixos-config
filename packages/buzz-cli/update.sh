#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEFAULT_NIX="${SCRIPT_DIR}/default.nix"
REPO="block/buzz"

if [[ -n "${1:-}" ]]; then
	VERSION="${1#v}"
	if [[ ! "${VERSION}" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
		echo "Failed to parse version: expected X.Y.Z or vX.Y.Z; got ${1}" >&2
		exit 1
	fi
	RELEASE_TAG="v${VERSION}"
else
	RELEASE_TAG="$(curl --fail --silent --show-error --location \
		-H "Accept: application/vnd.github+json" \
		"https://api.github.com/repos/${REPO}/tags?per_page=100" |
		jq -r '[.[].name | select(test("^v[0-9]+\\.[0-9]+\\.[0-9]+$"))][0] // empty')"
	if [[ -z "${RELEASE_TAG}" ]]; then
		echo "Failed to determine buzz-cli version: no generic vX.Y.Z tag found" >&2
		exit 1
	fi
	VERSION="${RELEASE_TAG#v}"
	if [[ ! "${VERSION}" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
		echo "Failed to parse generic buzz-cli tag: ${RELEASE_TAG}" >&2
		exit 1
	fi
fi

CURRENT_VERSION="$(sed -n 's/^[[:space:]]*version = "\([^"]*\)";.*/\1/p' "${DEFAULT_NIX}")"
if [[ "${CURRENT_VERSION}" == "${VERSION}" ]]; then
	echo "buzz-cli is already at ${VERSION}"
	exit 0
fi

SOURCE_URL="https://github.com/${REPO}/archive/refs/tags/${RELEASE_TAG}.tar.gz"
SOURCE_HASH="$(nix-prefetch-url --unpack "${SOURCE_URL}" 2>/dev/null | tail -n1)"
SOURCE_HASH="$(nix hash convert --hash-algo sha256 --to sri "${SOURCE_HASH}")"

sed -i \
	-e "s|version = \"${CURRENT_VERSION}\";|version = \"${VERSION}\";|" \
	-e "s|hash = \"sha256-[^\"]*\";|hash = \"${SOURCE_HASH}\";|" \
	-e 's|cargoHash = "sha256-[^"]*";|cargoHash = lib.fakeHash;|' \
	"${DEFAULT_NIX}"

set +e
BUILD_OUTPUT="$(nix build "${SCRIPT_DIR}/../..#buzz-cli" --no-link 2>&1)"
BUILD_STATUS=$?
set -e

CARGO_HASH="$(printf '%s\n' "${BUILD_OUTPUT}" | sed -n 's/.*got:[[:space:]]*\(sha256-[A-Za-z0-9+/=]*\).*/\1/p' | tail -n1)"
if [[ -z "${CARGO_HASH}" ]]; then
	printf '%s\n' "${BUILD_OUTPUT}" >&2
	echo "Failed to determine cargoHash (build status ${BUILD_STATUS})" >&2
	exit 1
fi

sed -i "s|cargoHash = lib.fakeHash;|cargoHash = \"${CARGO_HASH}\";|" "${DEFAULT_NIX}"

echo "Updated buzz-cli ${CURRENT_VERSION} -> ${VERSION}"
echo "Run: nix build .#buzz-cli"
