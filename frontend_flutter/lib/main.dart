import 'package:flutter/material.dart';

import 'theme/app_theme.dart';
import 'ui/pages/home_page.dart';
import 'ui/pages/encyclopedia_page.dart';
import 'ui/pages/forum_page.dart';
import 'ui/pages/profile_page.dart';

void main() {
  runApp(const BirdKingdomApp());
}

class BirdKingdomApp extends StatelessWidget {
  const BirdKingdomApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '鸟鸟王国',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      home: const _RootScaffold(),
    );
  }
}

class _RootScaffold extends StatefulWidget {
  const _RootScaffold();

  @override
  State<_RootScaffold> createState() => _RootScaffoldState();
}

class _RootScaffoldState extends State<_RootScaffold> {
  int _currentIndex = 0;

  final _pages = const [
    HomePage(),
    EncyclopediaPage(),
    ForumPage(),
    ProfilePage(),
  ];

  final _titles = const [
    '鸟舍',
    '百科与配色',
    '鸟友广场',
    '我的',
  ];

  @override
  Widget build(BuildContext context) {
    final bool isForum = _currentIndex == 2;

    return Scaffold(
      extendBody: true,
      appBar: AppBar(
        toolbarHeight: isForum ? 40 : kToolbarHeight,
        title: Text(
          _titles[_currentIndex],
          style: Theme.of(context).textTheme.titleLarge,
        ),
        centerTitle: true,
        elevation: 0,
      ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 250),
        child: _pages[_currentIndex],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded),
            label: '首页',
          ),
          NavigationDestination(
            icon: Icon(Icons.menu_book_outlined),
            selectedIcon: Icon(Icons.menu_book_rounded),
            label: '百科',
          ),
          NavigationDestination(
            icon: Icon(Icons.public_outlined),
            selectedIcon: Icon(Icons.public_rounded),
            label: '广场',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person_rounded),
            label: '我的',
          ),
        ],
      ),
    );
  }
}
