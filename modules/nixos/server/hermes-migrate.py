"""Copy legacy Hermes state before upstream activation renders managed files.

Run only as root, with both Hermes services stopped. A verified staging tree is
published by rename; the legacy tree is never modified or removed.
"""

import fcntl
import os
from pathlib import Path
import pwd
import grp
import subprocess
import sys
import re
import shutil
import tempfile

import yaml


SOURCE = Path("/home/sgiath/hermes")
DESTINATION = Path("/var/lib/hermes-agent")
MIGRATION = Path("/var/lib/hermes-migration")
STAGING = MIGRATION / "state"
MARKER = ".hermes-state-migrated"


def run(*args):
    return subprocess.run(args, check=True, text=True, capture_output=True)


def empty_directories(root):
    """Return a directory-only tree in removal order; never follow symlinks."""
    if root.is_symlink() or not root.is_dir():
        raise RuntimeError("destination must be a directory")
    directories = []
    for current, children, files in os.walk(root, topdown=False, followlinks=False):
        if files or any((Path(current) / child).is_symlink() for child in children):
            raise RuntimeError("populated destination has no migration marker; refusing to overwrite")
        directories.append(Path(current))
    return directories


def replace_private_file(path, content):
    # Replace rather than truncate: copied hardlinks must not modify unrelated
    # state files, and temporary names cannot follow a preexisting symlink.
    with tempfile.NamedTemporaryFile(mode="w", dir=path.parent, delete=False) as stream:
        temporary = Path(stream.name)
        stream.write(content)
    os.chmod(temporary, path.stat().st_mode & 0o777)
    temporary.replace(path)


def remove_retired_buzz():
    """Remove retired configuration only from the verified private copy."""
    home = STAGING / ".hermes"
    if home.is_symlink():
        raise RuntimeError("staged .hermes must not be a symlink")
    config_path = home / "config.yaml"
    env_path = home / ".env"
    plugins_path = home / "plugins"
    if any(path.is_symlink() for path in (config_path, env_path, plugins_path)):
        raise RuntimeError("staged config, environment, and plugin directory must not be symlinks")
    if config_path.exists():
        try:
            settings = yaml.safe_load(config_path.read_text())
        except (yaml.YAMLError, UnicodeError):
            raise RuntimeError("cannot parse staged Hermes config") from None
        if settings is not None and not isinstance(settings, dict):
            raise RuntimeError("staged Hermes config must be a mapping")
        changed = False
        if settings:
            for section in ("gateway", "display"):
                entry = settings.get(section)
                platforms = entry.get("platforms") if isinstance(entry, dict) else None
                if isinstance(platforms, dict) and "buzz" in platforms:
                    del platforms["buzz"]
                    changed = True
            plugins = settings.get("plugins")
            enabled = plugins.get("enabled") if isinstance(plugins, dict) else None
            if isinstance(enabled, list) and "buzz-platform" in enabled:
                plugins["enabled"] = [name for name in enabled if name != "buzz-platform"]
                changed = True
        if changed:
            replace_private_file(config_path, yaml.safe_dump(settings, sort_keys=False))
    if env_path.exists():
        try:
            original = env_path.read_text()
        except UnicodeError:
            raise RuntimeError("cannot parse staged Hermes environment") from None
        cleaned = "".join(
            line for line in original.splitlines(keepends=True)
            if not re.match(r"^\s*(?:export\s+)?BUZZ_[A-Za-z0-9_]*\s*=", line)
        )
        if cleaned != original:
            replace_private_file(env_path, cleaned)
    for name in ("buzz-platform", "nix-managed-buzz-platform"):
        path = plugins_path / name
        if path.is_symlink():
            path.unlink()
        elif path.is_dir():
            shutil.rmtree(path)
        elif path.exists():
            path.unlink()


def relocate_active_paths():
    """Rewrite active UTF-8 state, leaving histories and archived skills intact."""
    replacements = (
        (str(SOURCE), str(DESTINATION)),
        ("/home/sgiath/.local/bin/bird-vesta", f"{DESTINATION}/.local/bin/bird-vesta"),
        ("/home/sgiath/.local/bin/bird", f"{DESTINATION}/.local/bin/bird"),
        (
            "/home/sgiath/.openclaw/workspace/.credentials/twitter.env",
            "/run/secrets/hermes-bird-env",
        ),
    )
    patterns = [
        (
            re.compile(r"(?<![A-Za-z0-9_./~-])" + re.escape(old) + r"(?=/|$|[^A-Za-z0-9_.~-])"),
            new,
        )
        for old, new in replacements
    ]
    files = []
    for relative in (
        ".hermes/config.yaml",
        ".hermes/cron/jobs.json",
        ".hermes/memories/MEMORY.md",
        ".hermes/scripts",
        "workspace/scripts",
        ".hermes/skills",
    ):
        path = STAGING / relative
        for part in (path, *path.parents):
            if part == STAGING:
                break
            if part.is_symlink():
                raise RuntimeError("active state path must not have symlink ancestors")
        if path.is_file():
            files.append(path)
        elif path.is_dir():
            for root, directories, names in os.walk(path, followlinks=False):
                directories[:] = [
                    name for name in directories
                    if not name.startswith(".")
                    and name.lower() not in ("archive", "archives", "backup", "backups")
                    and not (Path(root) / name).is_symlink()
                ]
                files.extend(
                    Path(root) / name for name in names
                    if not name.startswith(".") and not (Path(root) / name).is_symlink()
                    and (Path(root) / name).is_file()
                )
    for path in files:
        try:
            original = path.read_bytes().decode("utf-8")
        except UnicodeError:
            # Skills/scripts can carry binary assets, which are not path text.
            continue
        updated = original
        for pattern, replacement in patterns:
            updated = pattern.sub(lambda _match: replacement, updated)
        if updated != original:
            replace_private_file(path, updated)


def migrate():
    if os.geteuid() != 0:
        raise RuntimeError("migration requires root")
    if MIGRATION.is_symlink():
        raise RuntimeError("migration directory must not be a symlink")
    MIGRATION.mkdir(mode=0o700, exist_ok=True)
    if MIGRATION.stat().st_uid != 0:
        raise RuntimeError("migration directory must belong to root")
    os.chmod(MIGRATION, 0o700)
    with (MIGRATION / "lock").open("w") as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        if DESTINATION.is_symlink():
            raise RuntimeError("destination must not be a symlink")
        marker = DESTINATION / MARKER
        if marker.is_file() and not marker.is_symlink():
            print("Hermes migration already completed; retaining legacy source", flush=True)
            return
        if DESTINATION.exists():
            empty_directories(DESTINATION)
        if SOURCE.is_symlink():
            raise RuntimeError("legacy source must not be a symlink")
        if SOURCE.exists() and not SOURCE.is_dir():
            raise RuntimeError("legacy source must be a directory")
        fresh_install = not SOURCE.exists()
        if fresh_install and STAGING.exists():
            pending_marker = STAGING / MARKER
            if any(path.name != MARKER for path in STAGING.iterdir()) or (
                pending_marker.exists()
                and pending_marker.read_text() != "Initialized fresh state.\n"
            ):
                raise RuntimeError("legacy source missing during interrupted migration; staging retained")
        if (SOURCE / MARKER).exists() or (SOURCE / MARKER).is_symlink():
            raise RuntimeError("legacy source contains reserved migration marker")

        if not fresh_install:
            print("Stopping Hermes gateway/dashboard before copying state", flush=True)
            run("systemctl", "stop", "hermes-dashboard.service", "hermes-agent.service")
        # A previous interrupted copy is private and can be resumed. Never merge
        # into the actual destination, even when its contents look similar.
        if STAGING.is_symlink():
            raise RuntimeError("staging directory must not be a symlink")
        STAGING.mkdir(mode=0o700, exist_ok=True)
        if fresh_install:
            print("Initializing empty Hermes state on a fresh installation", flush=True)
        else:
            print("Copying Hermes state into private staging directory", flush=True)
            # Delete only stale private staging entries, never source or live state.
            run("rsync", "-aH", "--checksum", "--delete-delay", f"{SOURCE}/", f"{STAGING}/")
            difference = run(
                "rsync", "-aHn", "--checksum", "--delete", "--itemize-changes",
                f"{SOURCE}/", f"{STAGING}/",
            )
            if difference.stdout:
                raise RuntimeError("staging verification differs from source; both trees retained")
            print("Verified state copy; relocating internal symlinks and ownership", flush=True)
        remove_retired_buzz()
        relocate_active_paths()
        uid = pwd.getpwnam("hermes").pw_uid
        gid = grp.getgrnam("hermes").gr_gid
        # Do not follow symlinks while changing ownership. Absolute links within
        # the old state root need relocation; links outside it remain unchanged
        # and are subject to the service's filesystem confinement.
        for root, directories, files in os.walk(STAGING, followlinks=False):
            for name in directories + files:
                path = Path(root) / name
                if path.is_symlink():
                    target = os.readlink(path)
                    if target == str(SOURCE) or target.startswith(f"{SOURCE}/"):
                        replacement = str(DESTINATION) + target[len(str(SOURCE)):]
                        path.unlink()
                        path.symlink_to(replacement)
                os.chown(path, uid, gid, follow_symlinks=False)
        os.chown(STAGING, uid, gid)
        marker = STAGING / MARKER
        marker.write_text(
            "Initialized fresh state.\n" if fresh_install
            else "Verified copy of /home/sgiath/hermes; source retained.\n"
        )
        os.chown(marker, 0, 0)
        os.chmod(marker, 0o444)
        # Persist data before the rename and the rename before returning. The
        # marker travels with the tree, including a crash immediately afterward.
        os.sync()
        if DESTINATION.exists():
            # Recheck immediately before publishing. rmdir refuses newly-created
            # files instead of deleting them if another process races activation.
            for directory in empty_directories(DESTINATION):
                directory.rmdir()
        STAGING.rename(DESTINATION)
        os.sync()
        print("Hermes migration complete; legacy source retained unchanged", flush=True)


if __name__ == "__main__":
    try:
        migrate()
    except (OSError, RuntimeError, subprocess.CalledProcessError) as error:
        print(f"Hermes migration failed: {error}", file=sys.stderr, flush=True)
        sys.exit(1)
