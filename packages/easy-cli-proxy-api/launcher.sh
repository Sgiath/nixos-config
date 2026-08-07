#!@bash@
set -euo pipefail

data_home="${XDG_DATA_HOME:-$HOME/.local/share}"
install_dir="$data_home/easy-cli-proxy-api/@version@"
launcher_path="$(@coreutils@/bin/readlink -f "${BASH_SOURCE[0]}")"
app_seed="$(@coreutils@/bin/dirname "$launcher_path")/../libexec/easy-cli-proxy-api"
seed_marker="$install_dir/.nix-seed"

if [[ ! -x "$install_dir/EasyCLIProxyAPI" ]]; then
	staging_dir="$install_dir.tmp.$$"
	@coreutils@/bin/rm -rf "$staging_dir"
	@coreutils@/bin/mkdir -p "$staging_dir"
	@coreutils@/bin/cp -R "$app_seed/." "$staging_dir/"
	@coreutils@/bin/chmod -R u+w "$staging_dir"
	printf '%s\n' "$app_seed" >"$staging_dir/.nix-seed"
	@coreutils@/bin/rm -rf "$install_dir"
	@coreutils@/bin/mv "$staging_dir" "$install_dir"
elif [[ ! -f "$seed_marker" ]] || [[ "$(@coreutils@/bin/cat "$seed_marker")" != "$app_seed" ]]; then
	@coreutils@/bin/rm -f "$install_dir/.EasyCLIProxyAPI-wrapped"
	@coreutils@/bin/cp -R "$app_seed/." "$install_dir/"
	@coreutils@/bin/chmod -R u+w "$install_dir"
	printf '%s\n' "$app_seed" >"$seed_marker"
fi

exec "$install_dir/EasyCLIProxyAPI" "$@"
