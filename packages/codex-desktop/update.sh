#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEFAULT_NIX="${SCRIPT_DIR}/default.nix"
KEYRING="${SCRIPT_DIR}/repository-key.asc"
EXPECTED_FINGERPRINT="3BFA0E4AE8B8CC16A2D9BA684A3B4A566C4660E4"
INRELEASE_URL="https://persistent.oaistatic.com/codex-app-prod/linux/deb/dists/stable/InRelease"
PACKAGES_URL="https://persistent.oaistatic.com/codex-app-prod/linux/deb/dists/stable/main/binary-amd64/Packages"
REPOSITORY_URL="https://persistent.oaistatic.com/codex-app-prod/linux/deb"
PACKAGES_PATH="main/binary-amd64/Packages"

TMPDIR="$(mktemp -d)"
trap 'rm -rf "${TMPDIR}"' EXIT

KEY_FINGERPRINT="$(gpg --show-keys --with-colons "${KEYRING}" | awk -F: '$1 == "fpr" { print $10; exit }')"
if [[ "${KEY_FINGERPRINT}" != "${EXPECTED_FINGERPRINT}" ]]; then
	echo "ERROR: unexpected Codex repository key fingerprint ${KEY_FINGERPRINT}" >&2
	exit 1
fi

echo "==> Fetching Codex Linux repository metadata..."
gpg --batch --quiet --no-default-keyring --keyring "${TMPDIR}/repository-key.gpg" --import "${KEYRING}"
curl -fsSL -o "${TMPDIR}/InRelease" "${INRELEASE_URL}"
gpgv --keyring "${TMPDIR}/repository-key.gpg" "${TMPDIR}/InRelease"
curl -fsSL -o "${TMPDIR}/Packages" "${PACKAGES_URL}"

read -r EXPECTED_PACKAGES_SHA256 EXPECTED_PACKAGES_SIZE < <(
	awk -v path="${PACKAGES_PATH}" '
    /^SHA256:/ { in_sha256 = 1; next }
    in_sha256 && $3 == path { print $1, $2; exit }
    in_sha256 && /^[^[:space:]]/ { exit }
  ' "${TMPDIR}/InRelease"
)
ACTUAL_PACKAGES_SHA256="$(sha256sum "${TMPDIR}/Packages" | awk '{ print $1 }')"
ACTUAL_PACKAGES_SIZE="$(stat -c %s "${TMPDIR}/Packages")"
if [[ "${ACTUAL_PACKAGES_SHA256}" != "${EXPECTED_PACKAGES_SHA256}" || "${ACTUAL_PACKAGES_SIZE}" != "${EXPECTED_PACKAGES_SIZE}" ]]; then
	echo "ERROR: Packages index does not match the signed InRelease metadata" >&2
	exit 1
fi

mapfile -t PACKAGE_RECORDS < <(
	awk -v RS='' -F '\n' '
    {
      package = architecture = version = filename = sha256 = ""
      for (i = 1; i <= NF; i++) {
        if ($i ~ /^Package: /) package = substr($i, 10)
        if ($i ~ /^Architecture: /) architecture = substr($i, 15)
        if ($i ~ /^Version: /) version = substr($i, 10)
        if ($i ~ /^Filename: /) filename = substr($i, 11)
        if ($i ~ /^SHA256: /) sha256 = substr($i, 9)
      }
      if (package == "chatgpt" && architecture == "amd64") {
        print version "\t" filename "\t" sha256
      }
    }
  ' "${TMPDIR}/Packages"
)
if [[ "${#PACKAGE_RECORDS[@]}" -ne 1 ]]; then
	echo "ERROR: expected one amd64 chatgpt package, found ${#PACKAGE_RECORDS[@]}" >&2
	exit 1
fi

IFS=$'\t' read -r VERSION FILENAME SHA256 <<<"${PACKAGE_RECORDS[0]}"

if [[ -z "${VERSION}" || ! "${FILENAME}" =~ ^pool/main/c/chatgpt/chatgpt_[0-9.]+_amd64\.deb$ || ! "${SHA256}" =~ ^[0-9a-f]{64}$ ]]; then
	echo "ERROR: incomplete chatgpt package metadata from ${PACKAGES_URL}" >&2
	exit 1
fi

URL="${REPOSITORY_URL}/${FILENAME}"
HASH_SRI="$(nix hash convert --to sri --hash-algo sha256 "${SHA256}")"

echo "    Latest version: ${VERSION}"
echo "    Artifact: ${URL}"

CURRENT_VERSION="$(grep 'version = "' "${DEFAULT_NIX}" | head -1 | sed 's/.*version = "\([^"]*\)".*/\1/')"
CURRENT_URL="$(grep 'url = "' "${DEFAULT_NIX}" | head -1 | sed 's/.*url = "\([^"]*\)".*/\1/')"
CURRENT_HASH="$(grep 'hash = "' "${DEFAULT_NIX}" | head -1 | sed 's/.*hash = "\([^"]*\)".*/\1/')"
if [[ "${VERSION}" == "${CURRENT_VERSION}" && "${URL}" == "${CURRENT_URL}" && "${HASH_SRI}" == "${CURRENT_HASH}" ]]; then
	echo "==> Already at version ${VERSION}, nothing to do"
	exit 0
fi

echo "==> Updating from ${CURRENT_VERSION} to ${VERSION}"
echo "    Hash: ${HASH_SRI}"

cp "${DEFAULT_NIX}" "${TMPDIR}/default.nix"

replace_exactly_once() {
	local old="$1"
	local new="$2"
	local file="$3"

	OLD="${old}" NEW="${new}" perl -0pi -e '
    $old = quotemeta($ENV{OLD});
    $count = s/$old/$ENV{NEW}/g;
    die "expected one replacement, made " . ($count || 0) . "\n" unless $count == 1;
  ' "${file}"
}

replace_exactly_once "version = \"${CURRENT_VERSION}\";" "version = \"${VERSION}\";" "${TMPDIR}/default.nix"
replace_exactly_once "url = \"${CURRENT_URL}\";" "url = \"${URL}\";" "${TMPDIR}/default.nix"
replace_exactly_once "hash = \"${CURRENT_HASH}\";" "hash = \"${HASH_SRI}\";" "${TMPDIR}/default.nix"

grep -Fq "version = \"${VERSION}\";" "${TMPDIR}/default.nix"
grep -Fq "url = \"${URL}\";" "${TMPDIR}/default.nix"
grep -Fq "hash = \"${HASH_SRI}\";" "${TMPDIR}/default.nix"
mv "${TMPDIR}/default.nix" "${DEFAULT_NIX}"

echo "==> Done! Updated Codex Desktop to ${VERSION}"
echo "Next step: nix build '.#codex-desktop'"
