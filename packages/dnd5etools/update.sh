#!/usr/bin/env bash
set -euo pipefail

# Usage:
#   ./update.sh 2.23.0
#
# Updates version, source hash, and npm dependencies hash in default.nix.
# Does NOT update image hashes - use update-img-hashes.sh for that.

VERSION="${1:-}"
if [[ -z "${VERSION}" ]]; then
  echo "Usage: $0 <version>    e.g. $0 2.23.0" >&2
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEFAULT_NIX="${SCRIPT_DIR}/default.nix"
TMPDIR="$(mktemp -d)"
trap 'rm -rf "${TMPDIR}"' EXIT

echo "==> Updating 5etools to version ${VERSION}"

# Step 1: Compute source hash
echo "==> Computing source hash..."
SRC_URL="https://github.com/5etools-mirror-3/5etools-src/releases/download/v${VERSION}/5etools-v${VERSION}.zip"
SRC_HASH=$(nix-prefetch-url --unpack "${SRC_URL}" 2>/dev/null)
SRC_SRI=$(nix hash convert --hash-algo sha256 --to sri "${SRC_HASH}")
echo "    Source hash: ${SRC_SRI}"

# Step 2: Download source and extract package-lock.json
echo "==> Downloading source for package-lock.json..."
curl -sL "${SRC_URL}" -o "${TMPDIR}/src.zip"
unzip -q "${TMPDIR}/src.zip" "package-lock.json" -d "${TMPDIR}" 2>/dev/null || \
  unzip -q "${TMPDIR}/src.zip" "*/package-lock.json" -d "${TMPDIR}"

LOCKFILE=$(find "${TMPDIR}" -name "package-lock.json" | head -1)
if [[ -z "${LOCKFILE}" ]]; then
  echo "ERROR: Could not find package-lock.json in source" >&2
  exit 1
fi

# Step 3: Compute npm deps hash
echo "==> Computing npm dependencies hash..."
NPM_DEPS_HASH=$(nix run nixpkgs#prefetch-npm-deps -- "${LOCKFILE}" 2>&1)
echo "    npm deps hash: ${NPM_DEPS_HASH}"

# Step 4: Update default.nix
echo "==> Updating default.nix..."

# Update version
sed -i "s/version = \"[0-9.]*\";/version = \"${VERSION}\";/" "${DEFAULT_NIX}"

# Update source hash (the one after url = ...5etools-src...)
sed -i "/5etools-src/,/hash = \"sha256-/ s|hash = \"sha256-[^\"]*\"|hash = \"${SRC_SRI}\"|" "${DEFAULT_NIX}"

# Update npmDepsHash
sed -i "s|npmDepsHash = \"sha256-[^\"]*\"|npmDepsHash = \"${NPM_DEPS_HASH}\"|" "${DEFAULT_NIX}"

echo "==> Done! Updated default.nix to version ${VERSION}"
echo ""
echo "Next steps:"
echo "  1. Test the build: nix build '.#dnd5etools'"
echo "  2. If images changed, run: ./update-img-hashes.sh ${VERSION}"
echo "  3. Commit changes"
