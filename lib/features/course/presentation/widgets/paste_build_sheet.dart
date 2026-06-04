import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories/question_repository.dart';
import '../../data/repositories/course_repository.dart';
import '../../domain/models/unit.dart';
import '../../domain/models/course.dart';
import '../../domain/models/question.dart';

class PasteBuildSheet extends ConsumerStatefulWidget {
  final Unit? unit; // Optional: If null, we use intelligent mapping
  final Course? course; // Required for intelligent mapping
  final bool isEmbedded; // If true, do not pop Navigator on success

  const PasteBuildSheet({super.key, this.unit, this.course, this.isEmbedded = false});

  @override
  ConsumerState<PasteBuildSheet> createState() => _PasteBuildSheetState();
}

class _PasteBuildSheetState extends ConsumerState<PasteBuildSheet> {
  final _textController = TextEditingController();
  bool _isProcessing = false;

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF121212), // Opaque background
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white24, width: 1),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const Icon(Icons.auto_awesome, color: Colors.white),
                    const SizedBox(width: 8),
                    const Text(
                      'AI PAPER ANALYZER',
                      style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900, letterSpacing: 1.0),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  widget.unit != null 
                    ? 'Pasting into ${widget.unit!.name}' 
                    : 'Intelligent Mapping Mode (Mapping 11->Unit I, 12->Unit II, etc.)',
                  style: const TextStyle(fontSize: 12, color: Colors.white54, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _textController,
                  maxLines: 5,
                  minLines: 3,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'Paste raw question paper text here...',
                    hintStyle: const TextStyle(color: Colors.white30),
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.05),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Colors.white10)),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Colors.white, width: 1.5)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Colors.white10)),
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: _isProcessing ? null : _processPaste,
                  child: _isProcessing 
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                      : const Text('ANALYZE & BUILD CHECKLIST', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.0)),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
    );
  }

  void _processPaste() async {
    final text = _textController.text.trim();
    if (text.isEmpty) return;

    setState(() => _isProcessing = true);

    try {
      // 1. Identify Questions & Answers
      // Smarter Regex: Matches "11.", "11.(a)", "Q11", "11 a)", etc. ONLY if it's the start of a line.
      // It avoids splitting on "1.", "2." if they look like simple list items deep in the text.
      final RegExp questionRegex = RegExp(
        r'^(?:Q\d+|\d{1,2}[\.\)]?\s*(?:\([a-z]\)|[a-z]\))?)',
        caseSensitive: false,
        multiLine: true,
      );
      
      final matches = questionRegex.allMatches(text).toList();
      final List<Map<String, dynamic>> parsedQuestions = [];

      if (matches.isEmpty) {
        parsedQuestions.add({'title': 'Pasted Content', 'content': text, 'unitIndex': 1});
      } else {
        // Filter out matches that drop sequentially (e.g. going from 11 to 1) to prevent splitting on lists
        final List<RegExpMatch> validMatches = [];
        int lastMainNumber = -1;

        for (final match in matches) {
          final markerStr = match.group(0)!.trim();
          final numMatch = RegExp(r'(\d+)').firstMatch(markerStr);
          
          if (numMatch != null) {
            final num = int.parse(numMatch.group(1)!);
            if (num < lastMainNumber && num < 10) {
              // Looks like a list item (e.g., 1. Public Cloud) inside an answer, ignore it!
              continue;
            }
            if (num >= 10) lastMainNumber = num; // Update main question tracker
          }
          validMatches.add(match);
        }

        if (validMatches.isEmpty) {
           parsedQuestions.add({'title': 'Pasted Content', 'content': text, 'unitIndex': 1});
        } else {
          for (int i = 0; i < validMatches.length; i++) {
            final marker = validMatches[i].group(0)!.trim();
            final start = validMatches[i].start;
            final end = (i + 1 < validMatches.length) ? validMatches[i + 1].start : text.length;
            
            final block = text.substring(start, end).trim();
            final lines = block.split('\n');
            String title = lines[0].trim();
            String content = lines.skip(1).join('\n').trim();

            int starCount = 0;
            starCount += title.split('⭐').length - 1;
            starCount += content.split('⭐').length - 1;
            int difficulty = starCount > 0 ? starCount.clamp(1, 5) : 3;

            title = title.replaceAll('⭐', '').trim();
            content = content.replaceAll('⭐', '').trim();

            // 2. Intelligent Unit Mapping
            final numberMatch = RegExp(r'(\d+)').firstMatch(marker);
            int unitIndex = 1;
            int questionNum = 1;
            if (numberMatch != null) {
              questionNum = int.parse(numberMatch.group(1)!);
              if (questionNum == 16) {
                unitIndex = 7; // Part C
              } else if (questionNum >= 11 && questionNum <= 15) {
                unitIndex = questionNum - 9; // Part B Units 1-5 (Indexes 2-6)
              } else {
                unitIndex = 1; // Part A (Index 1)
              }
            }

            parsedQuestions.add({
              'title': title,
              'content': content,
              'unitIndex': unitIndex,
              'difficulty': difficulty,
              'qNum': questionNum,
            });
          }
        }
      }

      // Process Part A questions to add visual Unit divisions
      final partAQuestions = parsedQuestions.where((q) => q['unitIndex'] == 1).toList();
      final n = partAQuestions.length;
      if (n > 0) {
        final questionsPerUnit = (n / 5).ceil(); 
        for (int i = 0; i < n; i++) {
          final logicalUnit = (i ~/ (questionsPerUnit > 0 ? questionsPerUnit : 1)) + 1;
          final displayUnit = logicalUnit > 5 ? 5 : logicalUnit;
          partAQuestions[i]['title'] = '[Unit $displayUnit] ${partAQuestions[i]['title']}';
        }
      }

      final qRepo = await ref.read(questionRepositoryProvider.future);
      final cRepo = await ref.read(courseRepositoryProvider.future);

      
      final currentCourse = widget.course ?? widget.unit?.course.value;
      if (currentCourse == null) return;

      await currentCourse.units.load();
      var units = currentCourse.units.toList()..sort((a, b) => (a.index ?? 0).compareTo(b.index ?? 0));

      if (units.isEmpty && widget.unit == null) {
        // Dynamically create the 7-Unit Structure
        await cRepo.isar.writeTxn(() async {
          final unitNames = [
            'Part A',
            'Part B | Unit 1',
            'Part B | Unit 2',
            'Part B | Unit 3',
            'Part B | Unit 4',
            'Part B | Unit 5',
            'Part C'
          ];
          
          for (var i = 0; i < unitNames.length; i++) {
            final unit = Unit()
              ..name = unitNames[i]
              ..index = i + 1;
            
            await cRepo.isar.units.put(unit);
            currentCourse.units.add(unit);
          }
          await currentCourse.units.save();
        });
        units = currentCourse.units.toList()..sort((a, b) => (a.index ?? 0).compareTo(b.index ?? 0));
      }

      for (final q in parsedQuestions) {
        final targetUnit = widget.unit ?? (q['unitIndex'] <= units.length ? units[q['unitIndex'] - 1] : units.last);
        
        await qRepo.isar.writeTxn(() async {
          final question = qRepo.createQuestionObject(q['title']!, targetUnit.id)
              ..notes = q['content']!
              ..courseId = currentCourse.id
              ..difficulty = q['difficulty'] as int;
          
          await qRepo.isar.collection<Question>().put(question);
          question.unitLink.value = targetUnit;
          await question.unitLink.save();
        });
      }

      final importantTopics = parsedQuestions.map((q) => q['title']).take(3).join(', ');
      final strategy = "STRATEGY: Focus on $importantTopics. High probability of Part B appearance. "
          "Map these concepts to diagrams for maximum marks.";
      
      await cRepo.isar.writeTxn(() async {
        currentCourse.examStrategy = "${currentCourse.examStrategy ?? ""}\n\n$strategy";
        await cRepo.isar.collection<Course>().put(currentCourse);
      });

      if (mounted && !widget.isEmbedded) Navigator.pop(context);
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }
}
