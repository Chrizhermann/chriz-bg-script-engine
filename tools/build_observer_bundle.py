"""Bundle only the authored observer modules; no installed-game content or global require hooks."""
import argparse
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
MODULES = (
    "kernel.manifest", "kernel.eligibility", "kernel.identity", "kernel.clock",
    "kernel.trace", "kernel.engine", "kernel.bootstrap", "adapters.registry",
    "adapters.eeex.engine", "adapters.eeex.listeners",
)


def build() -> str:
    lines = ["-- Generated from authored BGSE sources. Observer only.",
             "local factories,loaded={},{}",
             "local function require(name)",
             "  if loaded[name] then return loaded[name] end",
             "  local value=assert(factories[name], 'unbundled module')(require)",
             "  loaded[name]=value;return value", "end"]
    for name in MODULES:
        source = (ROOT / (name.replace(".", "/") + ".lua")).read_text(encoding="utf-8")
        lines.extend((f"factories[{json.dumps(name)}]=function(require)", source, "end"))
    lines.append("return {new=require('kernel.bootstrap').new,clock=require('kernel.clock'),"
                 "eeex=require('adapters.eeex.engine'),listeners=require('adapters.eeex.listeners'),"
                 "manifest=require('kernel.manifest')}")
    return "\n".join(lines) + "\n"


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("output", type=Path)
    args = parser.parse_args()
    with args.output.open("x", encoding="utf-8", newline="\n") as stream:
        stream.write(build())
    print(f"Built observer bundle: {len(MODULES)} authored modules")


if __name__ == "__main__":
    main()
