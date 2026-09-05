#!/usr/bin/env python3
"""Check built derivations and this flake's source copies for plaintext credentials.

Run in nix develop, with administrator SOPS access:
  python3 tests/check_store_secrets.py SYSTEM_CLOSURE [SYSTEM_CLOSURE ...]
Secret values are never printed or written to temporary files.
"""

import json
import os
from pathlib import Path
import re
import shlex
import subprocess
import sys


def command(arguments):
    result = subprocess.run(arguments, text=True, capture_output=True)
    if result.returncode:
        raise RuntimeError(result.stderr)
    return result.stdout


def main():
    repository = Path(__file__).resolve().parents[1]
    candidates = {}
    for name in ["secrets.yaml", "vesta.yaml", "ceres-signing.yaml"]:
        decoded = json.loads(command([
            "sops", "--decrypt", "--output-type", "json", str(repository / "secrets" / name),
        ]))
        for key, value in decoded.items():
            if not isinstance(value, str):
                continue
            values = [value]
            if key.endswith("-env"):
                for line in value.splitlines():
                    if re.match(r"^(?:export\s+)?[A-Za-z_][A-Za-z0-9_]*=", line):
                        encoded = line.split("=", 1)[1]
                        try:
                            words = shlex.split(encoded)
                            if len(words) == 1:
                                values.append(words[0])
                        except ValueError:
                            pass
            for item in values:
                # Avoid treating short non-secret identifiers as byte signatures.
                if len(item) >= 8:
                    label = name + ":" + key
                    candidates[item.encode()] = label
                    candidates[json.dumps(item, ensure_ascii=False)[1:-1].encode()] = label
    matcher = re.compile(b"|".join(re.escape(value) for value in candidates))
    paths = set()
    for system in sys.argv[1:]:
        derivation = command(["nix-store", "--query", "--deriver", system]).strip()
        paths.update(command(["nix-store", "--query", "--requisites", derivation]).splitlines())
    if not paths:
        raise RuntimeError("supply at least one built system closure")
    files = {Path(path) for path in paths if path.endswith(".drv")}
    source_count = 0
    for path in paths:
        source = Path(path)
        if (source / "flake.nix").is_file() and (source / "secrets/secrets.yaml").is_file():
            source_count += 1
            if (source / "secrets.json").exists():
                raise RuntimeError("legacy secrets.json remains in flake source " + path)
            for directory, _, names in os.walk(source, followlinks=False):
                files.update(Path(directory) / name for name in names if not (Path(directory) / name).is_symlink())
    leaks = []
    for path in sorted(files):
        match = matcher.search(path.read_bytes())
        if match:
            leaks.append((str(path), candidates[match.group()]))
    if leaks:
        for path, label in leaks:
            print(f"Plaintext credential {label} found in {path}", file=sys.stderr)
        raise RuntimeError(f"{len(leaks)} files contain plaintext credentials")
    print(f"No plaintext credential matches in {len(files)} build/source files ({source_count} flake source copies).")


if __name__ == "__main__":
    main()
