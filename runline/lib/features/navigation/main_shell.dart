import 'package:flutter/material.dart';

import '../../app/app_colors.dart';
import '../activity/activity_screen.dart';
import '../auth/runline_auth.dart';
import '../club/club_screen.dart';
import '../feed/feed_screen.dart';
import '../home/home_screen.dart';
import '../route/route_screen.dart';
import 'login_required_dialog.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key, this.authentication});

  final TabAuthentication? authentication;

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 2;
  bool _checkingLogin = false;
  bool _hasSession = false;
  late final _auth = widget.authentication ?? RunlineAuth();

  bool _requiresLogin(int index) => index == 3 || index == 4;

  Future<void> _selectTab(int index) async {
    if (_checkingLogin) return;
    if (!_requiresLogin(index)) {
      setState(() => _currentIndex = index);
      return;
    }

    _checkingLogin = true;
    try {
      final signedIn = await _auth.hasSession();
      if (!mounted) return;
      if (!signedIn) {
        setState(() {
          _hasSession = false;
          if (_requiresLogin(_currentIndex)) _currentIndex = 2;
        });
        final login = await showLoginRequiredDialog(context);
        if (!mounted || !login) return;
        await _auth.signIn();
      }
      if (mounted) {
        setState(() {
          _hasSession = true;
          _currentIndex = index;
        });
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('로그인에 연결할 수 없습니다. 다시 시도해 주세요.')),
        );
      }
    } finally {
      _checkingLogin = false;
    }
  }

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
      child: IndexedStack(
        index: _currentIndex,
        children: [
          for (var index = 0; index < _screens.length; index++)
            if (!_requiresLogin(index) || _hasSession)
              _screens[index]
            else
              const SizedBox.shrink(),
        ],
      ),
    ),
    bottomNavigationBar: NavigationBar(
      selectedIndex: _currentIndex,
      onDestinationSelected: _selectTab,
      indicatorColor: AppColors.primary.withValues(alpha: 0.12),
      destinations: _destinations,
    ),
  );
}
