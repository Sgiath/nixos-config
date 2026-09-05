#!/usr/bin/env python3
"""Run built credential generators in private filesystem/network namespaces.

Usage: python3 tests/check_service_credentials.py VESTA_SYSTEM [BWRAP]
Only synthetic credentials are used. No service or host /run path is modified.
"""

import json
from pathlib import Path
import shlex
import subprocess
import sys
import tempfile


def values(unit, key):
    return [line.split("=", 1)[1] for line in unit.splitlines() if line.startswith(key + "=")]


def main():
    system = Path(sys.argv[1])
    bwrap = sys.argv[2] if len(sys.argv) > 2 else "bwrap"
    cases = [
        ("livekit", "ExecStartPre", "turn-secret", "livekit", "config.json"),
        ("searx-init", "ExecStart", "secret-key", "searx", "settings.yml"),
        ("transmission", "ExecStartPre", "password", "transmission", "credentials.json"),
    ]
    secret = "quotes ' \" and \\ slash; $HOME $(false)\nsecond line\n"
    for service, directive, credential_name, runtime_name, filename in cases:
        unit = (system / "etc/systemd/system" / (service + ".service")).read_text()
        command = shlex.split(values(unit, directive)[0].lstrip("+"))
        environment = {}
        for assignment in values(unit, "Environment"):
            for item in shlex.split(assignment):
                key, value = item.split("=", 1)
                environment[key] = value
        with tempfile.TemporaryDirectory(prefix="service-credentials-") as temporary:
            root = Path(temporary)
            credentials = root / "credentials"
            output = root / "output"
            credentials.mkdir()
            output.mkdir()
            (credentials / credential_name).write_text(secret)
            credential_dir = "/run/credentials/" + service + ".service"
            sandbox = [
                bwrap, "--unshare-all", "--die-with-parent", "--clearenv",
                "--ro-bind", "/nix/store", "/nix/store", "--proc", "/proc", "--dev", "/dev",
                "--dir", "/tmp", "--dir", "/run", "--dir", "/run/credentials",
                "--ro-bind", str(credentials), credential_dir,
                "--bind", str(output), "/run/" + runtime_name,
                "--setenv", "CREDENTIALS_DIRECTORY", credential_dir,
                "--setenv", "PATH", environment["PATH"],
            ]
            result = subprocess.run(sandbox + command, capture_output=True, text=True)
            if result.returncode:
                raise RuntimeError(service + ": " + result.stderr)
            generated = output / filename
            data = json.loads(generated.read_text())
            if service == "livekit":
                actual = [server["secret"] for server in data["rtc"]["turn_servers"]]
                assert actual == [secret, secret, secret]
            elif service == "searx-init":
                assert data["server"]["secret_key"] == secret
            else:
                assert data["rpc-password"] == secret
            assert generated.stat().st_mode & 0o077 == 0, service + ": credential file is not private"
            (credentials / credential_name).unlink()
            missing = subprocess.run(sandbox + command, capture_output=True, text=True)
            assert missing.returncode != 0, service + ": missing credential did not stop startup"
            print(service + ": escaped credential preserved, private output, missing credential rejected")


if __name__ == "__main__":
    main()
