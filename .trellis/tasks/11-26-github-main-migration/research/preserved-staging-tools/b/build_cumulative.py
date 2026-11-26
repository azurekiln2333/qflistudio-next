"""Build B's cumulative commit inputs without touching Core sources or index.

All writes are confined to this script's reports/staging/b directory. Reads of
Core use frozen bytes and git show at the pinned R2 commit. No checkout, add,
apply, update-index, hash-object -w, test, build or service command is used.
"""
from __future__ import annotations

import argparse
import difflib
import hashlib
import json
import subprocess
from datetime import datetime, timezone
from pathlib import Path

CORE = Path('D:/MyNewProjects/_wt/studio-git-integration/qfli_studio_core')
OUT = Path(__file__).resolve().parent
DART = Path('D:/ProgramFiles/flutter_ohos/bin/cache/dart-sdk/bin/dart.exe')
BASE = '16a6a47'
ORDER = ['R1', 'R7', 'R3', 'R4', 'R5', 'R6', 'R8']
RANK = {stage: index for index, stage in enumerate(ORDER)}
PATHS = [
    'lib/pages/home_page.dart',
    'lib/pages/git/github_repository_picker.dart',
    'lib/widgets/project_card.dart',
    'lib/widgets/project_dialogs.dart',
    'lib/i18n/studio_localizations.dart',
    'test/github_repository_picker_test.dart',
    'test/project_card_cloud_actions_test.dart',
    'test/home_project_scope_test.dart',
    'test/home_search_archive_test.dart',
]
HOME, PICKER, CARD, DIALOGS, LABELS, PICKER_TEST, CARD_TEST, SCOPE_TEST, SHARE_TEST = PATHS
FINAL: dict[str, bytes] = {}
TEXT: dict[str, str] = {}
BASE_BYTES: dict[str, bytes | None] = {}
BASE_TEXT: dict[str, str] = {}


def git(*args: str, check: bool = True) -> subprocess.CompletedProcess:
    return subprocess.run(['git', '-C', str(CORE), *args], capture_output=True, check=check)


def normalized(data: bytes) -> str:
    return data.decode('utf-8').replace('\r\n', '\n')


def output_path(relative: str) -> Path:
    target = (OUT / relative).resolve()
    if not target.is_relative_to(OUT):
        raise ValueError(f'Output escaped report directory: {relative}')
    return target


def write(relative: str, data: bytes | str) -> None:
    target = output_path(relative)
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_bytes(data.encode('utf-8') if isinstance(data, str) else data)


def once(text: str, old: str, new: str = '') -> str:
    if text.count(old) != 1:
        raise ValueError(f'Expected one exact target, found {text.count(old)}: {old[:100]!r}')
    return text.replace(old, new, 1)


def region(text: str, start: str, end: str) -> str:
    first = text.index(start)
    last = text.index(end, first + len(start))
    return text[first:last]


def replace_region(text: str, start: str, end: str, replacement: str = '') -> str:
    return once(text, region(text, start, end), replacement)


def balanced_end(text: str, opening: int) -> int:
    """Dart brace scan, skipping quoted strings and comments."""
    if text[opening] != '{':
        raise ValueError('Expected an opening brace')
    depth = 0
    pos = opening
    while pos < len(text):
        if text.startswith('//', pos):
            line_end = text.find('\n', pos)
            pos = len(text) if line_end < 0 else line_end
            continue
        if text.startswith('/*', pos):
            nesting = 1
            pos += 2
            while nesting and pos < len(text):
                if text.startswith('/*', pos):
                    nesting += 1
                    pos += 2
                elif text.startswith('*/', pos):
                    nesting -= 1
                    pos += 2
                else:
                    pos += 1
            continue
        char = text[pos]
        if char in "'\"":
            raw = pos > 0 and text[pos - 1] == 'r'
            quote = char * 3 if text.startswith(char * 3, pos) else char
            pos += len(quote)
            while pos < len(text):
                if not raw and text[pos] == '\\':
                    pos += 2
                elif text.startswith(quote, pos):
                    pos += len(quote)
                    break
                else:
                    pos += 1
            continue
        if char == '{':
            depth += 1
        elif char == '}':
            depth -= 1
            if depth == 0:
                return pos + 1
        pos += 1
    raise ValueError('Unbalanced Dart braces')


def method(text: str, signature: str, *, home: bool = False) -> str:
    start = text.index(signature, text.index('class _HomeTabState') if home else 0)
    opening = text.index('{', start + len(signature))
    return text[start:balanced_end(text, opening)]


def replace_home_method(text: str, signature: str) -> str:
    return once(text, method(text, signature, home=True), method(BASE_TEXT[HOME], signature, home=True))


def has(stage: str, requirement: str) -> bool:
    return RANK[stage] >= RANK[requirement]


def home_version(stage: str) -> str:
    text = TEXT[HOME]
    if not has(stage, 'R8'):
        text = replace_region(text,
            '  /// R8: restore manifest metadata for scoped registry rows on first display.\n',
            '  @override\n  void didChangeDependencies()')
        # Two calls: initial load and identity changes. The auth-change wrapper
        # becomes empty and is removed separately below.
        if text.count('      unawaited(_inspectCloudCaches());\n') != 2:
            raise ValueError('Expected initial and auth-change cache inspection calls')
        text = text.replace('      unawaited(_inspectCloudCaches());\n', '')
        # Removing the nested call leaves its leading indentation before the
        # closing brace. Remove the entire now-empty wrapper too.
        import re
        empty_cache_check = r'      if \(loggedIn && StudioProfile\.current\?\.offlineOnly != true\) \{\n\s*\}\n'
        text, removed = re.subn(empty_cache_check, '', text)
        if removed != 1:
            raise ValueError(f'Expected one empty cache inspection wrapper, found {removed}')
        text = replace_region(text,
            '          // R8: make room for snapshot state/time/count/bytes on cloud cards.\n',
            '          return Center(',
            '          final itemExtent = (24 + 38 * scale).clamp(90.0, 180.0).toDouble();\n')
        text = once(text,
            '      // R8: snapshot state is observable and independent of directory existence.\n' +
            '      cacheStatus: project.isCloud ? _cloudActions.status(project) : null,\n')
        text = once(text,
            '      onCache: project.isCloud ? () => unawaited(_cacheProject(project)) : null,\n' +
            '      onClearCache: project.isCloud\n' +
            '          ? () => unawaited(_clearProjectCache(project))\n' +
            '          : null,\n')
        text = replace_region(text,
            '  // R8: cache/clear are distinct operations, never remote delete aliases.\n',
            '  // R3: do not promise local recycle-bin recovery for permanent remote deletion.\n')
    if not has(stage, 'R3'):
        text = once(text, '  final Set<String> _deletingCloudProjects = {};\n')
        if text.count('      _deletingCloudProjects.clear();\n') != 2:
            raise ValueError('Expected two cloud-delete guard resets')
        text = text.replace('      _deletingCloudProjects.clear();\n', '')
        text = once(text,
            '      cloudBusy:\n' +
            '          project.isCloud &&\n' +
            '          (_cloudActions.isBusy(project) ||\n' +
            '              _deletingCloudProjects.contains(project.id)),\n')
        text = replace_region(text,
            '  // R3: do not promise local recycle-bin recovery for permanent remote deletion.\n',
            '  Future<void> _exportProjectArchive(Project project)')
        text = once(text,
            '    if (project.isCloud) {\n' +
            '      await _deleteCloudProject(project);\n' +
            '      return;\n' +
            '    }\n')
    if not has(stage, 'R5'):
        text = once(text, "import '../services/archive_share_service.dart';\n")
        text = once(text,
            '      // R5/R6: sharing ZIP does not replace import-compatible .qsz export.\n' +
            '      onShare: () => unawaited(_shareProject(project)),\n')
        text = replace_region(text,
            '  // R5/R6: capture the account generation before download/ZIP/native handoff.\n',
            '  Future<void> _exportProjectArchive(Project project)') if not has(stage, 'R3') else replace_region(
                text,
                '  // R5/R6: capture the account generation before download/ZIP/native handoff.\n',
                '  // R3: do not promise local recycle-bin recovery for permanent remote deletion.\n')
    elif not has(stage, 'R6'):
        text = once(text,
            '      onShare: () => unawaited(_shareProject(project)),\n',
            '      onShare: project.isCloud ? null : () => unawaited(_shareProject(project)),\n')
        original = method(text, '  Future<void> _shareProject(Project project) async', home=True)
        local = original
        local = once(local,
            '    final generation = _accountGeneration;\n' +
            '    final token = widget.auth.token;\n' +
            '    final accountId = widget.auth.user?.id;\n' +
            '    final actions = _cloudActions;\n' +
            '    bool current() =>\n' +
            '        mounted &&\n' +
            '        (!project.isCloud ||\n' +
            '            generation == _accountGeneration &&\n' +
            '                widget.auth.token == token &&\n' +
            '                widget.auth.user?.id == accountId);\n' +
            '    if (project.isCloud && (token == null || accountId == null)) return;\n' +
            '    setState(\n' +
            '      () => _archiveBusyLabel = project.isCloud\n' +
            '          ? l10n.preparingCloudShare\n' +
            '          : l10n.preparingProjectShare,\n' +
            '    );',
            '    if (project.isCloud) return;\n' +
            '    bool current() => mounted;\n' +
            '    setState(() => _archiveBusyLabel = l10n.preparingProjectShare);')
        local = once(local,
            '      final result = await ArchiveShareService.shareProject(\n' +
            '        project,\n' +
            '        token: project.isCloud ? token : null,\n' +
            '        accountId: project.isCloud ? accountId : null,\n' +
            '        cloudActions: project.isCloud ? actions : null,\n' +
            '      );',
            '      final result = await ArchiveShareService.shareProject(project);')
        text = once(text, original, local)
    if not has(stage, 'R7'):
        text = once(text, "import '../config/api_config.dart';\n")
        text = once(text, "import '../services/cloud_project_actions.dart';\n")
        text = replace_region(text,
            '  // R3/R8: one C-owned observable handles all account-scoped cloud mutations.\n',
            '  late final HomeTabOrderStore')
        for signature in [
            '  void initState()',
            '  void didUpdateWidget(covariant HomeTab oldWidget)',
            '  void _onAuthChanged()',
            '  void dispose()',
            '  List<Project> _projectsFor(ProjectScope scope)',
            '  Future<void> _reloadProjects(ProjectScope scope) async',
            '  Future<void> _createCloudProject(BuildContext context) async',
        ]:
            text = replace_home_method(text, signature)
        text = replace_region(text,
            '  void _onCloudChanged() {\n',
            '  void _onAuthChanged()')
    return text


def label_version(stage: str) -> str:
    text = TEXT[LABELS]
    if not has(stage, 'R8'):
        text = replace_region(text,
            '  // R8: cache metadata describes the last complete snapshot, not freshness.\n',
            '  String _pick(')
    if not has(stage, 'R3'):
        text = replace_region(text,
            '  // R3: cloud deletion is permanent, unlike local recycle-bin deletion.\n',
            '  // R5/R6: ZIP share is separate from the existing .qsz export.\n')
    if not has(stage, 'R4'):
        text = replace_region(text,
            '  // R5/R6: ZIP share is separate from the existing .qsz export.\n',
            '  String _pick(')
    elif not has(stage, 'R6'):
        text = replace_region(text,
            '  String get preparingCloudShare => _pick(\n',
            '  String get projectShareHandedOff => _pick(')
        if not has(stage, 'R5'):
            for begin, end in [
                ('  String get shareProjectZip =>\n', '  String get projectShareHandedOff => _pick('),
                ('  String get projectShareHandedOff => _pick(\n', '  String get projectShareFailed =>'),
                ("  String get zipSaved => _pick(", '  String _pick('),
            ]:
                text = replace_region(text, begin, end)
    return text


def card_version(stage: str) -> str:
    if not has(stage, 'R7'):
        return BASE_TEXT[CARD]
    text = TEXT[CARD]
    if not has(stage, 'R8'):
        text = once(text, "import '../models/cloud_project.dart';\n")
        text = once(text, '  cache,\n  clearCache,\n')
        text = once(text, '    this.cacheStatus,\n')
        text = once(text, '    this.onCache,\n    this.onClearCache,\n')
        text = once(text,
            "  /// R8: C's manifest-backed state, not an existence test on project.path.\n" +
            '  final CloudCacheStatus? cacheStatus;\n' +
            '  final bool cloudBusy;\n' +
            '  final VoidCallback? onCache;\n' +
            '  final VoidCallback? onClearCache;\n',
            '  final bool cloudBusy;\n')
        text = once(text,
            '                      if (project.isCloud && widget.cacheStatus != null) ...[\n' +
            '                        const SizedBox(height: 6),\n' +
            '                        _CloudCacheSummary(status: widget.cacheStatus!),\n' +
            '                      ],\n')
        text = once(text,
            '                      case ProjectCardAction.cache:\n' +
            '                        widget.onCache?.call();\n' +
            '                      case ProjectCardAction.clearCache:\n' +
            '                        widget.onClearCache?.call();\n')
        text = replace_region(text,
            '                    // R8: update/clear never alias the remote delete command.\n',
            '                    PopupMenuItem(\n                      value: ProjectCardAction.remove,')
        text = replace_region(text,
            '/// R8: show the last complete manifest separately from live download progress.\n',
            '/// 单行文本，宽度不足时从左侧截断（保留尾部），供路径副标题使用：')
    if not has(stage, 'R5'):
        text = once(text, "import '../i18n/studio_localizations.dart';\n")
        text = once(text, '  share,\n')
        text = once(text, '    this.onShare,\n')
        text = once(text,
            '  /// R5/R6: ZIP sharing is separate from import-compatible archive export.\n' +
            '  final VoidCallback? onShare;\n\n')
        text = once(text,
            '        (oldWidget.onExport == null) != (widget.onExport == null) ||\n' +
            '        (oldWidget.onShare == null) != (widget.onShare == null)) {',
            '        (oldWidget.onExport == null) != (widget.onExport == null)) {')
        text = once(text,
            '    if ((widget.onExport == null && widget.onShare == null) ||\n' +
            '        widget.project.isCloud) {\n      return;\n    }',
            '    if (widget.onExport == null || widget.project.isCloud) return;')
        text = once(text, '    final l10n = StudioLocalizations.of(context);\n')
        text = once(text,
            '                      case ProjectCardAction.share:\n' +
            '                        widget.onShare?.call();\n')
        text = replace_region(text,
            '                    // R5/R6: cloud sharing downloads a complete snapshot first.\n',
            '                    PopupMenuItem(\n                      value: ProjectCardAction.remove,')
        text = replace_region(text, 'enum ProjectCardAction {\n', '/// 主页的项目卡片',
            'enum ProjectCardAction { open, reveal, remove, favorite, export }\n\n')
    elif not has(stage, 'R6'):
        text = once(text,
            '                    if (widget.onShare != null &&\n' +
            '                        (project.isCloud || _canExport))',
            '                    if (widget.onShare != null &&\n' +
            '                        !project.isCloud && _canExport)')
    if not has(stage, 'R3'):
        text = once(text, '    this.cloudBusy = false,\n')
        text = once(text, '  final bool cloudBusy;\n')
        text = once(text,
            '                    PopupMenuItem(\n' +
            '                      value: ProjectCardAction.remove,\n' +
            '                      enabled: !widget.cloudBusy,',
            '                    const PopupMenuItem(\n' +
            '                      value: ProjectCardAction.remove,')
    return text


def dialog_version(stage: str) -> str:
    if not has(stage, 'R3'):
        return BASE_TEXT[DIALOGS]
    text = TEXT[DIALOGS]
    if not has(stage, 'R8'):
        text = replace_region(text,
            "/// R8: clearing this device's cache never deletes the server project.\n",
            '/// 新建文件/文件夹时输入名称。')
    return text


def card_test_version(stage: str) -> str | None:
    if not has(stage, 'R3'):
        return None
    text = TEXT[CARD_TEST]
    if has(stage, 'R8'):
        return text
    text = once(text, "import 'package:qfli_studio_core/models/cloud_project.dart';\n")
    text = once(text, '    CloudCacheStatus status, {\n', '    {\n')
    text = once(text, '    VoidCallback? cache,\n    VoidCallback? clear,\n')
    text = once(text, '              cacheStatus: status,\n')
    text = once(text, '              onCache: cache ?? () {},\n              onClearCache: clear ?? () {},\n')
    text = replace_region(text,
        "  testWidgets('R8 renders all four cache states and snapshot metadata', (\n",
        "  testWidgets('R6 cloud cards offer ZIP sharing without a local directory', (\n")
    text = replace_region(text,
        "  testWidgets('R8 update and clear invoke distinct callbacks', (tester) async {\n",
        "  testWidgets(\n    'R3/R8 busy cloud operations cannot duplicate destructive actions',")
    text = once(text,
        '      await mount(\n        tester,\n' +
        '        const CloudCacheStatus(phase: CloudCachePhase.caching),\n' +
        '        busy: true,\n      );',
        '      await mount(tester, busy: true);')
    text = once(text, '        ProjectCardAction.cache,\n        ProjectCardAction.clearCache,\n')
    text = once(text,
        "    'R3/R8 busy cloud operations cannot duplicate destructive actions',",
        "    'R3 busy cloud deletion cannot be duplicated',")
    text = once(text,
        "    'R3 server delete and R8 cache clear have distinct confirmations',",
        "    'R3 server delete confirmation promises no recycle-bin recovery',")
    text = once(text,
        "                  TextButton(\n                    onPressed: () =>\n" +
        "                        showClearCloudCacheConfirm(context, cloud()),\n" +
        "                    child: const Text('clear'),\n                  ),\n")
    text = once(text,
        "      await tester.tap(find.text('clear'));\n" +
        '      await tester.pumpAndSettle();\n' +
        '      expect(\n' +
        "        find.byKey(const ValueKey('cloud-project-cache-clear-confirm')),\n" +
        '        findsOneWidget,\n      );\n' +
        "      expect(find.textContaining('不删除云端项目'), findsOneWidget);\n" +
        "      expect(find.text('永久删除'), findsNothing);\n")
    if has(stage, 'R6'):
        text = once(text,
            '    await mount(tester, const CloudCacheStatus(), share: () => shared++);',
            '    await mount(tester, share: () => shared++);')
    else:
        text = replace_region(text,
            "  testWidgets('R6 cloud cards offer ZIP sharing without a local directory', (\n",
            '  testWidgets(\n    \'R3 busy cloud deletion cannot be duplicated\',')
        text = once(text, '    VoidCallback? share,\n')
        text = once(text, '              onShare: share ?? () {},\n')
        text = once(text, '        ProjectCardAction.share,\n')
    return text


def share_test_version(stage: str) -> str:
    return TEXT[SHARE_TEST] if has(stage, 'R5') else BASE_TEXT[SHARE_TEST]


def formatted(text: str, name: str) -> str:
    result = subprocess.run([
        str(DART), 'format', '--output=show', '--summary=none',
        '--language-version=3.11', '--stdin-name=' + name,
    ], input=text.encode('utf-8'), capture_output=True)
    if result.returncode:
        raise ValueError(f'Dart parse/format failed for {name}:\n' + result.stderr.decode('utf-8'))
    return normalized(result.stdout)


def encoded(text: str, path: str) -> bytes:
    if text == TEXT[path]:
        return FINAL[path]
    # Preserve the frozen source's line-ending convention for intermediate files.
    if b'\r\n' in FINAL[path]:
        return text.replace('\n', '\r\n').encode('utf-8')
    return text.encode('utf-8')


def digest(data: bytes | None) -> str | None:
    return hashlib.sha256(data).hexdigest() if data is not None else None


def source_guard() -> dict[str, str]:
    return {path: digest((CORE / path).read_bytes()) for path in PATHS}


def index_digest() -> str:
    value = git('rev-parse', '--git-path', 'index').stdout.decode().strip()
    path = Path(value)
    if not path.is_absolute():
        path = CORE / path
    return digest(path.read_bytes())


def build() -> None:
    baseline = git('rev-parse', BASE).stdout.decode().strip()
    before_sources = source_guard()
    before_index = index_digest()
    before_head = git('rev-parse', 'HEAD').stdout.decode().strip()
    for path in PATHS:
        FINAL[path] = (CORE / path).read_bytes()
        TEXT[path] = normalized(FINAL[path])
        raw = git('show', f'{baseline}:{path}', check=False)
        BASE_BYTES[path] = raw.stdout if raw.returncode == 0 else None
        BASE_TEXT[path] = normalized(raw.stdout) if raw.returncode == 0 else ''

    if before_sources != source_guard():
        raise RuntimeError('Frozen source changed while reading input')
    versions: dict[str, dict[str, bytes]] = {}
    format_log = []
    for stage in ORDER:
        candidates: dict[str, str | None] = {
            HOME: home_version(stage),
            PICKER: TEXT[PICKER],
            CARD: card_version(stage),
            DIALOGS: dialog_version(stage),
            LABELS: label_version(stage),
            PICKER_TEST: TEXT[PICKER_TEST],
            CARD_TEST: card_test_version(stage),
            SCOPE_TEST: TEXT[SCOPE_TEST] if has(stage, 'R7') else BASE_TEXT[SCOPE_TEST],
            SHARE_TEST: share_test_version(stage),
        }
        current: dict[str, bytes] = {}
        for path, text in candidates.items():
            if text is None:
                continue
            # Untouched baseline and frozen-final files keep exact bytes. Parse
            # them too, but do not assign incidental formatter changes to a stage.
            parsed = formatted(text, path)
            if text == TEXT[path]:
                data = FINAL[path]
                final_format_equal = parsed == text
            elif text == BASE_TEXT[path]:
                data = BASE_BYTES[path]
                final_format_equal = parsed == text
            else:
                data = encoded(parsed, path)
                final_format_equal = True
            if data is not None:
                current[path] = data
            format_log.append({
                'stage': stage, 'path': path, 'parse': 'ok',
                'format_equal': final_format_equal,
                'unchanged_bytes_preserved': text in (TEXT[path], BASE_TEXT[path]),
            })
        versions[stage] = current

    # The final tree must be exactly the captured source. No reconstruction or
    # final fallback is allowed to mask a missing transformation.
    final_stage = versions[ORDER[-1]]
    for path in PATHS:
        if final_stage.get(path) != FINAL[path]:
            raise ValueError(f'Final accumulated file differs: {path}')

    previous = {path: data for path, data in BASE_BYTES.items() if data is not None}
    manifest_stages = []
    expected_outputs: set[str] = set()
    for stage in ORDER:
        current = versions[stage]
        entries = []
        for path in PATHS:
            data = current.get(path)
            prior = previous.get(path)
            if data == prior:
                continue
            if data is None:
                raise ValueError(f'Unexpected file deletion at {stage}: {path}')
            relative = f'{stage}/{path}'
            expected_outputs.add(relative)
            write(relative, data)
            old_text = normalized(prior).splitlines(keepends=True) if prior else []
            new_text = normalized(data).splitlines(keepends=True)
            diff = ''.join(difflib.unified_diff(old_text, new_text,
                fromfile=f'previous/{path}', tofile=f'{stage}/{path}'))
            write(f'_diffs/{stage}/{path}.diff', diff)
            entries.append({
                'path': path, 'copy': relative, 'action': 'add' if prior is None else 'modify',
                'prior_sha256': digest(prior), 'sha256': digest(data), 'bytes': len(data),
                'equals_frozen_source': data == FINAL[path],
            })
        manifest_stages.append({'requirement': stage, 'files': entries})
        previous = current

    # Fail closed on leftovers if the script is re-run after its construction
    # changes. It never deletes any prior artifacts or other worker's output.
    for stage in ORDER:
        for found in output_path(stage).rglob('*'):
            if found.is_file() and found.relative_to(OUT).as_posix() not in expected_outputs:
                raise ValueError(f'Unexpected prior output: {found}')

    replay = {path: data for path, data in BASE_BYTES.items() if data is not None}
    for stage in manifest_stages:
        for entry in stage['files']:
            replay[entry['path']] = output_path(entry['copy']).read_bytes()
    matches = {path: replay.get(path) == FINAL[path] for path in PATHS}
    if not all(matches.values()):
        raise RuntimeError('Written stage-copy replay does not equal frozen source')
    after_sources = source_guard()
    after_index = index_digest()
    if after_sources != before_sources:
        raise RuntimeError('Frozen Core source changed during generation')
    if after_index != before_index:
        raise RuntimeError('Core index changed concurrently; inspect root staging before rerun')

    manifest = {
        'generated_at': datetime.now(timezone.utc).isoformat(),
        'core': str(CORE), 'base_commit': baseline,
        'head_observed': before_head, 'order': ORDER,
        'semantics': 'Each listed file is its complete cumulative content at that stage. Only changed paths are present.',
        'stages': manifest_stages,
        'verification': {
            'final_replay_equals_frozen_bytes': matches,
            'frozen_source_sha256': before_sources,
            'source_unchanged_after_generation': before_sources == after_sources,
            'index_sha256_before': before_index, 'index_sha256_after': after_index,
            'index_unchanged_after_generation': before_index == after_index,
            'dart_parse_format_invocations': len(format_log),
            'runtime_tests_run': False, 'builds_run': False,
            'source_or_index_write_commands': [],
        },
    }
    write('manifest.json', json.dumps(manifest, indent=2, ensure_ascii=False) + '\n')
    write('format-verification.json', json.dumps(format_log, indent=2) + '\n')
    print(f'Wrote {sum(len(s["files"]) for s in manifest_stages)} stage copies for {len(PATHS)} frozen files')
    print(f'Parsed/formatted {len(format_log)} cumulative file candidates using Dart 3.11')
    print('Final replay matches all frozen bytes. Core source and index hashes unchanged.')
    for stage in manifest_stages:
        print(stage['requirement'] + ': ' + ', '.join(entry['path'] for entry in stage['files']))


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.parse_args()
    build()
