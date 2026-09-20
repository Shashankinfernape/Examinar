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
  List<Course> _courses = [];
  List<Unit> _units = [];
  bool _loadingCourses = true;
  bool _loadingUnits = false;

  @override
  void initState() {
    super.initState();
    _loadCourses();
  }

  Future<void> _loadCourses() async {
    final repo = ref.read(courseRepositoryProvider);
    final courses = await repo.getAllCourses();
    if (mounted) {
      setState(() {
        _courses = courses;
        _loadingCourses = false;
        if (courses.isNotEmpty) {
          _selectedCourse = courses.first;
        }
      });
      if (_selectedCourse != null) {
        _loadUnits(_selectedCourse!.id);
      }
    }
  }

  Future<void> _loadUnits(String courseId) async {
    setState(() {
      _loadingUnits = true;
      _units = [];
      _selectedUnit = null;
    });
    final repo = ref.read(courseRepositoryProvider);
    final units = await repo.watchCourseUnits(courseId).first;
    if (mounted && _selectedCourse?.id == courseId) {
      setState(() {
        _units = units;
        _loadingUnits = false;
        if (units.isNotEmpty) {
          _selectedUnit = units.first;
        }
      });
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loadingCourses) {
      return const Padding(
        padding: EdgeInsets.all(32.0),
        child: Center(child: CircularProgressIndicator()),
      );
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
                child: InputDecorator(
                  decoration: const InputDecoration(labelText: 'Course'),
                  child: DropdownButton<Course>(
                    value: _selectedCourse,
                    isExpanded: true,
                    underline: const SizedBox(),
                    items: _courses.map((c) => DropdownMenuItem(value: c, child: Text(c.name))).toList(),
                    onChanged: (val) {
                      if (val != null && val.id != _selectedCourse?.id) {
                        setState(() {
                          _selectedCourse = val;
                        });
                        _loadUnits(val.id);
                      }
                    },
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _loadingUnits 
                  ? const Center(child: CircularProgressIndicator())
                  : InputDecorator(
                      decoration: const InputDecoration(labelText: 'Unit'),
                      child: DropdownButton<Unit>(
                        value: _selectedUnit,
                        isExpanded: true,
                        underline: const SizedBox(),
                        items: _units.map((u) => DropdownMenuItem(value: u, child: Text(u.name))).toList(),
                        onChanged: (val) => setState(() => _selectedUnit = val),
                      ),
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
  }

  void _save() async {
    if (_titleController.text.isEmpty || _selectedUnit == null) return;

    final repo = ref.read(questionRepositoryProvider);
    await repo.addQuestion(
      _titleController.text,
      _selectedUnit!.id,
      courseId: _selectedCourse?.id,
    );

    if (mounted) Navigator.pop(context);
  }
}
