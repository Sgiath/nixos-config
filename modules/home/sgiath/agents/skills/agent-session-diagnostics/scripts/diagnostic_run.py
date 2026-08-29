#!/usr/bin/env python3
"""Prepare and validate private diagnostic runs over evidence case bundles."""

from __future__ import annotations

import argparse
from datetime import datetime, timezone
import hashlib
import json
import os
from pathlib import Path
import re
import secrets
import sys
from typing import Any


CASE_ID_RE = re.compile(r"case_[0-9a-f]{12}$")
FINDING_ID_RE = re.compile(r"finding_[0-9a-f]{12}$")
REMEDY_TARGETS = {
    "project-code",
    "project-config",
    "project-tooling",
    "project-agents",
    "global-agents",
    "skill",
    "harness",
    "system",
    "none",
}
REQUIRED_SECTIONS = [
    "Diagnosis",
    "Evidence",
    "Root cause",
    "Preventability",
    "Recommended remedy",
    "Placement rationale",
    "Alternatives rejected",
    "Verification plan",
    "Source map",
]


class DiagnosticError(Exception):
    pass


def utc_now() -> str:
    return datetime.now(timezone.utc).isoformat(timespec="seconds").replace("+00:00", "Z")


def private_dir(path: Path) -> None:
    path.mkdir(parents=True, exist_ok=True, mode=0o700)
    path.chmod(0o700)


def write_private(path: Path, content: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True, mode=0o700)
    path.write_text(content, encoding="utf-8")
    path.chmod(0o600)


def write_json(path: Path, payload: Any) -> None:
    write_private(path, json.dumps(payload, indent=2, sort_keys=True) + "\n")


def read_json(path: Path) -> Any:
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except FileNotFoundError as error:
        raise DiagnosticError(f"missing required file: {path}") from error
    except json.JSONDecodeError as error:
        raise DiagnosticError(f"invalid JSON in {path}: {error}") from error


def parse_inline_list(value: str) -> list[str]:
    if not value.startswith("[") or not value.endswith("]"):
        raise DiagnosticError(f"expected inline list, got: {value}")
    inner = value[1:-1].strip()
    if not inner:
        return []
    return [item.strip().strip("'\"") for item in inner.split(",")]


def parse_frontmatter(path: Path) -> tuple[dict[str, Any], str]:
    text = path.read_text(encoding="utf-8")
    if not text.startswith("---\n"):
        raise DiagnosticError(f"missing YAML frontmatter in {path}")
    try:
        raw, body = text[4:].split("\n---\n", 1)
    except ValueError as error:
        raise DiagnosticError(f"unterminated YAML frontmatter in {path}") from error
    fields: dict[str, Any] = {}
    current_key: str | None = None
    for line in raw.splitlines():
        if not line.strip() or line.lstrip().startswith("#"):
            continue
        if line[0].isspace():
            stripped = line.strip()
            if current_key and stripped.startswith("- "):
                if not isinstance(fields[current_key], list):
                    fields[current_key] = []
                fields[current_key].append(stripped[2:].strip().strip("'\""))
            continue
        if ":" not in line:
            raise DiagnosticError(f"unsupported frontmatter line in {path}: {line}")
        key, value = line.split(":", 1)
        current_key = key.strip()
        value = value.strip()
        fields[current_key] = parse_inline_list(value) if value.startswith("[") else value.strip("'\"")
    return fields, body


def source_sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def default_evidence_root() -> Path:
    state = Path(os.environ.get("XDG_STATE_HOME", Path.home() / ".local" / "state"))
    return state / "agent-session-evidence" / "runs"


def default_diagnostic_root() -> Path:
    state = Path(os.environ.get("XDG_STATE_HOME", Path.home() / ".local" / "state"))
    return state / "agent-session-diagnostics" / "runs"


def latest_finished_evidence_run(root: Path) -> Path:
    candidates: list[tuple[str, Path]] = []
    if root.exists():
        for manifest_path in root.glob("*/manifest.json"):
            try:
                manifest = read_json(manifest_path)
            except DiagnosticError:
                continue
            if manifest.get("finished_at") and list(manifest_path.parent.glob("projects/*/cases/*.md")):
                candidates.append((str(manifest["finished_at"]), manifest_path.parent))
    if not candidates:
        raise DiagnosticError(f"no finished evidence run with cases found under {root}")
    return max(candidates)[1]


def inventory_cases(evidence_run: Path) -> tuple[dict[str, Any], list[dict[str, str]], list[str]]:
    evidence_run = evidence_run.expanduser().resolve()
    manifest = read_json(evidence_run / "manifest.json")
    if str(manifest.get("schema_version")) != "1":
        raise DiagnosticError("only evidence bundle schema_version 1 is supported")
    if not manifest.get("finished_at"):
        raise DiagnosticError(f"evidence run is not finished: {evidence_run}")

    inventory: list[dict[str, str]] = []
    seen: set[str] = set()
    for case_path in sorted(evidence_run.glob("projects/*/cases/*.md")):
        fields, _ = parse_frontmatter(case_path)
        case_id = str(fields.get("case_id", ""))
        project_key = str(fields.get("project_key", ""))
        if not CASE_ID_RE.fullmatch(case_id):
            raise DiagnosticError(f"invalid or missing case_id in {case_path}: {case_id}")
        if case_id in seen:
            raise DiagnosticError(f"duplicate case_id in evidence bundle: {case_id}")
        if fields.get("status") != "evidence-only":
            raise DiagnosticError(f"case is not an evidence-only handoff: {case_path}")
        if not project_key:
            raise DiagnosticError(f"missing project_key in {case_path}")
        seen.add(case_id)
        inventory.append(
            {
                "case_id": case_id,
                "project_key": project_key,
                "project_slug": case_path.parents[1].name,
                "source_path": str(case_path.resolve()),
                "relative_path": str(case_path.relative_to(evidence_run)),
                "sha256": source_sha256(case_path),
            }
        )
    if not inventory:
        raise DiagnosticError(f"evidence run contains no case files: {evidence_run}")
    warnings: list[str] = []
    expected = manifest.get("counts", {}).get("cases")
    if expected is not None and int(expected) != len(inventory):
        warnings.append(f"manifest reports {expected} cases but {len(inventory)} case files exist")
    actual_by_project: dict[str, int] = {}
    for record in inventory:
        actual_by_project[record["project_slug"]] = actual_by_project.get(record["project_slug"], 0) + 1
    for project in manifest.get("resolved_projects", []):
        output_path = project.get("output_path")
        project_cases = project.get("counts", {}).get("cases")
        if not output_path or project_cases is None:
            continue
        slug = Path(output_path).name
        actual = actual_by_project.get(slug, 0)
        if int(project_cases) != actual:
            raise DiagnosticError(
                f"project {slug} reports {project_cases} cases but {actual} case files exist"
            )
    return manifest, inventory, warnings


def prepare(args: argparse.Namespace) -> dict[str, Any]:
    evidence_run = (
        Path(args.evidence_run).expanduser().resolve()
        if args.evidence_run
        else latest_finished_evidence_run(default_evidence_root())
    )
    evidence_manifest, all_inventory, input_warnings = inventory_cases(evidence_run)
    case_filters = sorted(set(args.case or []))
    project_filters = sorted(set(args.project or []))
    known_case_ids = {record["case_id"] for record in all_inventory}
    unknown_cases = sorted(set(case_filters) - known_case_ids)
    if unknown_cases:
        raise DiagnosticError(f"unknown case filters: {', '.join(unknown_cases)}")
    unmatched_projects = [
        token
        for token in project_filters
        if not any(
            token == record["project_slug"]
            or token in record["project_key"]
            or token in record["source_path"]
            for record in all_inventory
        )
    ]
    if unmatched_projects:
        raise DiagnosticError(f"unmatched project filters: {', '.join(unmatched_projects)}")
    inventory = [
        record
        for record in all_inventory
        if (not case_filters or record["case_id"] in case_filters)
        and (
            not project_filters
            or any(
                token == record["project_slug"]
                or token in record["project_key"]
                or token in record["source_path"]
                for token in project_filters
            )
        )
    ]
    if not inventory:
        raise DiagnosticError("case and project filters select no evidence cases")
    started_at = utc_now()
    run_id = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ") + "_" + secrets.token_hex(4)
    run_dir = Path(args.output_dir).expanduser().resolve() if args.output_dir else default_diagnostic_root() / run_id
    if run_dir.exists() and any(run_dir.iterdir()):
        raise DiagnosticError(f"output directory is not empty: {run_dir}")
    private_dir(run_dir)

    projects: dict[str, dict[str, Any]] = {}
    for record in inventory:
        project = projects.setdefault(
            record["project_slug"],
            {"project_slug": record["project_slug"], "project_key": record["project_key"], "case_ids": []},
        )
        if project["project_key"] != record["project_key"]:
            raise DiagnosticError(f"project slug maps to multiple project keys: {record['project_slug']}")
        project["case_ids"].append(record["case_id"])
    for slug in sorted(projects):
        private_dir(run_dir / "projects" / slug / "findings")
    private_dir(run_dir / "projects" / "_cross-project" / "findings")

    manifest = {
        "schema_version": 1,
        "run_id": run_id,
        "started_at": started_at,
        "finished_at": None,
        "status": "in_progress",
        "evidence_run": str(evidence_run),
        "evidence_run_id": evidence_manifest.get("run_id"),
        "evidence_manifest_sha256": source_sha256(evidence_run / "manifest.json"),
        "input_warnings": input_warnings,
        "filters": {"cases": case_filters, "projects": project_filters},
        "counts": {"input_cases": len(inventory), "covered_cases": 0, "findings": 0, "projects": len(projects)},
        "projects": [projects[slug] for slug in sorted(projects)],
    }
    write_json(run_dir / "manifest.json", manifest)
    write_private(
        run_dir / "case-inventory.jsonl",
        "".join(json.dumps(item, sort_keys=True) + "\n" for item in inventory),
    )
    return {"run_id": run_id, "run_dir": str(run_dir), "evidence_run": str(evidence_run), "cases": len(inventory)}


def finding_title(body: str, path: Path) -> str:
    for line in body.splitlines():
        if line.startswith("# "):
            title = line[2:].strip()
            if title:
                return title
    raise DiagnosticError(f"missing finding title in {path}")


def validate_finding(path: Path, inventory_by_id: dict[str, dict[str, str]]) -> dict[str, Any]:
    fields, body = parse_frontmatter(path)
    required = {
        "schema_version",
        "finding_id",
        "project_slug",
        "project_key",
        "evidence_cases",
        "preventability",
        "confidence",
        "remedy_target",
        "status",
    }
    missing = sorted(required - fields.keys())
    if missing:
        raise DiagnosticError(f"missing frontmatter fields in {path}: {', '.join(missing)}")
    finding_id = str(fields["finding_id"])
    if not FINDING_ID_RE.fullmatch(finding_id) or path.name != f"{finding_id}.md":
        raise DiagnosticError(f"finding_id must match filename in {path}")
    if str(fields["schema_version"]) != "1":
        raise DiagnosticError(f"unsupported finding schema_version in {path}")
    if fields["preventability"] not in {"yes", "partial", "no"}:
        raise DiagnosticError(f"invalid preventability in {path}: {fields['preventability']}")
    if fields["confidence"] not in {"high", "medium", "low"}:
        raise DiagnosticError(f"invalid confidence in {path}: {fields['confidence']}")
    if fields["remedy_target"] not in REMEDY_TARGETS:
        raise DiagnosticError(f"invalid remedy_target in {path}: {fields['remedy_target']}")
    if fields["status"] != "proposed":
        raise DiagnosticError(f"finding status must be proposed in {path}")
    if fields["preventability"] == "no" and fields["remedy_target"] != "none":
        raise DiagnosticError(f"non-preventable finding must use remedy_target none in {path}")
    if fields["preventability"] != "no" and fields["remedy_target"] == "none":
        raise DiagnosticError(f"preventable finding needs a remedy target in {path}")
    cases = fields["evidence_cases"]
    if not isinstance(cases, list) or not cases:
        raise DiagnosticError(f"evidence_cases must be a non-empty inline list in {path}")
    unknown = sorted(set(cases) - inventory_by_id.keys())
    if unknown:
        raise DiagnosticError(f"unknown evidence cases in {path}: {', '.join(unknown)}")
    expected_slug = path.parents[1].name
    if fields["project_slug"] != expected_slug:
        raise DiagnosticError(f"project_slug does not match directory in {path}")
    if fields["project_slug"] == "_cross-project":
        if fields["project_key"] != "_cross-project":
            raise DiagnosticError(f"cross-project finding must use project_key _cross-project in {path}")
        source_projects = {inventory_by_id[case_id]["project_slug"] for case_id in cases}
        if len(source_projects) < 2 and "_cross-project" not in source_projects:
            raise DiagnosticError(f"cross-project finding must cite cases from at least two projects in {path}")
        if fields["remedy_target"] not in {"global-agents", "skill", "harness", "system", "none"}:
            raise DiagnosticError(f"invalid cross-project remedy target in {path}: {fields['remedy_target']}")
    else:
        for case_id in cases:
            source = inventory_by_id[case_id]
            if source["project_slug"] != fields["project_slug"] or source["project_key"] != fields["project_key"]:
                raise DiagnosticError(f"finding crosses project boundary in {path}: {case_id}")
    missing_sections = [section for section in REQUIRED_SECTIONS if f"## {section}" not in body]
    if missing_sections:
        raise DiagnosticError(f"missing sections in {path}: {', '.join(missing_sections)}")
    return {
        **fields,
        "title": finding_title(body, path),
        "path": str(path),
        "evidence_cases": cases,
    }


def markdown_table_cell(value: str) -> str:
    return value.replace("|", "\\|").replace("\n", " ")


def finalize(args: argparse.Namespace) -> dict[str, Any]:
    run_dir = Path(args.run_dir).expanduser().resolve()
    manifest = read_json(run_dir / "manifest.json")
    if manifest.get("status") not in {"in_progress", "complete"}:
        raise DiagnosticError(f"diagnostic run has invalid status: {manifest.get('status')}")
    inventory_path = run_dir / "case-inventory.jsonl"
    try:
        inventory_lines = inventory_path.read_text(encoding="utf-8").splitlines()
    except FileNotFoundError as error:
        raise DiagnosticError(f"missing required file: {inventory_path}") from error
    inventory = [json.loads(line) for line in inventory_lines if line.strip()]
    inventory_by_id = {item["case_id"]: item for item in inventory}
    findings: list[dict[str, Any]] = []
    seen_finding_ids: set[str] = set()
    for path in sorted(run_dir.glob("projects/*/findings/*.md")):
        finding = validate_finding(path, inventory_by_id)
        if finding["finding_id"] in seen_finding_ids:
            raise DiagnosticError(f"duplicate finding_id: {finding['finding_id']}")
        seen_finding_ids.add(finding["finding_id"])
        findings.append(finding)
    if not findings:
        raise DiagnosticError("diagnostic run has no finding files")
    covered = {case_id for finding in findings for case_id in finding["evidence_cases"]}
    uncovered = sorted(inventory_by_id.keys() - covered)
    if uncovered:
        raise DiagnosticError(f"uncovered evidence cases: {', '.join(uncovered)}")
    for finding in findings:
        Path(finding["path"]).chmod(0o600)

    by_project: dict[str, list[dict[str, Any]]] = {}
    for finding in findings:
        by_project.setdefault(finding["project_slug"], []).append(finding)
    index_projects_by_slug = {project["project_slug"]: dict(project) for project in manifest["projects"]}
    if by_project.get("_cross-project"):
        cross_cases = sorted(
            {case_id for finding in by_project["_cross-project"] for case_id in finding["evidence_cases"]}
        )
        cross_project = index_projects_by_slug.setdefault(
            "_cross-project",
            {"project_slug": "_cross-project", "project_key": "_cross-project", "case_ids": []},
        )
        cross_project["case_ids"] = sorted(set(cross_project["case_ids"]) | set(cross_cases))
    index_projects = [index_projects_by_slug[slug] for slug in sorted(index_projects_by_slug)]
    for project in index_projects:
        slug = project["project_slug"]
        rows = by_project.get(slug, [])
        lines = [
            f"# Diagnostics for {slug}",
            "",
            f"Project key: `{project['project_key']}`",
            "",
            "| Finding | Preventability | Confidence | Remedy target | Evidence cases |",
            "|---|---|---|---|---|",
        ]
        for finding in rows:
            relative = f"findings/{finding['finding_id']}.md"
            lines.append(
                "| "
                + f"[{markdown_table_cell(finding['title'])}]({relative}) (`{finding['finding_id']}`) | "
                + f"{finding['preventability']} | {finding['confidence']} | {finding['remedy_target']} | "
                + ", ".join(f"`{case_id}`" for case_id in finding["evidence_cases"])
                + " |"
            )
        write_private(run_dir / "projects" / slug / "index.md", "\n".join(lines) + "\n")

    root_lines = [
        "# Agent session diagnostics",
        "",
        f"Evidence run: `{manifest['evidence_run_id']}`",
        "",
        "| Project | Cases | Findings |",
        "|---|---:|---:|",
    ]
    for project in index_projects:
        slug = project["project_slug"]
        root_lines.append(
            f"| [{slug}](projects/{slug}/index.md) | {len(project['case_ids'])} | {len(by_project.get(slug, []))} |"
        )
    write_private(run_dir / "index.md", "\n".join(root_lines) + "\n")

    manifest["finished_at"] = utc_now()
    manifest["status"] = "complete"
    manifest["counts"].update({"covered_cases": len(covered), "findings": len(findings)})
    write_json(run_dir / "manifest.json", manifest)
    return {"run_dir": str(run_dir), "findings": len(findings), "covered_cases": len(covered)}

def finding_id(args: argparse.Namespace) -> dict[str, str]:
    case_ids = sorted(set(args.case_id))
    invalid = [case_id for case_id in case_ids if not CASE_ID_RE.fullmatch(case_id)]
    if invalid:
        raise DiagnosticError(f"invalid case IDs: {', '.join(invalid)}")
    if args.remedy_target not in REMEDY_TARGETS:
        raise DiagnosticError(f"invalid remedy target: {args.remedy_target}")
    root_cause_key = " ".join(args.root_cause_key.lower().split())
    if not root_cause_key:
        raise DiagnosticError("root-cause-key must not be empty")
    identity = json.dumps(
        {
            "case_ids": case_ids,
            "remedy_target": args.remedy_target,
            "root_cause_key": root_cause_key,
        },
        sort_keys=True,
        separators=(",", ":"),
    )
    return {"finding_id": "finding_" + hashlib.sha256(identity.encode()).hexdigest()[:12]}



def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    subparsers = parser.add_subparsers(dest="command", required=True)
    prepare_parser = subparsers.add_parser("prepare", help="Create a diagnostic run from a finished evidence bundle")
    prepare_parser.add_argument("--evidence-run", help="Evidence run directory; defaults to the latest finished run")
    prepare_parser.add_argument("--output-dir", help="Explicit diagnostic output directory")
    prepare_parser.add_argument("--project", action="append", help="Project slug, key fragment, or path filter")
    prepare_parser.add_argument("--case", action="append", help="Exact evidence case ID filter")
    prepare_parser.set_defaults(handler=prepare)
    finalize_parser = subparsers.add_parser("finalize", help="Validate findings, require case coverage, and write indexes")
    finalize_parser.add_argument("--run-dir", required=True, help="Diagnostic run directory")
    finalize_parser.set_defaults(handler=finalize)
    id_parser = subparsers.add_parser("id", help="Derive a stable finding ID")
    id_parser.add_argument("--case-id", action="append", required=True, help="Contributing evidence case ID")
    id_parser.add_argument("--root-cause-key", required=True, help="Short normalized root-cause identity")
    id_parser.add_argument("--remedy-target", required=True, help="Final remedy target")
    id_parser.set_defaults(handler=finding_id)
    return parser


def main() -> int:
    try:
        args = build_parser().parse_args()
        print(json.dumps(args.handler(args), sort_keys=True))
        return 0
    except (DiagnosticError, OSError, ValueError, json.JSONDecodeError) as error:
        print(f"error: {error}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
