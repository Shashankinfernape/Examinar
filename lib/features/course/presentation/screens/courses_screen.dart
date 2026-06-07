import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../data/repositories/course_repository.dart';
import '../../data/repositories/question_repository.dart';
import '../../domain/models/course.dart';
import '../../domain/models/question.dart';
import 'package:exam_command_center/core/theme/app_theme.dart';
import '../../../../core/database/isar_provider.dart';
import 'package:isar/isar.dart';
import 'package:intl/intl.dart';

class CoursesScreen extends ConsumerWidget {
  const CoursesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final coursesAsync = ref.watch(courseRepositoryProvider);
    final isarAsync = ref.watch(isarProvider);
    final double screenWidth = MediaQuery.of(context).size.width;
    final bool isTablet = screenWidth > 720;
    final double hPad = isTablet ? 32.0 : 16.0;

    return Scaffold(
      backgroundColor: AppTheme.black,
      body: coursesAsync.when(
        data: (repo) => StreamBuilder<List<Course>>(
          stream: repo.isar.courses.where().watch(fireImmediately: true),
          builder: (context, snapshot) {
            final courses = snapshot.data ?? [];
            
            return CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                // ONE UI DYNAMIC HEADER
                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(hPad, 60, hPad, 24),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Subjects', style: GoogleFonts.spaceGrotesk(fontSize: 32, fontWeight: FontWeight.w800, color: AppTheme.textPrimary, letterSpacing: -1.5)),
                            Text('Manage your mission objectives', style: GoogleFonts.spaceGrotesk(color: AppTheme.textSecondary, fontSize: 16, fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                isarAsync.when(
                    data: (isar) => SliverPadding(
                      padding: EdgeInsets.symmetric(horizontal: hPad),
                      sliver: isTablet
                        ? SliverGrid(
                            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: (screenWidth ~/ 350).toInt().clamp(2, 6),
                              mainAxisSpacing: 16,
                              crossAxisSpacing: 16,
                              mainAxisExtent: 130, 
                            ),
                            delegate: SliverChildBuilderDelegate(
                              (context, index) {
                                if (index == courses.length) return _buildAddCourseCard(context, ref);
                                return _buildOneUICourseCard(context, ref, courses[index], isar);
                              },
                              childCount: courses.length + 1,
                            ),
                          )
                        : SliverList(
                            delegate: SliverChildBuilderDelegate(
                              (context, index) {
                                if (index == courses.length) return Padding(padding: const EdgeInsets.only(bottom: 12), child: _buildAddCourseCard(context, ref));
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: _buildOneUICourseCard(context, ref, courses[index], isar),
                                );
                              },
                              childCount: courses.length + 1,
                            ),
                          ),
                    ),
                    loading: () => const SliverFillRemaining(child: Center(child: CircularProgressIndicator())),
                    error: (e, s) => SliverFillRemaining(child: Center(child: Text('Error: $e'))),
                  ),
                
                const SliverToBoxAdapter(child: SizedBox(height: 120)),
              ],
            );
          },
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, s) => Center(child: Text('Error: $e')),
      ),
    );
  }

  Widget _buildOneUICourseCard(BuildContext context, WidgetRef ref, Course course, Isar isar) {
    return StreamBuilder<List<Question>>(
      stream: isar.questions.where().filter().courseIdEqualTo(course.id).watch(fireImmediately: true),
      builder: (context, qSnapshot) {
        final questions = qSnapshot.data ?? [];
        final completed = questions.where((q) => q.status == QuestionStatus.completed).length;
        final total = questions.length;
        final progress = total == 0 ? 0.0 : completed / total;

        return GestureDetector(
          onTap: () => context.push('/course/${course.id}'),
          onLongPress: () => _showCourseOptions(context, ref, course),
          onSecondaryTap: () => _showCourseOptions(context, ref, course),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.transparent, // Flat design
              borderRadius: BorderRadius.circular(AppTheme.cardRadius),
              border: Border.all(color: Colors.white24, width: 1.5),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        course.name,
                        style: GoogleFonts.spaceGrotesk(fontSize: 18, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: -0.5),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.white54),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  course.examDate != null 
                    ? 'Target Date: ${DateFormat('MMM dd, yyyy').format(course.examDate!)}' 
                    : 'Target date unassigned',
                  style: GoogleFonts.inter(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('${(progress * 100).toInt()}%', style: GoogleFonts.spaceGrotesk(fontSize: 13, fontWeight: FontWeight.w800, color: Colors.white)),
                    Text('$completed/$total', style: GoogleFonts.spaceGrotesk(fontSize: 13, color: Colors.white54, fontWeight: FontWeight.w800)),
                  ],
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 5,
                    backgroundColor: Colors.white10,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildAddCourseCard(BuildContext context, WidgetRef ref) {
    return GestureDetector(
      onTap: () => _showAddCourseDialog(context, ref),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(AppTheme.cardRadius),
          border: Border.all(color: Colors.white24, width: 1.5),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.add, size: 28, color: Colors.white54),
            const SizedBox(height: 8),
            Text('Add Subject', style: GoogleFonts.spaceGrotesk(color: Colors.white54, fontWeight: FontWeight.w800, fontSize: 16, letterSpacing: -0.5)),
          ],
        ),
      ),
    );
  }

  void _showCourseOptions(BuildContext context, WidgetRef ref, Course course) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: AppTheme.sidebarSurface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(course.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 24),
              _optionItem(Icons.edit_note_outlined, 'Update Objective', () {
                Navigator.pop(context);
                _showAddCourseDialog(context, ref, existingCourse: course);
              }),
              _optionItem(Icons.delete_sweep_outlined, 'Purge Subject', () {
                Navigator.pop(context);
                _confirmDelete(context, ref, course);
              }, isDestructive: true),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _optionItem(IconData icon, String label, VoidCallback onTap, {bool isDestructive = false}) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
      leading: Icon(icon, color: isDestructive ? AppTheme.urgentColor : AppTheme.textPrimary, size: 24),
      title: Text(label, style: TextStyle(color: isDestructive ? AppTheme.urgentColor : AppTheme.textPrimary, fontWeight: FontWeight.w700, fontSize: 16)),
      onTap: onTap,
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref, Course course) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.cardSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Confirm Purge', style: TextStyle(fontSize: 18)),
        content: Text('Are you sure you want to permanently delete "${course.name}"?', style: const TextStyle(fontSize: 14)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Abort')),
          TextButton(
            onPressed: () async {
              final repo = await ref.read(courseRepositoryProvider.future);
              await repo.deleteCourse(course.id);
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('Execute', style: TextStyle(color: AppTheme.urgentColor, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showAddCourseDialog(BuildContext context, WidgetRef ref, {Course? existingCourse}) {
    final controller = TextEditingController(text: existingCourse?.name ?? '');
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
              Text(existingCourse == null ? 'INITIALIZE SUBJECT' : 'UPDATE SUBJECT', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 2.0)),
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
                        if (existingCourse == null) {
                          await repo.createCourse(controller.text);
                        } else {
                          await repo.isar.writeTxn(() async {
                            existingCourse.name = controller.text;
                            await repo.isar.courses.put(existingCourse);
                          });
                        }
                        if (context.mounted) Navigator.pop(context);
                      }
                    },
                    child: Text(existingCourse == null ? 'INITIALIZE' : 'UPDATE', style: const TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.0)),
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
