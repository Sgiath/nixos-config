#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEFAULT_NIX="${SCRIPT_DIR}/default.nix"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
FLAKE_REF="${REPO_ROOT}#ccflare"
REPO="snipeship/ccflare"

if [[ -n "${1:-}" ]]; then
	REV="${1}"
	COMMIT_JSON="$(curl --fail --silent --show-error --location \
		-H "Accept: application/vnd.github+json" \
		"https://api.github.com/repos/${REPO}/commits/${REV}")"
else
	COMMIT_JSON="$(curl --fail --silent --show-error --location \
		-H "Accept: application/vnd.github+json" \
		"https://api.github.com/repos/${REPO}/commits/main")"
	REV="$(jq -r '.sha // empty' <<<"${COMMIT_JSON}")"
fi

if [[ ! "${REV}" =~ ^[0-9a-f]{40}$ ]]; then
	echo "ERROR: GitHub returned an invalid commit: ${REV:-<empty>}" >&2
	exit 1
fi

CURRENT_REV="$(grep 'rev = "' "${DEFAULT_NIX}" | head -1 | sed 's/.*rev = "\([^"]*\)".*/\1/')"
if [[ "${REV}" == "${CURRENT_REV}" ]]; then
	echo "==> Already at commit ${REV}, nothing to do"
	exit 0
fi

COMMIT_DATE="$(jq -r '.commit.committer.date // empty' <<<"${COMMIT_JSON}")"
VERSION="0-unstable-$(date -u -d "${COMMIT_DATE}" +%Y-%m-%d)"

echo "==> Updating ccflare from ${CURRENT_REV} to ${REV}"

PREFETCH_JSON="$(nix-prefetch-github snipeship ccflare --rev "${REV}")"
SRC_HASH="$(jq -r '.hash // empty' <<<"${PREFETCH_JSON}")"
if [[ ! "${SRC_HASH}" =~ ^sha256- ]]; then
	echo "ERROR: Could not prefetch the source hash" >&2
	exit 1
fi

BACKUP="$(mktemp)"
cp "${DEFAULT_NIX}" "${BACKUP}"
KEEP_CHANGES=0
cleanup() {
	if [[ ${KEEP_CHANGES} -eq 0 ]]; then
		cp "${BACKUP}" "${DEFAULT_NIX}"
	fi
	rm -f "${BACKUP}"
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

VERSION="${VERSION}" REV="${REV}" SRC_HASH="${SRC_HASH}" perl -0pi -e '
  s/version = "[^"]+";/version = "$ENV{VERSION}";/;
  s/rev = "[^"]+";/rev = "$ENV{REV}";/;
  s/hash = "sha256-[^"]+";/hash = "$ENV{SRC_HASH}";/;
  s/outputHash = "sha256-[^"]+";/outputHash = lib.fakeHash;/;
' "${DEFAULT_NIX}"

echo "==> Computing the dependency tree hash..."
set +e
BUILD_OUTPUT="$(nix build "${FLAKE_REF}" 2>&1)"
BUILD_STATUS=$?
set -e

if [[ ${BUILD_STATUS} -eq 0 ]]; then
	echo "ERROR: Expected the fake dependency hash to fail" >&2
	exit 1
fi

TREE_HASH="$(sed -n 's/^[[:space:]]*got:[[:space:]]*\(sha256-[^[:space:]]*\).*$/\1/p' <<<"${BUILD_OUTPUT}" | tail -1)"
if [[ ! "${TREE_HASH}" =~ ^sha256- ]]; then
	printf '%s\n' "${BUILD_OUTPUT}" >&2
	echo "ERROR: Could not extract the dependency tree hash" >&2
	exit 1
fi

TREE_HASH="${TREE_HASH}" perl -0pi -e '
  s/outputHash = lib\.fakeHash;/outputHash = "$ENV{TREE_HASH}";/;
' "${DEFAULT_NIX}"

nixfmt "${DEFAULT_NIX}"
nix build "${FLAKE_REF}"

KEEP_CHANGES=1

echo "==> Updated ccflare to ${VERSION} (${REV})"
