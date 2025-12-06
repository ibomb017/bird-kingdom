import 'package:flutter/material.dart';

import 'post_edit_page.dart';
import 'post_search_page.dart';

class ForumPage extends StatefulWidget {
  const ForumPage({super.key});

  @override
  State<ForumPage> createState() => _ForumPageState();
}

class _ForumPageState extends State<ForumPage> {
  final TextEditingController _searchController = TextEditingController();

  final List<_PostData> _posts = List.generate(
    6,
    (index) => _PostData(
      author: '鸟友 ${index + 1}',
      content: '今天在公园里发现了一只非常活泼的小文鸟，鸣叫声特别清脆～',
      distanceKm: 0.5 + index * 0.8,
    ),
  );

  String _keyword = '';
  int _tabIndex = 1; // 0: 关注, 1: 附近, 2: 推荐

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _posts.where((p) {
      if (_keyword.isEmpty) return true;
      final key = _keyword.toLowerCase();
      return p.author.toLowerCase().contains(key) ||
          p.content.toLowerCase().contains(key);
    }).toList();

    return Scaffold(
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Row(
              children: [
                const Icon(Icons.location_on_rounded, size: 18),
                const SizedBox(width: 4),
                Text(
                  '附近',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const Spacer(),
                Text(
                  '综合排序（距离优先）',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: Colors.grey[700]),
                ),
                IconButton(
                  icon: const Icon(Icons.search_rounded, size: 20),
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const PostSearchPage(),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
            child: Row(
              children: [
                _ForumTabChip(
                  label: '关注',
                  selected: _tabIndex == 0,
                  onTap: () => setState(() => _tabIndex = 0),
                ),
                const SizedBox(width: 8),
                _ForumTabChip(
                  label: '附近',
                  selected: _tabIndex == 1,
                  onTap: () => setState(() => _tabIndex = 1),
                ),
                const SizedBox(width: 8),
                _ForumTabChip(
                  label: '推荐',
                  selected: _tabIndex == 2,
                  onTap: () => setState(() => _tabIndex = 2),
                ),
              ],
            ),
          ),
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.fromLTRB(4, 4, 4, 96),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 4,
                crossAxisSpacing: 4,
                childAspectRatio: 0.6,
              ),
              itemCount: filtered.length,
              itemBuilder: (context, index) {
                return _PostCard(data: filtered[index]);
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => const PostEditPage(),
            ),
          );
        },
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
        child: const Icon(Icons.edit_rounded),
      ),
    );
  }
}

class _PostData {
  _PostData({
    required this.author,
    required this.content,
    required this.distanceKm,
  });

  final String author;
  final String content;
  final double distanceKm;
}

class _ForumTabChip extends StatelessWidget {
  const _ForumTabChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color:
              selected ? colorScheme.primary.withOpacity(0.12) : Colors.white,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color:
                selected ? colorScheme.primary : Colors.grey.withOpacity(0.2),
          ),
        ),
        child: Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: selected ? colorScheme.primary : Colors.grey[800],
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
              ),
        ),
      ),
    );
  }
}

class _PostCard extends StatelessWidget {
  const _PostCard({required this.data});

  final _PostData data;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  width: double.infinity,
                  color: Colors.grey[300],
                  child: const Center(
                    child: Icon(
                      Icons.landscape_rounded,
                      size: 40,
                      color: Colors.white70,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                const CircleAvatar(
                  radius: 14,
                  backgroundImage: AssetImage('assets/avatar_placeholder.png'),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        data.author,
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                      Text(
                        '今天 · 附近 ${data.distanceKm.toStringAsFixed(1)} km',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(Icons.favorite_border_rounded, size: 18),
                const SizedBox(width: 2),
                const Text('23'),
                const SizedBox(width: 8),
                const Icon(Icons.chat_bubble_outline_rounded, size: 18),
                const SizedBox(width: 2),
                const Text('5'),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              data.content,
              style: Theme.of(context).textTheme.bodySmall,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
