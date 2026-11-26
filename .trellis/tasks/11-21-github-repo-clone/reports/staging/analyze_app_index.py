"""Check App's staged Dart/configuration without builds or runtime tests."""
import io
import json
from pathlib import Path
import plistlib
import subprocess
import sys
from urllib.parse import urljoin
import xml.etree.ElementTree as ET
import zipfile

import yaml

from stage_requirement import ROOTS, git, safe_child

root = ROOTS['app']
report = Path(__file__).resolve().parent
tree = git(root, 'write-tree').stdout.decode().strip()
context = safe_child(report, f'_app_index_validation/{sys.argv[1]}-{tree[:10]}')
context.mkdir(parents=True, exist_ok=False)
archive = git(root, 'archive', '--format=zip', tree, 'lib', 'analysis_options.yaml',
              'pubspec.yaml').stdout
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
    package['rootUri'] = (context.as_uri() + '/' if package['name'] == 'qflistudio'
                          else urljoin(config_path.as_uri(), package['rootUri']))
(context / '.dart_tool').mkdir()
(context / '.dart_tool/package_config.json').write_text(json.dumps(config), encoding='utf-8')
changed = git(root, 'diff', '--cached', '--name-only',
              '1cea02946e5191f2a76bd8915ff0a527547f0463').stdout.decode().splitlines()
parsed = []
for path in changed:
    data = git(root, 'show', f':{path}').stdout
    suffix = Path(path).suffix
    parser = None
    if suffix == '.xml':
        ET.fromstring(data)
        parser = 'XML'
    elif suffix in {'.plist', '.entitlements'}:
        plistlib.loads(data)
        parser = 'plist'
    elif suffix in {'.yaml', '.yml'} or path == 'pubspec.lock':
        yaml.safe_load(data)
        parser = 'YAML'
    if parser:
        target = safe_child(context / 'configuration', path)
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_bytes(data)
        parsed.append({'path': path, 'parser': parser, 'result': 'passed'})
command = ['D:/ProgramFiles/flutter_ohos/bin/cache/dart-sdk/bin/dart.exe',
           'analyze', 'lib']
result = subprocess.run(command, cwd=context, capture_output=True)
output = result.stdout.decode('utf-8', errors='replace') + result.stderr.decode('utf-8', errors='replace')
(context / 'analyze.log').write_text(output, encoding='utf-8')
(context / 'evidence.json').write_text(json.dumps({
    'index_tree': tree, 'command': command, 'exit_code': result.returncode,
    'configuration_syntax': parsed, 'core_head': git(ROOTS['core'], 'rev-parse', 'HEAD').stdout.decode().strip(),
    'runtime_tests_run': False, 'native_compilation_run': False, 'builds_run': False,
}, indent=2), encoding='utf-8')
print(output)
print(f'Configuration syntax: {len(parsed)} files passed')
print(f'Index tree: {tree}\nEvidence: {context}')
assert tree == git(root, 'write-tree').stdout.decode().strip(), 'Index changed during analysis'
sys.exit(result.returncode)
