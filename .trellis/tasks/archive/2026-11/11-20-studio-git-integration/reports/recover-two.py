from pathlib import Path

base = Path(__file__).resolve().parent
prior = base / 'recovery-20261121'
destination = base / 'recovery-20261121b'
(destination / 'briefs').mkdir(parents=True, exist_ok=True)
for name in ('pi-c', 'pi-d'):
    content = (prior / 'briefs' / (name + '.md')).read_text(encoding='utf-8')
    content += '''
RECOVERY UPDATE: Root has now written git_models.dart, git_backend.dart,
git_cancellation.dart, git_repository_queue.dart and cli_git_backend.dart.
The previous workers ended. Do not wait. Read design and your partial source,
then edit missing code immediately. Do not output edit commands as XML text.
Invoke the actual write/edit tool. Do not repeat plans.
'''
    if name == 'pi-d':
        content += '''
Your bindings/types already exist. GitRepository's stagePaths/unstagePaths/diff/
log/branches/remotes/setRemote methods and qfli_git.dart exports are missing.
Finish only these methods and parser tests. Native C v2 code is now present.
'''
    content += '\nWrite final report to ' + str(destination / (name + '-report.md')) + '\n'
    (destination / 'briefs' / (name + '.md')).write_text(content, encoding='utf-8')
source = (prior / 'dispatch.py').read_text(encoding='utf-8')
source = source.replace("    'pi-a': ('qfli_git', 'Git plugin operations'),\n", '')
source = source.replace("    'pi-b': ('qfli_studio_core', 'Studio Git backend'),\n", '')
(destination / 'dispatch.py').write_text(source, encoding='utf-8')
print(str(destination))
