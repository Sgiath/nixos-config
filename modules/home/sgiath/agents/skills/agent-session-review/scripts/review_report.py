#!/usr/bin/env python3
"""Generate and serve a private review page for agent-session diagnostics."""

from __future__ import annotations

import argparse
from datetime import datetime, timezone
import hashlib
import html
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import json
import os
from pathlib import Path
import re
import secrets
import sys
from typing import Any
from review_state import (
    ReviewStateError,
    default_state_path,
    load_state,
    read_json,
    state_root,
    with_locked_state,
    write_private,
)
from urllib.parse import urlparse


FINDING_ID_RE = re.compile(r"finding_[0-9a-f]{12}$")
CASE_ID_RE = re.compile(r"case_[0-9a-f]{12}$")
REMEDY_ORDER = [
    "project-code",
    "project-config",
    "project-tooling",
    "project-agents",
    "skill",
    "harness",
    "system",
    "global-agents",
    "none",
]
TEMPLATE_PATH = Path(__file__).parents[1] / "references" / "report-template.html"


class ReviewError(Exception):
    pass


def utc_now() -> str:
    return datetime.now(timezone.utc).isoformat(timespec="seconds").replace("+00:00", "Z")

def default_diagnostic_root() -> Path:
    root = Path(os.environ.get("XDG_STATE_HOME", Path.home() / ".local" / "state"))
    return root / "agent-session-diagnostics" / "runs"




def parse_inline_list(value: str) -> list[str]:
    if not value.startswith("[") or not value.endswith("]"):
        raise ReviewError(f"expected inline list, got: {value}")
    inner = value[1:-1].strip()
    if not inner:
        return []
    return [item.strip().strip("'\"") for item in inner.split(",")]


def parse_finding(path: Path) -> dict[str, Any]:
    try:
        text = path.read_text(encoding="utf-8")
    except FileNotFoundError as error:
        raise ReviewError(f"missing finding: {path}") from error
    lines = text.splitlines()
    if not lines or lines[0] != "---":
        raise ReviewError(f"missing frontmatter in {path}")
    try:
        end = lines.index("---", 1)
    except ValueError as error:
        raise ReviewError(f"unterminated frontmatter in {path}") from error
    fields: dict[str, Any] = {}
    for line in lines[1:end]:
        if not line.strip():
            continue
        if ":" not in line:
            raise ReviewError(f"invalid frontmatter line in {path}: {line}")
        key, value = line.split(":", 1)
        value = value.strip()
        fields[key.strip()] = parse_inline_list(value) if value.startswith("[") else value.strip("'\"")
    body = "\n".join(lines[end + 1 :]).strip()
    title = next((line[2:].strip() for line in body.splitlines() if line.startswith("# ")), "")
    required = {
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
        raise ReviewError(f"missing finding fields in {path}: {', '.join(missing)}")
    finding_id = str(fields["finding_id"])
    if not FINDING_ID_RE.fullmatch(finding_id) or path.name != f"{finding_id}.md":
        raise ReviewError(f"finding ID does not match filename: {path}")
    cases = fields["evidence_cases"]
    if not isinstance(cases, list) or not cases or any(not CASE_ID_RE.fullmatch(str(case)) for case in cases):
        raise ReviewError(f"invalid evidence_cases in {path}")
    if not title:
        raise ReviewError(f"missing finding title in {path}")
    return {
        **fields,
        "title": title,
        "body": body,
        "path": str(path.resolve()),
        "sha256": hashlib.sha256(text.encode("utf-8")).hexdigest(),
    }


def latest_complete_run(root: Path | None = None) -> Path:
    candidates: list[tuple[str, Path]] = []
    search_root = root or default_diagnostic_root()
    if search_root.exists():
        for manifest_path in search_root.glob("*/manifest.json"):
            try:
                manifest = read_json(manifest_path)
            except ReviewError:
                continue
            if manifest.get("status") == "complete" and manifest.get("finished_at"):
                candidates.append((str(manifest["finished_at"]), manifest_path.parent.resolve()))
    if not candidates:
        raise ReviewError(f"no completed diagnostic run found under {search_root}")
    return max(candidates)[1]


def load_run(run_path: str | Path | None) -> dict[str, Any]:
    run_dir = Path(run_path).expanduser().resolve() if run_path else latest_complete_run()
    manifest = read_json(run_dir / "manifest.json")
    if str(manifest.get("schema_version")) != "1":
        raise ReviewError(f"unsupported diagnostic schema in {run_dir}")
    if manifest.get("status") != "complete" or not manifest.get("finished_at"):
        raise ReviewError(f"diagnostic run is not complete: {run_dir}")

    inventory_path = run_dir / "case-inventory.jsonl"
    try:
        inventory = [
            json.loads(line)
            for line in inventory_path.read_text(encoding="utf-8").splitlines()
            if line.strip()
        ]
    except FileNotFoundError as error:
        raise ReviewError(f"missing required file: {inventory_path}") from error
    except json.JSONDecodeError as error:
        raise ReviewError(f"invalid JSONL in {inventory_path}: {error}") from error
    cases = {str(record.get("case_id")): record for record in inventory}
    if not cases:
        raise ReviewError(f"diagnostic run has no evidence inventory: {run_dir}")

    findings = [parse_finding(path) for path in sorted(run_dir.glob("projects/*/findings/*.md"))]
    if not findings:
        raise ReviewError(f"diagnostic run has no findings: {run_dir}")
    seen: set[str] = set()
    for finding in findings:
        finding_id = finding["finding_id"]
        if finding_id in seen:
            raise ReviewError(f"duplicate finding ID: {finding_id}")
        seen.add(finding_id)
        unknown = sorted(set(finding["evidence_cases"]) - cases.keys())
        if unknown:
            raise ReviewError(f"finding {finding_id} cites unknown cases: {', '.join(unknown)}")
        expected_slug = Path(finding["path"]).parents[1].name
        if finding["project_slug"] != expected_slug:
            raise ReviewError(f"finding project does not match its directory: {finding['path']}")

    return {
        "run_dir": run_dir,
        "manifest": manifest,
        "inventory": cases,
        "findings": findings,
    }




def mark_fixed(run: dict[str, Any], finding_id: str, state_path: Path) -> dict[str, Any]:
    findings_by_id = {finding["finding_id"]: finding for finding in run["findings"]}
    if finding_id not in findings_by_id:
        raise ReviewError(f"unknown finding ID in diagnostic run: {finding_id}")
    finding = findings_by_id[finding_id]

    def update(state: dict[str, Any]) -> dict[str, Any]:
        now = utc_now()
        existing = state["findings"].get(finding_id)
        fixed_at = existing["fixed_at"] if existing else now
        state["findings"][finding_id] = {
            "status": "fixed",
            "fixed_at": fixed_at,
            "diagnostic_run_id": run["manifest"]["run_id"],
            "diagnostic_run": str(run["run_dir"]),
            "finding_path": finding["path"],
            "finding_sha256": finding["sha256"],
            "evidence_cases": finding["evidence_cases"],
        }
        fixed_ids = {
            key for key, value in state["findings"].items() if value.get("status") == "fixed"
        }
        fixed_cases: list[str] = []
        for case_id in sorted(run["inventory"]):
            citing = sorted(
                item["finding_id"]
                for item in run["findings"]
                if case_id in item["evidence_cases"]
            )
            if citing and set(citing).issubset(fixed_ids):
                case_record = run["inventory"][case_id]
                state["cases"].setdefault(
                    case_id,
                    {
                        "status": "fixed",
                        "fixed_at": now,
                        "diagnostic_run_id": run["manifest"]["run_id"],
                        "evidence_run_id": run["manifest"].get("evidence_run_id"),
                        "source_path": case_record.get("source_path"),
                        "source_sha256": case_record.get("sha256"),
                        "finding_ids": citing,
                    },
                )
                fixed_cases.append(case_id)
        return {"finding_id": finding_id, "fixed_at": fixed_at, "fixed_cases": fixed_cases}

    return with_locked_state(state_path, update)


def remedy_sort_key(target: str) -> tuple[int, str]:
    try:
        return REMEDY_ORDER.index(target), target
    except ValueError:
        return len(REMEDY_ORDER), target


def render_html(run: dict[str, Any], state: dict[str, Any], token: str | None) -> str:
    findings = run["findings"]
    fixed_ids = {
        finding_id
        for finding_id, record in state["findings"].items()
        if record.get("status") == "fixed"
    }
    projects: dict[str, dict[str, list[dict[str, Any]]]] = {}
    for finding in findings:
        projects.setdefault(finding["project_slug"], {}).setdefault(finding["remedy_target"], []).append(finding)

    target_counts: dict[str, int] = {}
    for finding in findings:
        target_counts[finding["remedy_target"]] = target_counts.get(finding["remedy_target"], 0) + 1

    project_sections: list[str] = []
    project_order = sorted(projects, key=lambda slug: (slug != "_cross-project", slug))
    for project_slug in project_order:
        groups: list[str] = []
        for target in sorted(projects[project_slug], key=remedy_sort_key):
            cards: list[str] = []
            for finding in sorted(projects[project_slug][target], key=lambda item: item["title"].lower()):
                finding_id = finding["finding_id"]
                is_fixed = finding_id in fixed_ids
                prompt = f"Fix this issue {finding['path']}"
                cases = " ".join(
                    f'<code class="case-id">{html.escape(case_id)}</code>'
                    for case_id in finding["evidence_cases"]
                )
                fixed_class = " is-fixed" if is_fixed else ""
                fixed_badge = "" if not is_fixed else '<span class="badge badge-fixed">fixed</span>'
                button_label = "Fixed" if is_fixed else "Mark fixed"
                disabled = " disabled" if is_fixed or token is None else ""
                cards.append(
                    f'''<details class="finding{fixed_class}" data-id="{html.escape(finding_id)}" data-target="{html.escape(target)}" data-status="{'fixed' if is_fixed else 'open'}">
  <summary class="finding-row">
    <span class="badge badge-prev-{html.escape(finding['preventability'])}">{html.escape(finding['preventability'])}</span>
    <span class="finding-title">{html.escape(finding['title'])}</span>
    <span class="badge badge-confidence">conf:{html.escape(finding['confidence'])}</span>
    {fixed_badge}
  </summary>
  <div class="finding-detail">
    <dl class="metadata">
      <div><dt>Finding</dt><dd><code>{html.escape(finding_id)}</code></dd></div>
      <div><dt>Evidence</dt><dd>{cases}</dd></div>
      <div><dt>Path</dt><dd><code>{html.escape(finding['path'])}</code></dd></div>
    </dl>
    <div class="finding-actions">
      <button type="button" class="button button-primary" data-action="copy" data-prompt="{html.escape(prompt, quote=True)}">Copy fix prompt</button>
      <button type="button" class="button" data-action="mark-fixed"{disabled}>{button_label}</button>
      <span class="action-status" role="status" aria-live="polite"></span>
    </div>
    <pre class="finding-body">{html.escape(finding['body'])}</pre>
  </div>
</details>'''
                )
            groups.append(
                f'''<section class="target-group" data-group-target="{html.escape(target)}">
  <h3>{html.escape(target)} <span>{len(cards)}</span></h3>
  {''.join(cards)}
</section>'''
            )
        project_sections.append(
            f'''<section class="project" id="project-{html.escape(project_slug)}">
  <header class="project-header"><h2>{html.escape(project_slug)}</h2><span>{sum(len(items) for items in projects[project_slug].values())} findings</span></header>
  {''.join(groups)}
</section>'''
        )

    target_filters = "".join(
        f'''<label><input type="checkbox" name="target" value="{html.escape(target)}" checked> {html.escape(target)} <span>{count}</span></label>'''
        for target, count in sorted(target_counts.items(), key=lambda item: remedy_sort_key(item[0]))
    )
    project_links = "".join(
        f'<a href="#project-{html.escape(slug)}">{html.escape(slug)} <span>{sum(len(items) for items in projects[slug].values())}</span></a>'
        for slug in project_order
    )
    run_id = str(run["manifest"]["run_id"])
    fixed_count = len(set(finding["finding_id"] for finding in findings) & fixed_ids)
    static_notice = (
        ""
        if token
        else '<p class="notice">Open this report through the local server to mark findings fixed.</p>'
    )
    try:
        template = TEMPLATE_PATH.read_text(encoding="utf-8")
    except FileNotFoundError as error:
        raise ReviewError(f"missing report template: {TEMPLATE_PATH}") from error
    replacements = {
        "__RUN_ID__": html.escape(run_id),
        "__FINDING_COUNT__": str(len(findings)),
        "__FIXED_COUNT__": str(fixed_count),
        "__PROJECT_COUNT__": str(len(projects)),
        "__STATIC_NOTICE__": static_notice,
        "__TARGET_FILTERS__": target_filters,
        "__PROJECT_LINKS__": project_links,
        "__PROJECT_SECTIONS__": "".join(project_sections),
        "__CSRF_TOKEN__": json.dumps(token or ""),
    }
    for marker, value in replacements.items():
        template = template.replace(marker, value)
    return template


def report_path_for(run: dict[str, Any]) -> Path:
    return state_root() / "reports" / str(run["manifest"]["run_id"]) / "index.html"


def generate(run: dict[str, Any], output: Path, state_path: Path, token: str | None = None) -> dict[str, Any]:
    state = load_state(state_path)
    write_private(output, render_html(run, state, token))
    return {
        "report_path": str(output),
        "run_dir": str(run["run_dir"]),
        "findings": len(run["findings"]),
        "projects": len({finding["project_slug"] for finding in run["findings"]}),
        "fixed": len(set(state["findings"]) & {finding["finding_id"] for finding in run["findings"]}),
    }


class ReviewServer(ThreadingHTTPServer):
    daemon_threads = True

    def __init__(self, address: tuple[str, int], run: dict[str, Any], state_path: Path, report_path: Path, token: str):
        super().__init__(address, ReviewHandler)
        self.run_data = run
        self.state_path = state_path
        self.report_path = report_path
        self.review_token = token

    def current_html(self) -> str:
        return render_html(self.run_data, load_state(self.state_path), self.review_token)


class ReviewHandler(BaseHTTPRequestHandler):
    server: ReviewServer

    def log_message(self, format_string: str, *args: Any) -> None:
        print(f"review server: {self.address_string()} {format_string % args}", file=sys.stderr)

    def send_body(self, status: int, body: bytes, content_type: str) -> None:
        self.send_response(status)
        self.send_header("Content-Type", content_type)
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Cache-Control", "no-store")
        self.send_header("Content-Security-Policy", "default-src 'self'; style-src 'unsafe-inline'; script-src 'unsafe-inline'; connect-src 'self'; frame-ancestors 'none'")
        self.send_header("X-Content-Type-Options", "nosniff")
        self.send_header("X-Frame-Options", "DENY")
        self.end_headers()
        self.wfile.write(body)

    def send_json(self, status: int, payload: dict[str, Any]) -> None:
        self.send_body(status, json.dumps(payload, sort_keys=True).encode("utf-8"), "application/json; charset=utf-8")

    def do_GET(self) -> None:
        if urlparse(self.path).path not in {"/", "/index.html"}:
            self.send_json(404, {"error": "not found"})
            return
        body = self.server.current_html().encode("utf-8")
        self.send_body(200, body, "text/html; charset=utf-8")

    def do_POST(self) -> None:
        match = re.fullmatch(r"/api/findings/(finding_[0-9a-f]{12})/fixed", urlparse(self.path).path)
        if not match:
            self.send_json(404, {"error": "not found"})
            return
        if not secrets.compare_digest(self.headers.get("X-Review-Token", ""), self.server.review_token):
            self.send_json(403, {"error": "invalid review token"})
            return
        try:
            result = mark_fixed(self.server.run_data, match.group(1), self.server.state_path)
            write_private(self.server.report_path, self.server.current_html())
            print(f"marked fixed: {match.group(1)}", file=sys.stderr)
            self.send_json(200, result)
        except (ReviewError, ReviewStateError, OSError, ValueError) as error:
            print(f"mark fixed failed for {match.group(1)}: {error}", file=sys.stderr)
            self.send_json(400, {"error": str(error)})


def command_generate(args: argparse.Namespace) -> dict[str, Any]:
    run = load_run(args.diagnostic_run)
    output = Path(args.output).expanduser().resolve() if args.output else report_path_for(run)
    return generate(run, output, Path(args.state).expanduser().resolve())


def command_mark_fixed(args: argparse.Namespace) -> dict[str, Any]:
    run = load_run(args.diagnostic_run)
    return mark_fixed(run, args.finding_id, Path(args.state).expanduser().resolve())


def command_serve(args: argparse.Namespace) -> None:
    run = load_run(args.diagnostic_run)
    state_path = Path(args.state).expanduser().resolve()
    report_path = Path(args.output).expanduser().resolve() if args.output else report_path_for(run)
    token = secrets.token_urlsafe(24)
    server = ReviewServer(("127.0.0.1", args.port), run, state_path, report_path, token)
    generate(run, report_path, state_path, token)
    host, port = server.server_address
    ready = {
        "url": f"http://{host}:{port}/",
        "report_path": str(report_path),
        "run_dir": str(run["run_dir"]),
        "findings": len(run["findings"]),
    }
    print(json.dumps(ready, sort_keys=True), flush=True)
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass
    finally:
        server.server_close()
        print("review server stopped", file=sys.stderr)


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--state", default=str(default_state_path()), help="durable review state JSON")
    subparsers = parser.add_subparsers(dest="command", required=True)

    generate_parser = subparsers.add_parser("generate", help="write a standalone read-only HTML report")
    generate_parser.add_argument("--diagnostic-run", help="completed diagnostic run; defaults to latest")
    generate_parser.add_argument("--output", help="HTML output path")
    generate_parser.set_defaults(handler=command_generate)

    fixed_parser = subparsers.add_parser("mark-fixed", help="mark one finding and fully handled evidence fixed")
    fixed_parser.add_argument("--diagnostic-run", help="completed diagnostic run; defaults to latest")
    fixed_parser.add_argument("--finding-id", required=True)
    fixed_parser.set_defaults(handler=command_mark_fixed)
    serve_parser = subparsers.add_parser("serve", help="serve the interactive review page on loopback")
    serve_parser.add_argument("--diagnostic-run", help="completed diagnostic run; defaults to latest")
    serve_parser.add_argument("--output", help="HTML snapshot output path")
    serve_parser.add_argument("--port", type=int, default=0, help="loopback port; 0 chooses a free port")
    serve_parser.set_defaults(handler=command_serve)
    return parser


def main() -> int:
    os.umask(0o077)
    try:
        args = build_parser().parse_args()
        result = args.handler(args)
        if result is not None:
            print(json.dumps(result, sort_keys=True))
        return 0
    except (ReviewError, ReviewStateError, OSError, ValueError, json.JSONDecodeError) as error:
        print(f"error: {error}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
