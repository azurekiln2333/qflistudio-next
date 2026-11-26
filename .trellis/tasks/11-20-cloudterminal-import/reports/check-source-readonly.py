"""Compare the original source without refreshing or writing its Git index."""
import hashlib
import json
from datetime import datetime
from pathlib import Path
import subprocess

task = Path(__file__).resolve().parent.parent
baseline = json.loads((task / 'research/source-baseline.json').read_text(encoding='utf-8'))
root = Path(baseline['source'])

def git(*args):
    return subprocess.check_output(['git', '--no-optional-locks', '-C', str(root), *args]).decode('utf-8')

deltas = []
if git('rev-parse', 'HEAD').strip() != baseline['head']:
    deltas.append('HEAD')
if git('status', '--porcelain=v1', '-uall') != baseline['status']:
    deltas.append('status')
if hashlib.sha256((root / '.git/index').read_bytes()).hexdigest() != baseline['index_sha256']:
    deltas.append('index')
for name, digest in baseline['tracked_sha256'].items():
    file = root / name
    if not file.is_file() or hashlib.sha256(file.read_bytes()).hexdigest() != digest:
        deltas.append(name)
result = {'checked_at': datetime.now().astimezone().isoformat(), 'unchanged': not deltas, 'deltas': deltas}
(task / 'reports/source-check-latest.json').write_text(json.dumps(result, indent=2) + '\n', encoding='utf-8')
print(json.dumps(result))
raise SystemExit(1 if deltas else 0)
