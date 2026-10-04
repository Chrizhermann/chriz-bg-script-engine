"""Bundle the bounded combat shadow slice; deliberately no dispatch module."""
import argparse
from pathlib import Path
from tools.build_observer_bundle import MODULES, EXPORTS, build as bundle

SHADOW_MODULES = MODULES + (
    'kernel.ownership', 'kernel.rng', 'combat-intent.snapshot', 'combat-intent.perception',
    'combat-intent.actions', 'combat-intent.legality', 'combat-intent.preparation',
    'combat-intent.spatial', 'combat-intent.geometry',
    'combat-intent.candidates', 'combat-intent.profile', 'combat-intent.utility',
    'combat-intent.choose', 'combat-intent.decision', 'combat-intent.trace',
    'combat-intent.controller', 'adapters.eeex.mage_inputs',
)

def build():
    return bundle(SHADOW_MODULES, EXPORTS + ",controller=require('combat-intent.controller'),"
                  "inputs=require('adapters.eeex.mage_inputs'),snapshot=require('combat-intent.snapshot'),"
                  "candidates=require('combat-intent.candidates'),decision=require('combat-intent.decision')")

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('output', type=Path)
    args = parser.parse_args()
    with args.output.open('x', encoding='utf-8', newline='\n') as stream:
        stream.write(build())
    print(f'Built shadow-only bundle: {len(SHADOW_MODULES)} authored modules')

if __name__ == '__main__':
    main()
