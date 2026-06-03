import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../domain/models/question.dart';
import 'difficulty_stars.dart';

class QuestionListItem extends ConsumerWidget {
  final Question question;

  const QuestionListItem({super.key, required this.question});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    Color getStatusColor() {
      switch (question.status) {
        case QuestionStatus.completed: return Colors.green;
        case QuestionStatus.revisionNeeded: return Colors.orange;
        case QuestionStatus.incomplete:
        default: return Colors.grey;
      }
    }
    
    IconData getStatusIcon() {
      switch (question.status) {
        case QuestionStatus.completed: return Icons.check;
        case QuestionStatus.revisionNeeded: return Icons.autorenew;
        case QuestionStatus.incomplete:
        default: return Icons.radio_button_unchecked;
      }
    }

    return ListTile(
      leading: CircleAvatar(
        radius: 12,
        backgroundColor: getStatusColor().withOpacity(0.2),
        child: Icon(getStatusIcon(), size: 14, color: getStatusColor()),
      ),
      title: Row(
        children: [
          Expanded(child: Text(question.title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500))),
          DifficultyStars(question: question, size: 14),
        ],
      ),
      subtitle: question.notes != null && question.notes!.isNotEmpty 
        ? Text(question.notes!, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12))
        : null,
      trailing: const Icon(Icons.chevron_right, size: 18),
      onTap: () {
        context.push('/question/${question.id}');
      },
    );
  }
}


