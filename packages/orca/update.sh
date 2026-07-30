#!/usr/bin/env bash
set -euo pipefail

# Usage:
#   ./update.sh         # Update to latest stable version
#   ./update.sh 1.4.161 # Update to specific version

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEFAULT_NIX="${SCRIPT_DIR}/default.nix"
ASSET_NAME="orca-linux.AppImage"

if [[ -n "${1:-}" ]]; then
	VERSION="${1#v}"
	echo "==> Fetching Orca release v${VERSION} from GitHub..."
	RELEASE_JSON="$(gh api "repos/stablyai/orca/releases/tags/v${VERSION}")"
else
	echo "==> Fetching latest stable Orca version from GitHub..."
	RELEASE_JSON="$(gh api repos/stablyai/orca/releases/latest)"
	VERSION="$(jq -r '.tag_name | ltrimstr("v")' <<<"${RELEASE_JSON}")"
fi

echo "    Latest version: ${VERSION}"

CURRENT_VERSION="$(grep 'version = "' "${DEFAULT_NIX}" | head -1 | sed 's/.*version = "\([^"]*\)".*/\1/')"
if [[ "${VERSION}" == "${CURRENT_VERSION}" ]]; then
	echo "==> Already at version ${VERSION}, nothing to do"
	exit 0
fi

echo "==> Updating from ${CURRENT_VERSION} to ${VERSION}"

DIGEST="$(jq -r --arg asset_name "${ASSET_NAME}" '.assets[] | select(.name == $asset_name) | .digest' <<<"${RELEASE_JSON}")"
if [[ -z "${DIGEST}" || "${DIGEST}" == "null" ]]; then
	echo "ERROR: Could not find digest for asset ${ASSET_NAME}" >&2
	exit 1
fi

HASH="$(nix hash convert --to sri --hash-algo sha256 "${DIGEST#sha256:}")"
echo "    Hash: ${HASH}"

echo "==> Updating default.nix..."
VERSION="${VERSION}" HASH="${HASH}" perl -0pi -e '
  s#(pname = "orca-ide";\n  version = ")[^"]+(";)#$1$ENV{VERSION}$2#;
  s#(src = fetchurl \{\n(?:(?!  \};).*\n)*?    hash = ")[^"]+(";\n  \};)#$1$ENV{HASH}$2#s;
' "${DEFAULT_NIX}"

if ! grep -Fq "version = \"${VERSION}\";" "${DEFAULT_NIX}"; then
	echo "ERROR: version was not updated in ${DEFAULT_NIX}" >&2
	exit 1
fi
if ! grep -Fq "hash = \"${HASH}\";" "${DEFAULT_NIX}"; then
	echo "ERROR: hash was not updated in ${DEFAULT_NIX}" >&2
	exit 1
fi

echo "==> Done! Updated Orca to version ${VERSION}"
echo "Next step: nix build '.#orca'"
