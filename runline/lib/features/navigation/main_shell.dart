import 'package:flutter/material.dart';

import '../../app/app_colors.dart';
import '../activity/activity_screen.dart';
import '../club/club_screen.dart';
import '../feed/feed_screen.dart';
import '../home/home_screen.dart';
import '../route/route_screen.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 2;

  static const _screens = [
    RouteScreen(),
    ActivityScreen(),
    HomeScreen(),
    ClubScreen(),
    FeedScreen(),
  ];

  static const _destinations = [
    NavigationDestination(
      icon: Icon(Icons.alt_route_outlined),
      selectedIcon: Icon(Icons.alt_route),
      label: '루트',
    ),
    NavigationDestination(
      icon: Icon(Icons.directions_run_outlined),
      selectedIcon: Icon(Icons.directions_run),
      label: '활동',
    ),
    NavigationDestination(
      icon: Icon(Icons.home_outlined),
      selectedIcon: Icon(Icons.home),
      label: '홈',
    ),
    NavigationDestination(
      icon: Icon(Icons.groups_outlined),
      selectedIcon: Icon(Icons.groups),
      label: '클럽',
    ),
    NavigationDestination(
      icon: Icon(Icons.article_outlined),
      selectedIcon: Icon(Icons.article),
      label: '피드',
    ),
  ];

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      bottom: false,
      child: IndexedStack(index: _currentIndex, children: _screens),
    ),
    bottomNavigationBar: NavigationBar(
      selectedIndex: _currentIndex,
      onDestinationSelected: (index) => setState(() => _currentIndex = index),
      indicatorColor: AppColors.primary.withValues(alpha: 0.12),
      destinations: _destinations,
    ),
  );
}
