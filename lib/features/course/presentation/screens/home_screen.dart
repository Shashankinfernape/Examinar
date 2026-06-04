import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar/isar.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import '../../domain/models/question.dart';
import '../../domain/models/course.dart';
import '../../data/repositories/course_repository.dart';
import 'package:exam_command_center/core/theme/app_theme.dart';
import 'package:exam_command_center/core/database/isar_provider.dart';
import 'package:exam_command_center/features/planner/domain/models/planner_event.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final ScrollController _scrollController = ScrollController();
  double _headerOpacity = 1.0;
  Timer? _minuteTimer;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(() {
      final offset = _scrollController.offset;
      setState(() {
        _headerOpacity = (1 - (offset / 100)).clamp(0.0, 1.0);
      });
    });
    _minuteTimer = Timer.periodic(const Duration(minutes: 1), (timer) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _minuteTimer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isarAsync = ref.watch(isarProvider);
    final double screenWidth = MediaQuery.of(context).size.width;
    final bool isTablet = screenWidth > 900;
    final double hPad = isTablet ? 32.0 : 16.0;

    return isarAsync.when(
      data: (isar) {
        final now = DateTime.now();
        final startOfDay = DateTime(now.year, now.month, now.day);
        final endOfDay = DateTime(now.year, now.month, now.day, 23, 59, 59);

        return StreamBuilder<List<PlannerEvent>>(
          stream: isar.plannerEvents.where().filter().startTimeBetween(startOfDay, endOfDay).watch(fireImmediately: true),
          builder: (context, snapshot) {
            final events = snapshot.data ?? [];
            final filteredEvents = events.where((e) => !e.title.startsWith('EXAM:')).toList();
            final pendingTasks = filteredEvents.where((e) => !e.isCompleted).toList()..sort((a, b) => a.startTime.compareTo(b.startTime));
            final completedTasks = filteredEvents.where((e) => e.isCompleted).toList()..sort((a, b) => a.startTime.compareTo(b.startTime));

            return Scaffold(
              backgroundColor: AppTheme.black,
              body: CustomScrollView(
                controller: _scrollController,
                physics: const BouncingScrollPhysics(),
                slivers: [
                  _buildHeader(hPad),
                  SliverPadding(
                    padding: EdgeInsets.symmetric(horizontal: hPad),
                    sliver: SliverToBoxAdapter(
                      child: isTablet 
                          ? _buildTabletLayout(isar, pendingTasks, completedTasks, filteredEvents.length, completedTasks.length)
                          : _buildPhoneLayout(isar, pendingTasks, completedTasks, filteredEvents.length, completedTasks.length),
                    ),
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: 120)),
                ],
              ),
            );
          }
        );
      },
      loading: () => const Scaffold(backgroundColor: AppTheme.black, body: SizedBox.shrink()),
      error: (e, s) => Scaffold(backgroundColor: AppTheme.black, body: Center(child: Text('Error: $e'))),
    );
  }

  Widget _buildHeader(double hPad) {
    return SliverToBoxAdapter(
      child: Opacity(
        opacity: _headerOpacity,
        child: Padding(
          padding: EdgeInsets.fromLTRB(hPad, 60, hPad, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                DateFormat('EEEE, MMMM d').format(DateTime.now()).toUpperCase(),
                style: const TextStyle(fontSize: 12, color: Colors.white54, fontWeight: 
FontWeight.w900, letterSpacing: 2.0),
              ),
              const SizedBox(height: 8),
              Text(
                'Command Center',
                style: Theme.of(context).textTheme.displayLarge?.copyWith(fontSize: 32),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTabletLayout(Isar isar, List<PlannerEvent> pending, List<PlannerEvent> completed, int total, int comp) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 3,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('TODAY\'S OBJECTIVES', style: TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 2.0)),
              const SizedBox(height: 16),
              AnimatedSize(
                duration: const Duration(milliseconds: 500),
                curve: Curves.easeOutCubic,
                child: _buildTodoList(pending, isar),
              ),
              if (completed.isNotEmpty) ...[
                const SizedBox(height: 32),
                const Text('COMPLETED', style: TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 2.0)),
                const SizedBox(height: 16),
                AnimatedSize(
                  duration: const Duration(milliseconds: 500),
                  curve: Curves.easeOutCubic,
                  child: _buildCompletedList(completed, isar),
                ),
              ]
            ],
          )
        ),
        const SizedBox(width: 48),
        Expanded(
          flex: 2,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildProgressWidget(total, comp),
            ]
          )
        )
      ]
    );
  }

  Widget _buildPhoneLayout(Isar isar, List<PlannerEvent> pending, List<PlannerEvent> completed, int total, int comp) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildProgressWidget(total, comp),
        const SizedBox(height: 32),
        const Text('TODAY\'S OBJECTIVES', style: TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 2.0)),
        const SizedBox(height: 16),
        AnimatedSize(
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeOutCubic,
          child: _buildTodoList(pending, isar),
        ),
        if (completed.isNotEmpty) ...[
          const SizedBox(height: 32),
          const Text('COMPLETED', style: TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 2.0)),
          const SizedBox(height: 16),
          AnimatedSize(
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeOutCubic,
            child: _buildCompletedList(completed, isar),
          ),
        ],
      ]
    );
  }

  Widget _buildProgressWidget(int total, int completed) {
    double progress = total == 0 ? 0 : completed / total;
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppTheme.cardSurface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 64,
            height: 64,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CircularProgressIndicator(
                  value: progress,
                  strokeWidth: 6,
                  backgroundColor: Colors.white10,
                  color: Colors.white,
                  strokeCap: StrokeCap.round,
                ),
                Text('${(progress * 100).toInt()}%', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16)),
              ]
            )
          ),
          const SizedBox(width: 24),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('DAILY PROGRESS', style: TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1.5)),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8)
                  ),
                  child: Text('$completed/$total Tasks', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
                )
              ]
            )
          )
        ]
      )
    );
  }

  Widget _buildTodoList(List<PlannerEvent> tasks, Isar isar) {
    if (tasks.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: AppTheme.cardSurface,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Text('No pending tasks. You are clear.', textAlign: TextAlign.center, style: TextStyle(color: Colors.white30, fontWeight: FontWeight.w600)),
      );
    }
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.cardSurface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: tasks.length,
        separatorBuilder: (context, index) => const Divider(height: 1, color: Colors.white10),
        itemBuilder: (context, index) {
          final task = tasks[index];
          return Dismissible(
            key: ValueKey('task_${task.id}'),
            direction: DismissDirection.startToEnd,
            movementDuration: const Duration(milliseconds: 400),
            resizeDuration: const Duration(milliseconds: 400),
            onDismissed: (_) async {
               await isar.writeTxn(() async {
                  task.isCompleted = true;
                  await isar.plannerEvents.put(task);
               });
            },
            background: Container(
              color: AppTheme.completedColor.withOpacity(0.15),
              alignment: Alignment.centerLeft,
              padding: const EdgeInsets.only(left: 24),
              child: const Icon(Icons.check, color: AppTheme.completedColor, size: 28),
            ),
            child: _buildTaskCard(task, false),
          );
        }
      ),
    );
  }

  Widget _buildCompletedList(List<PlannerEvent> tasks, Isar isar) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.cardSurface.withOpacity(0.5),
        borderRadius: BorderRadius.circular(16),
      ),
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: tasks.length,
        separatorBuilder: (context, index) => const Divider(height: 1, color: Colors.white10),
        itemBuilder: (context, index) {
          final task = tasks[index];
          return _buildTaskCard(task, true);
        }
      ),
    );
  }

  Widget _buildTaskCard(PlannerEvent task, bool isCompleted) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Time Column
          SizedBox(
            width: 70,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  DateFormat('h:mm a').format(task.startTime),
                  style: TextStyle(color: isCompleted ? Colors.white30 : Colors.white70, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 0.5)
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6.0),
                  child: isCompleted 
                      ? const Icon(Icons.check_circle, color: Colors.white24, size: 16)
                      : AnimatedClockIcon(startTime: task.startTime, endTime: task.endTime),
                ),
                Text(
                  DateFormat('h:mm a').format(task.endTime),
                  style: TextStyle(color: isCompleted ? Colors.white24 : Colors.white54, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 0.5)
                ),
              ],
            ),
          ),
          
          Container(
            width: 1,
            height: 50,
            margin: const EdgeInsets.symmetric(horizontal: 16),
            color: Colors.white10,
          ),
          
          // Task Title
          Expanded(
            child: Text(
              task.title,
              style: TextStyle(
                color: isCompleted ? Colors.white30 : Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.2,
                decoration: isCompleted ? TextDecoration.lineThrough : null
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            )
          ),
        ]
      )
    );
  }

}

class AnimatedClockIcon extends StatelessWidget {
  final DateTime startTime;
  final DateTime endTime;
  
  const AnimatedClockIcon({super.key, required this.startTime, required this.endTime});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    // Only spawn the clock icon if the task is currently active
    if (now.isBefore(startTime) || now.isAfter(endTime)) {
      return const SizedBox(width: 16, height: 16);
    }

    // Tick exactly every 15 minutes
    final int minutes = now.minute;
    final int quarter = minutes ~/ 15;
    final double angle = quarter * (3.141592653589793 / 2);

    return Container(
      width: 16,
      height: 16,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 1.5),
      ),
      child: Transform.rotate(
        angle: angle,
        child: Align(
          alignment: Alignment.topCenter,
          child: Container(
            width: 1.5,
            height: 6,
            color: Colors.white,
            margin: const EdgeInsets.only(top: 1.5),
          ),
        ),
      ),
    );
  }
}
