"""Verify frozen artifacts and committed source; no runtime tests."""
import hashlib
import json
from pathlib import Path

from stage_requirement import ROOTS, git, normal, safe_child

report = Path(__file__).resolve().parent
checks = []
for name in ['b', 'c', 'd']:
    bundle = report / name
    manifest = json.loads((bundle / 'manifest.json').read_text(encoding='utf-8'))
    latest = {}
    count = 0
    for stage in manifest['stages']:
        for row in stage['files']:
            content = safe_child(bundle, row['copy']).read_bytes()
            assert hashlib.sha256(content).hexdigest() == row['sha256'], row['copy']
            latest[(row.get('repo', 'core'), row['path'])] = content
            count += 1
    for (repo, path), content in latest.items():
        root = ROOTS[repo]
        assert safe_child(root, path).read_bytes() == content, f'Frozen source changed: {repo}/{path}'
        assert normal(git(root, 'show', f'HEAD:{path}').stdout) == normal(content), f'HEAD differs: {repo}/{path}'
    checks.append({'bundle': name, 'copies_checked': count, 'final_paths_checked': len(latest),
                   'all_copy_hashes_match': True, 'source_bytes_match': True, 'head_content_matches': True})
roots = []
for name, root in ROOTS.items():
    assert not git(root, 'status', '--porcelain=v1').stdout, f'Dirty {name}'
    roots.append({'repo': name, 'path': str(root), 'head': git(root, 'rev-parse', 'HEAD').stdout.decode().strip(),
                  'index_tree': git(root, 'write-tree').stdout.decode().strip(), 'clean': True})
analyses = []
for directory in ['_index_validation', '_app_index_validation']:
    for evidence in sorted((report / directory).glob('*/evidence.json')):
        row = json.loads(evidence.read_text(encoding='utf-8'))
        assert row['exit_code'] == 0, str(evidence)
        analyses.append({'stage': evidence.parent.name, 'exit_code': row['exit_code'],
                         'index_tree': row['index_tree'], 'evidence': str(evidence.relative_to(report))})
result = {'roots': roots, 'frozen_bundles': checks, 'stage_analysis': analyses,
          'runtime_tests_run': False, 'native_compilation_run': False, 'builds_run': False,
          'pushed': False, 'released': False}
(report / 'final-verification.json').write_text(json.dumps(result, indent=2), encoding='utf-8')
print(json.dumps(result, indent=2))
