import json
from pathlib import Path
import sys

source = Path(sys.argv[1])
tests = {}
errors = {}
counts = {}
done = None
for line in source.read_text(encoding='utf-8-sig', errors='replace').splitlines():
    pos = line.find('{')
    if pos < 0:
        continue
    try:
        event = json.loads(line[pos:])
    except json.JSONDecodeError:
        continue
    kind = event.get('type')
    if kind == 'testStart':
        tests[event['test']['id']] = event['test']
    elif kind == 'error':
        errors.setdefault(event.get('testID'), []).append(event)
    elif kind == 'testDone':
        key = 'skipped' if event.get('skipped') else event.get('result')
        counts[key] = counts.get(key, 0) + 1
    elif kind == 'done':
        done = event
summary = {'counts': counts, 'done': done, 'failures': []}
for test_id, values in errors.items():
    test = tests.get(test_id, {})
    summary['failures'].append({
        'name': test.get('name'), 'url': test.get('url'),
        'errors': [x.get('error', '')[:2200] for x in values],
        'trace': [x.get('stackTrace', '')[:650] for x in values],
    })
output = source.with_suffix('.failures.json')
output.write_text(json.dumps(summary, ensure_ascii=False, indent=2), encoding='utf-8')
print(json.dumps({'counts': counts, 'done': done}, ensure_ascii=False))
for failure in summary['failures']:
    print(f"{failure['url']}: {failure['name']}")
    print(failure['errors'][0][:220].replace('\n', ' '))
print(f'Full report: {output}')
