"""Extract failed Flutter JSON events from a downloaded cloud job log."""
import json
from pathlib import Path
import sys

events = []
for line in Path(sys.argv[1]).read_text(encoding='utf-8').splitlines():
    start = line.find('{')
    if start < 0:
        continue
    try:
        event = json.loads(line[start:])
    except json.JSONDecodeError:
        continue
    if isinstance(event, dict):
        events.append(event)
tests = {e['test']['id']: e['test'] for e in events if e.get('type') == 'testStart'}
for event in events:
    if event.get('type') == 'error':
        print(tests.get(event.get('testID')))
        print(event.get('error'))
        print(event.get('stackTrace'))
    if event.get('type') == 'testDone' and event.get('result') != 'success':
        print('FAILED', tests.get(event.get('testID')), event.get('result'))
