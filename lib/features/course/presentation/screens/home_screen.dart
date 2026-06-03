import 'dart:math' as math;
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
      setState(() {
        _headerOpacity = (1 - (_scrollController.offset / 100)).clamp(0.0, 1.0);
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final isarAsync = ref.watch(isarProvider);
    final double screenWidth = MediaQuery.of(context).size.width;
    final bool isTablet = screenWidth > 720;
    
    final double hPad = isTablet ? 32.0 : 16.0;

    return Scaffold(
      backgroundColor: AppTheme.black,
      body: isarAsync.when(
        data: (isar) => StreamBuilder<void>(
          stream: isar.courses.watchLazy(fireImmediately: true),
          builder: (context, _) => CustomScrollView(
            controller: _scrollController,
            physics: const BouncingScrollPhysics(),
            slivers: [
              // ONE UI HEADER
              SliverToBoxAdapter(
                child: Opacity(
                  opacity: _headerOpacity,
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(hPad, 60, hPad, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          DateFormat('EEEE, MMMM d').format(DateTime.now()),
                          style: const TextStyle(fontSize: 14, color: Colors.white, fontWeight: FontWeight.w800, letterSpacing: 1.0),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Your Subjects',
                          style: Theme.of(context).textTheme.displayLarge,
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // SUBJECTS LIST (SORTED BY EXAM DATE)
              SliverPadding(
                padding: EdgeInsets.symmetric(horizontal: hPad),
                sliver: _buildSubjectsList(isar, isTablet),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 120)),
            ],
          ),
        ),
        loading: () => const SizedBox.shrink(),
        error: (e, s) => Center(child: Text('Error: $e')),
      ),
    );
  }

  Widget _buildSubjectsList(Isar isar, bool isTablet) {
    return FutureBuilder<List<Course>>(
      future: isar.courses.where().findAll(),
      builder: (context, snapshot) {
        final courses = snapshot.data ?? [];
        if (courses.isEmpty) {
          return const SliverFillRemaining(
            child: Center(
              child: Text(
                'No subjects added yet.', 
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 16)
              )
            ),
          );
        }

        // Sort by exam date. Null dates go to the bottom.
        courses.sort((a, b) {
          if (a.examDate == null && b.examDate == null) return 0;
          if (a.examDate == null) return 1;
          if (b.examDate == null) return -1;
          return a.examDate!.compareTo(b.examDate!);
        });

        return SliverLayoutBuilder(
          builder: (context, constraints) {
            final double maxWidth = constraints.crossAxisExtent;
            if (maxWidth >= 650) {
              final int columns = (maxWidth ~/ 350).toInt().clamp(2, 6);
              return SliverGrid(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: columns,
                  mainAxisSpacing: 16,
                  crossAxisSpacing: 16,
                  mainAxisExtent: 95, // Compact height constraint
                ),
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    if (index == courses.length) return _buildAddCourseCard(context);
                    return _SubjectCard(course: courses[index], isar: isar);
                  },
                  childCount: courses.length + 1,
                ),
              );
            } else {
              return SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    if (index == courses.length) return Padding(padding: const EdgeInsets.only(bottom: 8.0), child: _buildAddCourseCard(context));
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8.0),
                      child: _SubjectCard(course: courses[index], isar: isar),
                    );
                  },
                  childCount: courses.length + 1,
                ),
              );
            }
          },
        );
      },
    );
  }

  Widget _buildAddCourseCard(BuildContext context) {
    return GestureDetector(
      onTap: () => _showAddCourseDialog(context, ref),
      child: Container(
        height: 100,
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
            height: 100,
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
