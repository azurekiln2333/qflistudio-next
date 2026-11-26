"""Create ignored analyzer configs from the existing local dependency cache."""
import json
from pathlib import Path
from urllib.parse import urljoin

source = Path('D:/MyNewProjects/qfli_studio_core/.dart_tool/package_config.json')
workspace = Path('D:/MyNewProjects/_wt/studio-git-integration')
data = json.loads(source.read_text(encoding='utf-8'))
packages = []
for package in data['packages']:
    entry = dict(package)
    entry['rootUri'] = urljoin(source.as_uri(), entry['rootUri'])
    if entry['name'] == 'qfli_studio_core':
        entry['rootUri'] = (workspace / 'qfli_studio_core').as_uri() + '/'
    elif entry['name'] == 're_editor':
        entry['rootUri'] = (workspace / 'qfli_studio_core/vendor/re_editor').as_uri() + '/'
    if entry['name'] != 'qfli_git':
        packages.append(entry)
packages.append({
    'name': 'qfli_git',
    'rootUri': (workspace / 'qfli_git').as_uri() + '/',
    'packageUri': 'lib/',
    'languageVersion': '3.11',
})
for name in ['qfli_studio_core', 'qfli_git']:
    target = workspace / name / '.dart_tool/package_config.json'
    if target.exists():
        raise SystemExit(f'Existing analyzer config was preserved: {target}')
for name in ['qfli_studio_core', 'qfli_git']:
    target = workspace / name / '.dart_tool/package_config.json'
    target.parent.mkdir(exist_ok=True)
    target.write_text(json.dumps({'configVersion': 2, 'packages': packages}, indent=2) + '\n', encoding='utf-8')
    print(f'Created ignored analyzer config: {target}')
