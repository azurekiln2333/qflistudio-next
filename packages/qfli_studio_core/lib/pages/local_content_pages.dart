import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../i18n/studio_localizations.dart';
import '../models/tutorial.dart';
import '../services/studio_profile.dart';
import '../services/tutorial_service.dart';

/// 离线语言 App 的第二页：从随包 JSON 加载入门教程。
class LocalTutorialsTab extends StatefulWidget {
  const LocalTutorialsTab({super.key, required this.language});

  final String language;

  @override
  State<LocalTutorialsTab> createState() => _LocalTutorialsTabState();
}

class _LocalTutorialsTabState extends State<LocalTutorialsTab> {
  late Future<Tutorial?> _tutorial;

  @override
  void initState() {
    super.initState();
    _tutorial = TutorialService.load(widget.language);
  }

  @override
  void didUpdateWidget(covariant LocalTutorialsTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.language != widget.language) {
      _tutorial = TutorialService.load(widget.language);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = StudioLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text('${_displayName(widget.language)} ${l10n.tutorial}'),
      ),
      body: FutureBuilder<Tutorial?>(
        future: _tutorial,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final tutorial = snapshot.data;
          if (tutorial == null) {
            return _LocalContentError(message: l10n.localTutorialMissing);
          }
          return _TutorialList(tutorial: tutorial);
        },
      ),
    );
  }
}

/// 离线语言 App 的第三页：展示教程 JSON 中的可复制示例代码。
class ExampleCodeTab extends StatefulWidget {
  const ExampleCodeTab({super.key, required this.language});

  final String language;

  @override
  State<ExampleCodeTab> createState() => _ExampleCodeTabState();
}

class _ExampleCodeTabState extends State<ExampleCodeTab> {
  late Future<Tutorial?> _tutorial;

  @override
  void initState() {
    super.initState();
    _tutorial = TutorialService.load(widget.language);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = StudioLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text('${_displayName(widget.language)} ${l10n.examples}'),
      ),
      body: FutureBuilder<Tutorial?>(
        future: _tutorial,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final tutorial = snapshot.data;
          if (tutorial == null) {
            return _LocalContentError(message: l10n.localExamplesMissing);
          }
          return _ExampleCodeList(tutorial: tutorial);
        },
      ),
    );
  }
}

class _TutorialList extends StatelessWidget {
  const _TutorialList({required this.tutorial});

  final Tutorial tutorial;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      children: [
        _RuntimeSummary(tutorial: tutorial),
        const SizedBox(height: 12),
        for (final chapter in tutorial.chapters) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 12, 4, 4),
            child: Text(chapter.title, style: theme.textTheme.titleMedium),
          ),
          for (final lesson in chapter.lessons)
            Card(
              child: ListTile(
                leading: const Icon(Icons.menu_book_outlined),
                title: Text(lesson.title),
                subtitle: Text(lesson.summary),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => _LessonPage(lesson: lesson),
                  ),
                ),
              ),
            ),
        ],
      ],
    );
  }
}

class _ExampleCodeList extends StatelessWidget {
  const _ExampleCodeList({required this.tutorial});

  final Tutorial tutorial;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = StudioLocalizations.of(context);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      children: [
        Text(
          l10n.examplesCount(tutorial.lessonCount),
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 8),
        for (final chapter in tutorial.chapters) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 12, 4, 4),
            child: Text(chapter.title, style: theme.textTheme.titleMedium),
          ),
          for (final lesson in chapter.lessons)
            _ExampleCodeCard(lesson: lesson),
        ],
      ],
    );
  }
}

class _ExampleCodeCard extends StatelessWidget {
  const _ExampleCodeCard({required this.lesson});

  final TutorialLesson lesson;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = StudioLocalizations.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 12, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(lesson.title, style: theme.textTheme.titleSmall),
                ),
                IconButton(
                  tooltip: l10n.copyExample,
                  icon: const Icon(Icons.copy_outlined),
                  onPressed: () async {
                    await Clipboard.setData(ClipboardData(text: lesson.code));
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(SnackBar(content: Text(l10n.exampleCopied)));
                  },
                ),
              ],
            ),
            const SizedBox(height: 8),
            DecoratedBox(
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SelectableText(
                    lesson.code,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RuntimeSummary extends StatelessWidget {
  const _RuntimeSummary({required this.tutorial});

  final Tutorial tutorial;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = StudioLocalizations.of(context);
    final runtime = tutorial.runtime;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(tutorial.displayName, style: theme.textTheme.titleLarge),
            const SizedBox(height: 6),
            Text(l10n.runMode(runtime.engine)),
            if (runtime.limits case final limits? when limits.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(l10n.limits(limits)),
            ],
          ],
        ),
      ),
    );
  }
}

class _LessonPage extends StatelessWidget {
  const _LessonPage({required this.lesson});

  final TutorialLesson lesson;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = StudioLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(lesson.title)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          Text(lesson.summary, style: theme.textTheme.titleMedium),
          const SizedBox(height: 12),
          Text(lesson.explain),
          const SizedBox(height: 20),
          Text(l10n.sampleCode, style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          _ExampleCodeCard(lesson: lesson),
          const SizedBox(height: 16),
          Text(l10n.expectedOutput, style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          SelectableText(lesson.output),
          if (lesson.tasks.isNotEmpty) ...[
            const SizedBox(height: 20),
            Text(l10n.practice, style: theme.textTheme.titleMedium),
            for (final task in lesson.tasks)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.task_alt_outlined),
                title: Text(task.prompt),
                subtitle: Text(
                  '${l10n.hint(task.hint)}\n${l10n.reference(task.answer)}',
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _LocalContentError extends StatelessWidget {
  const _LocalContentError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Text(message, textAlign: TextAlign.center),
    ),
  );
}

String _displayName(String language) {
  final profile = StudioProfile.current;
  if (profile?.isOffline == true) {
    return profile!.appTitle;
  }
  final product = StudioProductCatalog.forLanguage(language);
  return product == StudioProductCatalog.qfliStudio
      ? language.toUpperCase()
      : product;
}
