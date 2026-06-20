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
                      AnimatedBuilder(
                        animation: _tabController.animation!,
                        builder: (context, _) {
                          final double value = _tabController.animation!.value;
                          final double alignX = (value * 2) - 1.0;
                          final int selectedIndex = value.round();

                          return Container(
                            height: 48,
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(100),
                            ),
                            child: Stack(
                              children: [
                                // Sliding Thumb
                                Align(
                                  alignment: Alignment(alignX, 0.0),
                                  child: FractionallySizedBox(
                                    widthFactor: 0.5,
                                    heightFactor: 1.0,
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(0.2),
                                        borderRadius: BorderRadius.circular(100),
                                      ),
                                    ),
                                  ),
                                ),
                                // Segments
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    _buildCustomTab(
                                      label: 'CHECKLIST',
                                      isSelected: selectedIndex == 0,
                                      onTap: () => _tabController.animateTo(0, duration: const Duration(milliseconds: 300), curve: Curves.easeOutCubic),
                                    ),
                                    _buildCustomTab(
                                      label: 'READINESS',
                                      isSelected: selectedIndex == 1,
                                      onTap: () => _tabController.animateTo(1, duration: const Duration(milliseconds: 300), curve: Curves.easeOutCubic),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
                
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      // Checklist Tab (Modern Flat UI)
                      _KeepAliveTab(child: _buildChecklistTab(course, hPad)),

                      // Readiness Tab (Premium Design)
                      _KeepAliveTab(child: _CourseReadinessView(course: course, hPad: hPad)),
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

  Widget _buildCustomTab({required String label, required bool isSelected, required VoidCallback onTap}) {
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          color: Colors.transparent,
          child: Center(
            child: Text(
              label,
              style: GoogleFonts.spaceGrotesk(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                color: isSelected ? Colors.white : Colors.white54,
                letterSpacing: 1.5,
              ),
            ),
          ),
        ),
      ),
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

class _CourseReadinessView extends ConsumerStatefulWidget {
  final Course course;
  final double hPad;
  const _CourseReadinessView({required this.course, required this.hPad});

  @override
  ConsumerState<_CourseReadinessView> createState() => _CourseReadinessViewState();
}

class _CourseReadinessViewState extends ConsumerState<_CourseReadinessView> {
  int _selectedTab = 0; // 0: Secured, 1: Revise, 2: Pending

  String _getGrade(double progress) {
    int p = (progress * 100).toInt();
    if (p >= 90) return 'O';
    if (p >= 80) return 'A+';
    if (p >= 70) return 'A';
    if (p >= 60) return 'B+';
    if (p >= 50) return 'B';
    if (p >= 40) return 'C';
    if (p >= 30) return 'D';
    return 'F';
  }

  Color _getGradeColor(String grade) {
    if (grade == 'O' || grade == 'A+') return AppTheme.completedColor; 
    if (grade == 'A' || grade == 'B+') return AppTheme.samsungBlue; 
    if (grade == 'B' || grade == 'C') return AppTheme.inProgressColor; 
    return AppTheme.urgentColor; 
  }

  Widget _buildCustomSegment({
    required String label,
    required String count,
    required bool isSelected,
    required Color activeColor,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          color: Colors.transparent,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                count,
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 16, 
                  fontWeight: FontWeight.w900, 
                  color: isSelected ? activeColor : Colors.white54,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: isSelected ? Colors.white : AppTheme.textSecondary,
                  letterSpacing: 1.0,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final qRepoAsync = ref.watch(questionRepositoryProvider);

    return qRepoAsync.when(
      data: (qRepo) => StreamBuilder<List<Question>>(
        stream: qRepo.isar.questions.where().filter().courseIdEqualTo(widget.course.id).watch(fireImmediately: true),
        builder: (context, snapshot) {
          final questions = snapshot.data ?? [];
          if (questions.isEmpty) return const Center(child: Text('Initialize targets to view readiness.', style: TextStyle(color: AppTheme.textSecondary, fontSize: 14)));

          final securedList = questions.where((q) => q.status == QuestionStatus.completed).toList();
          final reviseList = questions.where((q) => q.status == QuestionStatus.revisionNeeded).toList();
          final pendingList = questions.where((q) => q.status == QuestionStatus.incomplete).toList();
          
          final completedCount = securedList.length;
          final progress = questions.isEmpty ? 0.0 : completedCount / questions.length;
          final grade = _getGrade(progress);
          final gradeColor = _getGradeColor(grade);

          List<Question> displayedQuestions = [];
          if (_selectedTab == 0) displayedQuestions = securedList;
          else if (_selectedTab == 1) displayedQuestions = reviseList;
          else if (_selectedTab == 2) displayedQuestions = pendingList;

          return CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(widget.hPad, 16, widget.hPad, 16),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
                    decoration: BoxDecoration(
                      color: AppTheme.black,
                      borderRadius: BorderRadius.circular(32),
                      border: Border.all(color: Colors.white.withOpacity(0.03), width: 1),
                      boxShadow: [
                        BoxShadow(color: gradeColor.withOpacity(0.05), blurRadius: 40, spreadRadius: 0)
                      ]
                    ),
                    child: Column(
                      children: [
                        const Text('SUBJECT READINESS', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 3.0)),
                        const SizedBox(height: 32),
                        SizedBox(
                          width: 180,
                          height: 180,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              Container(
                                width: 180, height: 180,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  boxShadow: [BoxShadow(color: gradeColor.withOpacity(0.15), blurRadius: 30, spreadRadius: -5)]
                                )
                              ),
                              SizedBox.expand(
                                child: CircularProgressIndicator(
                                  value: progress,
                                  strokeWidth: 12,
                                  backgroundColor: Colors.black.withOpacity(0.3),
                                  color: gradeColor,
                                  strokeCap: StrokeCap.round,
                                ),
                              ),
                              Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    grade,
                                    style: GoogleFonts.rubikMonoOne(
                                      fontSize: 64, 
                                      color: gradeColor,
                                      height: 1.1,
                                      shadows: [Shadow(color: gradeColor.withOpacity(0.5), blurRadius: 20)]
                                    ),
                                  ),
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment: CrossAxisAlignment.baseline,
                                    textBaseline: TextBaseline.alphabetic,
                                    children: [
                                      Text('${(progress * 100).toInt()}', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: AppTheme.textPrimary)),
                                      const Text('%', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Colors.white54)),
                                    ],
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              
              // Interactive Tabs
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: widget.hPad),
                  child: Container(
                    height: 56, // Fixed height for iOS picker
                    decoration: BoxDecoration(
                      color: AppTheme.black, // OLED black background
                      borderRadius: BorderRadius.circular(100), // Pill shape
                      border: Border.all(color: Colors.white.withOpacity(0.05)),
                    ),
                    child: Stack(
                      children: [
                        // Sliding Thumb
                        AnimatedAlign(
                          alignment: Alignment(
                            _selectedTab == 0 ? -1.0 : (_selectedTab == 1 ? 0.0 : 1.0),
                            0.0,
                          ),
                          duration: const Duration(milliseconds: 250),
                          curve: Curves.easeOutCubic,
                          child: FractionallySizedBox(
                            widthFactor: 1.0 / 3.0,
                            heightFactor: 1.0,
                            child: Padding(
                              padding: const EdgeInsets.all(4.0),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: _selectedTab == 0 
                                      ? AppTheme.completedColor.withOpacity(0.15) 
                                      : (_selectedTab == 1 ? AppTheme.inProgressColor.withOpacity(0.15) : Colors.white.withOpacity(0.1)),
                                  borderRadius: BorderRadius.circular(100),
                                ),
                              ),
                            ),
                          ),
                        ),
                        // Segments
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _buildCustomSegment(
                              label: 'SECURED',
                              count: '${securedList.length}',
                              isSelected: _selectedTab == 0,
                              activeColor: AppTheme.completedColor,
                              onTap: () => setState(() => _selectedTab = 0),
                            ),
                            _buildCustomSegment(
                              label: 'REVISE',
                              count: '${reviseList.length}',
                              isSelected: _selectedTab == 1,
                              activeColor: AppTheme.inProgressColor,
                              onTap: () => setState(() => _selectedTab = 1),
                            ),
                            _buildCustomSegment(
                              label: 'PENDING',
                              count: '${pendingList.length}',
                              isSelected: _selectedTab == 2,
                              activeColor: Colors.white,
                              onTap: () => setState(() => _selectedTab = 2),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              
              const SliverToBoxAdapter(child: SizedBox(height: 24)),
              
              // Question List
              SliverPadding(
                padding: EdgeInsets.fromLTRB(widget.hPad, 0, widget.hPad, 120),
                sliver: displayedQuestions.isEmpty 
                  ? const SliverToBoxAdapter(
                      child: Center(
                        child: Padding(
                          padding: EdgeInsets.all(32.0),
                          child: Text('No targets in this category.', style: TextStyle(color: Colors.white30, fontSize: 14)),
                        )
                      )
                    )
                  : SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final q = displayedQuestions[index];
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8.0),
                            child: _QuestionItemTile(q: q), // Assume a simple tile
                          );
                        },
                        childCount: displayedQuestions.length,
                      ),
                    ),
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

class _QuestionItemTile extends StatelessWidget {
  final Question q;
  const _QuestionItemTile({required this.q});

  @override
  Widget build(BuildContext context) {
    Color statusColor = AppTheme.textSecondary;
    IconData icon = Icons.circle_outlined;
    if (q.status == QuestionStatus.completed) {
      statusColor = AppTheme.completedColor;
      icon = Icons.check_circle;
    } else if (q.status == QuestionStatus.revisionNeeded) {
      statusColor = AppTheme.inProgressColor;
      icon = Icons.change_circle;
    }

    return InkWell(
      onTap: () => context.push('/question/${q.id}'),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.black,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.05)),
        ),
        child: Row(
          children: [
            Icon(icon, color: statusColor, size: 20),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                q.title.replaceAll(RegExp(r'[★☆]'), '').trim(),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14, fontWeight: FontWeight.w600),
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.white24, size: 20),
          ],
        ),
      ),
    );
  }
}


class _KeepAliveTab extends StatefulWidget {
  final Widget child;
  const _KeepAliveTab({required this.child});

  @override
  State<_KeepAliveTab> createState() => _KeepAliveTabState();
}

class _KeepAliveTabState extends State<_KeepAliveTab> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}
