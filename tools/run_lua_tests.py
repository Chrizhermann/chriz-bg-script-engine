"""Run the existing host tests with explicit Lua backend and collection reporting."""

import argparse
import importlib
from importlib.metadata import version
from pathlib import Path
import platform
import random
import sys


ROOT = Path(__file__).resolve().parents[1]
# Running this file directly sets sys.path[0] to tools/, unlike `python -m pytest`.
# Keep repository imports in the existing suites resolvable from any caller cwd.
sys.path.insert(0, str(ROOT))
SUITES = {
    "unit": ("unit",),
    "integration": ("integration",),
    "schemas": ("schemas",),
    "all": ("unit", "integration", "schemas"),
}


class CollectionReport:
    def __init__(self, seed):
        self.seed = seed

    def pytest_collection_finish(self, session):
        items = session.items
        if self.seed is not None:
            items.sort(key=lambda item: item.nodeid)
            random.Random(self.seed).shuffle(items)
        files = dict.fromkeys(item.path.relative_to(ROOT).as_posix() for item in items)
        file_label = "file" if len(files) == 1 else "files"
        print(f"Collected {len(items)} tests in {len(files)} {file_label}:", flush=True)
        for path in files:
            print(f"  {path}", flush=True)
        if not items:
            print("No tests discovered.", file=sys.stderr, flush=True)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--suite", choices=SUITES, default="all")
    parser.add_argument("--filter", dest="filter_expression")
    parser.add_argument("--seed", type=int)
    args = parser.parse_args()

    try:
        import pytest

        lua51 = importlib.import_module("lupa.lua51")
        luajit21 = importlib.import_module("lupa.luajit21")
        lua51_version = lua51.LuaRuntime().eval("_VERSION")
        luajit_version = luajit21.LuaRuntime().eval("jit.version")
        lupa_version = version("lupa")
    except (ImportError, RuntimeError, AttributeError) as exc:
        print(f"Required host test backend unavailable: {exc}", file=sys.stderr)
        return 2

    print(
        f"Host: Python {platform.python_version()}, Lupa {lupa_version}, "
        f"{lua51_version}, {luajit_version}",
        flush=True,
    )
    if args.seed is not None:
        print(f"Collection shuffle seed: {args.seed}", flush=True)

    # Lupa's expected pcall errors trigger misleading Windows faulthandler dumps.
    # Test errors and process exit status still flow through pytest unchanged.
    pytest_args = ["-p", "no:faulthandler", "-q", "-s", "--rootdir", str(ROOT)]
    if args.filter_expression is not None:
        pytest_args.extend(("-k", args.filter_expression))
    pytest_args.extend(str(ROOT / "tests" / suite) for suite in SUITES[args.suite])
    return int(pytest.main(pytest_args, plugins=[CollectionReport(args.seed)]))


if __name__ == "__main__":
    sys.exit(main())
