"""Build Pi C's cumulative commit inputs without touching Core sources or index.

Every write stays below this script's reports/staging/c directory. Core is only
read: frozen source bytes, `git show` at the R2 commit, `git rev-parse`, and its
existing `.dart_tool/package_config.json` for report-owned static analysis.
No checkout, add, apply, update-index, hash-object -w, test, build, service,
device, staging, commit or push command runs.
"""
from __future__ import annotations

import argparse
import difflib
import hashlib
import json
import shutil
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path
from urllib.parse import urljoin

CORE = Path('D:/MyNewProjects/_wt/studio-git-integration/qfli_studio_core')
OUT = Path(__file__).resolve().parent
DART = Path('D:/ProgramFiles/flutter_ohos/bin/cache/dart-sdk/bin/dart.exe')
BASE = '16a6a474da0d014f6c36a3a91430273feed0d337'
ORDER = ['R7', 'R3', 'R6', 'R8']
RANK = {stage: index for index, stage in enumerate(ORDER)}

PROJECT = 'lib/models/project.dart'
CLOUD_PROJECT = 'lib/models/cloud_project.dart'
API = 'lib/services/api_client.dart'
APP_PATHS = 'lib/services/app_paths.dart'
CACHE_PATHS = 'lib/services/cloud_cache_paths.dart'
CACHE = 'lib/services/cloud_cache_service.dart'
ACTIONS = 'lib/services/cloud_project_actions.dart'
SYNC = 'lib/services/cloud_sync_service.dart'
STORE = 'lib/store/project_store.dart'
AUTH = 'lib/store/auth_store.dart'
CACHE_TEST = 'test/cloud_cache_service_test.dart'
ACTIONS_TEST = 'test/cloud_project_actions_test.dart'
AUTH_TEST = 'test/cloud_auth_generation_test.dart'

PATHS = [
    PROJECT, CLOUD_PROJECT, API, APP_PATHS, CACHE_PATHS, CACHE, ACTIONS, SYNC,
    STORE, AUTH, CACHE_TEST, ACTIONS_TEST, AUTH_TEST,
]

FINAL: dict[str, bytes] = {}
TEXT: dict[str, str] = {}
BASE_BYTES: dict[str, bytes | None] = {}
TEXT_BY_STAGE: dict[tuple[str, str], str] = {}


def git(*args: str, check: bool = True) -> subprocess.CompletedProcess:
    return subprocess.run(
        ['git', '-C', str(CORE), *args], capture_output=True, check=check
    )


def norm(data: bytes) -> str:
    return data.decode('utf-8').replace('\r\n', '\n')


def once(text: str, old: str, new: str = '') -> str:
    if text.count(old) != 1:
        raise ValueError(
            f'Expected one exact target, found {text.count(old)}: {old[:120]!r}'
        )
    return text.replace(old, new, 1)


def region(text: str, start: str, end: str) -> str:
    first = text.index(start)
    last = text.index(end, first + len(start))
    return text[first:last]


def replace_region(text: str, start: str, end: str, value: str = '') -> str:
    return once(text, region(text, start, end), value)


def write(relative: str, data: bytes) -> None:
    target = (OUT / relative).resolve()
    if not target.is_relative_to(OUT):
        raise ValueError(f'Output escaped report directory: {relative}')
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_bytes(data)


def digest(data: bytes | None) -> str | None:
    return None if data is None else hashlib.sha256(data).hexdigest()


def index_digest() -> str:
    value = git('rev-parse', '--git-path', 'index').stdout.decode().strip()
    path = Path(value)
    if not path.is_absolute():
        path = CORE / path
    return digest(path.read_bytes())  # type: ignore[arg-type]


def source_guard() -> dict[str, str | None]:
    return {path: digest((CORE / path).read_bytes()) for path in PATHS}


# --------------------------------------------------------------------------
# Stage transforms. Each returns the complete cumulative text for that stage.
# --------------------------------------------------------------------------

def actions_version(stage: str) -> str:
    """R7: scoped refresh facade. R3: delete/busy. R6: export adapter. R8: status."""
    text = TEXT[ACTIONS]
    if not (RANK[stage] >= RANK['R8']):
        text = once(text, '    this.cache.addListener(_cacheChanged);\n')
        text = once(text, '    cache.removeListener(_cacheChanged);\n')
        text = replace_region(
            text, '  void _cacheChanged() {\n', '  CloudSession _capture() {'
        )
        text = replace_region(
            text,
            '  CloudCacheStatus status(Project project) =>\n',
            '  Future<void> refresh() async {',
        )
        text = replace_region(
            text,
            '    for (final project in projects) {\n',
            '    if (!_disposed) notifyListeners();\n  }',
        )
        text = replace_region(
            text,
            '  Future<CloudCacheStatus> inspect(Project project) =>\n',
            '  /// Workspace owners need not be present',
        )
    if not (RANK[stage] >= RANK['R6']):
        text = replace_region(
            text,
            '  /// Workspace owners need not be present',
            '  @override\n  void dispose()',
        )
    if not (RANK[stage] >= RANK['R3']):
        text = replace_region(
            text,
            '  bool isBusy(Project project) =>\n',
            '  Future<void> refresh() async {',
        )
        text = replace_region(
            text,
            '  Future<CloudDeleteResult> deleteProject(Project project) async {',
            '  @override\n  void dispose()',
        )
        text = once(
            text,
            '      session: session,\n      reconcile: true,\n',
            '      session: session,\n',
        )
    return text


def store_version(stage: str) -> str:
    """R7: scoped registration/merge/query only. R3: tombstones/reconcile."""
    if RANK[stage] >= RANK['R3']:
        return TEXT[STORE]
    text = TEXT[STORE]
    text = once(
        text,
        "({List<Project> projects, String? browsedId, Set<String> deletedCloud})\n"
        "_readProjectRegistry(({String path, IosSandboxPaths? iosPaths}) input) {\n"
        "  final file = File(input.path);\n"
        "  if (!file.existsSync()) {\n"
        "    return (projects: <Project>[], browsedId: null, deletedCloud: <String>{});\n"
        "  }\n",
        "({List<Project> projects, String? browsedId}) _readProjectRegistry(\n"
        "  ({String path, IosSandboxPaths? iosPaths}) input,\n"
        ") {\n"
        "  final file = File(input.path);\n"
        "  if (!file.existsSync()) return (projects: <Project>[], browsedId: null);\n",
    )
    text = once(
        text,
        "  final deletedCloud = <String>{};\n"
        "  for (final value\n"
        "      in data['deletedCloud'] is List\n"
        "          ? data['deletedCloud'] as List\n"
        "          : const []) {\n"
        "    if (value is String &&\n"
        "        RegExp(\n"
        "          r'^[a-f0-9]{64}/[a-f0-9]{64}/[A-Za-z0-9][A-Za-z0-9_-]{0,127}$',\n"
        "        ).hasMatch(value)) {\n"
        "      deletedCloud.add(value);\n"
        "    }\n"
        "  }\n"
        "  return (\n"
        "    projects: projects,\n"
        "    browsedId: data['lastBrowsedProjectId'] as String?,\n"
        "    deletedCloud: deletedCloud,\n"
        "  );\n",
        "  return (\n"
        "    projects: projects,\n"
        "    browsedId: data['lastBrowsedProjectId'] as String?,\n"
        "  );\n",
    )
    text = once(text, '  final Set<String> _deletedCloud = {};\n')
    text = replace_region(
        text,
        '      .where(\n'
        '        (project) =>\n'
        "            project.belongsToCloudScope(scope) &&\n"
        "            !_deletedCloud.contains('${scope.key}/${project.cloudId}'),\n"
        '      )\n',
        '      .toList();\n',
        '      .where((project) => project.belongsToCloudScope(scope))\n',
    )
    text = replace_region(
        text,
        '  bool _isDeletedCloud(Project project) {\n',
        '  /// 文件树上一次浏览的项目',
    )
    text = once(
        text,
        '    _deletedCloud.addAll(result.deletedCloud);\n'
        '    _projects\n'
        '      ..clear()\n'
        '      ..addAll(result.projects.where((project) => !_isDeletedCloud(project)));\n',
        '    _projects\n'
        '      ..clear()\n'
        '      ..addAll(result.projects);\n',
    )
    text = once(text, "          'deletedCloud': _deletedCloud.toList()..sort(),\n")
    text = once(
        text,
        '              if (!_isDeletedCloud(project) &&\n'
        '                  (!_pendingLocalRegistrations.contains(project) ||\n'
        '                      identical(project, registering)))\n',
        '              if (!_pendingLocalRegistrations.contains(project) ||\n'
        '                  identical(project, registering))\n',
    )
    text = once(
        text,
        '    CloudProjectScope.validateCloudId(cloudId);\n'
        "    if (_deletedCloud.contains('${scope.key}/$cloudId')) {\n"
        "      return (error: '该云端项目已删除，请刷新列表', project: null);\n"
        '    }\n',
        '    CloudProjectScope.validateCloudId(cloudId);\n',
    )
    text = replace_region(
        text,
        '  Future<void> mergeCloudProjects(\n',
        '  /// Records a server-confirmed fact',
        '  Future<void> mergeCloudProjects(\n'
        '    Iterable<Project> projects, {\n'
        '    CloudProjectScope? scope,\n'
        '    int? generation,\n'
        '    CloudSession? session,\n'
        '  }) async {\n'
        '    session?.ensureCurrent();\n'
        '    if (scope == null ||\n'
        '        generation == null ||\n'
        '        !cloudRefreshIsCurrent(scope, generation)) {\n'
        '      return;\n'
        '    }\n'
        '    final priorGeneration = _cloudGeneration;\n'
        '    for (final project in projects) {\n'
        '      if (!project.belongsToCloudScope(scope)) continue;\n'
        '      final existing = _projects.where(\n'
        '        (item) =>\n'
        '            item.cloudId == project.cloudId && item.belongsToCloudScope(scope),\n'
        '      );\n'
        '      if (existing.isEmpty) {\n'
        '        _projects.add(project);\n'
        '      } else {\n'
        '        // Do not move an old mirror: it may hold unsent editor changes.\n'
        '        existing.first.name = project.name;\n'
        '      }\n'
        '    }\n'
        '    void ensureCurrent() {\n'
        '      session?.ensureCurrent();\n'
        '      if (!cloudRefreshIsCurrent(scope, priorGeneration)) {\n'
        "        throw const CloudOperationException('staleRefresh', '云端列表已更新，请重试');\n"
        '      }\n'
        '    }\n'
        '\n'
        '    await _persist(ensureCurrent: ensureCurrent);\n'
        '    notifyListeners();\n'
        '  }\n'
        '\n',
    )
    text = replace_region(
        text,
        '  /// Records a server-confirmed fact',
        '  /// 仅从列表移除',
    )
    return text


def auth_test_version(stage: str) -> str:
    """R7: auth revision only. R6: adds the snapshot A-B-A case."""
    if RANK[stage] >= RANK['R6']:
        return TEXT[AUTH_TEST]
    text = TEXT[AUTH_TEST]
    text = replace_region(
        text,
        "  test(\n    'cloud snapshot invalidates same-token A-B-A but survives profile updates',\n",
        '}\n\nclass _ProfileApi extends ApiClient {',
    )
    for imported in [
        "import 'package:qfli_studio_core/config/api_config.dart';\n",
        "import 'package:qfli_studio_core/models/project.dart';\n",
        "import 'package:qfli_studio_core/services/cloud_cache_service.dart';\n",
        "import 'package:qfli_studio_core/services/cloud_project_actions.dart';\n",
        "import 'package:qfli_studio_core/store/project_store.dart';\n",
    ]:
        text = once(text, imported)
    return text


def actions_test_version(stage: str) -> str:
    """R3: deletion/scope cases. R6: adds the snapshot export cases."""
    if RANK[stage] >= RANK['R6']:
        return TEXT[ACTIONS_TEST]
    text = TEXT[ACTIONS_TEST]
    return replace_region(
        text,
        "  test('workspace export does not require registry membership', () async {\n",
        '}\n\nCommunityUser _user(String id) => CommunityUser(',
    )


def versions() -> dict[str, dict[str, str]]:
    """Complete cumulative text per stage, only paths changed by that stage."""
    stages: dict[str, dict[str, str]] = {stage: {} for stage in ORDER}
    stages['R7'] = {
        PROJECT: TEXT[PROJECT],
        CLOUD_PROJECT: TEXT[CLOUD_PROJECT],
        API: TEXT[API],
        APP_PATHS: TEXT[APP_PATHS],
        CACHE_PATHS: TEXT[CACHE_PATHS],
        CACHE: TEXT[CACHE],
        ACTIONS: actions_version('R7'),
        SYNC: TEXT[SYNC],
        STORE: store_version('R7'),
        AUTH: TEXT[AUTH],
        CACHE_TEST: TEXT[CACHE_TEST],
        AUTH_TEST: auth_test_version('R7'),
    }
    stages['R3'] = {
        STORE: store_version('R3'),
        ACTIONS: actions_version('R3'),
        ACTIONS_TEST: actions_test_version('R3'),
    }
    stages['R6'] = {
        ACTIONS: actions_version('R6'),
        AUTH_TEST: auth_test_version('R6'),
        ACTIONS_TEST: actions_test_version('R6'),
    }
    stages['R8'] = {ACTIONS: actions_version('R8')}
    return stages


def formatted(source: str, name: str) -> str:
    result = subprocess.run(
        [
            str(DART), 'format', '--output=show', '--summary=none',
            '--language-version=3.11', '--stdin-name=' + name,
        ],
        input=source.encode('utf-8'),
        capture_output=True,
    )
    if result.returncode:
        raise ValueError(
            f'Dart parse/format failed for {name}:\n' + result.stderr.decode('utf-8')
        )
    return norm(result.stdout)


def encoded(text: str, path: str) -> bytes:
    if text == TEXT[path]:
        return FINAL[path]
    if b'\r\n' in FINAL[path]:
        return text.replace('\n', '\r\n').encode('utf-8')
    return text.encode('utf-8')


def prepare_validation(stage: str, cumulative: dict[str, bytes]) -> Path:
    """Report-owned package that resolves package:qfli_studio_core to the stage.

    The whole Core lib tree is copied first, so unchanged imports such as
    config/api_config.dart resolve exactly as in Core. Only the cumulative C
    files are overwritten. Analysis targets stay limited to C-owned paths.
    """
    root = (OUT / '_validation' / stage).resolve()
    if not root.is_relative_to(OUT):
        raise ValueError(f'Validation directory escaped report root: {root}')
    if root.exists():
        shutil.rmtree(root)
    root.mkdir(parents=True)
    shutil.copytree(CORE / 'lib', root / 'lib', dirs_exist_ok=True)
    config_path = CORE / '.dart_tool' / 'package_config.json'
    core_config = json.loads(config_path.read_text(encoding='utf-8'))
    # Moving package_config.json changes the meaning of every relative rootUri.
    # Keep external dependencies at their original resolved location and point
    # only this package at the report-owned cumulative source tree.
    for package in core_config['packages']:
        package['rootUri'] = (
            root.as_uri() + '/'
            if package['name'] == 'qfli_studio_core'
            else urljoin(config_path.as_uri(), package['rootUri'])
        )
    (root / '.dart_tool').mkdir(parents=True)
    (root / '.dart_tool' / 'package_config.json').write_text(
        json.dumps(core_config, indent=2) + '\n', encoding='utf-8'
    )
    options = CORE / 'analysis_options.yaml'
    if options.exists():
        shutil.copy2(options, root / 'analysis_options.yaml')
    for path, data in cumulative.items():
        target = root / path
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_bytes(data)
    return root


def analyze(stage: str, root: Path, paths: list[str]) -> dict[str, object]:
    existing = [path for path in paths if (root / path).exists()]
    command = [str(DART), 'analyze', *existing]
    result = subprocess.run(
        command,
        cwd=str(root), capture_output=True, text=True, encoding='utf-8',
    )
    log = (result.stdout or '') + (result.stderr or '')
    (OUT / '_validation' / stage / 'analyze.log').write_text(log, encoding='utf-8')
    return {
        'stage': stage,
        'cwd': str(root),
        'command': command,
        'validation_model': 'full frozen Core library with cumulative C files overlaid, C-owned targets only',
        'paths': existing,
        'exit_code': result.returncode,
        'no_issues': 'No issues found!' in log,
        'log': log.strip(),
    }


def build() -> None:
    baseline = git('rev-parse', BASE).stdout.decode().strip()
    head = git('rev-parse', 'HEAD').stdout.decode().strip()
    before_sources = source_guard()
    prior_manifest_path = OUT / 'manifest.json'
    if prior_manifest_path.exists():
        expected_sources = json.loads(prior_manifest_path.read_text(
            encoding='utf-8'))['verification']['frozen_source_sha256']
        if before_sources != expected_sources:
            raise RuntimeError('Current Core sources differ from the frozen C manifest')
    before_index = index_digest()
    for path in PATHS:
        FINAL[path] = (CORE / path).read_bytes()
        TEXT[path] = norm(FINAL[path])
        raw = git('show', f'{baseline}:{path}', check=False)
        BASE_BYTES[path] = raw.stdout if raw.returncode == 0 else None
    if before_sources != source_guard():
        raise RuntimeError('Frozen source changed while capturing inputs')

    stages = versions()
    format_log: list[dict[str, object]] = []
    encoded_stages: dict[str, dict[str, bytes]] = {}
    for stage in ORDER:
        current: dict[str, bytes] = {}
        for path, text in stages[stage].items():
            candidate = formatted(text, path)
            data = encoded(candidate, path)
            current[path] = data
            format_log.append({
                'stage': stage,
                'path': path,
                'parse': 'ok',
                'equals_frozen_source': data == FINAL[path],
                'formatted_equals_input': candidate == text,
            })
        encoded_stages[stage] = current

    # The last stage that touches each path must reproduce frozen bytes exactly.
    last_stage: dict[str, str] = {}
    for stage in ORDER:
        for path in encoded_stages[stage]:
            last_stage[path] = stage
    for path, stage in last_stage.items():
        if encoded_stages[stage][path] != FINAL[path]:
            raise ValueError(
                f'{stage} is the last copy of {path} but differs from frozen bytes'
            )
    missing = [path for path in PATHS if path not in last_stage]
    if missing:
        raise ValueError(f'No stage copy reaches frozen bytes: {missing}')

    previous: dict[str, bytes | None] = dict(BASE_BYTES)
    manifest_stages = []
    cumulative_by_stage: dict[str, dict[str, bytes]] = {}
    expected: set[str] = set()
    for stage in ORDER:
        entries = []
        for path in PATHS:
            data = encoded_stages[stage].get(path)
            if data is None:
                continue
            prior = previous[path]
            if data == prior:
                continue
            relative = f'{stage}/{path}'
            expected.add(relative)
            write(relative, data)
            old_text = norm(prior).splitlines(keepends=True) if prior else []
            new_text = norm(data).splitlines(keepends=True)
            diff = ''.join(difflib.unified_diff(
                old_text, new_text,
                fromfile=f'previous/{path}', tofile=f'{stage}/{path}',
            ))
            write(f'_diffs/{stage}/{path}.diff', diff.encode('utf-8'))
            entries.append({
                'path': path,
                'copy': relative,
                'action': 'add' if prior is None else 'modify',
                'prior_sha256': digest(prior),
                'sha256': digest(data),
                'bytes': len(data),
                'equals_frozen_source': data == FINAL[path],
            })
            previous[path] = data
        manifest_stages.append({'requirement': stage, 'files': entries})
        cumulative_by_stage[stage] = {
            path: data for path, data in previous.items() if data is not None
        }

    for stage in ORDER:
        stage_dir = OUT / stage
        for found in stage_dir.rglob('*'):
            if found.is_file() and found.relative_to(OUT).as_posix() not in expected:
                raise ValueError(f'Unexpected prior output: {found}')

    replay: dict[str, bytes | None] = dict(BASE_BYTES)
    for entry_stage in manifest_stages:
        for entry in entry_stage['files']:
            replay[entry['path']] = (OUT / entry['copy']).read_bytes()
    matches = {path: replay[path] == FINAL[path] for path in PATHS}
    if not all(matches.values()):
        raise RuntimeError('Written stage-copy replay does not equal frozen source')

    # No-write format verification over the written copies.
    format_check = subprocess.run(
        [
            str(DART), 'format', '--output=none', '--set-exit-if-changed',
            '--language-version=3.11',
            *[str(OUT / entry['copy'])
              for entry_stage in manifest_stages for entry in entry_stage['files']],
        ],
        capture_output=True, text=True,
    )

    # Static analysis of every cumulative stage in a report-owned package.
    analysis = []
    for stage in ORDER:
        root = prepare_validation(stage, cumulative_by_stage[stage])
        analysis.append(analyze(stage, root, PATHS))

    after_sources = source_guard()
    after_index = index_digest()
    if after_sources != before_sources:
        raise RuntimeError('Frozen Core source changed during generation')
    if after_index != before_index:
        raise RuntimeError('Core index changed concurrently; inspect root staging')

    manifest = {
        'generated_at': datetime.now(timezone.utc).isoformat(),
        'core': str(CORE),
        'base_commit': baseline,
        'head_observed': head,
        'order': ORDER,
        'semantics': (
            'Each listed file is the complete cumulative content at that stage. '
            'Only changed paths are present.'
        ),
        'stage_notes': {
            'R7': 'Storage/scope/auth/workspace foundation plus the scoped facade refresh.',
            'R3': 'Remote-delete tombstones, reconciliation and the delete facade.',
            'R6': 'CloudProjectActions.prepareSnapshot export adapter and its tests.',
            'R8': 'Status/inspect/cache/clear facade surface and refresh metadata loading.',
        },
        'stages': manifest_stages,
        'verification': {
            'final_replay_equals_frozen_bytes': matches,
            'frozen_source_sha256': before_sources,
            'last_stage_per_path': last_stage,
            'source_unchanged_after_generation': before_sources == after_sources,
            'index_sha256_before': before_index,
            'index_sha256_after': after_index,
            'index_unchanged_after_generation': before_index == after_index,
            'dart_parse_format_invocations': len(format_log),
            'format_check_exit_code': format_check.returncode,
            'format_check_stdout': format_check.stdout.strip(),
            'format_check_stderr': format_check.stderr.strip(),
            'static_analysis_exit_codes': {
                item['stage']: item['exit_code'] for item in analysis
            },
            'runtime_tests_run': False,
            'builds_run': False,
            'dependency_resolution_run': False,
            'source_or_index_write_commands': [],
        },
    }
    write('manifest.json',
          (json.dumps(manifest, indent=2, ensure_ascii=False) + '\n').encode('utf-8'))
    write('format-verification.json',
          (json.dumps(format_log, indent=2, ensure_ascii=False) + '\n').encode('utf-8'))
    write('analysis-verification.json',
          (json.dumps(analysis, indent=2, ensure_ascii=False) + '\n').encode('utf-8'))

    print(
        f'Wrote {sum(len(s["files"]) for s in manifest_stages)} stage copies '
        f'for {len(PATHS)} frozen files'
    )
    print(
        f'Parsed/formatted {len(format_log)} cumulative candidates with Dart 3.11; '
        f'format check exit {format_check.returncode}'
    )
    for item in analysis:
        print(
            f'analysis {item["stage"]}: exit {item["exit_code"]}, '
            f'no-issues={item["no_issues"]}'
        )
    print('Final replay matches all frozen bytes; source and index unchanged.')
    for stage in manifest_stages:
        print(stage['requirement'] + ': ' +
              ', '.join(entry['path'] for entry in stage['files']))
    if format_check.returncode != 0:
        raise RuntimeError('Written stage copies failed no-write formatting verification')
    if any(item['exit_code'] != 0 or not item['no_issues'] for item in analysis):
        raise RuntimeError('A cumulative C stage has static findings; inspect analysis-verification.json')


if __name__ == '__main__':
    argparse.ArgumentParser().parse_args()
    sys.exit(build())