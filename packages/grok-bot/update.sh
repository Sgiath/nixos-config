#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEFAULT_NIX="${SCRIPT_DIR}/default.nix"
UPDATE_URL="https://api2.cursor.sh/updates/api/update/darwin-arm64/sand/0.0.0/nix-package-updater/stable"

echo "==> Fetching latest Grok Bot stable release metadata..."
RELEASE_JSON="$(curl -fsSL "${UPDATE_URL}")"

VERSION="$(jq -er '.name | select(test("^[0-9]+\\.[0-9]+\\.[0-9]+$"))' <<<"${RELEASE_JSON}")"
if [[ -n "${1:-}" && "${1#v}" != "${VERSION}" ]]; then
	echo "ERROR: requested version ${1#v} is not the current stable release (${VERSION})" >&2
	exit 1
fi
RELEASE_ID="$(
	jq -er '.url | capture("/sand/stable/(?<release>[0-9a-f]+)/").release' <<<"${RELEASE_JSON}"
)"
URL="https://downloads.cursor.com/sand/stable/${RELEASE_ID}/linux/x64/Grok_Bot_${VERSION}.deb"

echo "    Latest version: ${VERSION}"

CURRENT_VERSION="$(grep 'version = "' "${DEFAULT_NIX}" | head -1 | sed 's/.*version = "\([^"]*\)".*/\1/')"
if [[ "${VERSION}" == "${CURRENT_VERSION}" ]]; then
	echo "==> Already at version ${VERSION}, nothing to do"
	exit 0
fi

echo "==> Updating from ${CURRENT_VERSION} to ${VERSION}"
echo "==> Prefetching Linux x64 package..."
PREFETCH_JSON="$(nix store prefetch-file --json "${URL}")"
HASH="$(jq -er '.hash' <<<"${PREFETCH_JSON}")"
STORE_PATH="$(jq -er '.storePath' <<<"${PREFETCH_JSON}")"

PACKAGE="$(dpkg-deb --field "${STORE_PATH}" Package)"
PACKAGE_VERSION="$(dpkg-deb --field "${STORE_PATH}" Version)"
ARCHITECTURE="$(dpkg-deb --field "${STORE_PATH}" Architecture)"

if [[ "${PACKAGE}" != "sand" || "${PACKAGE_VERSION}" != "${VERSION}" || "${ARCHITECTURE}" != "amd64" ]]; then
	echo "ERROR: downloaded package metadata did not match the requested Grok Bot release" >&2
	echo "       Package=${PACKAGE} Version=${PACKAGE_VERSION} Architecture=${ARCHITECTURE}" >&2
	exit 1
fi

echo "    Release ID: ${RELEASE_ID}"
echo "    Hash: ${HASH}"
echo "==> Updating default.nix..."

VERSION="${VERSION}" RELEASE_ID="${RELEASE_ID}" HASH="${HASH}" perl -0pi -e '
  s/(version = ")[^"]+(";)/$1$ENV{VERSION}$2/;
  s/(releaseId = ")[^"]+(";)/$1$ENV{RELEASE_ID}$2/;
  s/(hash = ")[^"]+(";)/$1$ENV{HASH}$2/;
' "${DEFAULT_NIX}"

if ! grep -Fq "version = \"${VERSION}\";" "${DEFAULT_NIX}"; then
	echo "ERROR: version was not updated in ${DEFAULT_NIX}" >&2
	exit 1
fi
if ! grep -Fq "releaseId = \"${RELEASE_ID}\";" "${DEFAULT_NIX}"; then
	echo "ERROR: release ID was not updated in ${DEFAULT_NIX}" >&2
	exit 1
fi
if ! grep -Fq "hash = \"${HASH}\";" "${DEFAULT_NIX}"; then
	echo "ERROR: hash was not updated in ${DEFAULT_NIX}" >&2
	exit 1
fi

echo "==> Done! Updated Grok Bot to version ${VERSION}"
echo "Next step: nix build '.#grok-bot'"
