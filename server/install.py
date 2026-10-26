"""Reviewable, reversible patch installer. Defaults to a non-mutating check.

Run on AInfinity with its existing service Python. Does not restart processes.
"""
import argparse
import ast
import hashlib
import json
import os
import shutil
import time
from pathlib import Path
from formatters import MC_FORMATTER, KOOK_FORMATTER

ROOT = Path(__file__).resolve().parent


def replace_function(source, name, replacement):
    node = next(n for n in ast.parse(source).body if isinstance(n, (ast.FunctionDef, ast.AsyncFunctionDef)) and n.name == name)
    lines = source.splitlines(keepends=True)
    return ''.join(lines[:node.lineno-1]) + replacement + ''.join(lines[node.end_lineno:])


def build_changes(backend, bot):
    changes = {}
    environment = (ROOT/'environment.py').read_text(encoding='utf-8')
    changes[backend/'app/services/mobile_environment.py'] = environment
    changes[bot/'src/services/mobile_environment.py'] = environment
    for src, target in ((ROOT/'backend', backend), (ROOT/'qq_bot', bot)):
        for file in src.rglob('*.py'):
            if '__pycache__' not in file.parts:
                changes[target / file.relative_to(src)] = file.read_text(encoding='utf-8')
    main = backend/'main.py'
    source = main.read_text(encoding='utf-8')
    if 'from app.controllers.mobile_controller import' not in source:
        anchor = 'app.include_router(auth_router)'
        if source.count(anchor) != 1:
            raise RuntimeError('Cannot locate main router anchor')
        source = source.replace(anchor,
            'from app.controllers.mobile_controller import router as mobile_router\n'
            'from app.controllers.mobile_oauth import router as mobile_oauth_router\n'
            'app.include_router(mobile_router)\napp.include_router(mobile_oauth_router)\n' + anchor)
    changes[main] = source
    auth = backend/'app/controllers/auth_controller.py'
    source = auth.read_text(encoding='utf-8')
    if '# DEERAFT_MOBILE_OAUTH' not in source:
        anchor = '    # 1) Microsoft 端直接报错'
        index = source.find(anchor)
        if index < 0:
            raise RuntimeError('Cannot locate Microsoft callback anchor')
        source = source[:index] + (
            '    # DEERAFT_MOBILE_OAUTH: preserve the existing browser flow.\n'
            '    if state and state.startswith("mobile."):\n'
            '        from app.controllers.mobile_oauth import complete_callback\n'
            '        return complete_callback(code=code, state=state, error=error, db=db)\n\n') + source[index:]
    changes[auth] = source
    for name, function, body in (('mc_query.py', 'get_mc_info', MC_FORMATTER),
                                  ('kook.py', 'get_deep_kook_info', KOOK_FORMATTER)):
        path = bot/'src/plugins'/name
        changes[path] = replace_function(path.read_text(encoding='utf-8'), function, body)
    for path, source in changes.items():
        compile(source, str(path), 'exec')
    return changes


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--backend', type=Path, default=Path('/home/ainfinity/backend/backend'))
    parser.add_argument('--bot', type=Path, default=Path('/home/ainfinity/QQ_bot'))
    parser.add_argument('--apply', action='store_true')
    args = parser.parse_args()
    backend, bot = args.backend.resolve(), args.bot.resolve()
    changes = build_changes(backend, bot)
    # Snapshot hashes are checked again immediately before mutation.
    originals = {p: p.read_bytes() if p.exists() else None for p in changes}
    actual = {p: s for p, s in changes.items() if originals[p] != s.encode('utf-8')}
    baseline_file = ROOT/'baseline.json'
    if baseline_file.exists():
        baseline = json.loads(baseline_file.read_text(encoding='utf-8'))
        for path in actual:
            key = ('backend/' + path.relative_to(backend).as_posix()) if path.is_relative_to(backend) else ('qq_bot/' + path.relative_to(bot).as_posix())
            expected = baseline.get(key)
            observed = hashlib.sha256(originals[path]).hexdigest() if originals[path] is not None else None
            if observed != expected:
                raise RuntimeError(f'Source changed since baseline; review required: {key}')
    print(json.dumps({'mode': 'apply' if args.apply else 'check',
                      'files': [str(p) for p in actual]}, ensure_ascii=False, indent=2))
    if not args.apply or not actual:
        return
    backup = ROOT/'backups'/time.strftime('%Y%m%d-%H%M%S')
    backup.mkdir(parents=True, mode=0o700)
    os.chmod(backup.parent, 0o700)
    manifest = []
    for index, (path, source) in enumerate(actual.items()):
        current = originals[path]
        saved = str(index) if current is not None else None
        if saved:
            shutil.copy2(path, backup/saved)
        manifest.append({'path': str(path), 'backup': saved,
                         'installed_sha256': hashlib.sha256(source.encode()).hexdigest()})
    (backup/'manifest.json').write_text(json.dumps(manifest, indent=2), encoding='utf-8')
    written = []
    try:
        for path, source in actual.items():
            current = path.read_bytes() if path.exists() else None
            if current != originals[path]:
                raise RuntimeError(f'File changed during review: {path}')
            path.parent.mkdir(parents=True, exist_ok=True)
            temporary = path.with_name(path.name+'.deeraft-tmp')
            temporary.write_text(source, encoding='utf-8', newline='\n')
            temporary.replace(path)
            written.append(path)
    except Exception:
        for path in reversed(written):
            if originals[path] is None:
                path.unlink()
            else:
                path.write_bytes(originals[path])
        raise
    print(f'Backup manifest: {backup}/manifest.json. Processes were not restarted.')


if __name__ == '__main__':
    main()
