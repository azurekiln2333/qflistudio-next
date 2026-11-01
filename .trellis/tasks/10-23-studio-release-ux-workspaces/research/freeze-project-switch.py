"""Freeze the exact authorized selector dependencies without touching Git indexes."""
from datetime import datetime, timezone
import difflib
import hashlib
import json
from pathlib import Path
import shutil

TASK = Path(__file__).resolve().parent.parent
CORE = Path('D:/MyNewProjects/qfli_studio_core')
BASE = TASK / '.artifacts/project-switch-baseline-20261023T150053Z'
FREEZE = TASK / '.artifacts/project-switch-publication-v4'
PREVIOUS = TASK / 'c-publication-dependency-authorization-20261023-v3.json'
PAGE = 'lib/editor/editor_page.dart'
REPLACED = {'lib/editor/file_explorer.dart', 'lib/editor/retained_editor_host.dart',
            '.trellis/spec/frontend/saved-workspaces.md'}
ADDED = 'test/workspace_project_switch_test.dart'


def sha(data):
    return hashlib.sha256(data).hexdigest().upper()


def blob(data):
    # Git's index uses LF for these text paths; calculate without writing objects.
    normalized = data.replace(b'\r\n', b'\n')
    header = f'blob {len(normalized)}\0'.encode()
    return hashlib.sha1(header + normalized).hexdigest()


def record(relative, template=None):
    data = (CORE / relative).read_bytes()
    result = dict(template or {})
    result.update(path=relative, bytes=len(data), sha256=sha(data), git_blob=blob(data))
    return result


def patch_for(paths, name):
    lines = []
    for relative in paths:
        before = (BASE / relative).read_text(encoding='utf-8').splitlines(keepends=True)
        after = (CORE / relative).read_text(encoding='utf-8').splitlines(keepends=True)
        lines.extend(difflib.unified_diff(before, after, fromfile=f'a/{relative}',
                                          tofile=f'b/{relative}'))
    target = TASK / name
    target.write_bytes(''.join(lines).encode('utf-8'))
    return {'path': str(target), 'sha256': sha(target.read_bytes())}


def proof(directory):
    path = TASK / '.artifacts' / directory / 'process-handle-report.json'
    report = json.loads(path.read_text(encoding='utf-8'))
    assert report['test_result'] == 'PASS' and report['release_allowed']
    assert report['all_observed_flutter_processes_terminal']
    assert report['taskkill_helpers_terminal'] and not report['source_drift']
    return {'report': str(path), 'sha256': sha(path.read_bytes()), 'result': 'PASS',
            'elapsed_seconds': report['elapsed_seconds'],
            'all_observed_handles_terminal': True}


previous = json.loads(PREVIOUS.read_text(encoding='utf-8'))
files = []
replacements = []
for old in previous['files']:
    current = record(old['path'], old)
    if old['path'] in REPLACED:
        assert sha((BASE / old['path']).read_bytes()) == old['sha256']
        replacements.append({'old': old, 'new': current})
    else:
        assert current['sha256'] == old['sha256'], old['path']
        assert current['git_blob'] == old['git_blob'], old['path']
    files.append(current)
files.append(record(ADDED, {'tracked': False}))
assert len(files) == 19 and len(replacements) == 3
for item in files + [record(PAGE)]:
    destination = FREEZE / item['path']
    destination.parent.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(CORE / item['path'], destination)
    assert sha(destination.read_bytes()) == item['sha256']

index_sha = sha((CORE / '.git/index').read_bytes())
assert index_sha == previous['real_index_sha256_observed']
page_old = (BASE / PAGE).read_bytes()
page = record(PAGE)
page.update(baseline_sha256=sha(page_old), baseline_bytes=len(page_old),
            patch=patch_for([PAGE], 'project-switch-page-adapter.patch'),
            authorization='Only this exact three-hunk adapter delta on the composed C page; no whole-page staging authority.')
manifest = {
    'purpose': 'Exact19 dependency authorization and isolated C page adapter for project selector correction',
    'created_utc': datetime.now(timezone.utc).isoformat(),
    'supersedes': {'path': str(PREVIOUS), 'sha256': sha(PREVIOUS.read_bytes())},
    'authorization': 'C may refresh only the three replacement dependency blobs and add the new selector test, then integrate these exact19 dependencies with its composed page plus the separately authorized exact adapter patch. Other15 v3 versions, exclusions and ordering constraints remain unchanged. No further main approval required; main mutated neither Git index.',
    'change_scope': 'Saved member selection retains stable roots/order/children/expansion/scroll and dirty buffers, changing only browsing/default creation target. External main/saved selection opens or resumes a standalone editor. Legacy unsaved language-product browsing is preserved.',
    'replacements': replacements, 'added_paths': [ADDED], 'unchanged_prior_paths': 15,
    'files': files, 'frozen_copies': str(FREEZE), 'page_adapter': page,
    'patch': patch_for(sorted(REPLACED), 'project-switch-dependency-delta.patch'),
    'real_index_sha256_observed': index_sha,
    'verification': {
        'focused3': proof('main-project-switch-gate-20261023T151454Z-17f2de49'),
        'related40': proof('main-project-switch-regressions-gate-20261023T151546Z-daf488d1'),
        'analysis4': proof('main-project-switch-analysis-gate-20261023T151707Z-dc2565dd'),
    },
    'baseline_failure': 'main-project-switch-gate-20261023T151117Z-a533f62d: actual popup selecting B leaves only B; no-host external C never changes editor identity. Earlier attempt stopped in hidden-tree fixture and is not selector failure evidence.',
    'known_separate_issue': previous['known_separate_issue'],
    'limitations': 'Widget tests and scoped analysis only, no device install or native build. Separate broad formatting proposal remains unapplied and outside this authorization.',
}
target = TASK / 'c-publication-dependency-authorization-20261023-v4.json'
target.write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
assert sha((CORE / '.git/index').read_bytes()) == index_sha
print(json.dumps({'manifest': str(target), 'sha256': sha(target.read_bytes()),
                  'page': page, 'unchanged_prior_paths': 15}, indent=2))
