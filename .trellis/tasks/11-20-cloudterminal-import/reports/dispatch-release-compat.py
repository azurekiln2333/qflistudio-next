"""Run a fresh Pi worker for the four-file compatibility repair."""
import datetime
import json
import os
from pathlib import Path
import shutil
import subprocess

REPORTS = Path(__file__).resolve().parent
WORK = Path('D:/MyNewProjects/_wt/release-v5.0.5/qfli_studio_core')
CLI = 'D:/AppData/Roaming/npm/node_modules/@earendil-works/pi-coding-agent/dist/bundle/cli.js'
SESSIONS = REPORTS / 'release-compat-pi-sessions'
STATE = REPORTS / 'release-compat-pi-state.json'

def now():
    return datetime.datetime.now().astimezone().isoformat()

SESSIONS.mkdir(parents=True, exist_ok=True)
state = {'provider': 'pi', 'model_override': None, 'fresh_session': True,
         'cwd': str(WORK), 'started_at': now(), 'status': 'running',
         'stdout': str(REPORTS / 'release-compat-pi.jsonl'),
         'stderr': str(REPORTS / 'release-compat-pi.stderr.log'),
         'session_dir': str(SESSIONS)}

def save():
    STATE.write_text(json.dumps(state, indent=2) + '\n', encoding='utf-8')

env = os.environ.copy()
env.update(PI_OFFLINE='1', PYTHONUTF8='1', TRELLIS_CONTEXT_ID='pi-release-compat-20261120')
args = [shutil.which('node'), CLI, '--print', '--mode', 'json', '--no-extensions', '--no-mcp',
        '--session-dir', str(SESSIONS), '--name', 'Release 5.0.5 relay and attachment compatibility',
        '--tools', 'read,bash,powershell,edit,write,grep,find,ls',
        '@' + str(REPORTS / 'release-compat-pi-brief.md'),
        'Implement both assigned fixes within the exact four-file allowlist. Do not run tests or builds.']
save()
try:
    with open(state['stdout'], 'w', encoding='utf-8') as stdout, open(state['stderr'], 'w', encoding='utf-8') as stderr:
        child = subprocess.Popen(args, cwd=WORK, env=env, stdout=stdout, stderr=stderr,
                                 creationflags=subprocess.CREATE_NO_WINDOW if os.name == 'nt' else 0)
        state['pid'] = child.pid
        save()
        state['exit_code'] = child.wait()
    state['status'] = 'artifacts_ready_unreviewed' if state['exit_code'] == 0 else 'needs_attention'
except Exception as error:
    state['status'] = 'needs_attention'
    state['error'] = str(error)
finally:
    state['ended_at'] = now()
    save()
