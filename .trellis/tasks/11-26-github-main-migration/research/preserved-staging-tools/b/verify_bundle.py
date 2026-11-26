"""Read-only source/index verification and report-copy formatting checks."""
from __future__ import annotations

import hashlib
import json
import subprocess
from datetime import datetime, timezone
from pathlib import Path

OUT = Path(__file__).resolve().parent
manifest = json.loads((OUT / 'manifest.json').read_text(encoding='utf-8'))
CORE = Path(manifest['core'])
DART = 'D:/ProgramFiles/flutter_ohos/bin/cache/dart-sdk/bin/dart.exe'


def sha(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def git(*args: str, check: bool = True) -> subprocess.CompletedProcess:
    return subprocess.run(['git', '-C', str(CORE), *args], capture_output=True, check=check)


def index_hash() -> str:
    path = Path(git('rev-parse', '--git-path', 'index').stdout.decode().strip())
    return sha((path if path.is_absolute() else CORE / path).read_bytes())


before_index = index_hash()
state = {}
for path in manifest['verification']['frozen_source_sha256']:
    initial = git('show', f'{manifest["base_commit"]}:{path}', check=False)
    if initial.returncode == 0:
        state[path] = initial.stdout
checks = []
for stage in manifest['stages']:
    for entry in stage['files']:
        copy = OUT / entry['copy']
        raw = copy.read_bytes()
        text = raw.decode('utf-8').replace('\r\n', '\n')
        format_result = subprocess.run([
            DART, 'format', '--output=none', '--set-exit-if-changed',
            '--summary=none', '--language-version=3.11',
            '--stdin-name=' + entry['path'],
        ], input=text.encode('utf-8'), capture_output=True)
        if format_result.returncode != 0:
            raise RuntimeError(f'Copy not cleanly formatted: {entry["copy"]}')
        if sha(raw) != entry['sha256']:
            raise RuntimeError(f'Copy hash mismatch: {entry["copy"]}')
        state[entry['path']] = raw
        checks.append({'copy': entry['copy'], 'sha256_match': True, 'format_exit': 0})
final = {}
for path, expected in manifest['verification']['frozen_source_sha256'].items():
    raw = (CORE / path).read_bytes()
    final[path] = {
        'source_still_frozen': sha(raw) == expected,
        'replayed_copy_equals_source': state.get(path) == raw,
        'sha256': sha(raw),
    }
    if not all([final[path]['source_still_frozen'], final[path]['replayed_copy_equals_source']]):
        raise RuntimeError(f'Final copy replay/source mismatch: {path}')
after_index = index_hash()
if after_index != before_index:
    raise RuntimeError('Core index changed during read-only verification')
result = {
    'verified_at': datetime.now(timezone.utc).isoformat(),
    'copies': checks,
    'final_paths': final,
    'index_sha256_before': before_index,
    'index_sha256_after': after_index,
    'index_unchanged': before_index == after_index,
    'runtime_tests_run': False,
    'builds_run': False,
}
(OUT / 'bundle-verification.json').write_text(json.dumps(result, indent=2) + '\n', encoding='utf-8')
print(f'{len(checks)} stage copies: hashes match and no-write Dart format checks exit 0')
print(f'{len(final)} final replay paths: byte-identical to frozen source')
print('Core index unchanged. No Core source writes, index writes, tests or builds.')
