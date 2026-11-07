"""Make and update the Playground: Christopher's test install, where he plays the newest spell mod and
engine again and again (2026-11-06). It is a game folder of its own with a profile of its own; his game and
its saves stay out of it.

    python -I tools/playground.py setup <lab game folder> --weidu <weidu.exe> --magic-repo <folder> [--root <folder>]
    python -I tools/playground.py update [--root <folder>] [--engine <git ref>] [--magic <git ref>]
    python -I tools/playground.py status [--root <folder>]

setup copies a lab game that holds no engine and no lab files (labs clean up after each run), gives it its own
profile, writes `Start Playground.cmd` and installs what update installs. update takes out the engine and the
spell mod, last first, and puts the given versions in; saves stay. It stops while the game runs from the folder.
"""
import argparse
import datetime
import io
import json
import re
import shutil
import subprocess
import sys
import tarfile
import time
from pathlib import Path

REPO = Path(__file__).resolve().parents[1]
ENGINE_NAME = 'Chriz Playground'
ENGINE_TP2 = 'bgse/setup-bgse.tp2'
MAGIC_TP2 = 'setup-chriz-bg-magic.tp2'
ENGINE_FILES = ('bgse',)
MAGIC_FILES = (MAGIC_TP2, 'chriz-bg-magic', 'defs')
# The intended setup (AGENTS.md): Insane without double damage, no maximum hit points.
PROFILE = (('Game Options', 'Difficulty Level', '5'),
           ('Game Options', 'Suppress Extra Difficulty Damage', '1'),
           ('Game Options', 'Maximum HP', '0'),
           ('Program Options', 'EET Installation State', '2'),
           ('Program Options', 'Cloud Saves Enabled', '0'))
START = '@echo off\r\nstart "" /d "%~dp0game" "%~dp0game\\InfinityLoader.exe"\r\n'


def default_root():
    return Path.home() / 'Games' / 'Playground'


def components(log, tp2):
    """The component numbers of tp2 in the text of a WeiDU.log, in the log's order."""
    wanted = tp2.replace('\\', '/').rsplit('/', 1)[-1].upper()
    found = []
    for line in log.splitlines():
        match = re.match(r'~([^~]*)~\s+#\d+\s+#(\d+)', line)
        if match and match[1].replace('\\', '/').rsplit('/', 1)[-1].upper() == wanted:
            found.append(int(match[2]))
    return found


def profile_lines(text, values=PROFILE):
    """The lines of a Baldur.lua with each of values set, each once; other lines stay."""
    lines = text.splitlines()
    for section, key, value in values:
        wanted = f"SetPrivateProfileString('{section}','{key}','{value}')"
        start = f"SetPrivateProfileString('{section}','{key}',"
        hits = [i for i, line in enumerate(lines) if line.startswith(start)]
        if hits:
            lines[hits[0]] = wanted
            for i in reversed(hits[1:]):
                del lines[i]
        else:
            lines.append(wanted)
    return lines


def documents():
    out = subprocess.run(['powershell', '-NoProfile', '-Command', "[Environment]::GetFolderPath('MyDocuments')"],
                         capture_output=True, text=True, timeout=60, check=True)
    return Path(out.stdout.strip())


def running(game):
    """Processes running from the game folder."""
    script = ("$g = '" + str(game).replace("'", "''") + "'; Get-CimInstance Win32_Process | Where-Object { "
              "$_.ExecutablePath -and $_.ExecutablePath.StartsWith($g, [StringComparison]::OrdinalIgnoreCase) } "
              "| ForEach-Object { $_.Name }")
    out = subprocess.run(['powershell', '-NoProfile', '-Command', script], capture_output=True, text=True, timeout=60,
                         check=True)
    return out.stdout.split()


def weidu(config, root, label, *arguments):
    """One WeiDU run in the game folder at low priority; its output goes to logs/."""
    logs = root / 'logs'
    logs.mkdir(exist_ok=True)
    stamp = datetime.datetime.now().strftime('%Y%m%d-%H%M%S')
    start = time.monotonic()
    with (logs / f'{stamp}-{label}.out').open('w', encoding='utf-8', errors='replace') as out:
        code = subprocess.run([config['weidu'], *arguments, '--language', '0', '--use-lang', 'en_US', '--no-exit-pause',
                               '--noautoupdate', '--log', str(logs / f'{stamp}-{label}.debug')],
                              cwd=root / 'game', stdout=out, stderr=subprocess.STDOUT, stdin=subprocess.DEVNULL,
                              creationflags=getattr(subprocess, 'BELOW_NORMAL_PRIORITY_CLASS', 0)).returncode
    print(f'{label}: exit {code}, {time.monotonic() - start:.0f} s')
    if code != 0:
        raise SystemExit(f'{label} failed, see {logs}')


def unpack(repo, ref, names, game):
    """The named files of ref into the game folder; returns the commit."""
    def git(*arguments):
        return subprocess.run(['git', '-C', str(repo), *arguments], capture_output=True, check=True).stdout

    commit = git('rev-parse', '--short', ref).decode().strip()
    listed = set(git('ls-tree', '--name-only', ref).decode().split())
    with tarfile.open(fileobj=io.BytesIO(git('archive', '--format=tar', ref, *[n for n in names if n in listed]))) as tar:
        tar.extractall(game, filter='data')
    return commit


def take_out(config, root):
    """The engine, then the spell mod, with the files that installed them; each last first."""
    game = root / 'game'
    log = (game / 'WeiDU.log').read_text(encoding='utf-8', errors='replace')
    for label, tp2, names in (('engine-out', ENGINE_TP2, ENGINE_FILES), ('magic-out', MAGIC_TP2, MAGIC_FILES)):
        numbers = components(log, tp2)
        if numbers:
            weidu(config, root, label, tp2, '--force-uninstall-list', *[str(n) for n in reversed(numbers)])
        for name in names:
            path = game / name
            if path.is_dir():
                shutil.rmtree(path)
            elif path.exists():
                path.unlink()


def put_in(config, root, engine, magic):
    game = root / 'game'
    done = {'magic': unpack(config['magic_repo'], magic, MAGIC_FILES, game)}
    weidu(config, root, 'magic-in', MAGIC_TP2, '--force-install-list', '0')
    done['engine'] = unpack(config['engine_repo'], engine, ENGINE_FILES, game)
    # Component 0 the engine, 10 the playtest recorder.
    tp2 = (game / ENGINE_TP2).read_text(encoding='utf-8', errors='replace')
    wanted = ['0'] + (['10'] if re.search(r'DESIGNATED\s+10\b', tp2) else [])
    weidu(config, root, 'engine-in', ENGINE_TP2, '--force-install-list', *wanted)
    done['when'] = datetime.datetime.now().isoformat(timespec='seconds')
    return done


def load(root):
    return json.loads((root / 'playground.json').read_text(encoding='utf-8'))


def save(root, config):
    (root / 'playground.json').write_text(json.dumps(config, indent=1), encoding='utf-8')


def setup(args):
    root = Path(args.root)
    game = root / 'game'
    source = Path(args.lab)
    if game.exists():
        raise SystemExit(f'{game} exists already')
    for leftover in ('bgse', 'override/M_EEexRC.lua', 'override/BGSEQA.lua', 'override/M_BGSE.lua'):
        if (source / leftover).exists():
            raise SystemExit(f'the lab is not clean: {leftover}')
    game.mkdir(parents=True)
    code = subprocess.run(['robocopy', str(source), str(game), '/E', '/COPY:DAT', '/DCOPY:DAT', '/XJ', '/R:1', '/W:1',
                           '/MT:8', '/NFL', '/NDL', '/NP'], stdout=subprocess.DEVNULL).returncode
    if code >= 8:
        raise SystemExit(f'the copy failed: robocopy {code}')
    (game / 'engine.lua').write_text(f'engine_name = "{ENGINE_NAME}"\nengine_mode = 1 -- 0 = BGEE, 1 = BG2EE, 2 = IWDEE\n',
                                     encoding='ascii')
    profile = documents() / ENGINE_NAME
    (profile / 'save').mkdir(parents=True, exist_ok=True)
    options = profile / 'Baldur.lua'
    text = options.read_text(encoding='utf-8') if options.exists() else ''
    options.write_text('\n'.join(profile_lines(text)) + '\n', encoding='utf-8')
    (root / 'Start Playground.cmd').write_bytes(START.encode('ascii'))
    config = {'weidu': str(Path(args.weidu).resolve()), 'engine_repo': str(REPO), 'magic_repo': str(Path(args.magic_repo).resolve()),
              'engine': args.engine or 'HEAD', 'magic': args.magic or 'origin/main'}
    save(root, config)
    config['installed'] = put_in(config, root, config['engine'], config['magic'])
    save(root, config)
    print(json.dumps(config['installed'], indent=1))


def update(args):
    root = Path(args.root)
    config = load(root)
    busy = running(root / 'game')
    if busy:
        raise SystemExit(f'the Playground runs ({" ".join(busy)}): close the game first')
    engine, magic = args.engine or config['engine'], args.magic or config['magic']
    take_out(config, root)
    config['engine'], config['magic'] = engine, magic
    config['installed'] = put_in(config, root, engine, magic)
    save(root, config)
    print(json.dumps(config['installed'], indent=1))


def status(args):
    root = Path(args.root)
    config = load(root)
    log = (root / 'game' / 'WeiDU.log').read_text(encoding='utf-8', errors='replace')
    print(json.dumps({'installed': config.get('installed'), 'engine': components(log, ENGINE_TP2),
                      'magic': components(log, MAGIC_TP2)}, indent=1))


def main(argv):
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    commands = parser.add_subparsers(dest='command', required=True)
    make = commands.add_parser('setup')
    make.add_argument('lab')
    make.add_argument('--weidu', required=True)
    make.add_argument('--magic-repo', required=True)
    for command in (make, commands.add_parser('update'), commands.add_parser('status')):
        command.add_argument('--root', default=str(default_root()))
        command.add_argument('--engine')
        command.add_argument('--magic')
    args = parser.parse_args(argv)
    {'setup': setup, 'update': update, 'status': status}[args.command](args)


if __name__ == '__main__':
    main(sys.argv[1:])
