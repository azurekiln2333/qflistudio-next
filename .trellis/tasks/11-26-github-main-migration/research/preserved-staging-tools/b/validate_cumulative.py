"""Analyze B stage copies in report-owned package contexts. No runtime tests.

Contexts contain final frozen service contracts plus B's cumulative historical
UI versions. This checks B's typing against published A/C/D APIs, not a complete
historical build of the other workers' separate staged service implementations.
All writes (including analysis contexts/logs) remain below reports/staging/b.
"""
from __future__ import annotations

import hashlib
import json
import shutil
import subprocess
from datetime import datetime, timezone
from pathlib import Path
from urllib.parse import urljoin

OUT = Path(__file__).resolve().parent
MANIFEST = json.loads((OUT / 'manifest.json').read_text(encoding='utf-8'))
CORE = Path(MANIFEST['core'])
DART = 'D:/ProgramFiles/flutter_ohos/bin/cache/dart-sdk/bin/dart.exe'


def sha(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def git(*args: str, check: bool = True) -> subprocess.CompletedProcess:
    return subprocess.run(['git', '-C', str(CORE), *args], capture_output=True, check=check)


def source_hashes() -> dict[str, str]:
    return {path: sha((CORE / path).read_bytes())
        for path in MANIFEST['verification']['frozen_source_sha256']}


def index_hash() -> str:
    path = Path(git('rev-parse', '--git-path', 'index').stdout.decode().strip())
    if not path.is_absolute():
        path = CORE / path
    return sha(path.read_bytes())


before = source_hashes()
if before != MANIFEST['verification']['frozen_source_sha256']:
    raise RuntimeError('B source no longer matches the frozen input manifest')
before_index = index_hash()
config_path = CORE / '.dart_tool/package_config.json'
config = json.loads(config_path.read_text(encoding='utf-8'))
source_uri = config_path.as_uri()
paths = list(before)
current = {}
for path in paths:
    previous = git('show', f'{MANIFEST["base_commit"]}:{path}', check=False)
    if previous.returncode == 0:
        current[path] = previous.stdout
results = []
for stage in MANIFEST['stages']:
    name = stage['requirement']
    for entry in stage['files']:
        current[entry['path']] = (OUT / entry['copy']).read_bytes()
    context = (OUT / '_validation' / name).resolve()
    if not context.is_relative_to(OUT):
        raise ValueError('Invalid validation context path')
    # Final service types are references only. Source and index never change.
    shutil.copytree(CORE / 'lib', context / 'lib', dirs_exist_ok=True)
    for path in paths:
        target = context / path
        if path in current:
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_bytes(current[path])
        elif target.exists():
            target.unlink()  # Report-owned copy only; no later B file at this stage.
    local_config = dict(config)
    local_config['packages'] = []
    for package in config['packages']:
        local = dict(package)
        local['rootUri'] = (context.as_uri() + '/') if package['name'] == 'qfli_studio_core' else urljoin(source_uri, package['rootUri'])
        local_config['packages'].append(local)
    package_dir = context / '.dart_tool'
    package_dir.mkdir(parents=True, exist_ok=True)
    (package_dir / 'package_config.json').write_text(
        json.dumps(local_config, indent=2) + '\n', encoding='utf-8')
    (context / 'analysis_options.yaml').write_bytes((CORE / 'analysis_options.yaml').read_bytes())
    # Analyze only B's cumulative changed paths, including earlier stage files.
    changed = [path for path in paths if path in current and
        (git('show', f'{MANIFEST["base_commit"]}:{path}', check=False).returncode != 0 or
         current[path] != git('show', f'{MANIFEST["base_commit"]}:{path}', check=False).stdout)]
    command = [DART, 'analyze', *changed]
    result = subprocess.run(command, cwd=context, capture_output=True)
    stdout = result.stdout.decode('utf-8', errors='replace')
    stderr = result.stderr.decode('utf-8', errors='replace')
    (context / 'analyze.log').write_text(stdout + stderr, encoding='utf-8')
    results.append({
        'stage': name, 'cwd': str(context), 'command': command,
        'exit_code': result.returncode, 'output': stdout + stderr,
        'changed_paths': changed,
    })
    print(name + ': exit ' + str(result.returncode))
    print(stdout + stderr)

after = source_hashes()
after_index = index_hash()
record = {
    'verified_at': datetime.now(timezone.utc).isoformat(),
    'validation_model': 'report-only copied package, final service contracts plus cumulative B UI',
    'results': results,
    'all_targeted_analysis_clean': all(row['exit_code'] == 0 and 'No issues found!' in row['output'] for row in results),
    'sources_unchanged': before == after,
    'index_sha256_before': before_index, 'index_sha256_after': after_index,
    'index_unchanged': before_index == after_index,
    'runtime_tests_run': False, 'builds_run': False,
}
(OUT / 'static-analysis.json').write_text(json.dumps(record, indent=2) + '\n', encoding='utf-8')
if before != after:
    raise RuntimeError('Frozen source changed concurrently')
if before_index != after_index:
    raise RuntimeError('Index changed concurrently. Root must inspect its own staging.')
if not record['all_targeted_analysis_clean']:
    raise SystemExit(1)
print('All seven cumulative B UI stages analyze cleanly. Core source/index unchanged.')
