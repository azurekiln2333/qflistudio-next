"""Write curated task manifests and exact dispatch metadata, without starting Pi."""
import json
from pathlib import Path

TASK = Path(__file__).resolve().parent.parent
ROOT = TASK.parents[2]
relative = TASK.relative_to(ROOT).as_posix()
specs = [
    ('.trellis/spec/frontend/repository-layout.md', 'Sibling roots and pinned package graph'),
    ('.trellis/spec/frontend/project-storage.md', 'Clone destination and registration ownership'),
    ('.trellis/spec/frontend/process-lifecycle.md', 'Long Git process lifecycle and cancellation'),
    ('.trellis/spec/guides/cross-layer-thinking-guide.md', 'FFI/backend/controller/UI contracts'),
    ('.trellis/spec/guides/code-reuse-thinking-guide.md', 'Reuse current Git and project owners'),
    (relative + '/research/studio-integration.md', 'Source-backed platform and UI gap evidence'),
    (relative + '/research/baselines.md', 'Exact release baselines and isolated write roots'),
    (relative + '/research/cloud-delivery.md', 'Cloud-only verification and native artifact sequence'),
]
for name in ('implement', 'check'):
    (TASK / (name + '.jsonl')).write_text(''.join(
        json.dumps({'file': path, 'reason': reason}, ensure_ascii=False) + '\n'
        for path, reason in specs), encoding='utf-8')
data = json.loads((TASK / 'task.json').read_text(encoding='utf-8'))
data.update(priority='P1', dev_type='fullstack', scope='studio-git',
            package='qflistudio,qfli_studio_core,qfli_git',
            branch='release/studio-git-ui-20261120',
            base_branch='release/v5.0.5-preview.1',
            worktree_path='D:/MyNewProjects/_wt/studio-git-integration/qflistudio',
            relatedFiles=['prd.md', 'design.md', 'implement.md'],
            notes='User authorized planning then immediate actual Pi dispatch. No local tests/builds.')
data['meta'].update(
    planning_status='complete',
    planning_review='stream_fixtures: cloud scope, constructors, native CI sequence resolved',
    implementation_authorization='Latest user: 赶紧计划做完下去给pi去做',
    workers=['pi-a', 'pi-b', 'pi-c', 'pi-d'],
    dispatch_state=relative + '/reports/dispatch.json',
    validation_policy='cloud-only tests and builds',
    app_base='6d1b96d7118740f71e5dadf393cc8bd58238b6af',
    core_base='72c0b0955e4ddd5215dc818327fa5a67a4be22f7',
    plugin_base='89e656bd2c9f879c4fc7e6a0a343e17dc7d0f84a')
(TASK / 'task.json').write_text(json.dumps(data, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
print('Curated implementation/check manifests and dispatch metadata written.')
