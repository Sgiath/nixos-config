#!/usr/bin/env bash
set -euo pipefail

package_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
archive="${1:-$package_dir/delta-linux-x86_64.tar.gz}"
expected_name="delta-linux-x86_64.tar.gz"

if [[ ! -f "$archive" ]]; then
	echo "Missing Delta archive: $archive" >&2
	exit 1
fi

if [[ "$(basename "$archive")" != "$expected_name" ]]; then
	echo "Archive must be named $expected_name" >&2
	exit 1
fi

tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT

tar -xzf "$archive" -C "$tmp_dir" Delta/bin/delta Delta/lib
read -r program version < <(
	LD_LIBRARY_PATH="$tmp_dir/Delta/lib" "$tmp_dir/Delta/bin/delta" --version
)

if [[ "$program" != "delta" || ! "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+([.-][0-9A-Za-z.-]+)?$ ]]; then
	echo "Could not determine Delta version from archive" >&2
	exit 1
fi

hash="$(nix hash file --sri "$archive")"

cat >"$package_dir/source.nix" <<EOF
{
  version = "$version";
  hash = "$hash";
}
EOF

store_path="$(nix-store --add-fixed sha256 "$archive")"
printf 'Delta %s\nSource: %s\nStore: %s\n' "$version" "$hash" "$store_path"
