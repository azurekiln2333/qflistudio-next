"""Stage reviewed cumulative copies without changing working source files."""
import argparse
import hashlib
import json
from pathlib import Path
import subprocess

HERE = Path(__file__).resolve().parent
ROOTS = {
    'core': Path('D:/MyNewProjects/_wt/studio-git-integration/qfli_studio_core'),
    'app': Path('D:/MyNewProjects/_wt/studio-git-integration/qflistudio'),
}


def git(root, *args, data=None, check=True):
    result = subprocess.run(['git', '-C', str(root), *args], input=data,
                            stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    if check and result.returncode:
        raise RuntimeError(result.stderr.decode('utf-8', errors='replace'))
    return result


def normal(data):
    return data.replace(b'\r\n', b'\n')


def digest(data):
    return hashlib.sha256(data).hexdigest()


def safe_child(root, relative):
    value = (root / relative).resolve()
    if not value.is_relative_to(root.resolve()):
        raise ValueError(f'Path escaped its root: {relative}')
    return value


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('requirement')
    parser.add_argument('--repo', choices=ROOTS, required=True)
    parser.add_argument('--bundles', nargs='+', required=True)
    parser.add_argument('--apply', action='store_true')
    options = parser.parse_args()
    root = ROOTS[options.repo]
    pending = []
    for name in options.bundles:
        bundle = safe_child(HERE, name)
        manifest = json.loads((bundle / 'manifest.json').read_text(encoding='utf-8'))
        prior = {}
        latest = {}
        selected = []
        base = manifest.get('base_commit') or manifest['base_commits'][options.repo]
        for stage in manifest['stages']:
            for row in stage['files']:
                if row.get('repo', 'core') != options.repo:
                    continue
                path = row['path']
                safe_child(root, path)
                content = safe_child(bundle, row['copy']).read_bytes()
                assert digest(content) == row['sha256'], f'Copy hash changed: {path}'
                if stage['requirement'] == options.requirement:
                    before = prior.get(path)
                    if before is None:
                        shown = git(root, 'show', f'{base}:{path}', check=False)
                        before = shown.stdout if shown.returncode == 0 else None
                    selected.append((path, before, content, row['copy']))
                prior[path] = content
                latest[path] = content
        for path, before, content, source in selected:
            assert (root / path).read_bytes() == latest[path], f'Frozen source changed: {path}'
            current = git(root, 'show', f':{path}', check=False)
            if before is None:
                assert current.returncode != 0, f'Unexpected index path: {path}'
            else:
                assert current.returncode == 0 and normal(current.stdout) == normal(before), \
                    f'Index does not match prior stage: {path}'
            mode_result = git(root, 'ls-files', '-s', '--', path).stdout.decode().split()
            mode = mode_result[0] if mode_result else '100644'
            pending.append((path, content, mode, str(bundle / source)))
    assert len({row[0] for row in pending}) == len(pending), 'Overlapping bundle ownership'
    for path, content, mode, source in pending:
        if options.apply:
            blob = git(root, 'hash-object', '-w', f'--path={path}', '--stdin', data=content).stdout.decode().strip()
            git(root, 'update-index', '--add', '--cacheinfo', mode, blob, path)
        print(json.dumps({'repo': options.repo, 'requirement': options.requirement,
                          'path': path, 'copy': source, 'staged': options.apply}))
    print(json.dumps({'count': len(pending), 'staged': options.apply}))


if __name__ == '__main__':
    main()
