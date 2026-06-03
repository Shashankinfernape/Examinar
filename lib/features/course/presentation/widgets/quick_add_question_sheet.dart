import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories/course_repository.dart';
import '../../data/repositories/question_repository.dart';
import '../../domain/models/course.dart';
import '../../domain/models/unit.dart';

class QuickAddQuestionSheet extends ConsumerStatefulWidget {
  const QuickAddQuestionSheet({super.key});

  @override
  ConsumerState<QuickAddQuestionSheet> createState() => _QuickAddQuestionSheetState();
}

class _QuickAddQuestionSheetState extends ConsumerState<QuickAddQuestionSheet> {
  final _titleController = TextEditingController();
  Course? _selectedCourse;
  Unit? _selectedUnit;

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final coursesAsync = ref.watch(courseRepositoryProvider);
    
    return coursesAsync.when(
      data: (repo) => FutureBuilder<List<Course>>(
        future: repo.getAllCourses(),
        builder: (context, snapshot) {
          final courses = snapshot.data ?? [];
          if (_selectedCourse == null && courses.isNotEmpty) {
            _selectedCourse = courses.first;
            if (_selectedCourse!.units.isNotEmpty) {
              _selectedUnit = _selectedCourse!.units.first;
            }
          }

          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
              left: 16,
              right: 16,
              top: 16,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Quick Add Question',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _titleController,
                  autofocus: true,
                  decoration: const InputDecoration(
                    labelText: 'Question Title',
                    border: OutlineInputBorder(),
                  ),
                  onSubmitted: (_) => _save(),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<Course>(
                        value: _selectedCourse,
                        decoration: const InputDecoration(labelText: 'Course'),
                        items: courses.map((c) => DropdownMenuItem(value: c, child: Text(c.name))).toList(),
                        onChanged: (val) {
                          setState(() {
                            _selectedCourse = val;
                            if (_selectedCourse != null && _selectedCourse!.units.isNotEmpty) {
                              _selectedUnit = _selectedCourse!.units.first;
                            } else {
                              _selectedUnit = null;
                            }
                          });
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: DropdownButtonFormField<Unit>(
                        value: _selectedUnit,
                        decoration: const InputDecoration(labelText: 'Unit'),
                        items: _selectedCourse?.units.map((u) => DropdownMenuItem(value: u, child: Text(u.name))).toList() ?? [],
                        onChanged: (val) => setState(() => _selectedUnit = val),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _save,
                  child: const Text('Save Question'),
                ),
                const SizedBox(height: 16),
              ],
            ),
          );
        },
      ),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, s) => Center(child: Text('Error: $e')),
    );
  }

  void _save() async {
    if (_titleController.text.isEmpty || _selectedUnit == null) return;

    final repo = await ref.read(questionRepositoryProvider.future);
    await repo.addQuestion(
      _titleController.text,
      _selectedUnit!.id,
      courseId: _selectedCourse?.id,
    );

    if (mounted) Navigator.pop(context);
  }
}
