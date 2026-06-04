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

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(() {
      final offset = _scrollController.offset;
      setState(() {
        _headerOpacity = (1 - (offset / 100)).clamp(0.0, 1.0);
      });
    });
  }

  @override
  void dispose() {
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
            final pendingTasks = events.where((e) => !e.isCompleted).toList()..sort((a, b) => a.startTime.compareTo(b.startTime));
            final completedTasks = events.where((e) => e.isCompleted).toList()..sort((a, b) => a.startTime.compareTo(b.startTime));

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
                          ? _buildTabletLayout(isar, pendingTasks, completedTasks, events.length, completedTasks.length)
                          : _buildPhoneLayout(isar, pendingTasks, completedTasks, events.length, completedTasks.length),
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
              _buildTodoList(pending, isar),
              if (completed.isNotEmpty) ...[
                const SizedBox(height: 32),
                const Text('COMPLETED', style: TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 2.0)),
                const SizedBox(height: 16),
                _buildCompletedList(completed, isar),
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
              const SizedBox(height: 48),
              const Text('SUBJECTS', style: TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 2.0)),
              const SizedBox(height: 16),
              _buildSubjectsGrid(isar, true),
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
        _buildTodoList(pending, isar),
        if (completed.isNotEmpty) ...[
          const SizedBox(height: 32),
          const Text('COMPLETED', style: TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 2.0)),
          const SizedBox(height: 16),
          _buildCompletedList(completed, isar),
        ],
        const SizedBox(height: 48),
        const Text('SUBJECTS', style: TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 2.0)),
        const SizedBox(height: 16),
        _buildSubjectsGrid(isar, false),
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
          border: Border.all(color: Colors.white10, style: BorderStyle.solid),
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Text('No pending tasks. You are clear.', textAlign: TextAlign.center, style: TextStyle(color: Colors.white30, fontWeight: FontWeight.w600)),
      );
    }
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: tasks.length,
      itemBuilder: (context, index) {
        final task = tasks[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Dismissible(
            key: ValueKey('task_${task.id}'),
            direction: DismissDirection.startToEnd,
            onDismissed: (_) async {
               await isar.writeTxn(() async {
                  task.isCompleted = true;
                  await isar.plannerEvents.put(task);
               });
            },
            background: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              alignment: Alignment.centerLeft,
              padding: const EdgeInsets.only(left: 24),
              child: const Icon(Icons.check, color: Colors.black, size: 28),
            ),
            child: _buildTaskCard(task, false),
          )
        );
      }
    );
  }

  Widget _buildCompletedList(List<PlannerEvent> tasks, Isar isar) {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: tasks.length,
      itemBuilder: (context, index) {
        final task = tasks[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _buildTaskCard(task, true),
        );
      }
    );
  }

  Widget _buildTaskCard(PlannerEvent task, bool isCompleted) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isCompleted ? Colors.transparent : Colors.white.withOpacity(0.05),
        border: isCompleted ? Border.all(color: Colors.white10) : null,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 40,
            decoration: BoxDecoration(
              color: isCompleted ? Colors.white24 : Colors.white,
              borderRadius: BorderRadius.circular(2)
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${DateFormat('h:mm a').format(task.startTime)} - ${DateFormat('h:mm a').format(task.endTime)}',
                  style: TextStyle(color: isCompleted ? Colors.white30 : Colors.white54, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1.0)
                ),
                const SizedBox(height: 6),
                Text(
                  task.title,
                  style: TextStyle(
                    color: isCompleted ? Colors.white54 : Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    decoration: isCompleted ? TextDecoration.lineThrough : null
                  ),
                )
              ]
            )
          ),
          if (isCompleted)
            const Icon(Icons.check_circle, color: Colors.white30, size: 20)
        ]
      )
    );
  }

  Widget _buildSubjectsGrid(Isar isar, bool isTablet) {
    return StreamBuilder<List<Course>>(
      stream: isar.courses.where().watch(fireImmediately: true),
      builder: (context, snapshot) {
        final courses = snapshot.data ?? [];
        
        courses.sort((a, b) {
          if (a.examDate == null && b.examDate == null) return 0;
          if (a.examDate == null) return 1;
          if (b.examDate == null) return -1;
          return a.examDate!.compareTo(b.examDate!);
        });

        int columns = 1;
        if (isTablet) {
          columns = 2; // Fixed to 2 on tablet sidebar
        } else {
          final double width = MediaQuery.of(context).size.width;
          if (width > 600) columns = 2;
        }

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            mainAxisExtent: 95,
          ),
          itemCount: courses.length + 1,
          itemBuilder: (context, index) {
            if (index == courses.length) return _buildAddCourseCard(context);
            return _SubjectCard(course: courses[index], isar: isar);
          },
        );
      }
    );
  }

  Widget _buildAddCourseCard(BuildContext context) {
    return GestureDetector(
      onTap: () => _showAddCourseDialog(context, ref),
      child: Container(
        height: 95,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(AppTheme.cardRadius),
          border: Border.all(color: Colors.white24, width: 1),
        ),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add, size: 28, color: Colors.white54),
            SizedBox(height: 8),
            Text('Add Subject', style: TextStyle(color: Colors.white54, fontWeight: FontWeight.w600, fontSize: 13)),
          ],
        ),
      ),
    );
  }

  void _showAddCourseDialog(BuildContext context, WidgetRef ref) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      useRootNavigator: false,
      builder: (context) => Dialog(
        backgroundColor: AppTheme.black,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: const BorderSide(color: Colors.white10, width: 1),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('INITIALIZE SUBJECT', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Colors.white54, letterSpacing: 2.0)),
              const SizedBox(height: 16),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white10),
                ),
                child: TextField(
                  controller: controller,
                  autofocus: true,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.white),
                  decoration: const InputDecoration(
                    hintText: 'e.g. Quantum Physics',
                    hintStyle: TextStyle(color: Colors.white24, fontSize: 16),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.all(16),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context), 
                    child: const Text('CANCEL', style: TextStyle(color: Colors.white54, fontWeight: FontWeight.w800, letterSpacing: 1.0))
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () async {
                      if (controller.text.isNotEmpty) {
                        final repo = await ref.read(courseRepositoryProvider.future);
                        await repo.createCourse(controller.text);
                        if (context.mounted) Navigator.pop(context);
                      }
                    },
                    child: const Text('INITIALIZE', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.0)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SubjectCard extends StatelessWidget {
  final Course course;
  final Isar isar;

  const _SubjectCard({required this.course, required this.isar});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Question>>(
      stream: isar.questions.where().filter().courseIdEqualTo(course.id).watch(fireImmediately: true),
      builder: (context, snapshot) {
        final questions = snapshot.data ?? [];
        final completed = questions.where((q) => q.status == QuestionStatus.completed).length;
        final progress = questions.isEmpty ? 0.0 : completed / questions.length;
        final int percent = (progress * 100).toInt();

        // Calculate days left
        String daysLeftText = '';
        Color daysLeftColor = AppTheme.textSecondary;
        bool isUrgent = false;

        if (course.examDate != null) {
          final now = DateTime.now();
          final startOfToday = DateTime(now.year, now.month, now.day);
          final examDay = DateTime(course.examDate!.year, course.examDate!.month, course.examDate!.day);
          final days = examDay.difference(startOfToday).inDays;

          if (days < 0) {
            daysLeftText = 'Passed';
          } else if (days == 0) {
            daysLeftText = 'Today';
            daysLeftColor = AppTheme.urgentColor;
            isUrgent = true;
          } else {
            daysLeftText = '$days ${days == 1 ? 'day' : 'days'} left';
            if (days <= 7) {
              daysLeftColor = Colors.white;
              isUrgent = true;
            } else {
              daysLeftColor = Colors.white70;
            }
          }
        } else {
          daysLeftText = 'No date set';
        }

        return GestureDetector(
          onTap: () => context.push('/course/${course.id}'),
          child: Container(
            height: 95,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            decoration: BoxDecoration(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(AppTheme.cardRadius),
              border: Border.all(color: Colors.white24, width: 1),
            ),
            child: Row(
              children: [
                // Circular Progress
                SizedBox(
                  width: 42,
                  height: 42,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      CircularProgressIndicator(
                        value: progress,
                        strokeWidth: 4,
                        backgroundColor: Colors.white10,
                        color: progress == 1.0 ? Colors.white : Colors.white,
                        strokeCap: StrokeCap.round,
                      ),
                      Text(
                        '$percent%',
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 14),
                // Details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        course.name,
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.textPrimary, letterSpacing: -0.2),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: daysLeftColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              daysLeftText.toUpperCase(),
                              style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: daysLeftColor, letterSpacing: 0.5),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '$completed/${questions.length}',
                            style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.arrow_forward_ios, size: 14, color: AppTheme.textSecondary),
              ],
            ),
          ),
        );
      },
    );
  }
}
