import 'package:flutter/material.dart';

class LogListPage extends StatelessWidget {
  const LogListPage({super.key});

  static void pushFromContext(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const LogListPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final logs = <_LogItem>[
      _LogItem(
        birdName: '小白',
        time: DateTime.now().subtract(const Duration(hours: 2)),
        summary: '早间称重 18.2g，精神良好，喂食 millet 12g。',
      ),
      _LogItem(
        birdName: '小绿',
        time: DateTime.now().subtract(const Duration(hours: 5)),
        summary: '观察换羽，今日掉羽量正常，补充钙片。',
      ),
      _LogItem(
        birdName: '小白',
        time: DateTime.now().subtract(const Duration(days: 1, hours: 3)),
        summary: '晚上状态略安静，记录便便颜色正常。',
      ),
      _LogItem(
        birdName: '小蓝',
        time: DateTime.now().subtract(const Duration(days: 2, hours: 1)),
        summary: '第一次尝试洗澡，整体反应良好。',
      ),
    ]..sort((a, b) => b.time.compareTo(a.time));

    String? lastDateLabel;

    return Scaffold(
      appBar: AppBar(
        title: const Text('全部日志'),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        itemCount: logs.length,
        itemBuilder: (context, index) {
          final log = logs[index];
          final dateLabel = _formatDateLabel(log.time);

          final showDateHeader = dateLabel != lastDateLabel;
          lastDateLabel = dateLabel;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (showDateHeader) ...[
                Text(
                  dateLabel,
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: Colors.grey[700]),
                ),
                const SizedBox(height: 4),
              ],
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Column(
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primary,
                          shape: BoxShape.circle,
                        ),
                      ),
                      Container(
                        width: 2,
                        height: 40,
                        color: Theme.of(context)
                            .colorScheme
                            .primary
                            .withOpacity(0.2),
                      ),
                    ],
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  log.birdName,
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodyMedium
                                      ?.copyWith(fontWeight: FontWeight.w600),
                                ),
                                Text(
                                  _formatTime(log.time),
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(color: Colors.grey[600]),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              log.summary,
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],
          );
        },
      ),
    );
  }
}

class _LogItem {
  _LogItem({
    required this.birdName,
    required this.time,
    required this.summary,
  });

  final String birdName;
  final DateTime time;
  final String summary;
}

String _formatDateLabel(DateTime time) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(time.year, time.month, time.day);

  if (day == today) return '今天';
  if (day == today.subtract(const Duration(days: 1))) return '昨天';
  return '${time.year}-${time.month.toString().padLeft(2, '0')}-${time.day.toString().padLeft(2, '0')}';
}

String _formatTime(DateTime time) {
  final h = time.hour.toString().padLeft(2, '0');
  final m = time.minute.toString().padLeft(2, '0');
  return '$h:$m';
}
