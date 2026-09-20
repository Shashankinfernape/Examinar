import 'dart:async';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import '../../domain/models/question.dart';
import '../../data/repositories/question_repository.dart';
import '../../../planner/data/repositories/planner_repository.dart';


import 'package:exam_command_center/core/theme/app_theme.dart';

import 'package:exam_command_center/features/planner/domain/models/planner_event.dart';
import 'package:exam_command_center/features/planner/presentation/widgets/task_action_sheet.dart';
import 'package:exam_command_center/core/settings/settings_provider.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final ScrollController _scrollController = ScrollController();
    Timer? _minuteTimer;
  final Set<String> _dismissedTaskIds = {};

  @override
  void initState() {
    super.initState();

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
    final settings = ref.watch(settingsProvider);
    final plannerRepo = ref.watch(plannerRepositoryProvider);
    final double screenWidth = MediaQuery.of(context).size.width;
    final bool isTablet = screenWidth > 900;
    final double hPad = isTablet ? 32.0 : 16.0;

    final hour = DateTime.now().hour;
    String greeting = 'Good evening';
    if (hour < 12) {
      greeting = 'Good morning';
    } else if (hour < 17) {
      greeting = 'Good afternoon';
    }

        final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final endOfDay = DateTime(now.year, now.month, now.day, 23, 59, 59);

    return StreamBuilder<List<PlannerEvent>>(
      stream: plannerRepo.watchAllEvents(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Scaffold(backgroundColor: AppTheme.black, body: Center(child: Text('Error: ${snapshot.error}')));
        }
        if (!snapshot.hasData) {
          return const Scaffold(backgroundColor: AppTheme.black, body: SizedBox.shrink());
        }
        
        final allEvents = snapshot.data ?? [];
        final events = allEvents.where((e) => e.startTime.isAfter(startOfDay.subtract(const Duration(seconds: 1))) && e.startTime.isBefore(endOfDay.add(const Duration(seconds: 1)))).toList();
        
        final filteredEvents = events.where((e) => !e.title.startsWith('EXAM:')).toList();
        final pendingTasks = filteredEvents.where((e) => !e.isCompleted && !_dismissedTaskIds.contains(e.id)).toList()..sort((a, b) => a.startTime.compareTo(b.startTime));
        final completedTasks = filteredEvents.where((e) => e.isCompleted).toList()..sort((a, b) => a.startTime.compareTo(b.startTime));

        return Scaffold(
          backgroundColor: AppTheme.black,
          body: CustomScrollView(
            controller: _scrollController,
            physics: const BouncingScrollPhysics(),
            slivers: [
              SliverSafeArea(
                bottom: false,
                sliver: SliverPadding(
                  padding: EdgeInsets.symmetric(horizontal: hPad, vertical: 24),
                  sliver: SliverToBoxAdapter(
                    child: isTablet 
                        ? _buildTabletLayout(pendingTasks, completedTasks, filteredEvents.length, completedTasks.length, greeting, settings.userName)
                        : _buildPhoneLayout(pendingTasks, completedTasks, filteredEvents.length, completedTasks.length, greeting, settings.userName),
                  ),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 120)),
            ],
          ),
        );
      }
    );
  }


  Widget _buildTabletLayout(List<PlannerEvent> pending, List<PlannerEvent> completed, int total, int comp, String greeting, String userName) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('$greeting, $userName', style: GoogleFonts.spaceGrotesk(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w800, letterSpacing: -0.5)),
        const SizedBox(height: 24),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildTodoList(context, pending),
                  if (completed.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    _buildCompletedList(context, completed),
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
                  _buildProgressWidget(context, total, comp),
                ]
              )
            )
          ]
        )
      ]
    );
  }

  Widget _buildPhoneLayout(List<PlannerEvent> pending, List<PlannerEvent> completed, int total, int comp, String greeting, String userName) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('$greeting, $userName', style: GoogleFonts.spaceGrotesk(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w800, letterSpacing: -0.5)),
        const SizedBox(height: 24),
        _buildProgressWidget(context, total, comp),
        const SizedBox(height: 16),
        _buildTodoList(context, pending),
        if (completed.isNotEmpty) ...[
          const SizedBox(height: 16),
          _buildCompletedList(context, completed),
        ],
      ]
    );
  }

  Widget _buildProgressWidget(BuildContext context, int total, int completed) {
    double progress = total == 0 ? 0 : completed / total;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.24), width: 1.5),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 76,
            height: 76,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox.expand(
                  child: CircularProgressIndicator(
                    value: progress,
                    strokeWidth: 5,
                    backgroundColor: Colors.white10,
                    color: Colors.white,
                    strokeCap: StrokeCap.round,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: FittedBox(
                    child: Text('${(progress * 100).toInt()}%', style: GoogleFonts.spaceGrotesk(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 20)),
                  ),
                ),
              ]
            )
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('DAILY PROGRESS', style: GoogleFonts.spaceGrotesk(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 1.5)),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10)
                  ),
                  child: Text('$completed/$total Tasks Completed', style: GoogleFonts.inter(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700)),
                )
              ]
            )
          )
        ]
      )
    );
  }

  Widget _buildTodoList(BuildContext context, List<PlannerEvent> tasks) {
    if (tasks.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white24, width: 1.5),
        ),
        child: Column(
          children: [
            Text('TO-DO', style: GoogleFonts.spaceGrotesk(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
            const SizedBox(height: 24),
            Text('No pending tasks. You are clear.', textAlign: TextAlign.center, style: GoogleFonts.inter(color: Colors.white30, fontWeight: FontWeight.w600)),
          ],
        ),
      );
    }
    return Container(
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white24, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Center(
              child: Text('TO-DO LIST', style: GoogleFonts.spaceGrotesk(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
            ),
          ),
          const Divider(height: 1, color: Colors.white10),
          ListView.separated(
            padding: EdgeInsets.zero,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: tasks.length,
            separatorBuilder: (context, index) => const Divider(height: 1, color: Colors.white10, indent: 70),
            itemBuilder: (context, index) {
              final task = tasks[index];
              return Dismissible(
                key: ValueKey('task_${task.id}'),
                direction: DismissDirection.startToEnd,
                movementDuration: const Duration(milliseconds: 600),
                resizeDuration: const Duration(milliseconds: 500),
                dismissThresholds: const {DismissDirection.startToEnd: 0.3},
                onDismissed: (_) async {
                   task.isCompleted = true;
                   setState(() {
                     _dismissedTaskIds.add(task.id);
                   });
                   
                   final plannerRepo = ref.read(plannerRepositoryProvider);
                   final questionRepo = ref.read(questionRepositoryProvider);
                   
                   await plannerRepo.updateEvent(task);
                   if (task.questionIds != null && task.questionIds!.isNotEmpty) {
                     for (final qId in task.questionIds!) {
                       await questionRepo.updateStatus(qId, QuestionStatus.completed);
                     }
                   }
                   
                   if (mounted) {
                     setState(() {});
                   }
                },
                background: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [AppTheme.completedColor, Colors.transparent],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    )
                  ),
                  alignment: Alignment.centerLeft,
                  padding: const EdgeInsets.only(left: 32),
                  child: Text('COMPLETED', style: GoogleFonts.spaceGrotesk(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 16, letterSpacing: 2)),
                ),
                child: TaskCardWidget(task: task, isCompleted: false, currentPath: GoRouterState.of(context).uri.path),
              );
            }
          ),
        ],
      ),
    );
  }

  Widget _buildCompletedList(BuildContext context, List<PlannerEvent> tasks) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white24, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Center(
              child: Text('COMPLETED', style: GoogleFonts.spaceGrotesk(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
            ),
          ),
          const Divider(height: 1, color: Colors.white10),
          ListView.separated(
            padding: EdgeInsets.zero,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: tasks.length,
            separatorBuilder: (context, index) => const Divider(height: 1, color: Colors.white10, indent: 70),
            itemBuilder: (context, index) {
              final task = tasks[index];
              return TaskCardWidget(task: task, isCompleted: true, currentPath: GoRouterState.of(context).uri.path);
            }
          ),
        ],
      ),
    );
  }

}


class TaskCardWidget extends ConsumerStatefulWidget {
  final PlannerEvent task;
  final bool isCompleted;
  final String currentPath;
  const TaskCardWidget({super.key, required this.task, required this.isCompleted, required this.currentPath});

  @override
  ConsumerState<TaskCardWidget> createState() => _TaskCardWidgetState();
}

class _TaskCardWidgetState extends ConsumerState<TaskCardWidget> {
  List<Question> questions = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadQuestions();
  }
  
  @override
  void didUpdateWidget(TaskCardWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.task.questionIds != widget.task.questionIds) {
      _loadQuestions();
    }
  }

  Future<void> _loadQuestions() async {
    final ids = widget.task.questionIds;
    if (ids == null || ids.isEmpty) {
      if (mounted) {
        setState(() {
          questions = [];
          isLoading = false;
        });
      }
      return;
    }
    
    final repo = ref.read(questionRepositoryProvider);
    final futures = ids.map((id) => repo.getQuestion(id));
    final results = await Future.wait(futures);
    
    if (mounted) {
      setState(() {
        questions = results.whereType<Question>().toList();
        isLoading = false;
      });
    }
  }


  String _cleanTitle(String title) {
    return title.replaceAll(RegExp(r'[★☆]'), '').trim();
  }

  @override
  Widget build(BuildContext context) {
    final task = widget.task;
    final isCompleted = widget.isCompleted;
    final now = DateTime.now();
    final isActive = !isCompleted && now.isAfter(task.startTime) && now.isBefore(task.endTime);

    return InkWell(
      onLongPress: () {
        HapticFeedback.heavyImpact();
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (_) => TaskActionSheet(
            event: task, 
            currentPath: widget.currentPath,
          ),
        );
      },
      onSecondaryTap: () {
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (_) => TaskActionSheet(
            event: task, 
            currentPath: widget.currentPath,
          ),
        );
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Time Column
          SizedBox(
            width: 85,
            child: isCompleted 
              ? Center(
                  child: Text(
                    DateFormat('h:mm a').format(task.startTime),
                    style: GoogleFonts.jetBrainsMono(color: Colors.white30, fontSize: 13, fontWeight: FontWeight.w700)
                  ),
                )
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      DateFormat('h:mm a').format(task.startTime),
                      style: GoogleFonts.jetBrainsMono(color: isActive ? Colors.white : Colors.white70, fontSize: 13, fontWeight: FontWeight.w700)
                    ),
                    AnimatedSize(
                      duration: const Duration(milliseconds: 500),
                      curve: Curves.easeOutBack,
                      child: isActive 
                        ? Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8.0),
                            child: AnimatedClockIcon(startTime: task.startTime, endTime: task.endTime),
                          )
                        : const SizedBox(height: 4),
                    ),
                    Text(
                      DateFormat('h:mm a').format(task.endTime),
                      style: GoogleFonts.jetBrainsMono(color: isActive ? Colors.white70 : Colors.white54, fontSize: 13, fontWeight: FontWeight.w700)
                    ),
                  ],
                ),
          ),
          
          Container(
            width: 1.5,
            height: isCompleted ? 20 : 40,
            margin: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: isActive ? Colors.white : Colors.white10,
              borderRadius: BorderRadius.circular(2)
            ),
          ),
          
          // Task Title Column
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Subject Name with underline
                Container(
                  padding: const EdgeInsets.only(bottom: 2),
                  decoration: BoxDecoration(
                    border: Border(bottom: BorderSide(color: isCompleted ? Colors.white10 : Colors.white24, width: 1.5))
                  ),
                  child: Text(
                    task.title.toUpperCase(),
                    style: GoogleFonts.spaceGrotesk(
                      color: isCompleted ? Colors.white30 : Colors.white54,
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.0,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                if (isLoading)
                   Text('Loading...', style: GoogleFonts.inter(color: Colors.white54, fontSize: 14, fontStyle: FontStyle.italic))
                else if (questions.isEmpty)
                   Text('No specific tasks.', style: GoogleFonts.inter(color: Colors.white54, fontSize: 14, fontStyle: FontStyle.italic))
                else
                   ...questions.map((q) {
                     return Padding(
                       padding: const EdgeInsets.only(bottom: 4),
                       child: Builder(
                         builder: (context) {
                           return InkWell(
                             onTap: () => context.push('/question/${q.id}'),
                             borderRadius: BorderRadius.circular(4),
                             child: Text(
                               _cleanTitle(q.title), 
                               style: GoogleFonts.inter(
                                 color: isCompleted ? Colors.white30 : Colors.white,
                                 fontSize: 14,
                                 fontWeight: isActive ? FontWeight.w800 : FontWeight.w600,
                                 height: 1.3,
                                 decoration: isCompleted ? TextDecoration.lineThrough : null,
                                 decorationColor: Colors.white30,
                               ),
                               maxLines: 2,
                               overflow: TextOverflow.ellipsis,
                             ),
                           );
                         }
                       ),
                     );
                   }),
              ],
            )
          ),
        ]
      )
    ));
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
      return const SizedBox.shrink(); // Use shrink to completely remove space when inactive
    }

    // Tick exactly every 15 minutes
    final int minutes = now.minute;
    final int quarter = minutes ~/ 15;
    final double angle = quarter * (3.141592653589793 / 2);

    return Container(
      width: 20,
      height: 20,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.white.withValues(alpha: 0.4),
            blurRadius: 8,
            spreadRadius: 2,
          )
        ]
      ),
      child: Transform.rotate(
        angle: angle,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Center dot
            Container(width: 4, height: 4, decoration: const BoxDecoration(color: Colors.black, shape: BoxShape.circle)),
            // Minute hand
            Align(
              alignment: Alignment.topCenter,
              child: Container(
                width: 2,
                height: 7,
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(1),
                ),
                margin: const EdgeInsets.only(top: 3),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
