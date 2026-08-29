#!/usr/bin/env python3
import json
import os
from pathlib import Path
import re
import subprocess
import tempfile
import unittest

from urllib.request import Request, urlopen

SCRIPT = Path(__file__).with_name("review_report.py")


def write_finding(
    path: Path,
    finding_id: str,
    project_slug: str,
    project_key: str,
    case_ids: list[str],
    remedy_target: str,
    title: str,
) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(
        f"""---
schema_version: 1
finding_id: {finding_id}
project_slug: {project_slug}
project_key: {project_key}
evidence_cases: [{', '.join(case_ids)}]
preventability: yes
confidence: high
remedy_target: {remedy_target}
status: proposed
---

# {title}

## Diagnosis

Observed failure.

## Evidence

- Evidence line.

## Root cause

A reproducible cause.

## Preventability

yes.

## Recommended remedy

Change the named boundary.

## Placement rationale

The selected target owns the behavior.

## Alternatives rejected

None.

## Verification plan

Run the failing scenario.

## Source map

- Source path.
""",
        encoding="utf-8",
    )


class ReviewReportCliTests(unittest.TestCase):
    def setUp(self) -> None:
        self.temp_dir = tempfile.TemporaryDirectory()
        self.root = Path(self.temp_dir.name)
        self.state_home = self.root / "state"
        self.run_dir = self.root / "diagnostics" / "run_complete"
        self.evidence_run = self.root / "evidence" / "run_evidence"
        (self.run_dir / "projects").mkdir(parents=True)
        self.evidence_run.mkdir(parents=True)
        (self.evidence_run / "manifest.json").write_text(
            json.dumps({"run_id": "evidence_run"}), encoding="utf-8"
        )
        self.case_a = "case_aaaaaaaaaaaa"
        self.case_b = "case_bbbbbbbbbbbb"
        self.finding_a = "finding_aaaaaaaaaaaa"
        self.finding_b = "finding_bbbbbbbbbbbb"
        self.project_slug = "project-one"
        self.project_key = "github.com:owner/project"
        inventory = [
            {
                "case_id": self.case_a,
                "project_key": self.project_key,
                "project_slug": self.project_slug,
                "source_path": str(self.evidence_run / "projects" / self.project_slug / "cases" / f"{self.case_a}.md"),
                "relative_path": f"projects/{self.project_slug}/cases/{self.case_a}.md",
                "sha256": "a" * 64,
            },
            {
                "case_id": self.case_b,
                "project_key": self.project_key,
                "project_slug": self.project_slug,
                "source_path": str(self.evidence_run / "projects" / self.project_slug / "cases" / f"{self.case_b}.md"),
                "relative_path": f"projects/{self.project_slug}/cases/{self.case_b}.md",
                "sha256": "b" * 64,
            },
        ]
        (self.run_dir / "case-inventory.jsonl").write_text(
            "".join(json.dumps(record) + "\n" for record in inventory),
            encoding="utf-8",
        )
        (self.run_dir / "manifest.json").write_text(
            json.dumps(
                {
                    "schema_version": 1,
                    "run_id": "run_complete",
                    "status": "complete",
                    "finished_at": "2026-08-29T08:00:00Z",
                    "evidence_run": str(self.evidence_run),
                    "evidence_run_id": "evidence_run",
                    "counts": {"input_cases": 2, "findings": 2},
                }
            ),
            encoding="utf-8",
        )
        self.path_a = self.run_dir / "projects" / self.project_slug / "findings" / f"{self.finding_a}.md"
        self.path_b = self.run_dir / "projects" / self.project_slug / "findings" / f"{self.finding_b}.md"
        write_finding(
            self.path_a,
            self.finding_a,
            self.project_slug,
            self.project_key,
            [self.case_a],
            "project-code",
            "Fix the project boundary",
        )
        write_finding(
            self.path_b,
            self.finding_b,
            self.project_slug,
            self.project_key,
            [self.case_a, self.case_b],
            "project-tooling",
            "Make the check reproducible",
        )
        self.env = os.environ.copy()
        self.env["XDG_STATE_HOME"] = str(self.state_home)

    def tearDown(self) -> None:
        self.temp_dir.cleanup()

    def run_cli(self, *args: str, check: bool = True) -> subprocess.CompletedProcess[str]:
        result = subprocess.run(
            ["python3", str(SCRIPT), *args],
            text=True,
            capture_output=True,
            env=self.env,
            check=False,
        )
        if check and result.returncode != 0:
            self.fail(f"command failed ({result.returncode}): {result.stderr}")
        return result

    def test_generate_renders_grouped_findings_and_exact_fix_prompts(self) -> None:
        output = self.root / "report" / "index.html"
        result = self.run_cli(
            "generate", "--diagnostic-run", str(self.run_dir), "--output", str(output)
        )
        payload = json.loads(result.stdout)
        html = output.read_text(encoding="utf-8")

        self.assertEqual(payload["findings"], 2)
        self.assertEqual(payload["projects"], 1)
        self.assertIn("project-one", html)
        self.assertIn("project-code", html)
        self.assertIn("project-tooling", html)
        self.assertIn(f"Fix this issue {self.path_a.resolve()}", html)
        self.assertIn("data-action=\"mark-fixed\"", html)
        self.assertIn("aria-label=\"Search findings\"", html)
        self.assertEqual(output.stat().st_mode & 0o777, 0o600)
        self.assertEqual(output.parent.stat().st_mode & 0o777, 0o700)

    def test_mark_fixed_waits_until_every_finding_for_a_case_is_fixed(self) -> None:
        first = json.loads(
            self.run_cli(
                "mark-fixed",
                "--diagnostic-run",
                str(self.run_dir),
                "--finding-id",
                self.finding_a,
            ).stdout
        )
        self.assertEqual(first["fixed_cases"], [])

        second = json.loads(
            self.run_cli(
                "mark-fixed",
                "--diagnostic-run",
                str(self.run_dir),
                "--finding-id",
                self.finding_b,
            ).stdout
        )
        self.assertEqual(second["fixed_cases"], [self.case_a, self.case_b])

        state_path = self.state_home / "agent-session-review" / "state.json"
        state = json.loads(state_path.read_text(encoding="utf-8"))
        self.assertEqual(set(state["findings"]), {self.finding_a, self.finding_b})
        self.assertEqual(set(state["cases"]), {self.case_a, self.case_b})
        self.assertEqual(state_path.stat().st_mode & 0o777, 0o600)

    def test_mark_fixed_is_idempotent(self) -> None:
        args = (
            "mark-fixed",
            "--diagnostic-run",
            str(self.run_dir),
            "--finding-id",
            self.finding_a,
        )
        first = json.loads(self.run_cli(*args).stdout)
        second = json.loads(self.run_cli(*args).stdout)
        self.assertEqual(first["fixed_at"], second["fixed_at"])

    def test_generate_rejects_incomplete_diagnostic_run(self) -> None:
        manifest_path = self.run_dir / "manifest.json"
        manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
        manifest["status"] = "in_progress"
        manifest_path.write_text(json.dumps(manifest), encoding="utf-8")
        result = self.run_cli(
            "generate",
            "--diagnostic-run",
            str(self.run_dir),
            "--output",
            str(self.root / "report.html"),
            check=False,
        )
        self.assertEqual(result.returncode, 2)
        self.assertIn("not complete", result.stderr)

    def test_serve_persists_fixed_status_through_authenticated_api(self) -> None:
        process = subprocess.Popen(
            [
                "python3",
                str(SCRIPT),
                "serve",
                "--diagnostic-run",
                str(self.run_dir),
                "--port",
                "0",
            ],
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            env=self.env,
        )
        try:
            assert process.stdout is not None
            ready = json.loads(process.stdout.readline())
            with urlopen(ready["url"], timeout=5) as response:
                page = response.read().decode("utf-8")
            token_match = re.search(r'const csrfToken = "([^"]+)";', page)
            self.assertIsNotNone(token_match)
            request = Request(
                ready["url"] + f"api/findings/{self.finding_a}/fixed",
                method="POST",
                headers={"X-Review-Token": token_match.group(1)},
            )
            with urlopen(request, timeout=5) as response:
                payload = json.loads(response.read())
            self.assertEqual(payload["finding_id"], self.finding_a)
            state = json.loads(
                (self.state_home / "agent-session-review" / "state.json").read_text(
                    encoding="utf-8"
                )
            )
            self.assertEqual(state["findings"][self.finding_a]["status"], "fixed")
        finally:
            process.terminate()
            process.wait(timeout=5)
            if process.stdout:
                process.stdout.close()
            if process.stderr:
                process.stderr.close()



if __name__ == "__main__":
    unittest.main()
