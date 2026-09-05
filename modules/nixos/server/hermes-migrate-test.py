"""Isolated filesystem regression checks; requires rsync, never calls systemctl."""

from contextlib import ExitStack
import importlib.util
import os
from pathlib import Path
import subprocess
import tempfile
from types import SimpleNamespace
import unittest
from unittest.mock import patch


spec = importlib.util.spec_from_file_location(
    "hermes_migrate", Path(__file__).with_name("hermes-migrate.py")
)
migration = importlib.util.module_from_spec(spec)
spec.loader.exec_module(migration)


class MigrationTest(unittest.TestCase):
    def setUp(self):
        self.stack = ExitStack()
        self.addCleanup(self.stack.close)
        self.root = Path(self.stack.enter_context(tempfile.TemporaryDirectory()))
        for name, path in {
            "SOURCE": self.root / "legacy",
            "DESTINATION": self.root / "live",
            "MIGRATION": self.root / "migration",
            "STAGING": self.root / "migration" / "state",
        }.items():
            self.stack.enter_context(patch.object(migration, name, path))
        self.stack.enter_context(patch.object(migration.os, "geteuid", return_value=0))
        self.stack.enter_context(patch.object(migration.os, "chown"))
        self.stack.enter_context(patch.object(migration.os, "sync"))
        self.stack.enter_context(patch.object(migration.pwd, "getpwnam", return_value=SimpleNamespace(pw_uid=os.getuid())))
        self.stack.enter_context(patch.object(migration.grp, "getgrnam", return_value=SimpleNamespace(gr_gid=os.getgid())))
        original_stat = Path.stat

        def stat(path, *args, **kwargs):
            result = original_stat(path, *args, **kwargs)
            if path == migration.MIGRATION:
                fields = list(result)
                fields[4] = 0
                return os.stat_result(fields)
            return result

        self.stack.enter_context(patch.object(Path, "stat", stat))
        self.calls = []
        self.real_run = migration.run

        def run(*args):
            self.calls.append(args)
            if args[0] == "systemctl":
                return subprocess.CompletedProcess(args, 0, "", "")
            return self.real_run(*args)

        self.runner = self.stack.enter_context(patch.object(migration, "run", side_effect=run))

    def seed(self):
        state = migration.SOURCE / ".hermes"
        state.mkdir(parents=True)
        (state / "auth.json").write_bytes(b"private auth fixture\n")
        (state / "sessions").mkdir()
        (state / "sessions" / "one").write_bytes(b"session fixture\x00")
        (migration.SOURCE / "skills").mkdir()
        (migration.SOURCE / "skills" / "local").write_text("skill fixture")
        return state

    def test_copy_preserves_source_and_relocates_only_internal_symlinks(self):
        state = self.seed()
        (state / "auth-link").symlink_to(state / "auth.json")
        outside = self.root / "outside"
        outside.write_text("unchanged")
        (state / "outside").symlink_to(outside)
        migration.migrate()
        target = migration.DESTINATION / ".hermes"
        self.assertEqual((target / "auth.json").read_bytes(), (state / "auth.json").read_bytes())
        self.assertEqual((target / "sessions" / "one").read_bytes(), b"session fixture\x00")
        self.assertEqual((migration.DESTINATION / "skills" / "local").read_text(), "skill fixture")
        self.assertEqual(os.readlink(target / "auth-link"), str(target / "auth.json"))
        self.assertEqual(os.readlink(state / "auth-link"), str(state / "auth.json"))
        self.assertEqual(os.readlink(target / "outside"), str(outside))
        self.assertEqual(outside.read_text(), "unchanged")
        self.assertEqual(self.calls[0][0], "systemctl")

    def test_rerun_does_not_overwrite_evolved_live_state(self):
        self.seed()
        migration.migrate()
        auth = migration.DESTINATION / ".hermes" / "auth.json"
        auth.write_text("refreshed auth")
        self.calls.clear()
        migration.migrate()
        self.assertEqual(auth.read_text(), "refreshed auth")
        self.assertEqual(self.calls, [])

    def test_retired_buzz_removed_only_from_staged_copy(self):
        state = self.seed()
        config = (
            "gateway:\n  platforms:\n    buzz: {enabled: true}\n    matrix: {enabled: true}\n"
            "display:\n  platforms:\n    buzz: {tool_progress: off}\n    matrix: {enabled: true}\n"
            "plugins:\n  enabled: [buzz-platform, other-plugin]\n"
            "dashboard:\n  basic_auth:\n    password_hash: retained\n"
        )
        environment = "MATRIX_TOKEN=retained\nBUZZ_TOKEN=removed\nexport BUZZ_URL=removed\nOTHER=retained\n"
        (state / "config.yaml").write_text(config)
        (state / ".env").write_text(environment)
        plugins = state / "plugins"
        (plugins / "buzz-platform").mkdir(parents=True)
        (plugins / "buzz-platform" / "code.py").write_text("retired")
        external = self.root / "external-plugin"
        external.mkdir()
        (external / "retain").write_text("outside")
        (plugins / "nix-managed-buzz-platform").symlink_to(external)
        (plugins / "other-plugin").mkdir()
        migration.migrate()
        target = migration.DESTINATION / ".hermes"
        settings = migration.yaml.safe_load((target / "config.yaml").read_text())
        self.assertEqual(settings["gateway"]["platforms"], {"matrix": {"enabled": True}})
        self.assertEqual(settings["display"]["platforms"], {"matrix": {"enabled": True}})
        self.assertEqual(settings["plugins"]["enabled"], ["other-plugin"])
        self.assertEqual(settings["dashboard"]["basic_auth"]["password_hash"], "retained")
        self.assertEqual((target / ".env").read_text(), "MATRIX_TOKEN=retained\nOTHER=retained\n")
        self.assertFalse((target / "plugins" / "buzz-platform").exists())
        self.assertFalse((target / "plugins" / "nix-managed-buzz-platform").is_symlink())
        self.assertTrue((target / "plugins" / "other-plugin").is_dir())
        self.assertEqual((external / "retain").read_text(), "outside")
        self.assertEqual((state / "config.yaml").read_text(), config)
        self.assertEqual((state / ".env").read_text(), environment)
        self.assertTrue((plugins / "buzz-platform" / "code.py").exists())
        self.assertTrue((plugins / "nix-managed-buzz-platform").is_symlink())

    def test_cleanup_rejects_symlink_config_without_reading_target(self):
        state = self.seed()
        outside = self.root / "outside-config"
        outside.write_text("private: retained")
        (state / "config.yaml").symlink_to(outside)
        with self.assertRaisesRegex(RuntimeError, "must not be symlinks"):
            migration.migrate()
        self.assertEqual(outside.read_text(), "private: retained")
        self.assertFalse(migration.DESTINATION.exists())

    def test_config_parse_failure_does_not_include_private_content(self):
        state = self.seed()
        (state / "config.yaml").write_text("private-token: [SECRET_TOKEN")
        with self.assertRaises(RuntimeError) as raised:
            migration.migrate()
        self.assertEqual(str(raised.exception), "cannot parse staged Hermes config")
        self.assertFalse(migration.DESTINATION.exists())

    def test_active_paths_relocated_but_history_and_source_unchanged(self):
        self.seed()
        active = (
            ".hermes/config.yaml", ".hermes/cron/jobs.json",
            ".hermes/scripts/task.sh", "workspace/scripts/task.sh",
            ".hermes/skills/current/SKILL.md", ".hermes/memories/MEMORY.md",
        )
        history = (
            ".hermes/cron/output/old.json", ".hermes/sessions/history.json",
            ".hermes/logs/history", "workspace/memory/old.md",
            ".hermes/skills/.archive/old.md", ".hermes/skills/backups/old.md",
        )
        content = (
            f'path: "{migration.SOURCE}/scripts/task.sh"\n'
            f'unrelated: "{migration.SOURCE}-backup"\n'
            'bird: "/home/sgiath/.local/bin/bird"\n'
            'bird_vesta: "/home/sgiath/.local/bin/bird-vesta"\n'
            'bird_other: "/home/sgiath/.local/bin/bird-extra"\n'
            'credential: "/home/sgiath/.openclaw/workspace/.credentials/twitter.env"\n'
        )
        for relative in active + history:
            path = migration.SOURCE / relative
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text(content)
        binary = migration.SOURCE / ".hermes/skills/current/image.bin"
        binary.write_bytes(b"\xff\x00" + str(migration.SOURCE).encode())
        external = self.root / "external-active"
        external.write_text(content)
        (migration.SOURCE / ".hermes/skills/current/external").symlink_to(external)
        migration.migrate()
        for relative in active:
            changed = (migration.DESTINATION / relative).read_text()
            self.assertIn(f'"{migration.DESTINATION}/scripts/task.sh"', changed)
            self.assertIn(f'"{migration.SOURCE}-backup"', changed)
            self.assertIn(f'"{migration.DESTINATION}/.local/bin/bird"', changed)
            self.assertIn(f'"{migration.DESTINATION}/.local/bin/bird-vesta"', changed)
            self.assertIn('"/home/sgiath/.local/bin/bird-extra"', changed)
            self.assertIn('"/run/secrets/hermes-bird-env"', changed)
            self.assertEqual((migration.SOURCE / relative).read_text(), content)
        for relative in history:
            self.assertEqual((migration.DESTINATION / relative).read_text(), content)
            self.assertEqual((migration.SOURCE / relative).read_text(), content)
        self.assertEqual((migration.DESTINATION / binary.relative_to(migration.SOURCE)).read_bytes(), binary.read_bytes())
        self.assertEqual(external.read_text(), content)

    def test_active_directory_symlink_refused_without_reading_target(self):
        self.seed()
        external = self.root / "external-scripts"
        external.mkdir()
        script = external / "task.sh"
        script.write_text(str(migration.SOURCE))
        (migration.SOURCE / ".hermes/scripts").symlink_to(external)
        with self.assertRaisesRegex(RuntimeError, "symlink ancestors"):
            migration.migrate()
        self.assertEqual(script.read_text(), str(migration.SOURCE))
        self.assertFalse(migration.DESTINATION.exists())

    def test_divergent_destination_is_untouched(self):
        self.seed()
        migration.DESTINATION.mkdir()
        existing = migration.DESTINATION / "important"
        existing.write_text("retain")
        with self.assertRaisesRegex(RuntimeError, "populated destination"):
            migration.migrate()
        self.assertEqual(existing.read_text(), "retain")
        self.assertEqual(self.calls, [])

    def test_empty_tmpfiles_skeleton_is_replaced(self):
        self.seed()
        (migration.DESTINATION / ".hermes" / "sessions").mkdir(parents=True)
        (migration.DESTINATION / "workspace").mkdir()
        migration.migrate()
        self.assertTrue((migration.DESTINATION / ".hermes" / "auth.json").exists())
        self.assertFalse((migration.DESTINATION / "workspace").exists())

    def test_destination_symlink_is_not_an_empty_skeleton(self):
        self.seed()
        migration.DESTINATION.mkdir()
        outside = self.root / "outside"
        outside.mkdir()
        (migration.DESTINATION / "linked").symlink_to(outside)
        with self.assertRaisesRegex(RuntimeError, "populated destination"):
            migration.migrate()
        self.assertTrue((migration.DESTINATION / "linked").is_symlink())
        self.assertTrue(outside.is_dir())

    def test_file_created_during_publish_is_retained(self):
        self.seed()
        child = migration.DESTINATION / "workspace"
        child.mkdir(parents=True)
        original_rmdir = Path.rmdir

        def rmdir(path, *args, **kwargs):
            if path == child:
                (child / "concurrent").write_text("retain")
            return original_rmdir(path, *args, **kwargs)

        with patch.object(Path, "rmdir", rmdir):
            with self.assertRaises(OSError):
                migration.migrate()
        self.assertEqual((child / "concurrent").read_text(), "retain")
        self.assertTrue((migration.STAGING / ".hermes" / "auth.json").exists())

    def test_interrupted_staging_removes_stale_copy_entries_only(self):
        self.seed()
        migration.STAGING.mkdir(parents=True)
        stale = migration.STAGING / "deleted-since-copy"
        stale.write_text("stale")
        migration.migrate()
        self.assertFalse((migration.DESTINATION / stale.name).exists())
        self.assertTrue((migration.SOURCE / ".hermes" / "auth.json").exists())

    def test_crash_before_publish_can_resume(self):
        self.seed()
        with patch.object(Path, "rename", side_effect=OSError("interrupted publish")):
            with self.assertRaisesRegex(OSError, "interrupted publish"):
                migration.migrate()
        self.assertFalse(migration.DESTINATION.exists())
        self.assertTrue((migration.STAGING / migration.MARKER).exists())
        migration.migrate()
        self.assertTrue((migration.DESTINATION / ".hermes" / "auth.json").exists())

    def test_fresh_install_initializes_and_reruns(self):
        migration.migrate()
        self.assertTrue((migration.DESTINATION / migration.MARKER).exists())
        (migration.DESTINATION / "new-state").write_text("retain")
        migration.migrate()
        self.assertEqual((migration.DESTINATION / "new-state").read_text(), "retain")
        self.assertFalse(migration.SOURCE.exists())

    def test_missing_source_does_not_publish_interrupted_staging(self):
        migration.STAGING.mkdir(parents=True)
        (migration.STAGING / "important").write_text("retain")
        with self.assertRaisesRegex(RuntimeError, "source missing during interrupted"):
            migration.migrate()
        self.assertFalse(migration.DESTINATION.exists())
        self.assertEqual((migration.STAGING / "important").read_text(), "retain")

    def test_reserved_marker_symlink_cannot_write_outside_state(self):
        self.seed()
        outside = self.root / "missing-outside"
        (migration.SOURCE / migration.MARKER).symlink_to(outside)
        with self.assertRaisesRegex(RuntimeError, "reserved migration marker"):
            migration.migrate()
        self.assertFalse(outside.exists())


if __name__ == "__main__":
    unittest.main()
