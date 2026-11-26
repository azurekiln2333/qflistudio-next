"""Statically analyze a report-owned export of Core's actual Git index."""
import io
import json
from pathlib import Path
import subprocess
import sys
from urllib.parse import urljoin
import zipfile

from stage_requirement import ROOTS, git, safe_child

root = ROOTS['core']
report = Path(__file__).resolve().parent
tree = git(root, 'write-tree').stdout.decode().strip()
context = safe_child(report, f'_index_validation/{sys.argv[1]}-{tree[:10]}')
context.mkdir(parents=True, exist_ok=False)
archive = git(root, 'archive', '--format=zip', tree, 'lib', 'test',
              'analysis_options.yaml', 'pubspec.yaml').stdout
with zipfile.ZipFile(io.BytesIO(archive)) as zipped:
    for item in zipped.infolist():
        target = safe_child(context, item.filename)
        if item.is_dir():
            target.mkdir(parents=True, exist_ok=True)
        else:
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_bytes(zipped.read(item))
config_path = root / '.dart_tool/package_config.json'
config = json.loads(config_path.read_text(encoding='utf-8'))
for package in config['packages']:
    package['rootUri'] = (context.as_uri() + '/' if package['name'] == 'qfli_studio_core'
                          else urljoin(config_path.as_uri(), package['rootUri']))
(context / '.dart_tool').mkdir()
(context / '.dart_tool/package_config.json').write_text(json.dumps(config), encoding='utf-8')
changed = git(root, 'diff', '--cached', '--name-only', 'c619f9f', '--', 'test').stdout.decode().splitlines()
targets = ['lib'] + [path for path in changed if path.endswith('.dart') and (context / path).is_file()]
command = ['D:/ProgramFiles/flutter_ohos/bin/cache/dart-sdk/bin/dart.exe', 'analyze', *targets]
result = subprocess.run(command, cwd=context, capture_output=True)
output = result.stdout.decode('utf-8', errors='replace') + result.stderr.decode('utf-8', errors='replace')
(context / 'analyze.log').write_text(output, encoding='utf-8')
(context / 'evidence.json').write_text(json.dumps({
    'index_tree': tree, 'command': command, 'exit_code': result.returncode,
    'runtime_tests_run': False, 'builds_run': False,
}, indent=2), encoding='utf-8')
print(output)
print(f'Index tree: {tree}\nEvidence: {context}')
assert tree == git(root, 'write-tree').stdout.decode().strip(), 'Index changed during analysis'
sys.exit(result.returncode)
