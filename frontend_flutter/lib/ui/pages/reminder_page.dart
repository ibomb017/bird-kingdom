import 'package:flutter/material.dart';

class ReminderPage extends StatefulWidget {
  const ReminderPage({super.key});

  @override
  State<ReminderPage> createState() => _ReminderPageState();
}

class _ReminderPageState extends State<ReminderPage> {
  final List<_ReminderItem> _reminders = [
    _ReminderItem(title: '晚间喂食', time: '每天 20:00', enabled: true),
    _ReminderItem(title: '清洁鸟笼', time: '每周三 10:00', enabled: false),
  ];

  Future<void> _addReminderDialog() async {
    final titleController = TextEditingController();
    final timeController = TextEditingController();

    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('添加提醒'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                decoration: const InputDecoration(
                  labelText: '提醒内容',
                  hintText: '例如：喂食、小鸟体检',
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: timeController,
                decoration: const InputDecoration(
                  labelText: '时间',
                  hintText: '例如：每天 20:00',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () {
                final title = titleController.text.trim();
                final time = timeController.text.trim();
                if (title.isEmpty || time.isEmpty) {
                  return;
                }
                setState(() {
                  _reminders.add(
                    _ReminderItem(title: title, time: time, enabled: true),
                  );
                });
                Navigator.of(context).pop();
              },
              child: const Text('保存'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('提醒设置'),
      ),
      body: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
        itemBuilder: (context, index) {
          final item = _reminders[index];
          return SwitchListTile(
            title: Text(item.title),
            subtitle: Text(item.time),
            value: item.enabled,
            onChanged: (value) {
              setState(() {
                _reminders[index] = item.copyWith(enabled: value);
              });
            },
          );
        },
        separatorBuilder: (_, __) => const Divider(height: 0),
        itemCount: _reminders.length,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addReminderDialog,
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
        child: const Icon(Icons.add_alert_rounded),
      ),
    );
  }
}

class _ReminderItem {
  const _ReminderItem({
    required this.title,
    required this.time,
    required this.enabled,
  });

  final String title;
  final String time;
  final bool enabled;

  _ReminderItem copyWith({String? title, String? time, bool? enabled}) {
    return _ReminderItem(
      title: title ?? this.title,
      time: time ?? this.time,
      enabled: enabled ?? this.enabled,
    );
  }
}
