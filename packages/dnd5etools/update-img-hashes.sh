#!/usr/bin/env bash
set -euo pipefail

# Usage:
#   ./update-img-hashes.sh 2.10.0
#
# Requires:
#   - gh
#   - nix (for `nix hash file`)
#
# Notes:
#   - Outputs a complete `imgHashes = [ ... ];` block to imgHashes.nix.
#   - You can change NAMES if the set of parts changes.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEFAULT_NIX="${SCRIPT_DIR}/default.nix"
OUTPUT_FILE="${SCRIPT_DIR}/imgHashes.nix"

VERSION="${1:-}"
if [[ -z "${VERSION}" ]]; then
  echo "Usage: $0 <version>    e.g. $0 2.12.0" >&2
  exit 1
fi

NAMES=(z01 z02 z03 z04 z05 z06 z07 z08 z09 z10 z11 z12 zip)

# Create temp directory for results
TMPDIR="$(mktemp -d)"
trap 'rm -rf "${TMPDIR}"' EXIT

echo "==> Downloading 5etools image assets for v${VERSION}..."
gh release download "v${VERSION}" --repo 5etools-mirror-2/5etools-img --dir "${TMPDIR}"

for name in "${NAMES[@]}"; do
  file="${TMPDIR}/img-v${VERSION}.${name}"
  if [[ ! -f "${file}" ]]; then
    echo "  # WARNING: missing ${name} in release v${VERSION}" >&2
    continue
  fi

  sri_hash="$(nix hash file --sri --type sha256 "${file}")"

  cat >"${TMPDIR}/${name}.nix" <<EOF
  {
    name = "${name}";
    hash = "${sri_hash}";
  }
EOF
done

# Combine results into output file
echo "imgHashes = [" >"${OUTPUT_FILE}"
for name in "${NAMES[@]}"; do
  [[ -f "${TMPDIR}/${name}.nix" ]] && cat "${TMPDIR}/${name}.nix" >>"${OUTPUT_FILE}"
done
echo "];" >>"${OUTPUT_FILE}"

sed -i "/pname = \"5etools-img-\${v.name}\";/,/inherit (v) hash;/ s/version = \"[0-9.]*\";/version = \"${VERSION}\";/" "${DEFAULT_NIX}"
