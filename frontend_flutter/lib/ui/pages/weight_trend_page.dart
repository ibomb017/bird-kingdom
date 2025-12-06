import 'package:flutter/material.dart';

class WeightTrendPage extends StatefulWidget {
  const WeightTrendPage({super.key});

  static void pushFromContext(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const WeightTrendPage()),
    );
  }

  @override
  State<WeightTrendPage> createState() => _WeightTrendPageState();
}

class _WeightTrendPageState extends State<WeightTrendPage> {
  final List<String> _birds = ['全部', '小白', '小绿', '小蓝'];
  int _selectedBird = 0;
  int _rangeIndex = 1; // 0: 1周, 1: 1月, 2: 3月, 3: 1年

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('体重趋势总览'),
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: List.generate(_birds.length, (index) {
                  final selected = _selectedBird == index;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(_birds[index]),
                      selected: selected,
                      onSelected: (_) {
                        setState(() => _selectedBird = index);
                      },
                    ),
                  );
                }),
              ),
            ),
            const SizedBox(height: 12),
            ToggleButtons(
              isSelected: List.generate(4, (i) => i == _rangeIndex),
              onPressed: (i) {
                setState(() => _rangeIndex = i);
              },
              borderRadius: BorderRadius.circular(999),
              children: const [
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  child: Text('1 周'),
                ),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  child: Text('1 月'),
                ),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  child: Text('3 月'),
                ),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  child: Text('1 年'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  color:
                      Theme.of(context).colorScheme.primary.withOpacity(0.04),
                ),
                child: const Center(
                  child: Text('体重趋势图表占位（后续接入真实数据和图表库）'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
