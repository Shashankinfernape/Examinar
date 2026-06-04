import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:isar/isar.dart';
import '../../data/repositories/course_repository.dart';
import '../../data/repositories/question_repository.dart';
import '../../domain/models/unit.dart';
import '../../domain/models/question.dart';
import '../widgets/unit_detail_sheet.dart';
import '../widgets/paste_build_sheet.dart';
import '../widgets/difficulty_stars.dart';

class UnitDetailsScreen extends ConsumerWidget {
  final int unitId;

  const UnitDetailsScreen({super.key, required this.unitId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repoAsync = ref.watch(courseRepositoryProvider);
    final qRepoAsync = ref.watch(questionRepositoryProvider);

    return repoAsync.when(
      data: (repo) => StreamBuilder<Unit?>(
        stream: repo.isar.units.watchObject(unitId, fireImmediately: true),
        builder: (context, snapshot) {
          final unit = snapshot.data;
          if (unit == null) return const Scaffold(body: Center(child: Text('Unit not found')));

          return Scaffold(
            appBar: AppBar(
              title: Text(unit.name),
              actions: [
                TextButton.icon(
                  onPressed: () {
                    showDialog(
                      context: context,
                      useRootNavigator: false,
                      builder: (context) => Dialog(
                        backgroundColor: Colors.transparent,
                        insetPadding: const EdgeInsets.all(16),
                        child: PasteBuildSheet(unit: unit),
                      ),
                    );
                  },
                  icon: const Icon(Icons.bolt, size: 20),
                  label: const Text('Paste & Build'),
                ),
                IconButton(
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: () {
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      builder: (context) => UnitDetailSheet(unit: unit),
                    );
                  },
                ),
              ],
            ),
            body: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Questions', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                      IconButton(
                        icon: const Icon(Icons.add_circle_outline, size: 20),
                        onPressed: () => _showAddQuestionDialog(context, ref, unit),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  qRepoAsync.when(
                    data: (qRepo) => StreamBuilder<List<Question>>(
                      stream: qRepo.isar.questions.where().filter().unitIdEqualTo(unit.id).watch(fireImmediately: true),
                      builder: (context, qSnapshot) {
                        final questions = qSnapshot.data ?? [];
                        if (questions.isEmpty) {
                          return const Center(
                            child: Padding(
                              padding: EdgeInsets.all(32.0),
                              child: Text('No questions yet.\nUse "Paste & Build" for fast entry!', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
                            ),
                          );
                        }
                        List<Widget> children = [];
                        
                        String currentPrefix = "";
                        for (final q in questions) {
                          String displayTitle = q.title;
                          
                          if (unit.name == 'Part A') {
                            final match = RegExp(r'^\[(Unit \d+)\]').firstMatch(q.title);
                            if (match != null) {
                              final prefix = match.group(1)!;
                              displayTitle = displayTitle.replaceFirst(RegExp(r'^\[Unit \d+\]\s*'), '');
                              
                              if (prefix != currentPrefix) {
                                currentPrefix = prefix;
                                children.add(
                                  Padding(
                                    padding: const EdgeInsets.only(top: 24.0, bottom: 12.0),
                                    child: Row(
                                      children: [
                                        const Expanded(child: Divider(color: Colors.white10)),
                                        Padding(
                                          padding: const EdgeInsets.symmetric(horizontal: 12.0),
                                          child: Text(prefix.toUpperCase(), style: const TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 2.0)),
                                        ),
                                        const Expanded(child: Divider(color: Colors.white10)),
                                      ],
                                    ),
                                  )
                                );
                              }
                            }
                          }
                          
                          children.add(
                            Card(
                              elevation: 0,
                              color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
                              margin: const EdgeInsets.only(bottom: 8),
                              child: ListTile(
                                leading: _buildStatusIcon(q.status),
                                title: Row(
                                  children: [
                                    Expanded(child: Text(displayTitle, style: const TextStyle(fontWeight: FontWeight.w500))),
                                    DifficultyStars(question: q, size: 14),
                                  ],
                                ),
                                subtitle: q.notes != null && q.notes!.isNotEmpty 
                                  ? Text(q.notes!, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12))
                                  : null,
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                                      onPressed: () => _confirmDeleteQuestion(context, ref, q),
                                    ),
                                    const Icon(Icons.chevron_right, size: 20),
                                  ],
                                ),
                                onTap: () => context.push('/question/${q.id}'),
                              ),
                            )
                          );
                        }

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: children,
                        );
                      },
                    ),
                    loading: () => const Center(child: CircularProgressIndicator()),
                    error: (e, s) => Text('Error loading questions: $e'),
                  ),
                ],
              ),
            ),
          );
        },
      ),
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, s) => Scaffold(body: Center(child: Text('Error: $e'))),
    );
  }

  Widget _buildStatusIcon(QuestionStatus status) {
    switch (status) {
      case QuestionStatus.completed:
        return const CircleAvatar(radius: 12, backgroundColor: Colors.green, child: Icon(Icons.check, size: 14, color: Colors.white));
      case QuestionStatus.revisionNeeded:
        return const CircleAvatar(radius: 12, backgroundColor: Colors.orange, child: Icon(Icons.autorenew, size: 14, color: Colors.white));
      case QuestionStatus.incomplete:
      default:
        return CircleAvatar(radius: 12, backgroundColor: Colors.grey[300], child: const Icon(Icons.radio_button_unchecked, size: 14, color: Colors.grey));
    }
  }

  void _confirmDeleteQuestion(BuildContext context, WidgetRef ref, Question question) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Question'),
        content: Text('Are you sure you want to delete "${question.title}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              final repo = await ref.read(questionRepositoryProvider.future);
              await repo.deleteQuestion(question.id);
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showAddQuestionDialog(BuildContext context, WidgetRef ref, Unit unit) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Question'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Question (e.g. "11 (a)")'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              if (controller.text.isNotEmpty) {
                final repo = await ref.read(questionRepositoryProvider.future);
                await repo.addQuestion(controller.text, unit.id, courseId: unit.course.value?.id);
                if (context.mounted) Navigator.pop(context);
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }
}
