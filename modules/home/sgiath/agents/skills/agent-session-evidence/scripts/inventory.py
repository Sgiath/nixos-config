#!/usr/bin/env python3
"""Metadata-only session inventory for agent-session-evidence.

Scans all four transcript stores (omp, pi, opencode, grok) without reading
transcript bodies or credential stores. Emits `source_item` JSONL records
ready for `evidence_ledger.py pending`, plus `<output>.manifest` containing
store probes and the exact fingerprint algorithms.

Usage:
  inventory.py <output.jsonl> [--window-hours 24] [--since ISO] [--until ISO]
               [--harness omp|pi|opencode|grok ...]

`--since`/`--until` accept ISO datetimes; `--window-hours` is relative to
`--until` (default: now). Sessions whose activity overlaps the inclusive
window are inventoried. OMP subagent JSONLs are inventoried recursively;
sibling `.log` artifacts are excluded.
"""
import argparse
import hashlib
import json
import os
import re
import sqlite3
import subprocess
import sys
import time
from datetime import datetime, timedelta, timezone
from pathlib import Path

HOME = Path.home()
ACTIVE_WINDOW = 900  # seconds; mtime newer than this => session considered active
_manifest = {"stores": [], "fingerprint_algorithm": {}, "coverage_gaps": []}
SINCE = 0.0
NOW = 0.0
ONLY = None


def iso(ts):
    """Normalize epoch seconds/ms or ISO string to RFC3339 UTC."""
    if ts is None:
        return None
    if isinstance(ts, (int, float)):
        v = float(ts)
        if v > 1e12:
            v /= 1000.0
        return datetime.fromtimestamp(v, timezone.utc).isoformat(timespec="seconds").replace("+00:00", "Z")
    s = str(ts)
    if re.fullmatch(r"\d{10,14}", s):
        return iso(int(s))
    try:
        return datetime.fromisoformat(s.replace("Z", "+00:00")).astimezone(timezone.utc).isoformat(timespec="seconds").replace("+00:00", "Z")
    except ValueError:
        return None


def sha(data):
    return hashlib.sha256(data).hexdigest()[:16]


_git_cache = {}


def canonical_project(cwd):
    """Group by canonical git remote; fall back to repo dir / plain cwd.

    NOTE: pruned fusion/OMO worktrees (cwd no longer a git checkout) fall back
    to `cwd:` here; the coordinator merges them into the canonical remote using
    directory adjacency plus in-window OpenCode/OMO sessions that record the
    main repo directory (see SKILL.md "Canonicalize projects").
    """
    if not cwd:
        return None
    key = str(cwd)
    if key in _git_cache:
        return _git_cache[key]
    result = None
    try:
        r = subprocess.run(
            ["git", "-C", key, "remote", "get-url", "origin"],
            capture_output=True, text=True, timeout=5,
        )
        if r.returncode == 0 and r.stdout.strip():
            url = r.stdout.strip()
            url = re.sub(r"^[a-z]+://[^/@]+@", "", url)  # strip credentials
            url = re.sub(r"\.git$", "", url)
            result = url
        else:
            r2 = subprocess.run(
                ["git", "-C", key, "rev-parse", "--git-common-dir"],
                capture_output=True, text=True, timeout=5,
            )
            if r2.returncode == 0 and r2.stdout.strip():
                common = os.path.abspath(os.path.join(key, r2.stdout.strip()))
                result = "gitdir:" + common
    except Exception:
        result = None
    if result is None:
        result = "cwd:" + key
    _git_cache[key] = result
    return result


def emit(record):
    with open(OUT, "ab") as f:
        f.write(canonical_json(record).encode("utf-8") + b"\n")


def canonical_json(value):
    return json.dumps(value, ensure_ascii=False, separators=(",", ":"), sort_keys=True)


def last_complete_line(path):
    """Return last full line (newline-terminated) of file, and torn flag."""
    size = path.stat().st_size
    with open(path, "rb") as f:
        f.seek(max(0, size - 65536))
        tail = f.read()
    if not tail.endswith(b"\n"):
        idx = tail.rfind(b"\n")
        return (tail[: idx + 1] if idx >= 0 else b""), False
    lines = tail.rstrip(b"\n").rsplit(b"\n", 1)
    return (lines[-1] + b"\n"), True


def first_lines(path, n=2):
    out = []
    with open(path, "rb") as f:
        for _ in range(n):
            line = f.readline()
            if not line:
                break
            out.append(line)
    return out


def scan_file_based(harness, root_glob, header_parser, note=""):
    if ONLY and harness not in ONLY:
        return
    count = 0
    for path in sorted(root_glob):
        try:
            st = path.stat()
        except OSError:
            continue
        if st.st_mtime < SINCE:
            continue
        if UNTIL and st.st_mtime > UNTIL:
            continue
        rec = header_parser(path, st)
        if rec:
            emit(rec)
            count += 1
    _manifest["stores"].append({"harness": harness, "inventoried_recent": count, "note": note})


def file_based_record(harness, path, st, session_id, cwd, started_at, ended_at,
                      torn, title=None, parent_session=None, raw_extra=None):
    fl = first_lines(path, 2)
    head_hash = sha(b"|".join(fl)) if fl else "none"
    last, complete = last_complete_line(path)
    last_hash = sha(last) if last else "none"
    fp = f"{harness}:{session_id}:{st.st_size}:{st.st_mtime_ns}:{head_hash}:{last_hash}"
    mtime_iso = iso(st.st_mtime)
    active = st.st_mtime >= NOW - ACTIVE_WINDOW
    return {
        "kind": "source_item",
        "harness": harness,
        "session_id": session_id,
        "raw_locator": str(path),
        "fingerprint": fp,
        "project_key": canonical_project(cwd) if cwd else None,
        "started_at": iso(started_at),
        "ended_at": ended_at if ended_at else (mtime_iso if complete else None),
        "active": active or torn,
        "title": title,
        "parent_session": parent_session,
        "source_meta": raw_extra or {},
    }


# ---------------- OMP ----------------

def omp_scan():
    root = HOME / ".omp" / "agent" / "sessions"
    counts = {"main": 0, "child": 0}

    def parse(path, st):
        counts["main"] += 1
        lines = first_lines(path, 3)
        header = None
        title = None
        for ln in lines:
            try:
                obj = json.loads(ln)
            except Exception:
                continue
            if obj.get("type") == "session":
                header = obj
            elif obj.get("type") == "title_change":
                title = obj.get("title") or title
        if not header:
            counts["main"] -= 1
            return None
        last, complete = last_complete_line(path)
        ended = None
        try:
            ended = iso(json.loads(last).get("timestamp"))
        except Exception:
            pass
        cwd = header.get("cwd")
        return file_based_record(
            "omp", path, st, header.get("id") or path.stem, cwd,
            header.get("timestamp"), ended, not complete, title=title,
            parent_session=header.get("parentSession"),
            raw_extra={"version": header.get("version")},
        )

    def parse_child(path, st):
        counts["child"] += 1
        lines = first_lines(path, 2)
        header = None
        for ln in lines:
            try:
                obj = json.loads(ln)
            except Exception:
                continue
            if obj.get("type") == "session":
                header = obj
                break
        if not header:
            counts["child"] -= 1
            return None  # attachment/artifact, not a transcript
        last, complete = last_complete_line(path)
        ended = None
        try:
            ended = iso(json.loads(last).get("timestamp"))
        except Exception:
            pass
        parent_dir_name = path.parent.name
        return file_based_record(
            "omp", path, st, header.get("id") or path.stem, header.get("cwd"),
            header.get("timestamp"), ended, not complete,
            parent_session=header.get("parentSession") or parent_dir_name,
            raw_extra={"child_of_dir": parent_dir_name},
        )

    scan_file_based("omp", root.glob("*/*.jsonl"), parse,
                    note="main session transcripts")
    scan_file_based("omp", root.glob("*/*/*.jsonl"), parse_child,
                    note="subagent child transcripts; sibling .log artifacts excluded")
    _manifest["fingerprint_algorithm"]["omp/pi"] = (
        "harness:sessionId:byteSize:mtimeNs:sha256_16(first 2 complete lines):sha256_16(last complete line)"
    )
    _manifest["omp_counts"] = counts


# ---------------- Pi ----------------

def pi_scan():
    root = HOME / ".pi" / "agent" / "sessions"
    n = 0

    def parse(path, st):
        nonlocal n
        lines = first_lines(path, 2)
        header = None
        for ln in lines:
            try:
                obj = json.loads(ln)
            except Exception:
                continue
            if obj.get("type") == "session":
                header = obj
                break
        if not header:
            return None
        last, complete = last_complete_line(path)
        ended = None
        try:
            ended = iso(json.loads(last).get("timestamp"))
        except Exception:
            pass
        n += 1
        return file_based_record(
            "pi", path, st, header.get("id") or path.stem, header.get("cwd"),
            header.get("timestamp"), ended, not complete,
            parent_session=header.get("parentSession"),
            raw_extra={"version": header.get("version")},
        )

    scan_file_based("pi", root.glob("*/*.jsonl"), parse)


# ---------------- OpenCode ----------------

def opencode_scan():
    data_root = HOME / ".local" / "share" / "opencode"
    dbs = sorted(data_root.glob("*.db"))
    if not dbs:
        _manifest["coverage_gaps"].append("opencode: no *.db under data root")
        return
    scanned_any = False
    for db_path in dbs:
        try:
            con = sqlite3.connect(f"file:{db_path}?mode=ro", uri=True)
            con.execute("PRAGMA query_only=ON")
        except sqlite3.Error:
            continue
        tables = {r[0] for r in con.execute("select name from sqlite_master where type='table'")}
        total_for_db = 0
        for table in ("session", "session_v2"):
            if table not in tables:
                continue
            cols = {r[1] for r in con.execute(f"pragma table_info({table})")}
            if "time_updated" not in cols:
                continue
            try:
                rows = con.execute(
                    f"SELECT id, directory, title, agent, model, time_created, time_updated, parent_id, version "
                    f"FROM {table} WHERE CAST(time_updated AS INTEGER) > ?",
                    (SINCE * 1000,),
                ).fetchall()
            except sqlite3.Error:
                continue
            if not rows and total_for_db == 0 and table == "session":
                continue  # skip empty channel databases entirely
            if not scanned_any:
                _manifest["fingerprint_algorithm"]["opencode"] = (
                    "dbFile:size:mtimeNs:table:sessionId:timeUpdated:"
                    "sessionMessageCount:maxSeq:legacyMessageCount"
                )
                scanned_any = True
            db_fp = f"{db_path.name}:{db_path.stat().st_size}:{db_path.stat().st_mtime_ns}"
            for (sid, directory, title, agent, model, tc, tu, parent, version) in rows:
                tu_i = int(tu) / 1000.0 if tu else NOW
                if UNTIL and tu_i > UNTIL:
                    continue
                msg_stats = con.execute(
                    "SELECT COUNT(*), MAX(CAST(seq AS INTEGER)) FROM session_message WHERE session_id=?",
                    (sid,),
                ).fetchone()
                leg_stats = con.execute(
                    "SELECT COUNT(*) FROM message WHERE session_id=?", (sid,)
                ).fetchone()
                emit({
                    "kind": "source_item",
                    "harness": "opencode",
                    "session_id": sid,
                    "raw_locator": f"sqlite:{db_path}#{table}/{sid}",
                    "fingerprint": f"{db_fp}:{table}:{sid}:{tu}:{msg_stats[0]}:{msg_stats[1]}:{leg_stats[0]}",
                    "project_key": canonical_project(directory) if directory else None,
                    "started_at": iso(tc),
                    "ended_at": iso(tu),
                    "active": tu_i >= NOW - ACTIVE_WINDOW,
                    "title": title,
                    "parent_session": parent,
                    "source_meta": {"table": table, "agent": agent, "model": model,
                                    "version": version, "directory": directory,
                                    "message_count": msg_stats[0]},
                })
                total_for_db += 1
        if total_for_db:
            _manifest["stores"].append({
                "harness": "opencode", "db": str(db_path), "inventoried_recent": total_for_db,
                "note": "session + session_v2 tables",
            })
        else:
            _manifest["stores"].append({
                "harness": "opencode", "db": str(db_path), "inventoried_recent": 0,
                "note": "no sessions in window; skipped",
            })
        con.close()


# ---------------- Grok ----------------

def grok_scan():
    root = HOME / ".grok" / "sessions"
    n = 0
    for summary in sorted(root.glob("*/*/summary.json")):
        try:
            st = summary.stat()
        except OSError:
            continue
        upd = summary.parent / "updates.jsonl"
        upd_st = upd.stat() if upd.exists() else None
        latest = max(st.st_mtime, upd_st.st_mtime if upd_st else 0)
        if latest < SINCE:
            continue
        if UNTIL and latest > UNTIL:
            continue
        try:
            s = json.loads(summary.read_text(encoding="utf-8"))
        except Exception:
            continue
        info = s.get("info") if isinstance(s.get("info"), dict) else s
        sid = info.get("id") or summary.parent.name
        cwd = info.get("cwd")
        ended = None
        torn = False
        if upd_st:
            last, complete = last_complete_line(upd)
            torn = not complete
            try:
                env = json.loads(last)
                ts = env.get("timestamp") or (env.get("update") or {}).get("timestamp")
                ended = iso(ts)  # unix seconds handled by iso()
            except Exception:
                pass
        fp = (f"grok:{sid}:summary:{st.st_size}:{st.st_mtime_ns}:{sha(summary.read_bytes())}"
              f":updates:{upd_st.st_size if upd_st else 0}:{upd_st.st_mtime_ns if upd_st else 0}")
        emit({
            "kind": "source_item",
            "harness": "grok",
            "session_id": sid,
            "raw_locator": str(summary.parent),
            "fingerprint": fp,
            "project_key": canonical_project(cwd) if cwd else None,
            "started_at": iso(info.get("time_created") or info.get("created_at")),
            "ended_at": ended or iso(info.get("time_updated") or info.get("updated_at")),
            "active": latest >= NOW - ACTIVE_WINDOW or torn,
            "title": info.get("title") or s.get("title"),
            "parent_session": info.get("parent_session_id") or info.get("parentSession") or info.get("parent"),
            "source_meta": {
                "kind": s.get("kind") or info.get("kind"),
                "git_root": info.get("git_root") or info.get("gitRoot"),
                "git_remote": info.get("git_remote") or info.get("gitRemote"),
                "model": info.get("model"),
                "agent": info.get("agent"),
            },
        })
        n += 1
    _manifest["stores"].append({"harness": "grok", "root": str(root), "inventoried_recent": n})
    _manifest["fingerprint_algorithm"]["grok"] = (
        "grok:sessionId:summary(size,mtimeNs,sha256_16):updates(size,mtimeNs)"
    )


SCANNERS = {"omp": omp_scan, "pi": pi_scan, "opencode": opencode_scan, "grok": grok_scan}


def parse_since(value):
    dt = datetime.fromisoformat(value.replace("Z", "+00:00")).astimezone(timezone.utc)
    return dt.timestamp()


def main():
    global SINCE, NOW, UNTIL, OUT, ONLY
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("output")
    ap.add_argument("--window-hours", type=float, default=24.0)
    ap.add_argument("--since")
    ap.add_argument("--until")
    ap.add_argument("--harness", action="append", choices=sorted(SCANNERS))
    args = ap.parse_args()
    OUT = Path(args.output)
    UNTIL = parse_since(args.until) if args.until else 0.0
    NOW = UNTIL or time.time()
    SINCE = parse_since(args.since) if args.since else NOW - args.window_hours * 3600.0
    ONLY = set(args.harness) if args.harness else None

    OUT.parent.mkdir(parents=True, exist_ok=True)
    for harness in ("omp", "pi", "opencode", "grok"):
        if ONLY and harness not in ONLY:
            continue
        SCANNERS[harness]()
    Path(str(OUT) + ".manifest").write_text(canonical_json(_manifest), encoding="utf-8")
    from collections import Counter
    c = Counter()
    for line in OUT.read_text(encoding="utf-8").splitlines():
        if line.strip():
            c[json.loads(line)["harness"]] += 1
    print(json.dumps({
        "inventory": dict(c),
        "window_since": iso(SINCE),
        "window_until": iso(UNTIL) if UNTIL else iso(NOW),
    }), file=sys.stderr)


if __name__ == "__main__":
    main()
