#!/usr/bin/env python3
"""Smoke-test built Hermes activation without exposing host state or credentials.

Usage: python3 tests/check_hermes_setup.py SYSTEM_CLOSURE [BWRAP]
Requires Linux, sudo access (unless root), bubblewrap, and a built Vesta closure.
All writable sandbox paths are tmpfs; only /nix/store and synthetic fixtures are
bound read-only. Neither services nor the complete activation script are run.
"""

import argparse
import os
from pathlib import Path
import re
import shlex
import shutil
import subprocess
import tempfile


# Valid dotenv text with shell metacharacters that must remain literal.
FAKE_ENV = (
    "OPENROUTER_API_KEY=hermes-smoke-not-a-real-key\n"
    "HERMES_SMOKE_LITERAL='spaces $HOME $(touch /run/expanded-secret) ; quotes'\n"
)
FAKE_BIRD_ENV = "AUTH_TOKEN=hermes-smoke-fake-token\nCT0=hermes-smoke-fake-ct0\n"

DRIVER = r'''
set -euo pipefail
umask 022
trap 'printf "Hermes smoke failed at driver line %s\n" "$LINENO" >&2' ERR
fail() { printf '%s\n' "$1" >&2; exit 1; }
state=/var/lib/hermes-agent
ready=/run/hermes-agent-setup.ready
mkdir -p /var/lib /home/sgiath /run/secrets
cp /fixture/passwd /etc/passwd
cp /fixture/group /etc/group
cp /fixture/nsswitch.conf /etc/nsswitch.conf
cp /fixture/hermes-env /run/secrets/hermes-env
cp /fixture/hermes-bird-env /run/secrets/hermes-bird-env
chown 2000:2000 /run/secrets/hermes-env /run/secrets/hermes-bird-env
chmod 0400 /run/secrets/hermes-env /run/secrets/hermes-bird-env
[ ! -e /home/sgiath/hermes ] || fail 'Legacy source unexpectedly exists'

run_setup() {
    "$ACTIVATION_BASH" /fixture/setup.sh > /run/setup.log 2>&1
}
check_success() {
    [ -f "$ready" ] || fail 'Setup omitted readiness stamp'
    [ "$(stat -c '%u:%g' "$ready")" = 0:0 ] || fail 'Readiness is not root-owned'
    [ -d "$state/.hermes" ] || fail 'Setup omitted .hermes directory'
    [ -s "$state/.hermes/config.yaml" ] || fail 'Setup omitted managed configuration'
    [ -f "$state/.hermes/.env" ] || fail 'Setup omitted environment file'
    for file in "$state" "$state/.hermes" "$state/.hermes/config.yaml" "$state/.hermes/.env" "$state/.local/bin"; do
        [ "$(stat -c '%u:%g' "$file")" = 2000:2000 ] || fail "Wrong Hermes ownership: $file"
    done
    while IFS= read -r line; do
        grep -Fqx -- "$line" "$state/.hermes/.env" || fail 'Synthetic environment value was lost or expanded'
    done < /fixture/hermes-env
    [ ! -e /run/expanded-secret ] || fail 'Synthetic environment was executed'
    for name in bird bird-vesta; do
        link="$state/.local/bin/$name"
        [ -L "$link" ] && [ -x "$link" ] || fail "Missing executable link: $name"
        [ "$(stat -c '%u:%g' "$link")" = 2000:2000 ] || fail "Wrong link ownership: $name"
        case "$(readlink "$link")" in
            /nix/store/*) ;;
            *) fail "Link does not target the store: $name" ;;
        esac
    done
    [ ! -e /home/sgiath/hermes ] || fail 'Setup created a legacy source'
    cmp /fixture/hermes-env /run/secrets/hermes-env || fail 'Setup changed synthetic SOPS environment'
    cmp /fixture/hermes-bird-env /run/secrets/hermes-bird-env || fail 'Setup changed synthetic Bird environment'
}

if ! run_setup; then
    cat /run/setup.log >&2
    fail 'Fresh Hermes setup failed; upstream managed-file setup must run as hermes'
fi
check_success
# A second successful activation must retain user-owned data as well as secrets.
printf 'synthetic user state\n' > "$state/.hermes/smoke-preserved"
chown 2000:2000 "$state/.hermes/smoke-preserved"
if ! run_setup; then
    cat /run/setup.log >&2
    fail 'Repeated Hermes setup failed'
fi
check_success
[ "$(cat "$state/.hermes/smoke-preserved")" = 'synthetic user state' ] || fail 'Repeated setup changed user data'
printf 'Fresh and repeated setup passed with Hermes-owned managed files\n'

# Preserve the successful tree rather than deleting it to construct the attack.
mv "$state/.hermes" "$state/.hermes-preserved"
mkdir /run/victim
printf 'root-owned sentinel\n' > /run/victim/sentinel
printf 'root-owned config sentinel\n' > /run/victim/config.yaml
printf 'root-owned environment sentinel\n' > /run/victim/.env
chmod 0755 /run/victim
chmod 0644 /run/victim/sentinel /run/victim/config.yaml /run/victim/.env
ln -s /run/victim "$state/.hermes"
chown -h 2000:2000 "$state/.hermes"
# Compare entries, ownership, modes, sizes, timestamps, link targets and bytes.
# Exclude atime because reading for comparison can legitimately update it.
snapshot_victim() {
    find /run/victim -printf '%P %y %U %G %m %s %T@ %C@ %l\n' | LC_ALL=C sort
    find /run/victim -type f -exec sha256sum -- {} + | LC_ALL=C sort
}
snapshot_victim > /run/victim-before
if run_setup; then
    fail 'Hermes setup unexpectedly accepted a root-owned symlink target'
fi
[ ! -e "$ready" ] || fail 'Failed setup retained readiness stamp'
snapshot_victim > /run/victim-after
cmp -s /run/victim-before /run/victim-after || fail 'Setup changed victim contents or metadata'
[ -L "$state/.hermes" ] || fail 'Setup replaced the adversarial symlink'
[ "$(cat "$state/.hermes-preserved/smoke-preserved")" = 'synthetic user state' ] || fail 'Failure changed preserved user state'
cmp /fixture/hermes-env /run/secrets/hermes-env || fail 'Failure changed synthetic SOPS environment'
cmp /fixture/hermes-bird-env /run/secrets/hermes-bird-env || fail 'Failure changed synthetic Bird environment'
[ ! -e /home/sgiath/hermes ] || fail 'Failure created a legacy source'
printf 'Symlink attack rejected; victim unchanged and readiness removed\n'
'''


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("system_closure", type=Path)
    parser.add_argument("bwrap", nargs="?", default="bwrap")
    args = parser.parse_args()
    system = args.system_closure.resolve(strict=True)
    if not system.is_relative_to("/nix/store"):
        parser.error("SYSTEM_CLOSURE must resolve beneath /nix/store")
    activation = (system / "activate").read_text()
    interpreter = shlex.split(activation.splitlines()[0].removeprefix("#!"))
    if len(interpreter) != 1 or not interpreter[0].startswith("/nix/store/"):
        parser.error("activate must use one absolute Nix store interpreter")
    header = "#### Activation script snippet hermes-agent-setup:"
    sections = activation.split(header)
    if len(sections) != 2:
        parser.error("activate must contain exactly one hermes-agent-setup section")
    snippet = re.split(r"^#### Activation script snippet ", sections[1], maxsplit=1, flags=re.M)[0]
    # Nix activation records ERR rather than aborting its parent shell. Do not
    # source this inside an if/! condition, which disables nested Bash errexit.
    setup = (
        "_status=0\n_localstatus=0\ntrap '_localstatus=$?' ERR\n"
        + snippet
        + '\nexit "$(( _status != 0 || _localstatus != 0 ))"\n'
    )
    bwrap = shutil.which(args.bwrap)
    if bwrap is None:
        parser.error("bubblewrap executable not found")
    bwrap = str(Path(bwrap).resolve(strict=True))
    with tempfile.TemporaryDirectory(prefix="hermes-setup-smoke-") as temporary:
        fixture = Path(temporary)
        files = {
            "setup.sh": setup,
            "driver.sh": DRIVER,
            "hermes-env": FAKE_ENV,
            "hermes-bird-env": FAKE_BIRD_ENV,
            "passwd": "root:x:0:0:root:/root:/bin/sh\nhermes:x:2000:2000:Hermes:/var/lib/hermes-agent:/bin/sh\n",
            "group": "root:x:0:\nhermes:x:2000:\n",
            "nsswitch.conf": "passwd: files\ngroup: files\nshadow: files\nhosts: files\n",
        }
        for name, content in files.items():
            (fixture / name).write_text(content)
        # No writable host bind exists, so namespace-root never leaves files
        # requiring privileged cleanup. A fresh namespace owns every run.
        command = ([] if os.geteuid() == 0 else ["sudo", "--"]) + [
            bwrap, "--unshare-pid", "--unshare-net", "--unshare-ipc", "--unshare-uts",
            "--die-with-parent", "--new-session", "--clearenv",
            "--cap-add", "CAP_CHOWN", "--cap-add", "CAP_DAC_OVERRIDE",
            "--cap-add", "CAP_FOWNER", "--cap-add", "CAP_SETUID", "--cap-add", "CAP_SETGID",
            "--dir", "/nix", "--chmod", "0755", "/nix",
            "--ro-bind", "/nix/store", "/nix/store",
            "--proc", "/proc", "--dev", "/dev",
            "--tmpfs", "/etc", "--tmpfs", "/var", "--tmpfs", "/run",
            "--tmpfs", "/home", "--tmpfs", "/tmp",
            "--chmod", "0755", "/etc", "--chmod", "0755", "/var",
            "--chmod", "0755", "/run", "--chmod", "0755", "/home",
            "--chmod", "1777", "/tmp",
            "--ro-bind", str(fixture), "/fixture", "--chdir", "/",
            "--setenv", "PATH", str(system / "sw/bin"),
            "--setenv", "HOME", "/root",
            "--setenv", "ACTIVATION_BASH", interpreter[0],
            *interpreter, "/fixture/driver.sh",
        ]
        print("Running built Hermes activation in a disposable root namespace", flush=True)
        subprocess.run(command, check=True)
        for name, content in files.items():
            if (fixture / name).read_text() != content:
                raise RuntimeError("Read-only synthetic fixture changed: " + name)
    print("Hermes activation smoke passed; namespace discarded")


if __name__ == "__main__":
    main()
