"""Private durable state helpers for diagnostic reviews."""

from __future__ import annotations

import fcntl
import json
import os
from pathlib import Path
import secrets
from typing import Any, Callable


class ReviewStateError(Exception):
    pass


def state_root() -> Path:
    root = Path(os.environ.get("XDG_STATE_HOME", Path.home() / ".local" / "state"))
    return root / "agent-session-review"


def default_state_path() -> Path:
    return state_root() / "state.json"


def private_dir(path: Path) -> None:
    path.mkdir(parents=True, exist_ok=True, mode=0o700)
    path.chmod(0o700)


def write_private(path: Path, content: str) -> None:
    private_dir(path.parent)
    temporary = path.with_name(f".{path.name}.{secrets.token_hex(4)}.tmp")
    try:
        descriptor = os.open(temporary, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
        with os.fdopen(descriptor, "w", encoding="utf-8") as handle:
            handle.write(content)
            handle.flush()
            os.fsync(handle.fileno())
        os.replace(temporary, path)
        path.chmod(0o600)
    finally:
        if temporary.exists():
            temporary.unlink()


def read_json(path: Path) -> Any:
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except FileNotFoundError as error:
        raise ReviewStateError(f"missing required file: {path}") from error
    except json.JSONDecodeError as error:
        raise ReviewStateError(f"invalid JSON in {path}: {error}") from error


def empty_state() -> dict[str, Any]:
    return {"schema_version": 1, "findings": {}, "cases": {}}


def load_state(path: Path) -> dict[str, Any]:
    if not path.exists():
        return empty_state()
    state = read_json(path)
    if str(state.get("schema_version")) != "1":
        raise ReviewStateError(f"unsupported review state schema in {path}")
    if not isinstance(state.get("findings"), dict) or not isinstance(state.get("cases"), dict):
        raise ReviewStateError(f"invalid review state in {path}")
    return state


def with_locked_state(path: Path, operation: Callable[[dict[str, Any]], Any]) -> Any:
    private_dir(path.parent)
    lock_path = path.with_suffix(path.suffix + ".lock")
    descriptor = os.open(lock_path, os.O_RDWR | os.O_CREAT, 0o600)
    with os.fdopen(descriptor, "r+", encoding="utf-8") as lock:
        fcntl.flock(lock.fileno(), fcntl.LOCK_EX)
        state = load_state(path)
        result = operation(state)
        write_private(path, json.dumps(state, indent=2, sort_keys=True) + "\n")
        fcntl.flock(lock.fileno(), fcntl.LOCK_UN)
    lock_path.chmod(0o600)
    return result
