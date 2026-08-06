#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEFAULT_NIX="${SCRIPT_DIR}/default.nix"
REPO="PrimeIntellect-ai/prime-agent"

if [[ -n "${1:-}" ]]; then
	VERSION="${1#v}"
	echo "==> Updating prime-agent to specified version ${VERSION}"
else
	echo "==> Fetching latest prime-agent version from GitHub..."
	LATEST_TAG=$(gh api "repos/${REPO}/releases/latest" --jq '.tag_name')
	VERSION="${LATEST_TAG#v}"
	echo "    Latest version: ${VERSION}"
fi

CURRENT_VERSION=$(grep 'version = "' "${DEFAULT_NIX}" | head -1 | sed 's/.*version = "\([^"]*\)".*/\1/')
if [[ "${VERSION}" == "${CURRENT_VERSION}" ]]; then
	echo "==> Already at version ${VERSION}, nothing to do"
	exit 0
fi

echo "==> Updating from ${CURRENT_VERSION} to ${VERSION}"

TMPDIR="$(mktemp -d)"
trap 'rm -rf "${TMPDIR}"' EXIT

echo "==> Computing source hash..."
SRC_JSON=$(nix run nixpkgs#nix-prefetch-github -- PrimeIntellect-ai prime-agent --rev "v${VERSION}" 2>/dev/null)
SRC_HASH=$(jq -r '.hash' <<<"${SRC_JSON}")
echo "    Source hash: ${SRC_HASH}"

echo "==> Computing npm dependency hash..."
curl -fsSL "https://raw.githubusercontent.com/${REPO}/v${VERSION}/package-lock.json" \
	-o "${TMPDIR}/package-lock.json"
NPM_DEPS_HASH=$(prefetch-npm-deps "${TMPDIR}/package-lock.json")
echo "    npm dependency hash: ${NPM_DEPS_HASH}"

sed -i "s/version = \"[0-9.]*\";/version = \"${VERSION}\";/" "${DEFAULT_NIX}"
sed -i "/fetchFromGitHub/,/};/ s|hash = \"sha256-[^\"]*\"|hash = \"${SRC_HASH}\"|" "${DEFAULT_NIX}"
sed -i "s|npmDepsHash = \"sha256-[^\"]*\"|npmDepsHash = \"${NPM_DEPS_HASH}\"|" "${DEFAULT_NIX}"

echo "==> Done! Build to verify: nix build '.#prime-agent'"
