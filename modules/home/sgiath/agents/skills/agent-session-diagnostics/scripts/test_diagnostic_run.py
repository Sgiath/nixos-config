#!/usr/bin/env python3
import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest


SCRIPT = Path(__file__).with_name("diagnostic_run.py")


def write_case(path: Path, case_id: str, project_key: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(
        f"""---
schema_version: 1
case_id: {case_id}
project_key: {project_key}
signals:
  - correction.explicit
status: evidence-only
---

# Evidence for {case_id}
""",
        encoding="utf-8",
    )


def write_finding(
    path: Path,
    finding_id: str,
    project_slug: str,
    project_key: str,
    case_ids: list[str],
    remedy_target: str = "project-tooling",
) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    cases = ", ".join(case_ids)
    path.write_text(
        f"""---
schema_version: 1
finding_id: {finding_id}
project_slug: {project_slug}
project_key: {project_key}
evidence_cases: [{cases}]
preventability: yes
confidence: high
remedy_target: {remedy_target}
status: proposed
---

# Reproduce CI before claiming success

## Diagnosis
The local check did not reproduce CI.

## Evidence
The evidence cases record the mismatch.

## Root cause
The verification command used a different environment.

## Preventability
This is preventable with a canonical check.

## Recommended remedy
Add one project command matching CI.

## Placement rationale
The command is repository-specific and executable.

## Alternatives rejected
A prompt-only rule cannot enforce environment parity.

## Verification plan
Run the canonical command and the affected CI job.

## Source map
- Evidence cases: {cases}
""",
        encoding="utf-8",
    )


class DiagnosticRunCliTests(unittest.TestCase):
    def setUp(self) -> None:
        self.temp_dir = tempfile.TemporaryDirectory()
        self.root = Path(self.temp_dir.name)
        self.evidence_run = self.root / "evidence" / "run-a"
        self.evidence_run.mkdir(parents=True)
        (self.evidence_run / "manifest.json").write_text(
            json.dumps(
                {
                    "schema_version": 1,
                    "run_id": "evidence-run-a",
                    "finished_at": "2026-08-28T23:56:39Z",
                    "counts": {"cases": 2},
                }
            ),
            encoding="utf-8",
        )
        write_case(
            self.evidence_run / "projects" / "project-a" / "cases" / "case_aaaaaaaaaaaa.md",
            "case_aaaaaaaaaaaa",
            "github.com:example/project-a",
        )
        write_case(
            self.evidence_run / "projects" / "project-a" / "cases" / "case_bbbbbbbbbbbb.md",
            "case_bbbbbbbbbbbb",
            "github.com:example/project-a",
        )
        self.env = os.environ.copy()
        self.env["XDG_STATE_HOME"] = str(self.root / "state")

    def tearDown(self) -> None:
        self.temp_dir.cleanup()

    def run_cli(self, *args: str, check: bool = True) -> subprocess.CompletedProcess[str]:
        return subprocess.run(
            ["python3", str(SCRIPT), *args],
            check=check,
            capture_output=True,
            text=True,
            env=self.env,
        )

    def prepare(self) -> Path:
        result = self.run_cli("prepare", "--evidence-run", str(self.evidence_run))
        payload = json.loads(result.stdout)
        return Path(payload["run_dir"])

    def test_prepare_creates_private_inventory(self) -> None:
        run_dir = self.prepare()
        self.assertEqual(run_dir.stat().st_mode & 0o777, 0o700)
        inventory = [
            json.loads(line)
            for line in (run_dir / "case-inventory.jsonl").read_text(encoding="utf-8").splitlines()
        ]
        self.assertEqual([item["case_id"] for item in inventory], ["case_aaaaaaaaaaaa", "case_bbbbbbbbbbbb"])
        self.assertTrue(all(item["sha256"] for item in inventory))
        manifest = json.loads((run_dir / "manifest.json").read_text(encoding="utf-8"))
        self.assertEqual(manifest["status"], "in_progress")
        self.assertEqual(manifest["counts"]["input_cases"], 2)

    def test_prepare_records_manifest_case_count_mismatch(self) -> None:
        manifest_path = self.evidence_run / "manifest.json"
        manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
        manifest["counts"]["cases"] = 1
        manifest_path.write_text(json.dumps(manifest), encoding="utf-8")
        run_dir = self.prepare()
        diagnostic_manifest = json.loads((run_dir / "manifest.json").read_text(encoding="utf-8"))
        self.assertIn("reports 1 cases but 2 case files exist", diagnostic_manifest["input_warnings"][0])

    def test_prepare_filters_selected_cases(self) -> None:
        result = self.run_cli(
            "prepare",
            "--evidence-run",
            str(self.evidence_run),
            "--case",
            "case_bbbbbbbbbbbb",
        )
        run_dir = Path(json.loads(result.stdout)["run_dir"])
        inventory = [
            json.loads(line)
            for line in (run_dir / "case-inventory.jsonl").read_text(encoding="utf-8").splitlines()
        ]
        self.assertEqual([item["case_id"] for item in inventory], ["case_bbbbbbbbbbbb"])
        manifest = json.loads((run_dir / "manifest.json").read_text(encoding="utf-8"))
        self.assertEqual(manifest["filters"]["cases"], ["case_bbbbbbbbbbbb"])
    def test_prepare_skips_fixed_evidence_cases(self) -> None:
        review_state = self.root / "state" / "agent-session-review" / "state.json"
        review_state.parent.mkdir(parents=True)
        review_state.write_text(
            json.dumps(
                {
                    "schema_version": 1,
                    "findings": {},
                    "cases": {
                        "case_aaaaaaaaaaaa": {
                            "status": "fixed",
                            "fixed_at": "2026-08-29T09:00:00Z",
                        }
                    },
                }
            ),
            encoding="utf-8",
        )

        run_dir = self.prepare()
        inventory = [
            json.loads(line)
            for line in (run_dir / "case-inventory.jsonl").read_text(encoding="utf-8").splitlines()
        ]
        manifest = json.loads((run_dir / "manifest.json").read_text(encoding="utf-8"))
        self.assertEqual([item["case_id"] for item in inventory], ["case_bbbbbbbbbbbb"])
        self.assertEqual(manifest["counts"]["skipped_fixed_cases"], 1)
        self.assertFalse(manifest["filters"]["include_fixed"])

    def test_prepare_can_include_fixed_evidence_cases(self) -> None:
        review_state = self.root / "state" / "agent-session-review" / "state.json"
        review_state.parent.mkdir(parents=True)
        review_state.write_text(
            json.dumps(
                {
                    "schema_version": 1,
                    "findings": {},
                    "cases": {"case_aaaaaaaaaaaa": {"status": "fixed"}},
                }
            ),
            encoding="utf-8",
        )

        result = self.run_cli(
            "prepare",
            "--evidence-run",
            str(self.evidence_run),
            "--include-fixed",
        )
        run_dir = Path(json.loads(result.stdout)["run_dir"])
        inventory = [
            json.loads(line)
            for line in (run_dir / "case-inventory.jsonl").read_text(encoding="utf-8").splitlines()
        ]
        self.assertEqual(
            [item["case_id"] for item in inventory],
            ["case_aaaaaaaaaaaa", "case_bbbbbbbbbbbb"],
        )

    def test_finalize_rejects_uncovered_cases(self) -> None:
        run_dir = self.prepare()
        write_finding(
            run_dir / "projects" / "project-a" / "findings" / "finding_111111111111.md",
            "finding_111111111111",
            "project-a",
            "github.com:example/project-a",
            ["case_aaaaaaaaaaaa"],
        )
        result = self.run_cli("finalize", "--run-dir", str(run_dir), check=False)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("uncovered evidence cases", result.stderr)

    def test_finalize_writes_indexes_and_completes_manifest(self) -> None:
        run_dir = self.prepare()
        write_finding(
            run_dir / "projects" / "project-a" / "findings" / "finding_111111111111.md",
            "finding_111111111111",
            "project-a",
            "github.com:example/project-a",
            ["case_aaaaaaaaaaaa", "case_bbbbbbbbbbbb"],
        )
        finding_path = run_dir / "projects" / "project-a" / "findings" / "finding_111111111111.md"
        finding_path.chmod(0o644)
        result = self.run_cli("finalize", "--run-dir", str(run_dir))
        payload = json.loads(result.stdout)
        self.assertEqual(payload["findings"], 1)
        self.assertEqual(payload["covered_cases"], 2)
        manifest = json.loads((run_dir / "manifest.json").read_text(encoding="utf-8"))
        self.assertEqual(manifest["status"], "complete")
        self.assertEqual(manifest["counts"]["findings"], 1)
        index = (run_dir / "projects" / "project-a" / "index.md").read_text(encoding="utf-8")
        finding_path = run_dir / "projects" / "project-a" / "findings" / "finding_111111111111.md"
        self.assertEqual(finding_path.stat().st_mode & 0o777, 0o600)
        self.assertIn("finding_111111111111", index)
        self.assertIn("Reproduce CI before claiming success", index)

    def test_finalize_accepts_cross_project_finding(self) -> None:
        original = self.evidence_run / "projects" / "project-a" / "cases" / "case_bbbbbbbbbbbb.md"
        original.unlink()
        write_case(
            self.evidence_run / "projects" / "project-b" / "cases" / "case_bbbbbbbbbbbb.md",
            "case_bbbbbbbbbbbb",
            "github.com:example/project-b",
        )
        run_dir = self.prepare()
        write_finding(
            run_dir / "projects" / "_cross-project" / "findings" / "finding_222222222222.md",
            "finding_222222222222",
            "_cross-project",
            "_cross-project",
            ["case_aaaaaaaaaaaa", "case_bbbbbbbbbbbb"],
            remedy_target="global-agents",
        )
        self.run_cli("finalize", "--run-dir", str(run_dir))
        index = (run_dir / "projects" / "_cross-project" / "index.md").read_text(encoding="utf-8")
        self.assertIn("finding_222222222222", index)

    def test_finalize_accepts_evidence_side_cross_project_case(self) -> None:
        manifest_path = self.evidence_run / "manifest.json"
        manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
        manifest["counts"]["cases"] = 3
        manifest_path.write_text(json.dumps(manifest), encoding="utf-8")
        write_case(
            self.evidence_run / "projects" / "_cross-project" / "cases" / "case_cccccccccccc.md",
            "case_cccccccccccc",
            "_cross-project",
        )
        run_dir = self.prepare()
        write_finding(
            run_dir / "projects" / "project-a" / "findings" / "finding_111111111111.md",
            "finding_111111111111",
            "project-a",
            "github.com:example/project-a",
            ["case_aaaaaaaaaaaa", "case_bbbbbbbbbbbb"],
        )
        write_finding(
            run_dir / "projects" / "_cross-project" / "findings" / "finding_333333333333.md",
            "finding_333333333333",
            "_cross-project",
            "_cross-project",
            ["case_cccccccccccc"],
            remedy_target="harness",
        )
        self.run_cli("finalize", "--run-dir", str(run_dir))
        root_index = (run_dir / "index.md").read_text(encoding="utf-8")
        self.assertEqual(root_index.count("projects/_cross-project/index.md"), 1)

    def test_finding_id_is_stable_across_case_order(self) -> None:
        first = self.run_cli(
            "id",
            "--case-id",
            "case_aaaaaaaaaaaa",
            "--case-id",
            "case_bbbbbbbbbbbb",
            "--root-cause-key",
            "ci-environment-drift",
            "--remedy-target",
            "project-tooling",
        )
        second = self.run_cli(
            "id",
            "--case-id",
            "case_bbbbbbbbbbbb",
            "--case-id",
            "case_aaaaaaaaaaaa",
            "--root-cause-key",
            "ci-environment-drift",
            "--remedy-target",
            "project-tooling",
        )
        self.assertEqual(json.loads(first.stdout)["finding_id"], json.loads(second.stdout)["finding_id"])


if __name__ == "__main__":
    unittest.main()
