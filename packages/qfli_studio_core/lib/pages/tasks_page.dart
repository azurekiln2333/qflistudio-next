import 'package:flutter/material.dart';

import '../../services/api_client.dart';
import '../../store/auth_store.dart';

/// 签到任务页：每日签到（连签奖励）+ 任务列表。
class TasksPage extends StatefulWidget {
  const TasksPage({super.key, required this.auth});

  final AuthStore auth;

  @override
  State<TasksPage> createState() => _TasksPageState();
}

class _TasksPageState extends State<TasksPage> {
  bool _checkedToday = false;
  int _streak = 0;
  int _points = 0;
  final List<_TaskRow> _tasks = [];
  bool _loading = true;
  bool _checking = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final token = widget.auth.token;
    if (token == null) {
      setState(() => _loading = false);
      return;
    }
    try {
      final result = await ApiClient.instance.tasks(token);
      if (!mounted) return;
      setState(() {
        _checkedToday = result.checkedToday;
        _streak = result.streak;
        _points = result.points;
        _tasks
          ..clear()
          ..addAll([
            for (final t in result.tasks)
              _TaskRow(
                key: t.key,
                label: t.label,
                done: t.done,
                reward: t.reward,
              ),
          ]);
        _loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    }
  }

  Future<void> _checkin() async {
    if (_checking || _checkedToday) return;
    setState(() => _checking = true);
    try {
      final token = widget.auth.token!;
      final result = await ApiClient.instance.checkin(token);
      if (!mounted) return;
      setState(() {
        _checkedToday = true;
        _streak = result.streak;
        _points = result.points;
      });
      widget.auth.updatePoints(points: result.points, streak: result.streak);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result.alreadyChecked
                ? '今天已签到过啦'
                : '签到成功，获得 ${result.reward} 积分，已连签 ${result.streak} 天',
          ),
        ),
      );
      await _load();
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('签到任务')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Card.filled(
                  margin: EdgeInsets.zero,
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            _Stat(
                              icon: Icons.local_fire_department_outlined,
                              label: '连签',
                              value: '$_streak 天',
                            ),
                            Container(
                              width: 1,
                              height: 40,
                              color: scheme.outlineVariant,
                            ),
                            _Stat(
                              icon: Icons.stars_outlined,
                              label: '积分',
                              value: '$_points',
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        FilledButton.icon(
                          onPressed: _checking || _checkedToday
                              ? null
                              : _checkin,
                          icon: Icon(
                            _checkedToday
                                ? Icons.check_circle_outline
                                : Icons.calendar_today_outlined,
                          ),
                          label: Text(_checkedToday ? '今日已签到' : '立即签到'),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.all(8),
                    child: Text(
                      _error!,
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: scheme.error),
                    ),
                  )
                else
                  Card.filled(
                    margin: EdgeInsets.zero,
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      children: [
                        for (final task in _tasks)
                          ListTile(
                            leading: Icon(
                              task.done
                                  ? Icons.check_circle
                                  : Icons.radio_button_unchecked,
                              color: task.done ? scheme.primary : null,
                            ),
                            title: Text(task.label),
                            trailing: Text(
                              task.done ? '已完成' : '+${task.reward} 积分',
                              style: Theme.of(context).textTheme.labelMedium
                                  ?.copyWith(
                                    color: task.done
                                        ? scheme.primary
                                        : scheme.onSurfaceVariant,
                                  ),
                            ),
                          ),
                      ],
                    ),
                  ),
              ],
            ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.icon, required this.label, required this.value});

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: scheme.primary),
        const SizedBox(height: 6),
        Text(
          value,
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
        ),
        Text(
          label,
          style: Theme.of(
            context,
          ).textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant),
        ),
      ],
    );
  }
}

class _TaskRow {
  const _TaskRow({
    required this.key,
    required this.label,
    required this.done,
    required this.reward,
  });

  final String key;
  final String label;
  final bool done;
  final int reward;
}
