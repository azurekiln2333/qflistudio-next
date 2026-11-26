"""Run Pi phases; process exit is never an implementation acceptance signal."""
import datetime
import argparse
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess

TASK = Path(__file__).resolve().parent.parent
REPORTS = TASK / 'reports'
BRIEFS = REPORTS / 'phase-briefs'
WORK = Path('D:/MyNewProjects/_wt/cloudterminal-import/work')
ROOTS = {'core': WORK / 'qfli_studio_core', 'app': WORK / 'qflistudio'}
CLI = 'D:/AppData/Roaming/npm/node_modules/@earendil-works/pi-coding-agent/dist/bundle/cli.js'
parser = argparse.ArgumentParser()
parser.add_argument('--config', default='phases.json')
parser.add_argument('--state', default='dispatch-phases.json')
options = parser.parse_args()
STATE = REPORTS / options.state

def now():
    return datetime.datetime.now().astimezone().isoformat()

state = {'provider': 'pi', 'pid': os.getpid(), 'started_at': now(), 'status': 'running', 'phases': []}

def save():
    STATE.write_text(json.dumps(state, indent=2) + '\n', encoding='utf-8')

def source_check():
    baseline = json.loads((TASK / 'research/source-baseline.json').read_text(encoding='utf-8'))
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
    result = {'checked_at': now(), 'unchanged': not deltas, 'deltas': deltas}
    (REPORTS / 'source-check-latest.json').write_text(json.dumps(result, indent=2) + '\n', encoding='utf-8')
    if deltas:
        raise RuntimeError('Source changed; do not restore it. Review source-check-latest.json.')

def path_for(value):
    kind, relative = value.split('/', 1)
    return ROOTS[kind] / relative

try:
    source_check()
    phases = json.loads((REPORTS / options.config).read_text(encoding='utf-8'))
    env = os.environ.copy()
    env.update(PI_OFFLINE='1', PYTHONUTF8='1', TRELLIS_CONTEXT_ID='pi-cloudterminal-import-20261120')
    for phase in phases:
        phase_state = {'name': phase['name'], 'status': 'running', 'attempts': []}
        state['phases'].append(phase_state)
        save()
        for attempt in range(1, 3):
            prefix = REPORTS / (phase['name'] + '-' + str(attempt))
            sessions = REPORTS / 'phase-sessions' / phase['name']
            sessions.mkdir(parents=True, exist_ok=True)
            args = [shutil.which('node'), CLI, '--print', '--mode', 'json', '--no-extensions', '--no-mcp',
                    '--session-dir', str(sessions), '--name', 'CloudTerminal ' + phase['name'],
                    '--tools', 'read,bash,powershell,edit,write,grep,find,ls',
                    '@' + str(BRIEFS / 'common.md'), '@' + str(BRIEFS / (phase['name'] + '.md')),
                    'Execute the assigned phase with real file edits. Inspect existing partial work before editing. Do not stop at a proposed plan.']
            item = {'attempt': attempt, 'started_at': now(), 'stdout': str(prefix) + '.jsonl'}
            phase_state['attempts'].append(item)
            save()
            with open(str(prefix) + '.jsonl', 'w', encoding='utf-8') as stdout, open(str(prefix) + '.stderr.log', 'w', encoding='utf-8') as stderr:
                child = subprocess.Popen(args, cwd=ROOTS['core'], env=env, stdout=stdout, stderr=stderr)
                item['pid'] = child.pid
                save()
                item['exit_code'] = child.wait()
            item['ended_at'] = now()
            source_check()
            missing = [value for value in phase['paths'] if not path_for(value).exists()]
            if not (REPORTS / phase['report']).is_file():
                missing.append('reports/' + phase['report'])
            if phase['name'] in ('04-verification', '04b-ci'):
                for name in ('pi-implementation.md', 'pi-implementation.done'):
                    if not (REPORTS / name).is_file():
                        missing.append('reports/' + name)
            item['missing_artifacts'] = missing
            save()
            if item['exit_code'] == 0 and not missing:
                phase_state['status'] = 'artifacts_ready_unreviewed'
                save()
                break
        else:
            phase_state['status'] = 'incomplete'
            raise RuntimeError('Phase ended without required artifacts: ' + phase['name'])
    state['status'] = 'implementation_ready_for_review'
    state['accepted'] = False
except Exception as error:
    state['status'] = 'needs_attention'
    state['error'] = str(error)
finally:
    state['ended_at'] = now()
    save()
