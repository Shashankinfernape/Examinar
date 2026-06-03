import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories/question_repository.dart';
import '../../domain/models/question.dart';
import 'package:exam_command_center/core/theme/app_theme.dart';

class RevisionLoopScreen extends ConsumerStatefulWidget {
  final List<int> questionIds;

  const RevisionLoopScreen({super.key, required this.questionIds});

  @override
  ConsumerState<RevisionLoopScreen> createState() => _RevisionLoopScreenState();
}

class _RevisionLoopScreenState extends ConsumerState<RevisionLoopScreen> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    if (_currentIndex >= widget.questionIds.length) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('Revision Session Complete!', style: TextStyle(fontSize: 24)),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Return Home'),
              ),
            ],
          ),
        ),
      );
    }

    final questionId = widget.questionIds[_currentIndex];
    final repoAsync = ref.watch(questionRepositoryProvider);

    return repoAsync.when(
      data: (repo) => FutureBuilder<Question?>(
        future: repo.isar.questions.get(questionId),
        builder: (context, snapshot) {
          final question = snapshot.data;
          if (question == null) return const Scaffold(body: Center(child: Text('Question not found')));

          return Scaffold(
            appBar: AppBar(
              title: Text('Revising (${_currentIndex + 1}/${widget.questionIds.length})'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Exit', style: TextStyle(color: Colors.red)),
                ),
              ],
            ),
            body: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    question.title,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 24),
                  if (question.notes != null) ...[
                    Text('Notes', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.grey.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: SingleChildScrollView(child: Text(question.notes!)),
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  Text(
                    'Update Status to Advance',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      _statusButton(QuestionStatus.incomplete, 'Incomplete', Icons.radio_button_unchecked, Colors.grey),
                      const SizedBox(width: 8),
                      _statusButton(QuestionStatus.revisionNeeded, 'Revise', Icons.autorenew, Colors.orange),
                      const SizedBox(width: 8),
                      _statusButton(QuestionStatus.completed, 'Done', Icons.check, Colors.green),
                    ],
                  ),
                  const SizedBox(height: 32),
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

  Widget _statusButton(QuestionStatus status, String label, IconData icon, Color color) {
    return Expanded(
      child: InkWell(
        onTap: () => _updateAndAdvance(status),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            border: Border.all(color: color),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              Icon(icon, color: color, size: 24),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _updateAndAdvance(QuestionStatus status) async {
    final questionId = widget.questionIds[_currentIndex];
    final repo = await ref.read(questionRepositoryProvider.future);
    await repo.updateStatus(questionId, status);
    
    setState(() {
      _currentIndex++;
    });
  }
}
