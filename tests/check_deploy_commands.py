#!/usr/bin/env python3
"""Exercise built update commands without touching Nix stores or remote hosts.

Usage: python3 tests/check_deploy_commands.py UPDATE_BIN UPDATE_LIMITED_BIN
Pass the actual built Home Manager command paths, not extracted source strings.
"""

import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile


STUB = r'''
import json
import os
from pathlib import Path
import sys

command = Path(sys.argv[0]).name
args = sys.argv[1:]
with open(os.environ["COMMAND_LOG"], "a") as log:
    log.write(json.dumps({
        "command": command,
        "args": args,
        "NIX_SSHOPTS": os.environ.get("NIX_SSHOPTS"),
        "SSH_AUTH_SOCK": os.environ.get("SSH_AUTH_SOCK"),
    }) + "\n")
failure = os.environ["FAIL_STAGE"]
if command == "sudo":
    if args == ["test", "-r", "/run/secrets/nix-signing-key"]:
        sys.exit(1 if failure == "key" else 0)
    if args[:3] == ["nix", "store", "sign"]:
        os.execv(os.environ["STUB_BIN"] + "/nix", args)
    raise SystemExit("unexpected sudo invocation")
if command == "nix":
    if args[0] == "build":
        if failure == "build":
            sys.exit(21)
        Path(args[args.index("--out-link") + 1]).symlink_to(os.environ["TOPLEVEL"])
    elif args[:2] == ["store", "sign"]:
        if failure == "sign":
            sys.exit(22)
    else:
        raise SystemExit("unexpected nix invocation")
elif command == "nixos-rebuild":
    if failure == "copy":
        sys.exit(23)
elif command == "nix-store":
    if failure == "import":
        sys.exit(24)
elif command != "git":
    raise SystemExit("unexpected command")
'''


def check_case(binary, limited, failure, target="--vesta"):
    with tempfile.TemporaryDirectory(prefix="check-deploy-") as temporary:
        root = Path(temporary)
        home = root / "home"
        repo = home / "nixos"
        repo.mkdir(parents=True)
        old_result = root / "existing-result"
        old_result.mkdir()
        result = repo / "result"
        result.symlink_to(old_result)
        lock = repo / "flake.lock"
        lock.write_text("unchanged lock sentinel\n")
        archive = home / "nix-root" / "FoundryVTT-Linux-14.367.zip"
        archive.parent.mkdir()
        archive.write_text("fake test archive\n")
        toplevel = root / "built-toplevel"
        toplevel.mkdir()
        scratch = root / "scratch"
        scratch.mkdir()
        stubs = root / "bin"
        stubs.mkdir()
        stub = stubs / "stub"
        stub.write_text("#!" + sys.executable + "\n" + STUB)
        stub.chmod(0o755)
        for name in ("git", "nix-store", "nix", "sudo", "nixos-rebuild"):
            (stubs / name).symlink_to(stub)
        log = root / "commands.jsonl"
        env = os.environ | {
            "HOME": str(home),
            "PATH": str(stubs) + os.pathsep + os.environ["PATH"],
            "TMPDIR": str(scratch),
            "COMMAND_LOG": str(log),
            "STUB_BIN": str(stubs),
            "TOPLEVEL": str(toplevel),
            "FAIL_STAGE": failure,
            "SSH_AUTH_SOCK": str(root / "fake-agent.sock"),
            "NIX_SSHOPTS": "-o BatchMode=yes",
        }
        forwarded = ["--keep-going", "--option", "connect-timeout", "7"]
        args = [str(binary), target]
        if not limited:
            args.append("--no-commit")
        completed = subprocess.run(
            args + forwarded, cwd=root, env=env, text=True,
            capture_output=True, timeout=30,
        )
        events = [json.loads(line) for line in log.read_text().splitlines()] if log.exists() else []
        if target != "--vesta":
            assert completed.returncode != 0, "unknown target was accepted"
            assert events == [], "unknown target caused Git, build or deployment side effects"
            assert result.is_symlink() and result.readlink() == old_result
            assert lock.read_text() == "unchanged lock sentinel\n"
            assert not list(scratch.iterdir())
            print(f"PASS: {binary.name} rejects {target}", flush=True)
            return
        stages = []
        for event in events:
            command, arguments = event["command"], event["args"]
            assert "--no-check-sigs" not in arguments, event
            assert not any("trusted=true" in value for value in arguments), event
            if command == "sudo" and arguments[0] == "test":
                stages.append("key")
            elif command == "nix-store":
                stages.append("import")
                assert arguments == ["--add-fixed", "sha256", str(archive)], event
            elif command == "nix" and arguments[0] == "build":
                stages.append("build")
                expected = (["--max-jobs", "2", "--cores", "12"] if limited else [])
                assert arguments[1:1 + len(expected + forwarded)] == expected + forwarded, event
                assert "--no-update-lock-file" in arguments, event
                assert arguments[-1] == ".#nixosConfigurations.vesta.config.system.build.toplevel", event
                out_link = Path(arguments[arguments.index("--out-link") + 1])
                assert out_link.parent.parent == scratch, event
                assert not out_link.parent.exists(), "temporary root leaked"
            elif command == "nix" and arguments[:2] == ["store", "sign"]:
                stages.append("sign")
                assert arguments == [
                    "store", "sign", "--recursive", "--key-file",
                    "/run/secrets/nix-signing-key", str(toplevel),
                ], event
                assert any(previous["command"] == "sudo" and previous["args"] == ["nix"] + arguments
                           for previous in events[:events.index(event)]), event
            elif command == "nixos-rebuild":
                stages.append("copy")
                assert arguments == [
                    "switch", "--sudo", "--store-path", str(toplevel),
                    "--target-host", "sgiath@vesta.local",
                ], event
                assert event["NIX_SSHOPTS"] == "-o BatchMode=yes -o IdentityAgent=" + env["SSH_AUTH_SOCK"], event
                assert event["SSH_AUTH_SOCK"] == env["SSH_AUTH_SOCK"], event
        expected_stages = ["key", "import", "build", "sign", "copy"]
        if failure:
            expected_stages = expected_stages[:expected_stages.index(failure) + 1]
            assert completed.returncode != 0, completed
        else:
            assert completed.returncode == 0, completed.stderr
        assert stages == expected_stages, events
        if failure == "key":
            assert "Activate the Ceres signing-key configuration first" in completed.stderr
        assert result.is_symlink() and result.readlink() == old_result, "existing result changed"
        assert lock.read_text() == "unchanged lock sentinel\n", "lock changed"
        assert not list(scratch.iterdir()), "temporary deployment root leaked"
        print(f"PASS: {'update-limited' if limited else 'update'} {failure or 'success'}", flush=True)


def main():
    if len(sys.argv) != 3:
        raise SystemExit(__doc__)
    binaries = [Path(argument).absolute() for argument in sys.argv[1:]]
    for binary in binaries:
        if not binary.is_file() or not os.access(binary, os.X_OK):
            raise SystemExit(f"Not an executable built command: {binary}")
    for binary, limited in zip(binaries, (False, True)):
        for failure in ("", "key", "import", "build", "sign", "copy"):
            check_case(binary, limited, failure)
        for target in ("--hygiea", "--unknown"):
            check_case(binary, limited, "", target)


if __name__ == "__main__":
    main()
