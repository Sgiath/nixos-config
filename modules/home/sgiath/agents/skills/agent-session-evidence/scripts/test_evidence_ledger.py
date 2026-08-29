#!/usr/bin/env python3

import json
import os
from pathlib import Path
import stat
import subprocess
import sys
import tempfile
import unittest


SCRIPT = Path(__file__).with_name("evidence_ledger.py")


class EvidenceLedgerCliTest(unittest.TestCase):
    def setUp(self):
        self.temp_dir = tempfile.TemporaryDirectory()
        self.root = Path(self.temp_dir.name)
        self.db = self.root / "private" / "ledger.sqlite"
        self.output = self.root / "run-output"

    def tearDown(self):
        self.temp_dir.cleanup()

    def run_cli(self, *args, input_records=None, check=True):
        input_text = None
        if input_records is not None:
            input_text = "".join(json.dumps(record) + "\n" for record in input_records)
        result = subprocess.run(
            [sys.executable, str(SCRIPT), "--db", str(self.db), *args],
            input=input_text,
            text=True,
            capture_output=True,
            check=False,
        )
        if check and result.returncode != 0:
            self.fail(f"command failed ({result.returncode}): {result.stderr}")
        return result

    def output_records(self, result):
        return [json.loads(line) for line in result.stdout.splitlines() if line]

    def start_run(self, run_id="run_test"):
        result = self.run_cli(
            "start-run",
            "--run-id",
            run_id,
            "--output-dir",
            str(self.output),
            "--filters-json",
            '{"projects":[],"reprocess":false}',
        )
        return self.output_records(result)[0]

    def test_init_creates_private_ledger_and_reports_schema(self):
        record = self.output_records(self.run_cli("init"))[0]

        self.assertEqual(record["schema_version"], 1)
        self.assertEqual(record["detection_schema_version"], 1)
        self.assertEqual(stat.S_IMODE(self.db.parent.stat().st_mode), 0o700)
        self.assertEqual(stat.S_IMODE(self.db.stat().st_mode), 0o600)

        status = self.output_records(self.run_cli("status"))[0]
        self.assertEqual(status["runs"], {})
        self.assertEqual(status["source_items"], {})
        self.assertEqual(status["context_files"], {})

    def test_run_lifecycle_creates_private_output_and_records_counts(self):
        started = self.start_run()

        self.assertEqual(started["run_id"], "run_test")
        self.assertEqual(started["status"], "running")
        self.assertEqual(stat.S_IMODE(self.output.stat().st_mode), 0o700)
        case_path = self.output / "projects" / "project-a" / "cases" / "case_aaaaaaaaaaaa.md"
        case_path.parent.mkdir(parents=True)
        case_path.write_text("# case\n", encoding="utf-8")

        finished = self.output_records(
            self.run_cli(
                "finish-run",
                "--run-id",
                "run_test",
                "--status",
                "completed",
                "--counts-json",
                '{"processed":2,"cases":1}',
                "--coverage-json",
                '["grok unavailable"]',
            )
        )[0]
        self.assertEqual(finished["status"], "completed")

        status = self.output_records(self.run_cli("status"))[0]
        self.assertEqual(status["runs"], {"completed": 1})

    def test_finish_run_rejects_case_count_mismatch(self):
        self.start_run()
        case_path = self.output / "projects" / "project-a" / "cases" / "case_aaaaaaaaaaaa.md"
        case_path.parent.mkdir(parents=True)
        case_path.write_text("# case\n", encoding="utf-8")

        result = self.run_cli(
            "finish-run",
            "--run-id",
            "run_test",
            "--status",
            "completed",
            "--counts-json",
            '{"cases":0}',
            "--coverage-json",
            "[]",
            check=False,
        )
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("case files exist", result.stderr)
        status = self.output_records(self.run_cli("status"))[0]
        self.assertEqual(status["runs"], {"running": 1})

    def test_finish_run_rejects_manifest_case_count_mismatch(self):
        self.start_run()
        case_path = self.output / "projects" / "project-a" / "cases" / "case_aaaaaaaaaaaa.md"
        case_path.parent.mkdir(parents=True)
        case_path.write_text("# case\n", encoding="utf-8")
        (self.output / "manifest.json").write_text(
            json.dumps({"counts": {"cases": 0}}),
            encoding="utf-8",
        )

        result = self.run_cli(
            "finish-run",
            "--run-id",
            "run_test",
            "--status",
            "completed",
            "--counts-json",
            '{"cases":1}',
            "--coverage-json",
            "[]",
            check=False,
        )
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("manifest.json reports 0 cases", result.stderr)
        status = self.output_records(self.run_cli("status"))[0]
        self.assertEqual(status["runs"], {"running": 1})

    def test_pending_and_checkpoint_follow_incremental_rules(self):
        self.start_run()
        source = {
            "kind": "source_item",
            "harness": "omp",
            "session_id": "session-1",
            "raw_locator": "/sessions/session-1.jsonl",
            "fingerprint": "fingerprint-a",
            "project_key": "github.com/sgiath/project",
            "active": False,
        }

        pending = self.output_records(
            self.run_cli("pending", "--schema-version", "1", input_records=[source])
        )
        self.assertEqual(pending[0]["pending_reason"], "new")

        checkpoint = {
            **source,
            "status": "no_signal",
        }
        self.run_cli(
            "checkpoint", "--run-id", "run_test", "--schema-version", "1", input_records=[checkpoint]
        )

        unchanged = self.output_records(
            self.run_cli("pending", "--schema-version", "1", input_records=[source])
        )
        self.assertEqual(unchanged, [])

        changed = {**source, "fingerprint": "fingerprint-b"}
        changed_pending = self.output_records(
            self.run_cli("pending", "--schema-version", "1", input_records=[changed])
        )
        self.assertEqual(changed_pending[0]["pending_reason"], "fingerprint_changed")

        reprocessed = self.output_records(
            self.run_cli("pending", "--schema-version", "1", "--reprocess", input_records=[source])
        )
        self.assertEqual(reprocessed[0]["pending_reason"], "reprocess")

        partial = {**source, "status": "partial", "active": True}
        self.run_cli(
            "checkpoint", "--run-id", "run_test", "--schema-version", "1", input_records=[partial]
        )
        retry = self.output_records(
            self.run_cli("pending", "--schema-version", "1", input_records=[source])
        )
        self.assertEqual(retry[0]["pending_reason"], "partial")

    def test_checkpoint_requires_durable_bundle_files(self):
        self.start_run()
        source = {
            "kind": "source_item",
            "harness": "pi",
            "session_id": "session-2",
            "raw_locator": "/sessions/session-2.jsonl",
            "fingerprint": "fingerprint-a",
            "project_key": "github.com/sgiath/project",
            "active": False,
            "status": "bundled",
            "case_ids": ["case_1"],
            "durable_paths": ["projects/project/cases/case_1.md"],
        }

        rejected = self.run_cli(
            "checkpoint",
            "--run-id",
            "run_test",
            "--schema-version",
            "1",
            input_records=[source],
            check=False,
        )
        self.assertNotEqual(rejected.returncode, 0)
        self.assertIn("durable file does not exist", rejected.stderr)

        case_path = self.output / source["durable_paths"][0]
        case_path.parent.mkdir(parents=True)
        case_path.write_text("# Evidence\n", encoding="utf-8")
        self.run_cli(
            "checkpoint",
            "--run-id",
            "run_test",
            "--schema-version",
            "1",
            input_records=[source],
        )

        status = self.output_records(self.run_cli("status"))[0]
        self.assertEqual(status["source_items"], {"bundled": 1})

    def test_context_files_use_the_same_pending_and_checkpoint_interface(self):
        self.start_run()
        context = {
            "kind": "context_file",
            "project_key": "github.com/sgiath/project",
            "path": ".omo/plans/fix.md",
            "fingerprint": "context-a",
        }

        pending = self.output_records(
            self.run_cli("pending", "--schema-version", "1", input_records=[context])
        )
        self.assertEqual(pending[0]["pending_reason"], "new")

        self.run_cli(
            "checkpoint",
            "--run-id",
            "run_test",
            "--schema-version",
            "1",
            input_records=[{**context, "status": "no_signal"}],
        )
        unchanged = self.output_records(
            self.run_cli("pending", "--schema-version", "1", input_records=[context])
        )
        self.assertEqual(unchanged, [])

    def test_invalid_json_fails_with_line_number_without_partial_checkpoint(self):
        self.start_run()
        valid = {
            "kind": "context_file",
            "project_key": "project",
            "path": ".omo/boulder.json",
            "fingerprint": "a",
            "status": "no_signal",
        }
        input_text = json.dumps(valid) + "\nnot-json\n"
        result = subprocess.run(
            [
                sys.executable,
                str(SCRIPT),
                "--db",
                str(self.db),
                "checkpoint",
                "--run-id",
                "run_test",
                "--schema-version",
                "1",
            ],
            input=input_text,
            text=True,
            capture_output=True,
            check=False,
        )

        self.assertNotEqual(result.returncode, 0)
        self.assertIn("input line 2 is not valid JSON", result.stderr)
        status = self.output_records(self.run_cli("status"))[0]
        self.assertEqual(status["context_files"], {})


if __name__ == "__main__":
    unittest.main()
