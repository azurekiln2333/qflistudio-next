"""Prepare an artifacts-only Home workspace candidate; never write core or indexes."""
from datetime import datetime, timezone
import difflib
import hashlib
import json
from pathlib import Path
import subprocess

TASK = Path(__file__).resolve().parent.parent
CORE = Path('D:/MyNewProjects/qfli_studio_core')
OUT = TASK / '.artifacts/home-named-workspace-dependency-20261024'
HOME = 'lib/pages/home_page.dart'
TAB = 'lib/workspace/saved_workspaces_tab.dart'
CAPABILITY = Path('D:/MyNewProjects/qfli_json/.trellis/tasks/10-22-offline-json-ide/research')
GUARDS = [HOME, TAB, 'lib/editor/editor_page.dart', 'lib/editor/editor_controller.dart',
          'lib/editor/file_explorer.dart', 'lib/editor/retained_editor_host.dart',
          'lib/editor/terminal_pane.dart', 'lib/services/studio_profile.dart',
          'lib/workspace/saved_workspace.dart', 'lib/pages/local_content_pages.dart',
          'lib/pages/points_page.dart', 'lib/pages/tasks_page.dart', 'lib/pages/tools_grid.dart',
          '.trellis/spec/frontend/saved-workspaces.md']


def digest(data):
    return hashlib.sha256(data).hexdigest().upper()


def git(*args, data=None):
    return subprocess.run(['git', '-C', str(CORE), *args], input=data,
                          capture_output=True, check=True).stdout


def describe(path, data):
    return {'path': path, 'bytes': len(data), 'sha256': digest(data),
            'git_blob': git('hash-object', f'--path={path}', '--stdin', data=data).decode().strip()}


def snapshot():
    return {'core_head': git('rev-parse', 'HEAD').decode().strip(),
            'real_index_sha256': digest((CORE / '.git/index').read_bytes()),
            'files': {path: digest((CORE / path).read_bytes()) for path in GUARDS}}


def write(relative, data):
    target = (OUT / relative).resolve()
    assert OUT.resolve() in target.parents
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_bytes(data)
    return target


before = snapshot()
base = git('show', f"{before['core_head']}:{HOME}")
assert git('rev-parse', f"{before['core_head']}:{HOME}").decode().strip() == '38163e47bdd203d0c5f181d6162de2bae5ab83fd'
candidate = base.decode('utf-8')
edits = [
    ("import '../services/local_stats_service.dart';\n",
     "import '../services/local_stats_service.dart';\nimport '../workspace/saved_workspace.dart';\nimport '../workspace/saved_workspaces_tab.dart';\n"),
    ('enum _ProjectScope { all, history, favorite, cloud }',
     'enum _ProjectScope { all, history, favorite, workspace, cloud }'),
    ('''  late final List<_ProjectScope> _scopes =
      StudioProfile.current?.offlineOnly == true
      ? const [_ProjectScope.all, _ProjectScope.history, _ProjectScope.favorite]
      : _ProjectScope.values;''',
     '''  late final List<_ProjectScope> _scopes = [
    _ProjectScope.all,
    _ProjectScope.history,
    _ProjectScope.favorite,
    if (supportsSavedWorkspaces) _ProjectScope.workspace,
    if (StudioProfile.current?.offlineOnly != true) _ProjectScope.cloud,
  ];'''),
    ('''                        if (_scopes.contains(_ProjectScope.cloud))
                          Tab(''',
     '''                        if (_scopes.contains(_ProjectScope.workspace))
                          const Tab(
                            height: 36,
                            child: Center(child: Text('工作区')),
                          ),
                        if (_scopes.contains(_ProjectScope.cloud))
                          Tab('''),
    ('''                          for (final scope in _scopes)
                            _buildProjectList(context, scope: scope),''',
     '''                          for (final scope in _scopes)
                            scope == _ProjectScope.workspace
                                ? SavedWorkspacesTab(
                                    store: widget.store,
                                    auth: widget.auth,
                                    settings: widget.settings,
                                  )
                                : _buildProjectList(context, scope: scope),'''),
    ('''      case _ProjectScope.cloud:
        return all.where((p) => p.isCloud).toList();''',
     '''      case _ProjectScope.workspace:
        return const [];
      case _ProjectScope.cloud:
        return all.where((p) => p.isCloud).toList();'''),
]
worktree = (CORE / HOME).read_text(encoding='utf-8')
for old, new in edits:
    assert candidate.count(old) == 1, old
    # Exact existing workspace code is reused except the narrower scopes list.
    if '_scopes =' not in old:
        assert new in worktree, new
    candidate = candidate.replace(old, new, 1)
candidate = candidate.encode('utf-8')
tab = (CORE / TAB).read_bytes()
assert digest(tab) == 'D63E6E55D4CFADF4982FF841A2C3835D6D7EE727D966682A5A1914494B4536A5'
base_path = write('baseline/' + HOME, base)
candidate_path = write('candidate/' + HOME, candidate)
tab_path = write('candidate/' + TAB, tab)
home_patch = ''.join(difflib.unified_diff(base.decode().splitlines(keepends=True),
    candidate.decode().splitlines(keepends=True), fromfile='a/' + HOME, tofile='b/' + HOME))
assert sum(line.startswith('@@ ') for line in home_patch.splitlines()) == 6
home_patch_path = write('home-named-workspace.patch', home_patch.encode())
tab_patch = ''.join(difflib.unified_diff([], tab.decode().splitlines(keepends=True),
                                      fromfile='/dev/null', tofile='b/' + TAB))
combined_path = write('home-named-workspace-dependencies.patch', (home_patch + tab_patch).encode())
check = subprocess.run(['git', '-C', str(CORE), 'apply', '--check', '--whitespace=error',
    '--unsafe-paths', '--directory=' + str(OUT / 'baseline'), str(combined_path)],
    capture_output=True, text=True)
write('isolated-apply-check.json', json.dumps({'exit_code': check.returncode,
    'stdout': check.stdout, 'stderr': check.stderr,
    'scope': 'Read-only check against artifact baseline; no patch applied'}, indent=2).encode())
assert check.returncode == 0, check.stderr
capability_manifest = CAPABILITY / 'standalone-workspace-capability-handoff.json'
capability_patch = CAPABILITY / 'standalone-workspace-capability-implemented.patch'
after = snapshot()
assert before == after, 'Source, HEAD or real index changed during artifact preparation; inspect external owner activity.'
manifest = {
    'purpose': 'C421 exact minimal Home named-workspace dependency; artifacts only',
    'created_utc': datetime.now(timezone.utc).isoformat(),
    'authorization': 'C, as sole core publisher, may integrate ONLY this exact six-hunk Home candidate plus exact saved_workspaces_tab.dart frozen here into its next candidate. No wholesale current Home staging. This extends the published v4 closure without changing its authorized versions. No other Home/catalog/cloud/menu/cards/points/tools/assets/spec/page WIP is authorized.',
    'base': {'core_head': before['core_head'], 'home': describe(HOME, base)},
    'files': [dict(describe(HOME, candidate), frozen_path=str(candidate_path),
                   scope='Only the six-hunk candidate diff from the recorded base Home'),
              dict(describe(TAB, tab), frozen_path=str(tab_path), scope='Exact complete new tab module')],
    'patches': [{'path': str(home_patch_path), 'sha256': digest(home_patch_path.read_bytes()),
                 'scope': 'Home only; six hunks'},
                {'path': str(combined_path), 'sha256': digest(combined_path.read_bytes()),
                 'scope': 'Same Home plus exact tab addition'}],
    'current_home_wip_observed': describe(HOME, (CORE / HOME).read_bytes()),
    'capability_dependency': {
        'manifest': str(capability_manifest), 'manifest_sha256': digest(capability_manifest.read_bytes()),
        'patch': str(capability_patch), 'patch_sha256': digest(capability_patch.read_bytes()),
        'composition': 'This final capability-controlled Home mapping SUBSUMES the JSON Home hunk. Do not apply that old Home hunk a second time or import its broader main-cloud rule. Apply only the other three separately C-authorized capability paths (studio_profile, saved_workspace, file_explorer) alongside this Home candidate.',
        'required_api': 'supportsSavedWorkspaces getter backed by StudioProfile.supportsSavedWorkspaces default true; tab also requires existing v4 workspace models/store/dialogs/retained-host/page closure.',
    },
    'scope_policy': 'Preserve HEAD cloud behavior: cloud iff offlineOnly != true. Workspace iff supportsSavedWorkspaces, independently of offlineOnly and showHomeTabs. No _reloadProjects change is required: its existing scope guard already excludes workspace; tab owns workspace refresh.',
    'verification': {'isolated_patch_check_exit': check.returncode,
        'source_index_page_mutation': False, 'heavy_commands_run': False,
        'runtime_candidate_pass': False,
        'existing_evidence_boundary': 'JSON435 real-profile Home worktree PASS is observed historical evidence; it does not validate this smaller isolated candidate. C must verify its eventual composed candidate in its serial slot.'},
    'guards_before': before, 'guards_after': after,
    'exclusions': ['all other current Home WIP', 'catalog routing and main profile fallback',
        'main cloud filtering/create/fetch suppression', 'popup label ellipsis and other cards/menu changes',
        'points/tools/content/assets', 'same-id retained metadata follow-up', 'all source/index/page writes'],
}
manifest_path = write('manifest.json', (json.dumps(manifest, ensure_ascii=False, indent=2) + '\n').encode())
print(json.dumps({'manifest': str(manifest_path), 'sha256': digest(manifest_path.read_bytes()),
                  'files': manifest['files'], 'patches': manifest['patches'],
                  'checks': manifest['verification']}, indent=2))
