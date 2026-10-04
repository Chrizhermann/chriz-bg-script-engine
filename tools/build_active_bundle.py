"""Bundle the admitted Task25 active slice, with runtime dispatch default-off."""
import argparse
from pathlib import Path

from tools.build_observer_bundle import EXPORTS, build as bundle
from tools.build_combat_bundle import SHADOW_MODULES


ACTIVE_MODULES = SHADOW_MODULES + (
    'kernel.lease', 'kernel.action_attempt', 'kernel.action_dispatch',
    'combat-intent.dispatch', 'adapters.eeex.action_dispatch',
)
ACTIVE_EXPORTS = (
    EXPORTS + ",controller=require('combat-intent.controller'),"
    "inputs=require('adapters.eeex.mage_inputs'),snapshot=require('combat-intent.snapshot'),"
    "candidates=require('combat-intent.candidates'),decision=require('combat-intent.decision'),"
    "activeDispatch=require('kernel.action_dispatch'),"
    "nativeDispatch=require('adapters.eeex.action_dispatch')"
)


def build():
    return bundle(ACTIVE_MODULES, ACTIVE_EXPORTS).replace(
        '-- Generated from authored BGSE sources. Observer only.',
        '-- Generated from authored BGSE sources. Task25 active-capable; default-off.', 1,
    )


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('output', type=Path)
    args = parser.parse_args()
    with args.output.open('x', encoding='utf-8', newline='\n') as stream:
        stream.write(build())
    print(f'Built default-off active bundle: {len(ACTIVE_MODULES)} authored modules')


if __name__ == '__main__':
    main()
