import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/course/presentation/widgets/quick_add_question_sheet.dart';
import '../theme/app_theme.dart';

class MainScaffold extends ConsumerWidget {
  final Widget child;

  const MainScaffold({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final location = GoRouterState.of(context).uri.path;
    final double screenWidth = MediaQuery.of(context).size.width;
    final bool isTablet = screenWidth > 720;

    int getIndex() {
      if (location.startsWith('/course/')) return 1;
      if (location.startsWith('/unit/')) return 1;
      if (location.startsWith('/question/')) return 1;
      if (location == '/') return 0;
      if (location == '/courses') return 1;
      if (location.startsWith('/planner')) return 2;
      if (location == '/profile') return 3;
      return 0;
    }

    if (isTablet) {
      return Scaffold(
        resizeToAvoidBottomInset: false,
        backgroundColor: AppTheme.black,
        body: Row(
          children: [
            _buildOneUISidebar(context, getIndex()),
            Expanded(
              child: Container(
                margin: const EdgeInsets.fromLTRB(0, 12, 12, 12),
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: AppTheme.black,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: child,
              ),
            ),
          ],
        ),
      );
    }

    // Mobile View
    final hideFab = location == '/planner/day';

    return Scaffold(
      extendBody: true,
      resizeToAvoidBottomInset: false,
      backgroundColor: AppTheme.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          child,
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            height: 120,
            child: IgnorePointer(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      AppTheme.black.withOpacity(0.9),
                      AppTheme.black,
                    ],
                    stops: const [0.0, 0.7, 1.0],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: _buildOneUIBottomNav(context, getIndex()),
    );
  }

  Widget _buildOneUISidebar(BuildContext context, int selectedIndex) {
    return Container(
      width: 260, // Normalized width
      decoration: const BoxDecoration(
        color: AppTheme.cardSurface, // Grey color for navigation tab layout
        borderRadius: BorderRadius.only(
          topRight: Radius.circular(32),
          bottomRight: Radius.circular(32),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Mission', style: TextStyle(fontSize: 32, fontWeight: FontWeight.w800, color: AppTheme.textPrimary, letterSpacing: -1.5)),
                Text('Control'.toUpperCase(), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF8888A0), letterSpacing: 4.0)),
              ],
            ),
          ),
          const SizedBox(height: 48),
          _sidebarPill(context, 0, Icons.grid_view_outlined, Icons.grid_view_rounded, 'Dashboard', selectedIndex == 0),
          _sidebarPill(context, 1, Icons.auto_stories_outlined, Icons.auto_stories_rounded, 'Subjects', selectedIndex == 1),
          _sidebarPill(context, 2, Icons.calendar_today_outlined, Icons.calendar_today_rounded, 'Study Plan', selectedIndex == 2),
          _sidebarPill(context, 3, Icons.settings_outlined, Icons.settings_rounded, 'Settings', selectedIndex == 3),
          const Spacer(),
        ],
      ),
    );
  }

  Widget _sidebarPill(BuildContext context, int index, IconData icon, IconData activeIcon, String label, bool isSelected) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOutCubic,
      margin: const EdgeInsets.only(bottom: 6),
      child: InkWell(
        onTap: () => _navigate(context, index),
        borderRadius: BorderRadius.circular(24),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? AppTheme.selectedTile : Colors.transparent,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Row(
            children: [
              Icon(
                isSelected ? activeIcon : icon, 
                color: isSelected ? AppTheme.samsungBlue : AppTheme.textSecondary, 
                size: 22
              ),
              const SizedBox(width: 16),
              Text(
                label,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected ? AppTheme.textPrimary : AppTheme.textSecondary,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOneUIBottomNav(BuildContext context, int selectedIndex) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.4), blurRadius: 16, offset: const Offset(0, 8)),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(32),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 4),
            color: AppTheme.sidebarSurface.withOpacity(0.85),
            child: NavigationBar(
              selectedIndex: selectedIndex,
              onDestinationSelected: (index) => _navigate(context, index),
              height: 60, // Normalized height
              backgroundColor: Colors.transparent,
              elevation: 0,
              destinations: const [
                NavigationDestination(icon: Icon(Icons.grid_view_outlined), selectedIcon: Icon(Icons.grid_view_rounded), label: 'Dashboard'),
                NavigationDestination(icon: Icon(Icons.auto_stories_outlined), selectedIcon: Icon(Icons.auto_stories_rounded), label: 'Subjects'),
                NavigationDestination(icon: Icon(Icons.calendar_today_outlined), selectedIcon: Icon(Icons.calendar_today_rounded), label: 'Plan'),
                NavigationDestination(icon: Icon(Icons.settings_outlined), selectedIcon: Icon(Icons.settings_rounded), label: 'Settings'),
              ],
            ),
          ),
        ),
      ),
    );
  }


  void _navigate(BuildContext context, int index) {
    switch (index) {
      case 0: context.go('/'); break;
      case 1: context.go('/courses'); break;
      case 2: context.go('/planner'); break;
      case 3: context.go('/profile'); break;
    }
  }

  void _showQuickAdd(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const QuickAddQuestionSheet(),
    );
  }
}
