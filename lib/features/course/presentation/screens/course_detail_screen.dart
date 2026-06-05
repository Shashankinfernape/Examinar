import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:isar/isar.dart';
import '../../data/repositories/course_repository.dart';
import '../../data/repositories/question_repository.dart';
import '../../domain/models/course.dart';
import '../../domain/models/unit.dart';
import '../../domain/models/question.dart';
import 'package:exam_command_center/core/theme/app_theme.dart';
import '../widgets/unit_detail_sheet.dart';
import '../widgets/difficulty_stars.dart';
import '../widgets/paste_build_sheet.dart';

class CourseDetailScreen extends ConsumerStatefulWidget {
  final int courseId;

  const CourseDetailScreen({super.key, required this.courseId});

  @override
  ConsumerState<CourseDetailScreen> createState() => _CourseDetailScreenState();
}

class _CourseDetailScreenState extends ConsumerState<CourseDetailScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this); // Reduced to 2 tabs
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final repoAsync = ref.watch(courseRepositoryProvider);
    final double screenWidth = MediaQuery.of(context).size.width;
    final bool isTablet = screenWidth > 900;
    final double hPad = isTablet ? 32.0 : 16.0;

    return repoAsync.when(
      data: (repo) => StreamBuilder<Course?>(
        stream: repo.isar.courses.watchObject(widget.courseId, fireImmediately: true),
        builder: (context, snapshot) {
          final course = snapshot.data;
          if (course == null) return const Scaffold(body: Center(child: Text('Subject not found')));

          return Scaffold(
            backgroundColor: AppTheme.black,
            body: Column(
              children: [
                Padding(
                  padding: EdgeInsets.fromLTRB(hPad, 60, hPad, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          GestureDetector(
                            onTap: () => Navigator.pop(context),
                            child: const Icon(Icons.arrow_back_ios_new, size: 24, color: AppTheme.textPrimary),
                          ),
                          const Text('QUESTION SPACE', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w900, letterSpacing: 4.0)),
                          IconButton(
                            icon: const Icon(Icons.auto_awesome, size: 28, color: Colors.white),
                            onPressed: () {
                              showDialog(
                                context: context,
                                useRootNavigator: false,
                                builder: (context) => Dialog(
                                  backgroundColor: Colors.transparent,
                                  insetPadding: const EdgeInsets.all(16),
                                  child: PasteBuildSheet(course: course),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        course.name,
                        style: GoogleFonts.spaceGrotesk(fontSize: 28, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: -0.5),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 2,
                      ),
                      const SizedBox(height: 16),
                      Container(
                        height: 48,
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: TabBar(
                          controller: _tabController,
                          indicator: BoxDecoration(
                            borderRadius: BorderRadius.circular(24),
                            color: AppTheme.cardSurface,
                            boxShadow: [
                              BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 4, offset: const Offset(0, 2)),
                            ],
                          ),
                          labelColor: Colors.white,
                          unselectedLabelColor: AppTheme.textSecondary,
                          labelStyle: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.w800, fontSize: 13, letterSpacing: 1.5),
                          unselectedLabelStyle: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.w600, fontSize: 13, letterSpacing: 1.5),
                          dividerColor: Colors.transparent,
                          indicatorSize: TabBarIndicatorSize.tab,
                          tabs: const [
                            Tab(text: 'CHECKLIST'),
                            Tab(text: 'READINESS'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      // Checklist Tab (Modern Flat UI)
                      _buildChecklistTab(course, hPad),

                      // Readiness Tab (Premium Design)
                      _CourseReadinessView(course: course, hPad: hPad),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, s) => Scaffold(body: Center(child: Text('Error: $e'))),
    );
  }

  Widget _buildChecklistTab(Course course, double hPad) {
    if (course.units.isEmpty) {
      return SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.fromLTRB(hPad, 16, hPad, 100),
          child: PasteBuildSheet(course: course, isEmbedded: true),
        ),
      );
    }
    return ListView.builder(
      padding: EdgeInsets.fromLTRB(hPad, 16, hPad, 120),
      itemCount: course.units.length,
      itemBuilder: (context, index) {
        final unit = course.units.elementAt(index);
        return _FlatUnitSection(unit: unit);
      },
    );
  }
}

class _FlatUnitSection extends ConsumerWidget {
  final Unit unit;
  const _FlatUnitSection({required this.unit});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repoAsync = ref.watch(questionRepositoryProvider);
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(unit.name.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: Colors.white70, letterSpacing: 1.5)),
              IconButton(
                icon: const Icon(Icons.edit_note, size: 20, color: AppTheme.textSecondary),
                onPressed: () {
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (context) => UnitDetailSheet(unit: unit),
                  ).then((_) => ref.invalidate(courseRepositoryProvider));
                },
              ),
            ],
          ),
          const SizedBox(height: 8),
          repoAsync.when(
            data: (repo) => StreamBuilder<List<Question>>(
              stream: repo.isar.questions.where().filter().unitIdEqualTo(unit.id).watch(fireImmediately: true),
              builder: (context, snapshot) {
                final questions = snapshot.data ?? [];
                if (questions.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8.0),
                    child: Text('No active tasks.', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                  );
                }
                List<Widget> children = [];
                if (unit.name == 'Part A') {
                  String currentPrefix = "";
                  for (final q in questions) {
                    final match = RegExp(r'^\[(Unit \d+)\]').firstMatch(q.title);
                    if (match != null) {
                      final prefix = match.group(1)!;
                      if (prefix != currentPrefix) {
                        bool isFirst = currentPrefix.isEmpty;
                        currentPrefix = prefix;
                        children.add(
                          Padding(
                            padding: EdgeInsets.only(top: isFirst ? 0.0 : 16.0, bottom: 8.0),
                            child: Row(
                              children: [
                                const Expanded(child: Divider(color: Colors.white10)),
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 12.0),
                                  child: Text(prefix.toUpperCase(), style: const TextStyle(color: Colors.white30, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 2.0)),
                                ),
                                const Expanded(child: Divider(color: Colors.white10)),
                              ],
                            ),
                          )
                        );
                      }
                    }
                    children.add(_FlatQuestionTile(q: q));
                  }
                } else {
                  children = questions.map((q) => _FlatQuestionTile(q: q)).toList();
                }

                return Container(
                  decoration: BoxDecoration(
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    children: children,
                  ),
                );
              },
            ),
            loading: () => const SizedBox(),
            error: (e, s) => Text('Error: $e'),
          ),
          const SizedBox(height: 16),
          const Divider(color: Colors.white10, height: 1),
        ],
      ),
    );
  }
}

class _FlatQuestionTile extends StatelessWidget {
  final Question q;
  const _FlatQuestionTile({required this.q});

  @override
  Widget build(BuildContext context) {
    final bool isDone = q.status == QuestionStatus.completed;
    
    // Clean prefix for display
    String displayTitle = q.title;
    if (displayTitle.startsWith(RegExp(r'^\[Unit \d+\]'))) {
      displayTitle = displayTitle.replaceFirst(RegExp(r'^\[Unit \d+\]\s*'), '');
    }

    return InkWell(
      onTap: () => context.push('/question/${q.id}'),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Expanded(
              child: Text(
                displayTitle, 
                style: TextStyle(
                  fontSize: 15, 
                  color: isDone ? AppTheme.textSecondary : Colors.white, 
                  fontWeight: FontWeight.w500, 
                  height: 1.3,
                  decoration: isDone ? TextDecoration.lineThrough : null
                )
              )
            ),
            DifficultyStars(question: q, size: 10),
            const SizedBox(width: 16),
            Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isDone ? AppTheme.completedColor : Colors.transparent,
                border: Border.all(
                  color: isDone ? AppTheme.completedColor : (q.status == QuestionStatus.revisionNeeded ? AppTheme.inProgressColor : Colors.white24),
                  width: 1.5,
                ),
              ),
              child: isDone ? const Icon(Icons.check, size: 12, color: Colors.black) : null,
            ),
          ],
        ),
      ),
    );
  }
}

class _CourseReadinessView extends ConsumerWidget {
  final Course course;
  final double hPad;
  const _CourseReadinessView({required this.course, required this.hPad});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final qRepoAsync = ref.watch(questionRepositoryProvider);

    return qRepoAsync.when(
      data: (qRepo) => StreamBuilder<List<Question>>(
        stream: qRepo.isar.questions.where().filter().courseIdEqualTo(course.id).watch(fireImmediately: true),
        builder: (context, snapshot) {
          final questions = snapshot.data ?? [];
          if (questions.isEmpty) return const Center(child: Text('Initialize targets to view readiness.', style: TextStyle(color: AppTheme.textSecondary, fontSize: 14)));

          final completed = questions.where((q) => q.status == QuestionStatus.completed).length;
          final revisionNeeded = questions.where((q) => q.status == QuestionStatus.revisionNeeded).length;
          final incomplete = questions.where((q) => q.status == QuestionStatus.incomplete).length;
          final progress = questions.isEmpty ? 0.0 : completed / questions.length;

          return ListView(
            padding: EdgeInsets.all(hPad),
            children: [
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppTheme.cardSurface,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: Colors.white.withOpacity(0.05), width: 1),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('OVERALL READINESS', style: TextStyle(color: AppTheme.textSecondary, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 2.0)),
                    const SizedBox(height: 8),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('${(progress * 100).toInt()}', style: const TextStyle(fontSize: 56, fontWeight: FontWeight.w900, color: AppTheme.textPrimary, height: 1.0)),
                        const Padding(
                          padding: EdgeInsets.only(bottom: 8.0, left: 4.0),
                          child: Text('%', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: Colors.white54)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 12,
                        backgroundColor: AppTheme.selectedTile,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(child: _PremiumStatCard(label: 'SECURED', value: '$completed', color: AppTheme.completedColor)),
                  const SizedBox(width: 16),
                  Expanded(child: _PremiumStatCard(label: 'REVISE', value: '$revisionNeeded', color: AppTheme.inProgressColor)),
                  const SizedBox(width: 16),
                  Expanded(child: _PremiumStatCard(label: 'PENDING', value: '$incomplete', color: AppTheme.textSecondary)),
                ],
              ),
            ],
          );
        },
      ),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, s) => Center(child: Text('Error: $e')),
    );
  }
}

class _PremiumStatCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _PremiumStatCard({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20),
      decoration: BoxDecoration(
        color: AppTheme.cardSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.05), width: 1),
      ),
      child: Column(
        children: [
          Text(value, style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: color)),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: AppTheme.textSecondary, letterSpacing: 1.5)),
        ],
      ),
    );
  }
}
