import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'dashboard_screen.dart';
import 'patient_list_screen.dart';
import 'todo_screen.dart';
import 'settings_screen.dart';
import '../providers/todos_provider.dart';

/// 首页（底部导航容器）
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _currentIndex = 0;

  final List<Widget> _pages = const [
    DashboardScreen(),
    PatientListScreen(),
    TodoScreen(),
    SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final pendingCountAsync = ref.watch(pendingTodoCountProvider);
    final pendingCount = pendingCountAsync.value ?? 0;

    return Scaffold(
      body: _pages[_currentIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        destinations: [
          const NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: '首页',
          ),
          const NavigationDestination(
            icon: Icon(Icons.people_outline),
            selectedIcon: Icon(Icons.people),
            label: '患者库',
          ),
          NavigationDestination(
            icon: Badge(
              label: pendingCount > 0 ? Text('$pendingCount') : null,
              isLabelVisible: pendingCount > 0,
              child: const Icon(Icons.checklist_outlined),
            ),
            selectedIcon: Badge(
              label: pendingCount > 0 ? Text('$pendingCount') : null,
              isLabelVisible: pendingCount > 0,
              child: const Icon(Icons.checklist),
            ),
            label: '待办',
          ),
          const NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: '设置',
          ),
        ],
      ),
    );
  }
}
