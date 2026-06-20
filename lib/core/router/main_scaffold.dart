import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../features/course/presentation/widgets/quick_add_question_sheet.dart';
import '../theme/app_theme.dart';

class MainScaffold extends ConsumerStatefulWidget {
  final StatefulNavigationShell navigationShell;
  const MainScaffold({super.key, required this.navigationShell});

  @override
  ConsumerState<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends ConsumerState<MainScaffold> {
  bool _isSidebarExpanded = false;
  bool _isMenuPressed = false;

  void _navigate(BuildContext context, int index) {
    widget.navigationShell.goBranch(
      index,
      initialLocation: index == widget.navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).uri.path;
    final double screenWidth = MediaQuery.of(context).size.width;
    final bool isTablet = screenWidth > 720;
    final int selectedIndex = widget.navigationShell.currentIndex;

    if (isTablet) {
      return Scaffold(
        resizeToAvoidBottomInset: false,
        backgroundColor: AppTheme.black,
        body: Row(
          children: [
            _buildOneUISidebar(context, selectedIndex),
            Expanded(
              child: Container(
                margin: const EdgeInsets.fromLTRB(0, 12, 12, 12),
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: AppTheme.black,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: widget.navigationShell,
              ),
            ),
          ],
        ),
      );
    }

    // Mobile View
    return Scaffold(
      extendBody: true,
      resizeToAvoidBottomInset: false,
      backgroundColor: AppTheme.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          widget.navigationShell,
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
      bottomNavigationBar: _buildOneUIBottomNav(context, selectedIndex),
    );
  }

  Widget _buildOneUISidebar(BuildContext context, int selectedIndex) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOutQuad,
      width: _isSidebarExpanded ? 280 : 80,
      decoration: const BoxDecoration(
        color: AppTheme.cardSurface,
        borderRadius: BorderRadius.only(
          topRight: Radius.circular(32),
          bottomRight: Radius.circular(32),
        ),
      ),
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 32),
          AnimatedPadding(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutQuad,
            padding: EdgeInsets.only(left: _isSidebarExpanded ? 24 : 16),
            child: Row(
              children: [
                GestureDetector(
                  onTapDown: (_) => setState(() => _isMenuPressed = true),
                  onTapUp: (_) => setState(() => _isMenuPressed = false),
                  onTapCancel: () => setState(() => _isMenuPressed = false),
                  onTap: () {
                    setState(() {
                      _isSidebarExpanded = !_isSidebarExpanded;
                    });
                  },
                  behavior: HitTestBehavior.opaque,
                  child: Container(
                    width: 48,
                    height: 48,
                    alignment: Alignment.center,
                    child: const Icon(Icons.hourglass_bottom_rounded, color: Colors.white, size: 32)
                      .animate(target: _isSidebarExpanded ? 1 : 0)
                      .rotate(begin: -0.125, end: 0.875, duration: 800.ms, curve: Curves.easeInOutBack),
                  ).animate(target: _isMenuPressed ? 1 : 0)
                   .scale(begin: const Offset(1, 1), end: const Offset(0.85, 0.85), duration: 100.ms, curve: Curves.easeOutCubic)
                   .fade(begin: 1.0, end: 0.7, duration: 100.ms),
                ),
                Expanded(
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 150),
                    opacity: _isSidebarExpanded ? 1.0 : 0.0,
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      physics: const NeverScrollableScrollPhysics(),
                      child: Row(
                        children: [
                          const SizedBox(width: 8),
                          Text(
                            'Examinar',
                            style: GoogleFonts.outfit(fontSize: 28, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
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
      curve: Curves.easeOutQuad,
      margin: EdgeInsets.symmetric(horizontal: _isSidebarExpanded ? 16 : 12, vertical: 3),
      child: InkWell(
        onTap: () => _navigate(context, index),
        borderRadius: BorderRadius.circular(24),
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: _isSidebarExpanded ? 16 : 12, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Row(
            children: [
              Icon(
                isSelected ? activeIcon : icon, 
                color: isSelected ? Colors.white : AppTheme.textSecondary, 
                size: 24
              ),
              Expanded(
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 150),
                  opacity: _isSidebarExpanded ? 1.0 : 0.0,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    physics: const NeverScrollableScrollPhysics(),
                    child: Padding(
                      padding: const EdgeInsets.only(left: 16),
                      child: Text(
                        label,
                        style: GoogleFonts.inter(
                          fontSize: 15,
                          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                          color: isSelected ? AppTheme.textPrimary : AppTheme.textSecondary,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ),
                  ),
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


  void _showQuickAdd(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const QuickAddQuestionSheet(),
    );
  }
}
