#!/usr/bin/env python3
"""Manage the agent-session-evidence ledger through a small JSONL interface."""

import argparse
from datetime import datetime, timezone
import json
import os
from pathlib import Path
import secrets
import sqlite3
import sys


LEDGER_SCHEMA_VERSION = 1
DEFAULT_DETECTION_SCHEMA_VERSION = 1
SOURCE_STATUSES = {"no_signal", "candidate", "bundled", "partial", "failed"}
RUN_STATUSES = {"completed", "partial", "failed"}

SCHEMA_PATH = Path(__file__).with_name("ledger_schema.sql")


class UsageError(Exception):
    pass


def utc_now():
    return datetime.now(timezone.utc).isoformat().replace("+00:00", "Z")


def default_db_path():
    state_home = os.environ.get("XDG_STATE_HOME")
    root = Path(state_home) if state_home else Path.home() / ".local" / "state"
    return root / "agent-session-evidence" / "ledger.sqlite"


def canonical_json(value):
    return json.dumps(value, ensure_ascii=False, separators=(",", ":"), sort_keys=True)


def parse_json_argument(value, name, expected_type):
    try:
        parsed = json.loads(value)
    except json.JSONDecodeError as error:
        raise UsageError(f"{name} is not valid JSON: {error.msg}") from error
    if not isinstance(parsed, expected_type):
        types = expected_type if isinstance(expected_type, tuple) else (expected_type,)
        names = " or ".join(item.__name__ for item in types)
        raise UsageError(f"{name} must decode to {names}")
    return parsed


def read_records(path):
    if path == "-":
        stream = sys.stdin
        close_stream = False
    else:
        try:
            stream = open(path, "r", encoding="utf-8")
        except OSError as error:
            raise UsageError(f"cannot open input {path}: {error}") from error
        close_stream = True

    records = []
    try:
        for line_number, line in enumerate(stream, 1):
            if not line.strip():
                continue
            try:
                record = json.loads(line)
            except json.JSONDecodeError as error:
                raise UsageError(
                    f"input line {line_number} is not valid JSON: {error.msg}"
                ) from error
            if not isinstance(record, dict):
                raise UsageError(f"input line {line_number} must contain a JSON object")
            records.append(record)
    finally:
        if close_stream:
            stream.close()
    return records


def emit(record):
    print(canonical_json(record))


def require_text(record, field):
    value = record.get(field)
    if not isinstance(value, str) or not value:
        raise UsageError(f"{record.get('kind', 'record')} requires non-empty {field}")
    return value


def require_kind(record):
    kind = record.get("kind")
    if kind not in {"source_item", "context_file"}:
        raise UsageError("record kind must be source_item or context_file")
    return kind


def prepare_database(path):
    path = path.expanduser().resolve()
    path.parent.mkdir(parents=True, exist_ok=True, mode=0o700)
    os.chmod(path.parent, 0o700)
    connection = sqlite3.connect(path, timeout=30)
    connection.row_factory = sqlite3.Row
    connection.execute("PRAGMA busy_timeout=30000")
    connection.execute("PRAGMA foreign_keys=ON")
    connection.execute("PRAGMA journal_mode=WAL")
    connection.execute("PRAGMA synchronous=NORMAL")
    connection.executescript(SCHEMA_PATH.read_text(encoding="utf-8"))

    columns = {
        row["name"] for row in connection.execute("PRAGMA table_info(context_files)")
    }
    if "schema_version" not in columns:
        connection.execute(
            "ALTER TABLE context_files ADD COLUMN schema_version INTEGER NOT NULL DEFAULT 1"
        )

    connection.executemany(
        "INSERT OR IGNORE INTO meta(key, value) VALUES (?, ?)",
        [
            ("ledger_schema_version", str(LEDGER_SCHEMA_VERSION)),
            ("detection_schema_version", str(DEFAULT_DETECTION_SCHEMA_VERSION)),
        ],
    )
    connection.commit()
    os.chmod(path, 0o600)
    return connection, path


def grouped_counts(connection, table):
    return {
        row["status"]: row["count"]
        for row in connection.execute(
            f"SELECT status, COUNT(*) AS count FROM {table} GROUP BY status ORDER BY status"
        )
    }


def command_init(connection, db_path, _args):
    emit(
        {
            "db": str(db_path),
            "schema_version": LEDGER_SCHEMA_VERSION,
            "detection_schema_version": DEFAULT_DETECTION_SCHEMA_VERSION,
        }
    )


def command_status(connection, db_path, _args):
    emit(
        {
            "db": str(db_path),
            "runs": grouped_counts(connection, "runs"),
            "source_items": grouped_counts(connection, "source_items"),
            "context_files": grouped_counts(connection, "context_files"),
        }
    )


def command_start_run(connection, _db_path, args):
    filters = parse_json_argument(args.filters_json, "--filters-json", dict)
    run_id = args.run_id or (
        datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ") + "_" + secrets.token_hex(4)
    )
    output_dir = Path(args.output_dir).expanduser().resolve()
    output_dir.mkdir(parents=True, exist_ok=True, mode=0o700)
    os.chmod(output_dir, 0o700)
    started_at = utc_now()
    try:
        connection.execute(
            """
            INSERT INTO runs(
              run_id, started_at, schema_version, filters_json, output_dir, status
            ) VALUES (?, ?, ?, ?, ?, 'running')
            """,
            (
                run_id,
                started_at,
                args.schema_version,
                canonical_json(filters),
                str(output_dir),
            ),
        )
        connection.commit()
    except sqlite3.IntegrityError as error:
        raise UsageError(f"run already exists: {run_id}") from error
    emit(
        {
            "run_id": run_id,
            "started_at": started_at,
            "output_dir": str(output_dir),
            "status": "running",
        }
    )


def pending_source(connection, record, schema_version, reprocess):
    require_text(record, "harness")
    require_text(record, "session_id")
    require_text(record, "raw_locator")
    fingerprint = require_text(record, "fingerprint")
    if reprocess:
        return "reprocess"
    if record.get("active"):
        return "active"
    row = connection.execute(
        """
        SELECT fingerprint, status, schema_version
        FROM source_items
        WHERE harness = ? AND session_id = ? AND raw_locator = ?
        """,
        (record["harness"], record["session_id"], record["raw_locator"]),
    ).fetchone()
    if row is None:
        return "new"
    if row["fingerprint"] != fingerprint:
        return "fingerprint_changed"
    if row["status"] in {"partial", "failed", "candidate"}:
        return row["status"]
    if row["schema_version"] != schema_version:
        return "schema_changed"
    return None


def pending_context(connection, record, schema_version, reprocess):
    require_text(record, "project_key")
    require_text(record, "path")
    fingerprint = require_text(record, "fingerprint")
    if reprocess:
        return "reprocess"
    row = connection.execute(
        """
        SELECT fingerprint, status, schema_version
        FROM context_files
        WHERE project_key = ? AND path = ?
        """,
        (record["project_key"], record["path"]),
    ).fetchone()
    if row is None:
        return "new"
    if row["fingerprint"] != fingerprint:
        return "fingerprint_changed"
    if row["status"] in {"partial", "failed", "candidate"}:
        return row["status"]
    if row["schema_version"] != schema_version:
        return "schema_changed"
    return None


def command_pending(connection, _db_path, args):
    records = read_records(args.input)
    for record in records:
        kind = require_kind(record)
        if kind == "source_item":
            reason = pending_source(
                connection, record, args.schema_version, args.reprocess
            )
        else:
            reason = pending_context(
                connection, record, args.schema_version, args.reprocess
            )
        if reason:
            emit({**record, "pending_reason": reason})


def get_running_output_dir(connection, run_id):
    row = connection.execute(
        "SELECT output_dir, status FROM runs WHERE run_id = ?", (run_id,)
    ).fetchone()
    if row is None:
        raise UsageError(f"unknown run: {run_id}")
    if row["status"] != "running":
        raise UsageError(f"run is not running: {run_id}")
    return Path(row["output_dir"]).resolve()


def validate_durable_paths(record, output_dir):
    status = record.get("status")
    paths = record.get("durable_paths", [])
    if paths is None:
        paths = []
    if not isinstance(paths, list) or any(not isinstance(path, str) for path in paths):
        raise UsageError("durable_paths must be an array of strings")
    if status in {"candidate", "bundled"} and not paths:
        raise UsageError(f"{status} records require durable_paths")
    for relative in paths:
        path = Path(relative)
        if path.is_absolute():
            raise UsageError(f"durable path must be relative to the run output: {relative}")
        resolved = (output_dir / path).resolve()
        try:
            resolved.relative_to(output_dir)
        except ValueError as error:
            raise UsageError(f"durable path escapes the run output: {relative}") from error
        if not resolved.is_file():
            raise UsageError(f"durable file does not exist: {relative}")


def validate_checkpoint_record(record, output_dir):
    kind = require_kind(record)
    status = record.get("status")
    if status not in SOURCE_STATUSES:
        raise UsageError(f"invalid checkpoint status: {status}")
    require_text(record, "fingerprint")
    if kind == "source_item":
        require_text(record, "harness")
        require_text(record, "session_id")
        require_text(record, "raw_locator")
        if record.get("active") and status != "partial":
            raise UsageError("an active source_item must have partial status")
        case_ids = record.get("case_ids", [])
        if not isinstance(case_ids, list) or any(
            not isinstance(case_id, str) for case_id in case_ids
        ):
            raise UsageError("case_ids must be an array of strings")
        if status == "bundled" and not case_ids:
            raise UsageError("bundled source_item requires case_ids")
    else:
        require_text(record, "project_key")
        require_text(record, "path")
        linked = record.get("linked_session_ids", [])
        if not isinstance(linked, list) or any(
            not isinstance(session_id, str) for session_id in linked
        ):
            raise UsageError("linked_session_ids must be an array of strings")
    validate_durable_paths(record, output_dir)


def checkpoint_source(connection, record, run_id, schema_version, processed_at):
    connection.execute(
        """
        INSERT INTO source_items(
          harness, session_id, raw_locator, fingerprint, project_key,
          started_at, ended_at, active, status, schema_version, processed_at,
          last_run_id, case_ids_json, error
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        ON CONFLICT(harness, session_id, raw_locator) DO UPDATE SET
          fingerprint = excluded.fingerprint,
          project_key = excluded.project_key,
          started_at = excluded.started_at,
          ended_at = excluded.ended_at,
          active = excluded.active,
          status = excluded.status,
          schema_version = excluded.schema_version,
          processed_at = excluded.processed_at,
          last_run_id = excluded.last_run_id,
          case_ids_json = excluded.case_ids_json,
          error = excluded.error
        """,
        (
            record["harness"],
            record["session_id"],
            record["raw_locator"],
            record["fingerprint"],
            record.get("project_key"),
            record.get("started_at"),
            record.get("ended_at"),
            int(bool(record.get("active"))),
            record["status"],
            schema_version,
            processed_at,
            run_id,
            canonical_json(record.get("case_ids", [])),
            record.get("error"),
        ),
    )


def checkpoint_context(connection, record, run_id, schema_version, processed_at):
    connection.execute(
        """
        INSERT INTO context_files(
          project_key, path, fingerprint, status, schema_version, processed_at,
          last_run_id, linked_session_ids_json, error
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
        ON CONFLICT(project_key, path) DO UPDATE SET
          fingerprint = excluded.fingerprint,
          status = excluded.status,
          schema_version = excluded.schema_version,
          processed_at = excluded.processed_at,
          last_run_id = excluded.last_run_id,
          linked_session_ids_json = excluded.linked_session_ids_json,
          error = excluded.error
        """,
        (
            record["project_key"],
            record["path"],
            record["fingerprint"],
            record["status"],
            schema_version,
            processed_at,
            run_id,
            canonical_json(record.get("linked_session_ids", [])),
            record.get("error"),
        ),
    )


def command_checkpoint(connection, _db_path, args):
    records = read_records(args.input)
    output_dir = get_running_output_dir(connection, args.run_id)
    for record in records:
        validate_checkpoint_record(record, output_dir)

    processed_at = utc_now()
    with connection:
        for record in records:
            if record["kind"] == "source_item":
                checkpoint_source(
                    connection, record, args.run_id, args.schema_version, processed_at
                )
            else:
                checkpoint_context(
                    connection, record, args.run_id, args.schema_version, processed_at
                )
    emit({"run_id": args.run_id, "checkpointed": len(records)})


def command_finish_run(connection, _db_path, args):
    counts = parse_json_argument(args.counts_json, "--counts-json", dict)
    coverage = parse_json_argument(args.coverage_json, "--coverage-json", (dict, list))
    finished_at = utc_now()
    cursor = connection.execute(
        """
        UPDATE runs
        SET finished_at = ?, status = ?, counts_json = ?, coverage_json = ?
        WHERE run_id = ? AND status = 'running'
        """,
        (
            finished_at,
            args.status,
            canonical_json(counts),
            canonical_json(coverage),
            args.run_id,
        ),
    )
    if cursor.rowcount != 1:
        connection.rollback()
        raise UsageError(f"unknown or finished run: {args.run_id}")
    connection.commit()
    emit({"run_id": args.run_id, "finished_at": finished_at, "status": args.status})


def build_parser():
    parser = argparse.ArgumentParser(
        description="Manage the private incremental ledger for agent-session-evidence."
    )
    parser.add_argument("--db", type=Path, default=default_db_path())
    subparsers = parser.add_subparsers(dest="command", required=True)

    subparsers.add_parser("init", help="create or migrate the ledger")
    subparsers.add_parser("status", help="print status counts as JSON")

    start = subparsers.add_parser("start-run", help="register a running scan")
    start.add_argument("--run-id")
    start.add_argument("--output-dir", required=True)
    start.add_argument("--filters-json", default="{}")
    start.add_argument("--schema-version", type=int, default=1)

    pending = subparsers.add_parser(
        "pending", help="filter inventory JSONL to items requiring work"
    )
    pending.add_argument("--input", default="-")
    pending.add_argument("--schema-version", type=int, required=True)
    pending.add_argument("--reprocess", action="store_true")

    checkpoint = subparsers.add_parser(
        "checkpoint", help="atomically record one completed batch from JSONL"
    )
    checkpoint.add_argument("--input", default="-")
    checkpoint.add_argument("--run-id", required=True)
    checkpoint.add_argument("--schema-version", type=int, required=True)

    finish = subparsers.add_parser("finish-run", help="finish a registered scan")
    finish.add_argument("--run-id", required=True)
    finish.add_argument("--status", choices=sorted(RUN_STATUSES), required=True)
    finish.add_argument("--counts-json", default="{}")
    finish.add_argument("--coverage-json", default="[]")
    return parser


def main():
    os.umask(0o077)
    parser = build_parser()
    args = parser.parse_args()
    handlers = {
        "init": command_init,
        "status": command_status,
        "start-run": command_start_run,
        "pending": command_pending,
        "checkpoint": command_checkpoint,
        "finish-run": command_finish_run,
    }
    try:
        connection, db_path = prepare_database(args.db)
        try:
            handlers[args.command](connection, db_path, args)
        finally:
            connection.close()
    except (UsageError, OSError, sqlite3.Error) as error:
        print(f"error: {error}", file=sys.stderr)
        return 2
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
