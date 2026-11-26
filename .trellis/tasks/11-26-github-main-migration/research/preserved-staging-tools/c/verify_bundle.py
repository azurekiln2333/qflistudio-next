"""Verify Pi C's staged cumulative copies without writing Core source or index.

Checks, in order:
1. every manifest entry exists, matches sha256 and byte count;
2. replaying the listed copies from the R2 base reproduces all frozen bytes;
3. current Core sources still equal the recorded frozen hashes;
4. Core index and sources do not change while verifying.

No test, build, service, device, staging, commit or push command runs.
"""
from __future__ import annotations

import hashlib
import json
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path

CORE = Path('D:/MyNewProjects/_wt/studio-git-integration/qfli_studio_core')
OUT = Path(__file__).resolve().parent


def git(*args: str) -> subprocess.CompletedProcess:
    return subprocess.run(['git', '-C', str(CORE), *args], capture_output=True)


def digest(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def index_hash() -> str:
    value = git('rev-parse', '--git-path', 'index').stdout.decode().strip()
    path = Path(value)
    if not path.is_absolute():
        path = CORE / path
    return digest(path.read_bytes())


def main() -> int:
    manifest = json.loads((OUT / 'manifest.json').read_text(encoding='utf-8'))
    base = manifest['base_commit']
    paths = sorted(manifest['verification']['frozen_source_sha256'])
    index_before = index_hash()

    failures: list[str] = []
    hashes_ok = 0
    if len(paths) != 13:
        failures.append(f'expected 13 frozen paths, found {len(paths)}')
    if [stage['requirement'] for stage in manifest['stages']] != ['R7', 'R3', 'R6', 'R8']:
        failures.append('unexpected cumulative stage order')
    for stage in manifest['stages']:
        seen = set()
        for entry in stage['files']:
            if entry['path'] in seen:
                failures.append(f'duplicate stage path: {stage["requirement"]}/{entry["path"]}')
            seen.add(entry['path'])
            if entry['copy'] != f'{stage["requirement"]}/{entry["path"]}':
                failures.append(f'noncanonical mirrored copy path: {entry["copy"]}')
            target = (OUT / entry['copy']).resolve()
            if not target.is_relative_to(OUT):
                raise ValueError(f'copy escapes report directory: {target}')
            data = target.read_bytes()
            if len(data) != entry['bytes']:
                failures.append(f"size {entry['copy']}: {len(data)} != {entry['bytes']}")
            if digest(data) != entry['sha256']:
                failures.append(f"sha256 mismatch: {entry['copy']}")
            if data == (CORE / entry['path']).read_bytes():
                frozen_claim = True
            else:
                frozen_claim = False
            if frozen_claim != entry['equals_frozen_source']:
                failures.append(f"frozen flag mismatch: {entry['copy']}")
            hashes_ok += 1

    replay: dict[str, bytes | None] = {}
    for path in paths:
        shown = git('show', f'{base}:{path}')
        replay[path] = shown.stdout if shown.returncode == 0 else None
    for stage in manifest['stages']:
        for entry in stage['files']:
            prior = replay.get(entry['path'])
            actual_prior = digest(prior) if prior is not None else None
            if actual_prior != entry['prior_sha256']:
                failures.append(f'prior-stage hash mismatch: {entry["copy"]}')
            replay[entry['path']] = (OUT / entry['copy']).read_bytes()

    equality = {}
    for path in paths:
        frozen = (CORE / path).read_bytes()
        equality[path] = replay[path] == frozen
        if not equality[path]:
            failures.append(f'replay differs from frozen source: {path}')
        if manifest['verification']['frozen_source_sha256'][path] != digest(frozen):
            failures.append(f'frozen source hash changed: {path}')

    index_after = index_hash()
    if index_before != index_after:
        failures.append('Core index changed during verification')
    missing = [path for path in paths if path not in
               {entry['path'] for stage in manifest['stages']
                for entry in stage['files']}]
    if missing:
        failures.append(f'paths never supplied: {missing}')

    analysis = json.loads((OUT / 'analysis-verification.json').read_text(encoding='utf-8'))
    if any(item['exit_code'] != 0 or not item['no_issues'] for item in analysis):
        failures.append('stage static-analysis findings remain')
    if manifest['verification']['format_check_exit_code'] != 0:
        failures.append('stage no-write formatting check did not pass')
    for stage in ['R7', 'R3', 'R6']:
        facade = (OUT / stage / 'lib/services/cloud_project_actions.dart').read_text(encoding='utf-8')
        if '_cacheChanged' in facade:
            failures.append(f'pre-R8 cache-listener reference: {stage}')
        if stage in ['R3', 'R6'] and 'bool isBusy(Project project)' not in facade:
            failures.append(f'isBusy missing at consumer stage: {stage}')

    record = {
        'verified_at': datetime.now(timezone.utc).isoformat(),
        'copies_checked': hashes_ok,
        'frozen_paths_replayed': len(paths),
        'final_replay_equals_frozen_source': equality,
        'stage_static_analysis': {item['stage']: item['exit_code'] for item in analysis},
        'format_check_exit_code': manifest['verification']['format_check_exit_code'],
        'index_sha256_before': index_before,
        'index_sha256_after': index_after,
        'index_unchanged': index_before == index_after,
        'failures': failures,
        'runtime_tests_run': False,
        'builds_run': False,
        'product_or_index_write_commands': [],
    }
    (OUT / 'bundle-verification.json').write_text(
        json.dumps(record, indent=2) + '\n', encoding='utf-8')
    print(f'copies checked: {hashes_ok}')
    print(f'stage copies: {sum(len(s["files"]) for s in manifest["stages"])}')
    print(f'frozen paths replayed: {len(paths)}')
    for path in paths:
        print(f'  {"OK " if equality[path] else "BAD"} {path}')
    if failures:
        for failure in failures:
            print('FAIL ' + failure)
        return 1
    print('All manifest hashes match and replay equals frozen bytes.')
    print('Core source and index unchanged.')
    return 0


if __name__ == '__main__':
    sys.exit(main())
