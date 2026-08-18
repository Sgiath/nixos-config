#!/usr/bin/env bash
set -euo pipefail

# Usage:
#   ./update.sh            # Update to latest npm version
#   ./update.sh 0.1.0-rc.7 # Update to a specific npm version

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEFAULT_NIX="${SCRIPT_DIR}/default.nix"
LOCKFILE="${SCRIPT_DIR}/package-lock.json"
NPM_NAME="@deepseek-ai/dsh"

if [[ -n "${1:-}" ]]; then
	VERSION="${1#v}"
	VERSION="${VERSION#dsh-v}"
	echo "==> Updating dsh to specified version ${VERSION}"
else
	echo "==> Fetching latest dsh version from npm..."
	VERSION="$(npm view "${NPM_NAME}" version)"
	echo "    Latest version: ${VERSION}"
fi

CURRENT_VERSION="$(grep 'version = "' "${DEFAULT_NIX}" | head -1 | sed 's/.*version = "\([^"]*\)".*/\1/')"
if [[ "${VERSION}" == "${CURRENT_VERSION}" ]]; then
	echo "==> Already at version ${VERSION}, nothing to do"
	exit 0
fi

echo "==> Updating from ${CURRENT_VERSION} to ${VERSION}"

TARBALL_URL="https://registry.npmjs.org/${NPM_NAME}/-/dsh-${VERSION}.tgz"

echo "==> Computing source hash..."
SRC_HASH_B32="$(nix-prefetch-url "${TARBALL_URL}")"
SRC_HASH="$(nix hash convert --to sri --hash-algo sha256 "${SRC_HASH_B32}")"
echo "    Source hash: ${SRC_HASH}"

TMPDIR="$(mktemp -d)"
trap 'rm -rf "${TMPDIR}"' EXIT

echo "==> Generating package-lock.json..."
TARBALL="${TMPDIR}/dsh.tgz"
curl -fsSL "${TARBALL_URL}" -o "${TARBALL}"
mkdir -p "${TMPDIR}/src"
tar -xzf "${TARBALL}" -C "${TMPDIR}/src" --strip-components=1
(
	cd "${TMPDIR}/src"
	npm install --package-lock-only --ignore-scripts
)
cp "${TMPDIR}/src/package-lock.json" "${LOCKFILE}"

echo "==> Computing npm dependencies hash..."
NPM_DEPS_HASH="$(prefetch-npm-deps "${LOCKFILE}")"
echo "    npm deps hash: ${NPM_DEPS_HASH}"

echo "==> Updating default.nix..."
SRC_HASH="${SRC_HASH}" NPM_DEPS_HASH="${NPM_DEPS_HASH}" VERSION="${VERSION}" perl -0pi -e '
  s/version = "[^"]+";/version = "$ENV{VERSION}";/;
  s#(url = "https://registry.npmjs.org/@deepseek-ai/dsh/-/dsh-\$\{version\}\.tgz";\n    hash = ")[^"]+(";)#$1$ENV{SRC_HASH}$2#;
  s/npmDepsHash = "[^"]+";/npmDepsHash = "$ENV{NPM_DEPS_HASH}";/;
' "${DEFAULT_NIX}"

if ! grep -Fq "version = \"${VERSION}\";" "${DEFAULT_NIX}"; then
	echo "ERROR: version was not updated in ${DEFAULT_NIX}" >&2
	exit 1
fi
if ! grep -Fq "hash = \"${SRC_HASH}\";" "${DEFAULT_NIX}"; then
	echo "ERROR: source hash was not updated in ${DEFAULT_NIX}" >&2
	exit 1
fi
if ! grep -Fq "npmDepsHash = \"${NPM_DEPS_HASH}\";" "${DEFAULT_NIX}"; then
	echo "ERROR: npm deps hash was not updated in ${DEFAULT_NIX}" >&2
	exit 1
fi

echo "==> Done! Updated dsh to version ${VERSION}"
echo ""
echo "Next steps:"
echo "  1. Test the build: nix build '.#dsh'"
echo "  2. Commit changes"
