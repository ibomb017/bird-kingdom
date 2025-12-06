import 'package:flutter/material.dart';

class TodayLogPage extends StatefulWidget {
  const TodayLogPage({super.key, required this.birdName});

  final String birdName;

  @override
  State<TodayLogPage> createState() => _TodayLogPageState();
}

class _TodayLogPageState extends State<TodayLogPage> {
  final _formKey = GlobalKey<FormState>();
  double? _weight;
  double? _feedAmount;
  double? _water;
  int _feedTimes = 0;

  String? _spiritStatus;
  String? _stoolStatus;
  String? _activityLevel;
  String? _socialStatus;
  bool _vocalAbnormal = false;

  int? _eggCount;
  String? _eggShellStatus;
  int? _incubationDay;
  String? _moltStatus;

  double? _temperature;
  double? _humidity;
  bool _cageCleaned = false;

  String? _notes;
  double _healthScore = 90;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final dateText =
        '${now.year}.${now.month.toString().padLeft(2, '0')}.${now.day.toString().padLeft(2, '0')}';

    return Scaffold(
      appBar: AppBar(
        title: const Text('今日养鸟日志'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: [
            Row(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      dateText,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '记录今天和小鸟在一起的点滴',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color:
                        Theme.of(context).colorScheme.primary.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.pets_rounded,
                        size: 18,
                      ),
                      const SizedBox(width: 6),
                      Text(widget.birdName),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.restaurant_rounded,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '喂食与饮水',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            decoration: const InputDecoration(
                              labelText: '体重 (g)',
                              border: OutlineInputBorder(),
                            ),
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            onSaved: (v) => _weight = double.tryParse(v ?? ''),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            decoration: const InputDecoration(
                              labelText: '喂食量 (g)',
                              border: OutlineInputBorder(),
                            ),
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            onSaved: (v) =>
                                _feedAmount = double.tryParse(v ?? ''),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            decoration: const InputDecoration(
                              labelText: '饮水量 (ml)',
                              border: OutlineInputBorder(),
                            ),
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            onSaved: (v) => _water = double.tryParse(v ?? ''),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: DropdownButtonFormField<int>(
                            decoration: const InputDecoration(
                              labelText: '喂食次数',
                              border: OutlineInputBorder(),
                            ),
                            value: _feedTimes,
                            items: const [
                              DropdownMenuItem(value: 0, child: Text('未记录')),
                              DropdownMenuItem(value: 1, child: Text('1 次')),
                              DropdownMenuItem(value: 2, child: Text('2 次')),
                              DropdownMenuItem(value: 3, child: Text('3 次及以上')),
                            ],
                            onChanged: (v) =>
                                setState(() => _feedTimes = v ?? 0),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.mood_rounded,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '心情与行为',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _chip(
                          context,
                          label: '精神良好',
                          selected: _spiritStatus == '良好',
                          onTap: () => setState(() => _spiritStatus = '良好'),
                        ),
                        _chip(
                          context,
                          label: '一般',
                          selected: _spiritStatus == '一般',
                          onTap: () => setState(() => _spiritStatus = '一般'),
                        ),
                        _chip(
                          context,
                          label: '有点萎靡',
                          selected: _spiritStatus == '萎靡',
                          onTap: () => setState(() => _spiritStatus = '萎靡'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _chip(
                          context,
                          label: '安静',
                          selected: _activityLevel == '安静',
                          onTap: () => setState(() => _activityLevel = '安静'),
                        ),
                        _chip(
                          context,
                          label: '正常',
                          selected: _activityLevel == '正常',
                          onTap: () => setState(() => _activityLevel = '正常'),
                        ),
                        _chip(
                          context,
                          label: '活泼',
                          selected: _activityLevel == '活泼',
                          onTap: () => setState(() => _activityLevel = '活泼'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _chip(
                          context,
                          label: '单独',
                          selected: _socialStatus == '单独',
                          onTap: () => setState(() => _socialStatus = '单独'),
                        ),
                        _chip(
                          context,
                          label: '和同伴玩耍',
                          selected: _socialStatus == '与同伴互动',
                          onTap: () => setState(() => _socialStatus = '与同伴互动'),
                        ),
                        _chip(
                          context,
                          label: '有点攻击性',
                          selected: _socialStatus == '有攻击行为',
                          onTap: () => setState(() => _socialStatus = '有攻击行为'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('鸣叫异常'),
                      subtitle: const Text('例如突然不叫或持续尖叫'),
                      value: _vocalAbnormal,
                      onChanged: (v) => setState(() => _vocalAbnormal = v),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.egg_rounded,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '繁殖与换羽',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            decoration: const InputDecoration(
                              labelText: '今日产蛋数',
                              border: OutlineInputBorder(),
                            ),
                            keyboardType: TextInputType.number,
                            onSaved: (v) => _eggCount = int.tryParse(v ?? ''),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            decoration: const InputDecoration(
                              labelText: '蛋壳情况',
                              border: OutlineInputBorder(),
                            ),
                            items: const [
                              DropdownMenuItem(value: '正常', child: Text('正常')),
                              DropdownMenuItem(value: '软壳', child: Text('软壳')),
                              DropdownMenuItem(value: '破损', child: Text('破损')),
                            ],
                            onChanged: (v) =>
                                setState(() => _eggShellStatus = v),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            decoration: const InputDecoration(
                              labelText: '孵化第几天',
                              border: OutlineInputBorder(),
                            ),
                            keyboardType: TextInputType.number,
                            onSaved: (v) =>
                                _incubationDay = int.tryParse(v ?? ''),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            decoration: const InputDecoration(
                              labelText: '换羽状态',
                              border: OutlineInputBorder(),
                            ),
                            items: const [
                              DropdownMenuItem(
                                  value: '未开始', child: Text('未开始')),
                              DropdownMenuItem(
                                  value: '进行中', child: Text('进行中')),
                              DropdownMenuItem(
                                  value: '已结束', child: Text('已结束')),
                            ],
                            onChanged: (v) => setState(() => _moltStatus = v),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.home_rounded,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '环境与清洁',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            decoration: const InputDecoration(
                              labelText: '温度 (°C)',
                              border: OutlineInputBorder(),
                            ),
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            onSaved: (v) =>
                                _temperature = double.tryParse(v ?? ''),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            decoration: const InputDecoration(
                              labelText: '湿度 (%)',
                              border: OutlineInputBorder(),
                            ),
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            onSaved: (v) =>
                                _humidity = double.tryParse(v ?? ''),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('今日已清洁鸟笼'),
                      value: _cageCleaned,
                      onChanged: (v) => setState(() => _cageCleaned = v),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '今天想记录的事',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      decoration: InputDecoration(
                        hintText: '今天有没有发生什么特别的小事？',
                        filled: true,
                        fillColor: Theme.of(context)
                            .colorScheme
                            .surfaceVariant
                            .withOpacity(0.3),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      maxLines: 3,
                      onSaved: (v) => _notes = v?.trim(),
                    ),
                    const SizedBox(height: 16),
                    Text('今日健康评分：${_healthScore.toInt()}'),
                    Slider(
                      value: _healthScore,
                      min: 0,
                      max: 100,
                      divisions: 20,
                      label: _healthScore.toInt().toString(),
                      onChanged: (v) => setState(() => _healthScore = v),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          _formKey.currentState?.save();
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('已保存到本地（示例）')),
                          );
                        },
                        child: const Text('完成今日记录'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Widget _chip(
  BuildContext context, {
  required String label,
  required bool selected,
  required VoidCallback onTap,
}) {
  return GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: selected
            ? Theme.of(context).colorScheme.primary.withOpacity(0.12)
            : Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.4),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: selected
              ? Theme.of(context).colorScheme.primary
              : Colors.transparent,
        ),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: selected
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).colorScheme.onSurface,
            ),
      ),
    ),
  );
}
