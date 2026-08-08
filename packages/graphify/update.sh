#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEFAULT_NIX="${SCRIPT_DIR}/default.nix"

if [[ -n "${1:-}" ]]; then
	VERSION="${1#v}"
else
	echo "==> Fetching latest Graphify release..."
	VERSION="$(curl -fsSL https://api.github.com/repos/Graphify-Labs/graphify/releases/latest | jq -r '.tag_name | sub("^v"; "")')"
fi

CURRENT_VERSION="$(sed -n 's/.*version = "\([^"]*\)";.*/\1/p' "${DEFAULT_NIX}" | head -1)"
if [[ "${VERSION}" == "${CURRENT_VERSION}" ]]; then
	echo "==> Already at version ${VERSION}, nothing to do"
	exit 0
fi

echo "==> Updating Graphify from ${CURRENT_VERSION} to ${VERSION}"
HASH_B32="$(nix-prefetch-url --unpack "https://github.com/Graphify-Labs/graphify/archive/refs/tags/v${VERSION}.tar.gz" 2>/dev/null)"
HASH_SRI="$(nix hash convert --to sri --hash-algo sha256 "${HASH_B32}")"

VERSION="${VERSION}" HASH_SRI="${HASH_SRI}" perl -0pi -e '
  s/version = "[^"]+";/version = "$ENV{VERSION}";/;
  s/hash = "sha256-[^"]+";/hash = "$ENV{HASH_SRI}";/;
' "${DEFAULT_NIX}"

echo "==> Updated Graphify to ${VERSION}"
echo "Next step: nix build '.#graphify'"
