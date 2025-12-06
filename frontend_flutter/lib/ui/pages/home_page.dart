import 'package:flutter/material.dart';

import '../../models/bird.dart';
import '../../models/bird_log.dart';
import '../../models/reminder.dart';
import '../../services/api_service.dart';
import 'add_bird_page.dart';
import 'bird_list_page.dart';
import 'log_list_page.dart';
import 'reminder_page.dart';
import 'today_log_page.dart';
import 'weight_trend_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final ApiService _api = ApiService();

  List<Bird> _birds = [];
  List<BirdLog> _logs = [];
  List<Reminder> _reminders = [];
  bool _isLoading = true;
  String? _error;
  int? _selectedBirdIndex;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        _api.getBirds(),
        _api.getLogs(),
        _api.getReminders(),
      ]);
      setState(() {
        _birds = results[0] as List<Bird>;
        _logs = results[1] as List<BirdLog>;
        _reminders = results[2] as List<Reminder>;
        _isLoading = false;
        if (_birds.isNotEmpty && _selectedBirdIndex == null) {
          _selectedBirdIndex = 0;
        }
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Bird? get _selectedBird {
    if (_birds.isEmpty || _selectedBirdIndex == null) return null;
    return _birds[_selectedBirdIndex!.clamp(0, _birds.length - 1)];
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('加载失败: $_error'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadData,
              child: const Text('重试'),
            ),
          ],
        ),
      );
    }

    final selectedBird = _selectedBird;

    return Stack(
      children: [
        ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
          children: [
            _SectionTitle(
              '我的鸟舍',
              onAdd: () async {
                await Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const AddBirdPage(),
                  ),
                );
                _loadData(); // 刷新数据
              },
              onViewAll: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const BirdListPage(),
                  ),
                );
              },
            ),
            const SizedBox(height: 8),
            _BirdListPreview(
              birds: _birds,
              selectedIndex: _selectedBirdIndex,
              onSelect: (index) {
                setState(() {
                  if (_selectedBirdIndex == index) {
                    _selectedBirdIndex = null;
                  } else {
                    _selectedBirdIndex = index;
                  }
                });
              },
            ),
            const SizedBox(height: 24),
            _SectionTitle(
              '日志',
              onViewAll: () => LogListPage.pushFromContext(context),
            ),
            const SizedBox(height: 8),
            _TodayRecordCard(
              logs: _logs,
              selectedBird: selectedBird,
              birds: _birds,
              onSelectBird: (index) {
                setState(() => _selectedBirdIndex = index);
              },
            ),
            const SizedBox(height: 24),
            _SectionTitle(
              '体重趋势',
              onViewAll: () => WeightTrendPage.pushFromContext(context),
            ),
            const SizedBox(height: 8),
            _StatsPreviewCard(birdName: selectedBird?.nickname),
            const SizedBox(height: 24),
            _SectionTitle(
              '近期提醒',
              onAdd: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const ReminderPage(),
                  ),
                );
              },
            ),
            const SizedBox(height: 8),
            _ReminderRow(reminders: _reminders),
          ],
        ),
        Positioned(
          right: 24,
          bottom: 80,
          child: FloatingActionButton.small(
            heroTag: 'addRecord',
            backgroundColor: Theme.of(context).colorScheme.primary,
            foregroundColor: Colors.white,
            onPressed: () {
              if (selectedBird == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('请先在上方鸟舍添加并选择一只鸟'),
                  ),
                );
                return;
              }
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => TodayLogPage(
                    birdName: selectedBird.nickname,
                  ),
                ),
              );
            },
            child: const Icon(Icons.note_add_rounded),
          ),
        ),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title, {this.onAdd, this.onViewAll});

  final String title;
  final VoidCallback? onAdd;
  final VoidCallback? onViewAll;

  @override
  Widget build(BuildContext context) {
    final showAdd = onAdd != null;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (onViewAll != null)
              GestureDetector(
                onTap: onViewAll,
                child: Text(
                  '查看全部',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.primary,
                      ),
                ),
              ),
            if (showAdd) ...[
              const SizedBox(width: 8),
              InkWell(
                borderRadius: BorderRadius.circular(999),
                onTap: onAdd,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color:
                        Theme.of(context).colorScheme.primary.withOpacity(0.08),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.add_rounded,
                    size: 18,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}

class _BirdListPreview extends StatelessWidget {
  const _BirdListPreview({
    required this.birds,
    required this.selectedIndex,
    required this.onSelect,
  });

  final List<Bird> birds;
  final int? selectedIndex;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    if (birds.isEmpty) {
      return SizedBox(
        height: 140,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () async {
            final state = context.findAncestorStateOfType<_HomePageState>();
            if (state == null) return;
            await Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const AddBirdPage(),
              ),
            );
            state._loadData();
          },
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Theme.of(context)
                          .colorScheme
                          .primary
                          .withOpacity(0.08),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Icon(
                      Icons.add_rounded,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '还没有任何鸟档案',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '点击这里添加你的第一只鸟',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return SizedBox(
      height: 180,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: birds.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final bird = birds[index];
          final isSelected = selectedIndex == index;
          return GestureDetector(
            onTap: () => onSelect(index),
            child: AspectRatio(
              aspectRatio: 3 / 4,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                child: Card(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                    side: isSelected
                        ? const BorderSide(
                            color: Color(0xFF1C6758),
                            width: 2,
                          )
                        : BorderSide.none,
                  ),
                  elevation: isSelected ? 4 : 1,
                  child: Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Color(0xFF1C6758),
                          Color(0xFF3D8361),
                        ],
                      ),
                    ),
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          height: 64,
                          decoration: BoxDecoration(
                            color: const Color(0xFFB7E4C7).withOpacity(0.6),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Center(
                            child: Icon(
                              Icons.pets_rounded,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        const Spacer(),
                        Text(
                          bird.nickname,
                          style:
                              Theme.of(context).textTheme.titleSmall?.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                  ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${bird.species} · ${bird.ageText}',
                          style:
                              Theme.of(context).textTheme.labelSmall?.copyWith(
                                    color: Colors.white.withOpacity(0.9),
                                  ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _TagChip extends StatelessWidget {
  const _TagChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.16),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w500,
            ),
      ),
    );
  }
}

class _TodayRecordCard extends StatelessWidget {
  const _TodayRecordCard({
    required this.logs,
    required this.selectedBird,
    required this.birds,
    required this.onSelectBird,
  });

  final List<BirdLog> logs;
  final Bird? selectedBird;
  final List<Bird> birds;
  final ValueChanged<int> onSelectBird;

  @override
  Widget build(BuildContext context) {
    List<BirdLog> filtered = logs;
    if (selectedBird != null) {
      filtered = logs.where((log) => log.birdId == selectedBird!.id).toList();
    }

    if (filtered.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Icon(
                Icons.menu_book_rounded,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  '今天还没有任何日志，试着为小鸟写下第一条记录吧',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return SizedBox(
      height: 150,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: filtered.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final log = filtered[index];
          final isCurrent =
              selectedBird != null && log.birdId == selectedBird!.id;
          return GestureDetector(
            onTap: () {
              final birdIndex = birds.indexWhere((b) => b.id == log.birdId);
              if (birdIndex != -1) {
                onSelectBird(birdIndex);
              }
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => TodayLogPage(birdName: log.birdName),
                ),
              );
            },
            child: SizedBox(
              width: 260,
              child: Card(
                elevation: isCurrent ? 4 : 1,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                  side: isCurrent
                      ? const BorderSide(
                          color: Color(0xFF1C6758),
                          width: 2,
                        )
                      : BorderSide.none,
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            log.birdName,
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _formatLogTime(log.logDate),
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(color: Colors.grey[600]),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Expanded(
                        child: Text(
                          log.summary,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          if (log.weight != null)
                            _MiniStatTile(
                              label: '体重',
                              value: '${log.weight!.toStringAsFixed(1)} g',
                            ),
                          const Spacer(),
                          const Icon(
                            Icons.chevron_right_rounded,
                            size: 20,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

String _formatLogTime(DateTime time) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final logDay = DateTime(time.year, time.month, time.day);

  if (logDay == today) {
    final h = time.hour.toString().padLeft(2, '0');
    final m = time.minute.toString().padLeft(2, '0');
    return '今天 $h:$m';
  }

  if (logDay == today.subtract(const Duration(days: 1))) {
    return '昨天';
  }

  return '${time.month}/${time.day}';
}

class _MiniStatTile extends StatelessWidget {
  const _MiniStatTile({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.4),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
        ],
      ),
    );
  }
}

class _StatsPreviewCard extends StatelessWidget {
  const _StatsPreviewCard({required this.birdName});

  final String? birdName;

  @override
  Widget build(BuildContext context) {
    final hasBird = birdName != null && birdName!.isNotEmpty;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              hasBird ? '$birdName 的体重趋势' : '体重趋势',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            Container(
              height: 90,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: LinearGradient(
                  colors: [
                    Theme.of(context).colorScheme.primary.withOpacity(0.16),
                    Theme.of(context).colorScheme.primary.withOpacity(0.02),
                  ],
                ),
              ),
              child: hasBird
                  ? CustomPaint(
                      painter: _FakeLineChartPainter(
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    )
                  : Center(
                      child: Text(
                        '请选择一只鸟查看体重趋势',
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: Colors.grey[700]),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FakeLineChartPainter extends CustomPainter {
  _FakeLineChartPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round;

    final path = Path();
    final points = [
      const Offset(0.05, 0.7),
      const Offset(0.2, 0.4),
      const Offset(0.4, 0.55),
      const Offset(0.6, 0.3),
      const Offset(0.8, 0.45),
      const Offset(0.95, 0.25),
    ];

    for (var i = 0; i < points.length; i++) {
      final p = Offset(points[i].dx * size.width, points[i].dy * size.height);
      if (i == 0) {
        path.moveTo(p.dx, p.dy);
      } else {
        path.lineTo(p.dx, p.dy);
      }
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _ReminderRow extends StatelessWidget {
  const _ReminderRow({required this.reminders});

  final List<Reminder> reminders;

  @override
  Widget build(BuildContext context) {
    if (reminders.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(
                Icons.notifications_none_rounded,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 12),
              Text(
                '暂无提醒，点击右上角添加',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
        ),
      );
    }

    return SizedBox(
      height: 76,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemBuilder: (context, index) {
          final reminder = reminders[index];
          return Container(
            width: 180,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(
              children: [
                Icon(
                  reminder.enabled
                      ? Icons.alarm_rounded
                      : Icons.alarm_off_rounded,
                  color: reminder.enabled
                      ? Theme.of(context).colorScheme.primary
                      : Colors.grey,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        reminder.title,
                        style: Theme.of(context).textTheme.bodyMedium,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        reminder.timeDescription,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Colors.grey[600],
                            ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemCount: reminders.length,
      ),
    );
  }
}
