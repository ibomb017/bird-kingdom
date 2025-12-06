import 'package:flutter/material.dart';

class BirdListPage extends StatelessWidget {
  const BirdListPage({super.key});

  @override
  Widget build(BuildContext context) {
    final birds = <_BirdListItem>[
      const _BirdListItem(name: '小白', species: '文鸟', age: '8 个月'),
      const _BirdListItem(name: '小绿', species: '牡丹鹦鹉', age: '1 岁 2 个月'),
      const _BirdListItem(name: '小蓝', species: '虎皮鹦鹉', age: '5 个月'),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('我的鸟舍'),
      ),
      body: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        itemBuilder: (context, index) {
          final bird = birds[index];
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: const Color(0xFFB7E4C7).withOpacity(0.9),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.pets_rounded,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          bird.name,
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          bird.species,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '年龄：${bird.age}',
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(color: Colors.grey[700]),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemCount: birds.length,
      ),
    );
  }
}

class _BirdListItem {
  const _BirdListItem({
    required this.name,
    required this.species,
    required this.age,
  });

  final String name;
  final String species;
  final String age;
}
