"""Build D-owned cumulative source copies under this report directory only.

No repository writes, index mutations, tests, builds, package resolution or
services. Git is used only for pinned baseline reads. Final source bytes are
captured before any transformation and verified again before completion.
"""
from __future__ import annotations

import difflib
import hashlib
import json
import re
import subprocess
from datetime import datetime, timezone
from pathlib import Path

CORE = Path('D:/MyNewProjects/_wt/studio-git-integration/qfli_studio_core')
APP = Path('D:/MyNewProjects/_wt/studio-git-integration/qflistudio')
OUT = Path(__file__).resolve().parent
BASE = {
    'core': '16a6a474da0d014f6c36a3a91430273feed0d337',
    'app': '1cea02946e5191f2a76bd8915ff0a527547f0463',
}
ROOTS = {'core': CORE, 'app': APP}
ORDER = ['R1', 'R7', 'R3', 'R4', 'R5', 'R6', 'R8']
OWNED = {
    'core': [
        'android/src/main/AndroidManifest.xml',
        'android/src/main/java/com/azurekiln/qfli/core/QfliPickerPlugin.java',
        'android/src/main/java/com/azurekiln/qfli/core/QfliArchiveProvider.java',
        'lib/editor/editor_page.dart',
        'lib/editor/file_explorer.dart',
        'lib/services/project_zip_service.dart',
        'lib/services/share_service.dart',
        'lib/services/archive_share_service.dart',
        'test/file_explorer_state_test.dart',
        'test/archive_share_test.dart',
        'test/editor_cloud_open_lifecycle_test.dart',
    ],
    'app': [
        'ios/Runner/AppDelegate.swift',
        'macos/Runner/MainFlutterWindow.swift',
        'ohos/entry/src/main/ets/entryability/EntryAbility.ets',
        'linux/runner/my_application.cc',
        'windows/runner/archive_share.h',
        'windows/runner/archive_share.cpp',
        'windows/runner/flutter_window.h',
        'windows/runner/flutter_window.cpp',
        'windows/runner/main.cpp',
        'windows/runner/CMakeLists.txt',
    ],
}
FINAL: dict[tuple[str, str], bytes] = {}
TEXT: dict[tuple[str, str], str] = {}
BASE_BYTES: dict[tuple[str, str], bytes | None] = {}
DART = Path('D:/ProgramFiles/flutter_ohos/bin/cache/dart-sdk/bin/dart.exe')


def git(root: Path, *args: str, check: bool = True) -> subprocess.CompletedProcess:
    return subprocess.run(['git', '-C', str(root), *args], capture_output=True, check=check)


def norm(data: bytes) -> str:
    return data.decode('utf-8').replace('\r\n', '\n')


def write(relative: str, data: str | bytes) -> None:
    target = (OUT / relative).resolve()
    if not target.is_relative_to(OUT):
        raise ValueError(f'Output escaped report directory: {relative}')
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_bytes(data.encode('utf-8') if isinstance(data, str) else data)


def once(text: str, old: str, new: str = '') -> str:
    if text.count(old) != 1:
        raise ValueError(f'Expected one target, got {text.count(old)}: {old[:130]!r}')
    return text.replace(old, new, 1)


def region(text: str, start: str, end: str) -> str:
    first = text.index(start)
    last = text.index(end, first + len(start))
    return text[first:last]


def replace_region(text: str, start: str, end: str, value: str = '') -> str:
    return once(text, region(text, start, end), value)


def text(repo: str, path: str) -> str:
    return TEXT[(repo, path)]


EDITOR = 'lib/editor/editor_page.dart'
ARCHIVE = 'lib/services/archive_share_service.dart'
TEST = 'test/archive_share_test.dart'
PICKER = 'android/src/main/java/com/azurekiln/qfli/core/QfliPickerPlugin.java'
IOS = 'ios/Runner/AppDelegate.swift'
MACOS = 'macos/Runner/MainFlutterWindow.swift'


def editor_version(stage: str) -> str:
    result = text('core', EDITOR)
    if stage == 'R6':
        return result
    if stage == 'R7':
        for added in [
            "import '../i18n/studio_localizations.dart';\n",
            "import '../services/archive_share_service.dart';\n",
            "import '../services/cloud_project_actions.dart';\n",
            '      onShareEntry: _shareArchiveEntry,\n',
        ]:
            result = once(result, added)
        return replace_region(result, '  bool _sharingArchive = false;\n',
                              '  /// 文件树卡片：')
    if stage != 'R4':
        raise ValueError(stage)
    result = once(result, "import '../services/cloud_project_actions.dart';\n")
    start = '  Future<void> _shareArchiveEntry(Project owner, String path) async {'
    end = '  /// 文件树卡片：'
    method = region(result, start, end)
    method = once(method,
        '    if (_sharingArchive) return;\n',
        '    if (_sharingArchive || owner.isCloud) return;\n')
    method = replace_region(method,
        '    final auth = widget.auth;\n',
        '    try {\n',
        '    bool current() => mounted;\n')
    method = once(method,
        '        token: token,\n        accountId: accountId,\n        cloudActions: actions,\n')
    method = once(method,
        '      if (owner.isCloud) auth.removeListener(authChanged);\n' +
        '      actions?.dispose();\n')
    return replace_region(result, start, end, method)


def archive_version(stage: str) -> str:
    result = text('core', ARCHIVE)
    if stage == 'R6':
        return result
    result = once(result, "import 'cloud_project_actions.dart';\n")
    if stage == 'R4':
        result = replace_region(result,
            '  static Future<ArchiveShareResult> shareProject(\n',
            '  static Future<ArchiveShareResult> shareSelection(\n')
    else:
        wrapper = region(result,
            '  static Future<ArchiveShareResult> shareProject(\n',
            '  static Future<ArchiveShareResult> shareSelection(\n')
        wrapper = once(wrapper,
            '    String? token,\n    String? accountId,\n' +
            '    CloudProjectActions? cloudActions,\n')
        wrapper = once(wrapper,
            '    token: token,\n    accountId: accountId,\n    cloudActions: cloudActions,\n')
        wrapper = once(wrapper, '    Project project, {\n  })', '    Project project,\n  )')
        result = replace_region(result,
            '  static Future<ArchiveShareResult> shareProject(\n',
            '  static Future<ArchiveShareResult> shareSelection(\n', wrapper)
    result = once(result,
        '    String? token,\n    String? accountId,\n' +
        '    CloudProjectActions? cloudActions,\n')
    result = once(result, '    final relative = p.relative(selected, from: root);\n',
                  "    final selectedIsRoot = p.equals(selected, root);\n")
    result = once(result, "      relative == '.' ? project.name : p.basename(selected),\n",
                  '      selectedIsRoot ? project.name : p.basename(selected),\n')
    result = replace_region(result,
        '    if (project.isCloud) {\n',
        '    return _prepareAndShare(root: root, selected: selected, name: name);',
        "    if (project.isCloud) {\n" +
        "      throw const ProjectZipException('Cloud sharing requires a complete snapshot.');\n" +
        "    }\n")
    result = once(result, '    void Function()? ensureCurrent,\n')
    if result.count('    ensureCurrent?.call();\n') != 5:
        raise ValueError('Expected five preparation generation guards')
    result = result.replace('    ensureCurrent?.call();\n', '')
    return result


def tests_version(stage: str) -> str:
    result = text('core', TEST)
    if stage == 'R6':
        return result
    for imported in [
        "import 'dart:async';\n",
        "import 'package:qfli_studio_core/community/models.dart';\n",
        "import 'package:qfli_studio_core/services/cloud_cache_service.dart';\n",
        "import 'package:qfli_studio_core/services/cloud_project_actions.dart';\n",
        "import 'package:qfli_studio_core/store/auth_store.dart';\n",
        "import 'package:qfli_studio_core/store/project_store.dart';\n",
    ]:
        result = once(result, imported)
    result = replace_region(result,
        "  test(\n    'cloud ZIP uses only complete snapshot payload, never workspace or manifest',\n",
        "  test('native failure is not silently reported as unsupported',")
    result = replace_region(result, 'CommunityUser _user(String id)',
                            'class _Paths extends PathProviderPlatform {')
    if stage == 'R4':
        # Local selection regression is useful before the R5 project wrapper.
        result = result.replace('ArchiveShareService.shareProject(project)',
            'ArchiveShareService.shareSelection(project, selectedPath: project.path)')
    return result


def picker_browser_only() -> str:
    result = text('core', PICKER)
    result = once(result, 'import android.content.ClipData;\n')
    return replace_region(result,
        '                case "shareFile": {\n',
        '                case "pickDocument":')


def apple_browser_only(path: str) -> str:
    result = text('app', path)
    result = once(result,
        '    channel.setMethodCallHandler { [weak self] call, reply in\n',
        '    channel.setMethodCallHandler { call, reply in\n')
    if path == MACOS:
        result = once(result, '  private var sharePicker: NSSharingServicePicker?\n')
        end = '    }\n\n    super.awakeFromNib()'
    else:
        end = '    }\n  }\n}'
    start = '      guard call.method == "shareFile" else { reply(FlutterMethodNotImplemented); return }\n'
    return replace_region(result, start, end, '      reply(FlutterMethodNotImplemented)\n')


def digest(data: bytes | None) -> str | None:
    return None if data is None else hashlib.sha256(data).hexdigest()


def formatted(source: str, name: str) -> str:
    process = subprocess.run([
        str(DART), 'format', '--output=show', '--summary=none',
        '--language-version=3.11', '--stdin-name=' + name,
    ], input=source.encode('utf-8'), capture_output=True)
    if process.returncode:
        raise ValueError(f'Dart stage syntax/format failure: {name}\n' +
                         process.stderr.decode('utf-8'))
    return norm(process.stdout)


def index_hash(root: Path) -> str | None:
    value = git(root, 'rev-parse', '--git-path', 'index').stdout.decode().strip()
    path = Path(value)
    if not path.is_absolute():
        path = root / path
    return digest(path.read_bytes()) if path.exists() else None


def main() -> None:
    index_before = {repo: index_hash(root) for repo, root in ROOTS.items()}
    for repo, paths in OWNED.items():
        for path in paths:
            key = (repo, path)
            FINAL[key] = (ROOTS[repo] / path).read_bytes()
            TEXT[key] = norm(FINAL[key])
            base = git(ROOTS[repo], 'show', f'{BASE[repo]}:{path}', check=False)
            BASE_BYTES[key] = base.stdout if base.returncode == 0 else None

    versions: dict[str, dict[tuple[str, str], bytes | str]] = {
        stage: {} for stage in ORDER
    }
    versions['R1'][('core', PICKER)] = picker_browser_only()
    versions['R1'][('app', IOS)] = apple_browser_only(IOS)
    versions['R1'][('app', MACOS)] = apple_browser_only(MACOS)
    versions['R7'][('core', EDITOR)] = editor_version('R7')
    versions['R7'][('core', 'test/editor_cloud_open_lifecycle_test.dart')] = FINAL[
        ('core', 'test/editor_cloud_open_lifecycle_test.dart')]

    for repo, paths in OWNED.items():
        for path in paths:
            key = (repo, path)
            if key in [('core', ARCHIVE), ('core', TEST), ('core', EDITOR),
                       ('core', 'test/editor_cloud_open_lifecycle_test.dart')]:
                continue
            versions['R4'][key] = FINAL[key]
    # R4 exposes only implemented local sharing. Cloud menu visibility arrives
    # with R6 rather than offering an action that cannot yet prepare a snapshot.
    explorer = 'lib/editor/file_explorer.dart'
    versions['R4'][('core', explorer)] = once(text('core', explorer),
        '      if (widget.onShareEntry != null)\n',
        '      if (widget.onShareEntry != null && !owner.isCloud)\n')
    versions['R4'][('core', EDITOR)] = editor_version('R4')
    versions['R4'][('core', ARCHIVE)] = archive_version('R4')
    versions['R4'][('core', TEST)] = tests_version('R4')
    versions['R5'][('core', ARCHIVE)] = archive_version('R5')
    versions['R5'][('core', TEST)] = tests_version('R5')
    versions['R6'][('core', EDITOR)] = FINAL[('core', EDITOR)]
    versions['R6'][('core', ARCHIVE)] = FINAL[('core', ARCHIVE)]
    versions['R6'][('core', TEST)] = FINAL[('core', TEST)]
    versions['R6'][('core', 'lib/editor/file_explorer.dart')] = FINAL[
        ('core', 'lib/editor/file_explorer.dart')]

    # Parse every Dart candidate. Format only intermediate report copies;
    # baseline/final source bytes are never rewritten by formatting.
    format_log = []
    for stage, candidates in versions.items():
        for key, candidate in list(candidates.items()):
            repo, path = key
            if not path.endswith('.dart'):
                continue
            data = candidate.encode('utf-8') if isinstance(candidate, str) else candidate
            parsed = formatted(norm(data), path)
            is_frozen = data == FINAL[key]
            if not is_frozen:
                newline = '\r\n' if b'\r\n' in FINAL[key] else '\n'
                candidates[key] = parsed.replace('\n', newline).encode('utf-8')
            format_log.append({'stage': stage, 'repo': repo, 'path': path,
                               'parse': 'ok', 'frozen_bytes_preserved': is_frozen,
                               'format_equal': parsed == norm(data)})

    current = dict(BASE_BYTES)
    manifest = {
        'generated_at': datetime.now(timezone.utc).isoformat(),
        'roots': {repo: str(root) for repo, root in ROOTS.items()},
        'base_commits': BASE,
        'heads_observed': {repo: git(root, 'rev-parse', 'HEAD').stdout.decode().strip()
                           for repo, root in ROOTS.items()},
        'order': ORDER,
        'semantics': 'Complete cumulative content for changed paths only; no real root/index writes.',
        'absent_stages': ['R3', 'R8'],
        'ownership': 'A owns App dependency/lock/generated registrants. D excludes them.',
        'stages': [],
    }
    for stage in ORDER:
        rows = []
        patch = []
        for (repo, path), value in sorted(versions[stage].items()):
            data = value.encode('utf-8') if isinstance(value, str) else value
            prior = current[(repo, path)]
            if data == prior:
                continue
            relative = f'{stage}/{repo}/{path}'
            write(relative, data)
            rows.append({
                'repo': repo, 'path': path, 'copy': relative,
                'action': 'add' if prior is None else 'modify',
                'prior_sha256': digest(prior), 'sha256': digest(data),
                'bytes': len(data), 'equals_frozen_source': data == FINAL[(repo, path)],
            })
            patch.extend(difflib.unified_diff(
                [] if prior is None else norm(prior).splitlines(keepends=True),
                norm(data).splitlines(keepends=True),
                fromfile='/dev/null' if prior is None else f'a/{repo}/{path}',
                tofile=f'b/{repo}/{path}',
            ))
            current[(repo, path)] = data
        if rows:
            write(f'diffs/{stage}.patch', ''.join(patch))
        manifest['stages'].append({'requirement': stage, 'files': rows})

    equality = []
    for key, frozen in sorted(FINAL.items()):
        repo, path = key
        if current[key] != frozen:
            raise ValueError(f'Cumulative copies do not reach frozen bytes: {repo}/{path}')
        if (ROOTS[repo] / path).read_bytes() != frozen:
            raise ValueError(f'Source drifted during report generation: {repo}/{path}')
        equality.append({'repo': repo, 'path': path, 'sha256': digest(frozen),
                         'bytes': len(frozen), 'matches_frozen_source': True})
    # Replay bytes actually written to disk, not only the in-memory versions.
    replay = dict(BASE_BYTES)
    for stage in manifest['stages']:
        for entry in stage['files']:
            replay[(entry['repo'], entry['path'])] = (OUT / entry['copy']).read_bytes()
    if any(replay[key] != frozen for key, frozen in FINAL.items()):
        raise ValueError('Written report copies do not replay to frozen source')
    index_after = {repo: index_hash(root) for repo, root in ROOTS.items()}
    if index_before != index_after:
        raise ValueError('Repository index changed concurrently; recheck before replay')
    manifest['final_equality'] = equality
    manifest['all_final_bytes_equal'] = True
    manifest['verification'] = {
        'written_copy_replay_equals_frozen_bytes': True,
        'sources_unchanged_after_generation': True,
        'index_sha256_before': index_before,
        'index_sha256_after': index_after,
        'indices_unchanged_after_generation': True,
        'dart_parse_format_invocations': len(format_log),
        'runtime_tests_run': False, 'builds_run': False,
        'worktree_or_index_write_commands': [],
    }
    write('format-verification.json', json.dumps(format_log, indent=2) + '\n')
    write('manifest.json', json.dumps(manifest, indent=2) + '\n')
    print(json.dumps({'stage_file_counts': {
        item['requirement']: len(item['files']) for item in manifest['stages']},
        'all_final_bytes_equal': True, 'owned_paths': len(equality)}, indent=2))


if __name__ == '__main__':
    main()
