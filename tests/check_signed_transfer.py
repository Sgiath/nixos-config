#!/usr/bin/env python3
"""Verify closure signatures before and after a real SSH transfer.

Usage: python3 tests/check_signed_transfer.py KEY_FILE PUBLIC_KEY_FILE [HOST]
The private key stays local. The receiver uses a disposable store, not a system
profile. An SSH store owner is trusted to write that store; explicit verification
below checks cryptographic trust independently of that ownership.
"""

import json
from pathlib import Path
import shlex
import subprocess
import sys
import urllib.parse
import uuid


def run(arguments, **kwargs):
    return subprocess.run(arguments, text=True, capture_output=True, check=True, **kwargs)


def main():
    secret_file, public_file = sys.argv[1:3]
    host = sys.argv[3] if len(sys.argv) > 3 else "vesta.local"
    public_key = Path(public_file).read_text().strip()
    ssh = ["ssh", "-o", "BatchMode=yes", "-o", "StrictHostKeyChecking=yes", host]
    remote_dir = run(ssh + ["mktemp", "-d", "/tmp/nix-signature-test.XXXXXX"]).stdout.strip()
    if not remote_dir.startswith("/tmp/nix-signature-test."):
        raise RuntimeError("unexpected temporary directory")
    try:
        name = "signed-transfer-probe-" + uuid.uuid4().hex
        expression = (
            'let flake = builtins.getFlake '
            + json.dumps("git+file://" + str(Path(__file__).resolve().parents[1]))
            + '; pkgs = import flake.inputs.nixpkgs {}; in pkgs.runCommand '
            + json.dumps(name) + ' {} "printf signature-probe > $out"'
        )
        path = run([
            "nix-build", "--no-out-link", "--expr", expression,
            "--option", "require-sigs", "true",
        ]).stdout.strip()
        verify = ["nix", "store", "verify", "--no-contents", "--sigs-needed", "1"]
        rejected = subprocess.run(
            verify + ["--option", "trusted-public-keys", "", path],
            text=True, capture_output=True,
        )
        if rejected.returncode == 0 or "untrusted" not in rejected.stderr:
            raise RuntimeError("verification did not reject missing trust: " + rejected.stderr)
        print("PASS: verification rejects a path without a trusted signature", flush=True)
        run(["sudo", "-n", "nix", "store", "sign", "--key-file", secret_file, path])
        run(verify + ["--option", "trusted-public-keys", public_key, path])
        print("PASS: Ceres signature verifies locally", flush=True)
        destination = "ssh://" + host + "?" + urllib.parse.urlencode({
            "remote-store": remote_dir + "/store",
        })
        run(["nix", "copy", "--to", destination, path, "--option", "require-sigs", "true"])
        run(ssh + [shlex.join(verify + [
            "--store", remote_dir + "/store", "--option", "trusted-public-keys", public_key, path,
        ])])
        print("PASS: Ceres signature verifies on Vesta after SSH transfer", flush=True)
        print("No system profile or running service was changed.", flush=True)
    finally:
        cleanup = "import shutil\nshutil.rmtree(" + repr(remote_dir) + ")\n"
        run(ssh + ["python3", "-"], input=cleanup)


if __name__ == "__main__":
    try:
        main()
    except subprocess.CalledProcessError as error:
        print(error.stderr, file=sys.stderr)
        sys.exit(error.returncode)
