import 'package:flutter/material.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        _HeaderCard(),
        SizedBox(height: 16),
        _StatsRow(),
        SizedBox(height: 24),
        _SettingsSection(),
        SizedBox(height: 24),
        _MyPostsSection(),
      ],
    );
  }
}

class _MyPostsSection extends StatelessWidget {
  const _MyPostsSection();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '我的广场帖子',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        Card(
          child: ListTile(
            leading: const Icon(Icons.article_rounded),
            title: const Text('今天和小白在阳台晒太阳'),
            subtitle: const Text('发表于 今天 · 23 赞 · 5 评论'),
            onTap: () {
              // 预留：跳转到我的帖子列表或详情
            },
          ),
        ),
        Card(
          child: ListTile(
            leading: const Icon(Icons.article_rounded),
            title: const Text('第一次给小绿洗澡的记录'),
            subtitle: const Text('发表于 昨天 · 12 赞 · 3 评论'),
            onTap: () {},
          ),
        ),
      ],
    );
  }
}

class _HeaderCard extends StatelessWidget {
  const _HeaderCard();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            const CircleAvatar(
              radius: 30,
              backgroundImage: AssetImage('assets/avatar_placeholder.png'),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '鸟の守护者',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '已坚持记录 32 天 · 养鸟 3 只',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatsRow extends StatelessWidget {
  const _StatsRow();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: const [
        Expanded(
          child: _StatTile(label: '累计记录', value: '128'),
        ),
        SizedBox(width: 12),
        Expanded(
          child: _StatTile(label: '本周活跃', value: '5 天'),
        ),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}

class _SettingsSection extends StatelessWidget {
  const _SettingsSection();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Column(
        children: [
          SwitchListTile(
            value: true,
            onChanged: (_) {},
            title: const Text('提醒通知'),
            subtitle: const Text('换羽期、产蛋期与喂食时间提醒'),
          ),
          const Divider(height: 0),
          SwitchListTile(
            value: false,
            onChanged: (_) {},
            title: const Text('深色模式'),
          ),
          const Divider(height: 0),
          ListTile(
            leading: const Icon(Icons.help_outline_rounded),
            title: const Text('使用帮助'),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () {},
          ),
          const Divider(height: 0),
          ListTile(
            leading: const Icon(Icons.info_outline_rounded),
            title: const Text('关于鸟鸟王国'),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () {},
          ),
        ],
      ),
    );
  }
}
