import 'package:flutter/material.dart';

import '../services/studio_profile.dart';
import 'editor_analysis_controller.dart';

String _status(EditorAnalysisController analysis) => analysis.pending
    ? '正在检查…'
    : analysis.unavailableReason ??
          (analysis.checked
              ? analysis.problems.isEmpty
                    ? '本地检查未发现问题'
                    : '问题 ${analysis.problems.length}'
              : '尚未检查');

class EditorProblemsBar extends StatelessWidget {
  const EditorProblemsBar({
    super.key,
    required this.analysis,
    required this.onOpenProblems,
    required this.child,
  });
  final EditorAnalysisController analysis;
  final VoidCallback onOpenProblems;
  final Widget child;
  @override
  Widget build(BuildContext context) {
    final product =
        StudioProfile.current?.productKey ?? StudioProductCatalog.qfliStudioKey;
    if (product == StudioProductCatalog.qfliStudioKey &&
        analysis.analyzer == null) {
      return child;
    }
    return Column(
      children: [
        Expanded(child: child),
        ListenableBuilder(
          listenable: analysis,
          builder: (context, _) => Material(
            color: Theme.of(context).colorScheme.surfaceContainer,
            child: InkWell(
              key: const ValueKey('editor-problems-status'),
              onTap: onOpenProblems,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                child: Row(
                  children: [
                    const Icon(Icons.rule, size: 16),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        _status(analysis),
                        style: Theme.of(context).textTheme.labelSmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Actual bounded editor panel. Availability failures never appear as clean code.
class EditorProblemsPanel extends StatelessWidget {
  const EditorProblemsPanel({
    super.key,
    required this.analysis,
    required this.onClose,
  });
  final EditorAnalysisController analysis;
  final VoidCallback onClose;
  @override
  Widget build(BuildContext context) => Material(
    color: Theme.of(context).colorScheme.surfaceContainer,
    child: ListenableBuilder(
      listenable: analysis,
      builder: (context, _) => LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxHeight < 56) {
            return InkWell(
              onTap: onClose,
              child: Center(
                child: Text(
                  '问题 · ${_status(analysis)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            );
          }
          return Column(
            children: [
              Row(
                children: [
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      '问题',
                      style: Theme.of(context).textTheme.titleSmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    tooltip: '重新检查',
                    onPressed: () => analysis.requestAnalysis(immediate: true),
                    icon: const Icon(Icons.refresh),
                  ),
                  IconButton(
                    key: const ValueKey('close-editor-problems'),
                    tooltip: '关闭问题面板',
                    onPressed: onClose,
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              if (analysis.pending) const LinearProgressIndicator(minHeight: 2),
              Expanded(
                child: analysis.problems.isEmpty
                    ? SingleChildScrollView(
                        padding: const EdgeInsets.all(12),
                        child: SelectableText(_status(analysis)),
                      )
                    : ListView.builder(
                        key: const ValueKey('editor-problems-list'),
                        itemCount: analysis.problems.length,
                        itemBuilder: (context, index) {
                          final problem = analysis.problems[index];
                          return ListTile(
                            leading: Icon(switch (problem.severity) {
                              CodeDiagnosticSeverity.error =>
                                Icons.error_outline,
                              CodeDiagnosticSeverity.warning =>
                                Icons.warning_amber,
                              _ => Icons.info_outline,
                            }),
                            title: Text(problem.message),
                            subtitle: Text(
                              '${analysis.location(problem)}'
                              '${problem.source.isEmpty ? '' : ' · ${problem.source}'}'
                              '${problem.code.isEmpty ? '' : ' ${problem.code}'}',
                            ),
                            onTap: () => analysis.navigate(problem),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    ),
  );
}
