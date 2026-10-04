"""Replay bounded JSONL decision records through the pure Lua trace checker.

Only the repository's fixed Lua modules execute. Trace content is converted to data
tables; malformed input and Lua diagnostics are never echoed to the console.
"""
from __future__ import annotations

import argparse
import importlib
import json
import sys
from dataclasses import dataclass
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parents[2]
MAX_BYTES = 16 * 1024 * 1024
MAX_ROWS = 1000
BACKENDS = ("lua51", "luajit21")


class ReplayFailure(ValueError):
    def __init__(self, row_index: int | None, reason: str) -> None:
        self.row_index = row_index
        self.reason = reason
        label = f"row {row_index}" if row_index is not None else "input"
        super().__init__(f"{label}: {reason}")


@dataclass(frozen=True)
class ReplaySummary:
    row_count: int
    selected_ids: tuple[str, ...]


def _to_lua(runtime: Any, value: Any) -> Any:
    if isinstance(value, dict):
        table = runtime.table()
        for key, item in value.items():
            table[key] = _to_lua(runtime, item)
        return table
    if isinstance(value, list):
        table = runtime.table()
        for index, item in enumerate(value, 1):
            table[index] = _to_lua(runtime, item)
        return table
    return value


def _reject_constant(_: str) -> None:
    raise ValueError("non-JSON number")


def _rows(path: Path) -> list[dict]:
    try:
        with path.open("rb") as handle:
            payload = handle.read(MAX_BYTES + 1)
    except OSError:
        raise ReplayFailure(None, "input-unavailable") from None
    if len(payload) > MAX_BYTES:
        raise ReplayFailure(None, "input-too-large")
    lines = payload.splitlines()
    if not lines:
        raise ReplayFailure(1, "malformed")
    if len(lines) > MAX_ROWS:
        raise ReplayFailure(MAX_ROWS + 1, "too-many-rows")
    rows = []
    for index, line in enumerate(lines, 1):
        try:
            row = json.loads(line.decode("utf-8"), parse_constant=_reject_constant)
            if not isinstance(row, dict):
                raise ValueError("record is not an object")
        except (UnicodeError, ValueError, RecursionError):
            raise ReplayFailure(index, "malformed") from None
        rows.append(row)
    return rows


def replay_jsonl(path: str | Path, backend: str = "lua51") -> ReplaySummary:
    """Regenerate each saved decision and return only its selected scalar ID."""
    if backend not in BACKENDS:
        raise ValueError("unsupported Lua backend")
    rows = _rows(Path(path))
    module = importlib.import_module(f"lupa.{backend}")
    runtime = module.LuaRuntime()
    runtime.execute("package.path = ... .. '/?.lua;' .. package.path", ROOT.as_posix())
    check = runtime.eval("require('combat-intent.trace').replay")
    selected = []
    for index, row in enumerate(rows, 1):
        try:
            checked = check(_to_lua(runtime, row))
            if isinstance(checked, tuple):
                if checked[0] is None:
                    raise ReplayFailure(index, "trace-disagreement")
                checked = checked[0]
            choice = checked["choice"]
            selected_id = "none" if choice is False else choice["id"]
            if not isinstance(selected_id, str):
                raise ValueError("invalid selection")
        except ReplayFailure:
            raise
        except (module.LuaError, TypeError, KeyError, ValueError, RecursionError):
            raise ReplayFailure(index, "malformed") from None
        selected.append(selected_id)
    return ReplaySummary(len(rows), tuple(selected))


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Replay saved scalar combat decisions")
    parser.add_argument("jsonl", type=Path)
    parser.add_argument("--backend", choices=BACKENDS, default="lua51")
    args = parser.parse_args(argv)
    try:
        summary = replay_jsonl(args.jsonl, args.backend)
    except ReplayFailure as error:
        print(f"replay failed: {error}", file=sys.stderr)
        return 1
    print(f"replay passed: {summary.row_count} row(s) on {args.backend}")
    for index, selected_id in enumerate(summary.selected_ids, 1):
        print(f"row {index}: {selected_id}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
