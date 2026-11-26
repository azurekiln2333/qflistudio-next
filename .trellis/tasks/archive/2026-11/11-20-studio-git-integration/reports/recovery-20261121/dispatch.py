"""Run four real Pi workers with durable sessions; exit is not acceptance."""
from __future__ import annotations

import datetime
import json
import os
from pathlib import Path
import shutil
import subprocess
import time

REPORTS = Path(__file__).resolve().parent
TASK = REPORTS.parent
WORK = Path('D:/MyNewProjects/_wt/studio-git-integration')
CLI = Path('D:/AppData/Roaming/npm/node_modules/@earendil-works/pi-coding-agent/dist/bundle/cli.js')
STATE = REPORTS / 'dispatch.json'
WORKERS = {
    'pi-a': ('qfli_git', 'Git plugin operations'),
    'pi-b': ('qfli_studio_core', 'Studio Git backend'),
    'pi-c': ('qfli_studio_core', 'Recovery native Git backend'),
    'pi-d': ('qfli_git', 'Recovery Git Dart API'),
}


def now():
    return datetime.datetime.now().astimezone().isoformat()


def save(state):
    temporary = STATE.with_suffix('.tmp')
    temporary.write_text(json.dumps(state, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    temporary.replace(STATE)


def main():
    if STATE.exists():
        raise RuntimeError('Dispatch state already exists. Inspect sessions before any restart.')
    node = shutil.which('node')
    if not node or not CLI.is_file():
        raise RuntimeError('Installed Pi CLI or Node is unavailable.')
    state = {'provider': 'pi', 'model_override': None, 'fresh_sessions': True,
             'supervisor_pid': os.getpid(), 'started_at': now(),
             'status': 'starting', 'accepted': False, 'workers': {}}
    processes = {}
    logs = []
    save(state)
    try:
        for name, (repo, title) in WORKERS.items():
            session_dir = REPORTS / 'sessions' / name
            session_dir.mkdir(parents=True, exist_ok=True)
            cwd = WORK / repo
            brief = REPORTS / 'briefs' / (name + '.md')
            item = {'cwd': str(cwd), 'brief': str(brief), 'session_dir': str(session_dir),
                    'started_at': now(), 'status': 'starting',
                    'stdout': str(REPORTS / (name + '.jsonl')),
                    'stderr': str(REPORTS / (name + '.stderr.log'))}
            state['workers'][name] = item
            env = os.environ.copy()
            env.update(PI_OFFLINE='1', PYTHONUTF8='1',
                       TRELLIS_CONTEXT_ID='studio-git-integration-' + name + '-20261120')
            args = [node, str(CLI), '--print', '--mode', 'json', '--no-extensions', '--no-mcp',
                    '--session-dir', str(session_dir), '--name', title,
                    '--tools', 'read,bash,powershell,edit,write,grep,find,ls',
                    '@' + str(brief),
                    'Implement this bounded recovery task. Read design.md and applicable source/specs, then make actual edits promptly. No local tests/builds.']
            stdout = open(item['stdout'], 'w', encoding='utf-8')
            stderr = open(item['stderr'], 'w', encoding='utf-8')
            logs.extend([stdout, stderr])
            child = subprocess.Popen(args, cwd=cwd, env=env, stdout=stdout, stderr=stderr,
                                     creationflags=subprocess.CREATE_NO_WINDOW if os.name == 'nt' else 0)
            processes[name] = child
            item.update(pid=child.pid, status='running')
            save(state)
        state['status'] = 'running'
        save(state)
        while processes:
            for name, child in list(processes.items()):
                code = child.poll()
                if code is None:
                    continue
                state['workers'][name].update(
                    exit_code=code, ended_at=now(),
                    status='exited_unreviewed' if code == 0 else 'needs_attention')
                del processes[name]
                save(state)
            if processes:
                time.sleep(5)
        state['status'] = 'workers_exited_unreviewed'
    except Exception as error:
        state.update(status='needs_attention', error=str(error))
    finally:
        state['updated_at'] = now()
        save(state)
        for handle in logs:
            handle.close()


if __name__ == '__main__':
    main()
