import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories/question_repository.dart';
import '../../domain/models/question.dart';

class DifficultyStars extends ConsumerWidget {
  final Question question;
  final double size;

  const DifficultyStars({
    super.key,
    required this.question,
    this.size = 16,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(
        5,
        (starIndex) {
          final starVal = starIndex + 1;
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () async {
              final repo = await ref.read(questionRepositoryProvider.future);
              await repo.updateDifficulty(question.id, starVal);
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 1),
              child: Icon(
                starIndex < question.difficulty ? Icons.star : Icons.star_border,
                size: size,
                color: starIndex < question.difficulty ? Colors.white : Colors.white24,
              ),
            ),
          );
        },
      ),
    );
  }
}
