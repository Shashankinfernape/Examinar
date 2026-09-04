import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../data/repositories/question_repository.dart';
import '../../data/repositories/course_repository.dart';
import '../../domain/models/unit.dart';
import '../../domain/models/course.dart';
import '../../domain/models/question.dart';

// ---------------------------------------------------------------------------
// Data model for a parsed question before DB insertion
// ---------------------------------------------------------------------------
class _ParsedQuestion {
  final String title;
  final String content;
  final int unitIndex; // 1=Part A, 2-6=Part B Units 1-5, 7=Part C
  final int difficulty; // 1-5 stars
  final int questionNum;

  const _ParsedQuestion({
    required this.title,
    required this.content,
    required this.unitIndex,
    required this.difficulty,
    required this.questionNum,
  });
}

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
          color: const Color(0xFF0A0A0A),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white12, width: 1),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Header ──────────────────────────────────────────────────
              Row(
                children: [
                  const Icon(Icons.document_scanner_outlined, color: Colors.white, size: 18),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'AI PAPER ANALYZER',
                      style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w900, letterSpacing: 1.2),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.clear_all_rounded, color: Colors.white38, size: 18),
                    tooltip: 'Clear',
                    onPressed: () => _textController.clear(),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                widget.unit != null
                    ? 'Mode: Pinned → ${widget.unit!.name}'
                    : 'Mode: Intelligent Mapping  ·  Q1–10 → Part A  ·  Q11–15 → Part B  ·  Q16 → Part C',
                style: const TextStyle(fontSize: 11, color: Colors.white38, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 16),
              const _StepLabel(step: '1', label: 'Paste your raw question paper below'),
              const SizedBox(height: 8),
              TextField(
                controller: _textController,
                maxLines: 8,
                minLines: 4,
                style: const TextStyle(color: Colors.white, fontSize: 13, height: 1.5),
                decoration: InputDecoration(
                  hintText: 'Paste raw exam questions OR formatted ChatGPT output here…',
                  hintStyle: const TextStyle(color: Colors.white24, fontSize: 13),
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.04),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Colors.white10)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Colors.white38, width: 1.2)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Colors.white10)),
                  contentPadding: const EdgeInsets.all(14),
                ),
              ),
              const SizedBox(height: 20),
              const _StepLabel(step: '2', label: 'Choose an action'),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white70,
                        side: const BorderSide(color: Colors.white24),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: _generatePrompt,
                      icon: const Icon(Icons.auto_awesome_outlined, size: 15),
                      label: const Text('FOR CHATGPT', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 11, letterSpacing: 0.6)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.black,
                        disabledBackgroundColor: Colors.white30,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                      onPressed: _isProcessing ? null : _processPaste,
                      icon: _isProcessing
                          ? const SizedBox(height: 13, width: 13, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black54))
                          : const Icon(Icons.checklist_rtl_rounded, size: 15),
                      label: Text(
                        _isProcessing ? 'BUILDING…' : 'BUILD CHECKLIST',
                        style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 11, letterSpacing: 0.6),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Parser — strips markdown, detects question numbers, maps to units
  // ---------------------------------------------------------------------------
  List<_ParsedQuestion> _parseText(String raw) {
    String text = raw
        .replaceAll(RegExp(r'\*\*(.*?)\*\*', dotAll: true), r'$1')
        .replaceAll(RegExp(r'__(.*?)__', dotAll: true), r'$1')
        .replaceAll(RegExp(r'#{1,6}\s*'), '')
        .replaceAll(RegExp(r'---+'), '')
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n');

    final RegExp qRegex = RegExp(
      r'^[ \t]*(?:Q(\d{1,2})|(\d{1,2})[\.\)])(?:\s*[\(\[]?[a-z][\)\]]?)?',
      caseSensitive: false,
      multiLine: true,
    );

    final allMatches = qRegex.allMatches(text).toList();
    if (allMatches.isEmpty) {
      return [_ParsedQuestion(title: 'Pasted Content', content: text.trim(), unitIndex: 1, difficulty: 3, questionNum: 1)];
    }

    final List<RegExpMatch> validMatches = [];
    int lastMainNum = -1;
    for (final m in allMatches) {
      final num = int.tryParse(m.group(1) ?? m.group(2) ?? '0') ?? 0;
      if (lastMainNum >= 10 && num < 10) continue;
      if (num >= 10) lastMainNum = num;
      validMatches.add(m);
    }

    if (validMatches.isEmpty) {
      return [_ParsedQuestion(title: 'Pasted Content', content: text.trim(), unitIndex: 1, difficulty: 3, questionNum: 1)];
    }

    final List<_ParsedQuestion> parsed = [];
    for (int i = 0; i < validMatches.length; i++) {
      final block = text.substring(validMatches[i].start, i + 1 < validMatches.length ? validMatches[i + 1].start : text.length).trim();
      final lines = block.split('\n');

      String title = lines[0].replaceAll(RegExp(r'^[\s\*\-]+'), '').trim();
      String content = lines.skip(1).map((l) => l.trim()).where((l) => l.isNotEmpty).join('\n').trim();

      final starCount = ('⭐'.allMatches(title).length + '⭐'.allMatches(content).length).clamp(0, 5);
      final difficulty = starCount > 0 ? starCount : 3;

      title = title.replaceAll('⭐', '').replaceAll(RegExp(r'\s{2,}'), ' ').trim();
      content = content.replaceAll('⭐', '').trim();

      final questionNum = int.tryParse(validMatches[i].group(1) ?? validMatches[i].group(2) ?? '1') ?? 1;

      parsed.add(_ParsedQuestion(
        title: title,
        content: content,
        unitIndex: _unitIndexFor(questionNum),
        difficulty: difficulty,
        questionNum: questionNum,
      ));
    }
    return parsed;
  }

  int _unitIndexFor(int q) {
    if (q >= 16) return 7;
    if (q >= 11) return q - 9;
    return 1;
  }

  // ---------------------------------------------------------------------------
  // Build Checklist
  // ---------------------------------------------------------------------------
  void _processPaste() async {
    final raw = _textController.text.trim();
    if (raw.isEmpty) {
      _snack('Paste some content first.', color: Colors.orange);
      return;
    }
    setState(() => _isProcessing = true);

    try {
      final parsedQuestions = _parseText(raw);

      // Assign [U1]..[U5] labels to Part A questions
      final partA = parsedQuestions.where((q) => q.unitIndex == 1).toList();
      final Map<int, String> partALabel = {};
      if (partA.isNotEmpty) {
        final perUnit = (partA.length / 5).ceil().clamp(1, 999);
        for (int i = 0; i < partA.length; i++) {
          partALabel[i] = '[U${((i ~/ perUnit) + 1).clamp(1, 5)}]';
        }
      }

      final qRepo = await ref.read(questionRepositoryProvider.future);
      final cRepo = await ref.read(courseRepositoryProvider.future);

      final currentCourse = widget.course ?? widget.unit?.course.value;
      if (currentCourse == null) {
        _snack('Course not found. Please re-open this sheet.', color: Colors.red);
        return;
      }

      // Ensure 7-unit structure exists
      await currentCourse.units.load();
      var units = currentCourse.units.toList()..sort((a, b) => (a.index ?? 0).compareTo(b.index ?? 0));

      if (units.isEmpty && widget.unit == null) {
        await cRepo.isar.writeTxn(() async {
          const unitNames = ['Part A', 'Part B | Unit I', 'Part B | Unit II', 'Part B | Unit III', 'Part B | Unit IV', 'Part B | Unit V', 'Part C'];
          for (var i = 0; i < unitNames.length; i++) {
            final u = Unit()..name = unitNames[i]..index = i + 1;
            await cRepo.isar.units.put(u);
            currentCourse.units.add(u);
          }
          await currentCourse.units.save();
        });
        units = currentCourse.units.toList()..sort((a, b) => (a.index ?? 0).compareTo(b.index ?? 0));
      }

      // Build duplicate-detection sets
      final Map<int, Set<String>> existingTitles = {};
      for (final u in units) {
        final existing = await qRepo.getQuestionsForUnit(u.id);
        existingTitles[u.id] = existing.map((q) => q.title.toLowerCase().trim()).toSet();
      }

      int added = 0, skipped = 0, partAIdx = 0;

      for (final pq in parsedQuestions) {
        final targetUnit = widget.unit ?? (pq.unitIndex <= units.length ? units[pq.unitIndex - 1] : units.last);

        String finalTitle = pq.title;
        if (pq.unitIndex == 1 && widget.unit == null) {
          finalTitle = '${partALabel[partAIdx] ?? ''} $finalTitle'.trim();
          partAIdx++;
        }

        final key = finalTitle.toLowerCase().trim();
        if (existingTitles[targetUnit.id]?.contains(key) == true) { skipped++; continue; }

        await qRepo.isar.writeTxn(() async {
          final q = qRepo.createQuestionObject(finalTitle, targetUnit.id)
            ..notes = pq.content
            ..courseId = currentCourse.id
            ..difficulty = pq.difficulty;
          await qRepo.isar.collection<Question>().put(q);
          q.unitLink.value = targetUnit;
          await q.unitLink.save();
        });
        existingTitles[targetUnit.id]?.add(key);
        added++;
      }

      // Update strategy blurb
      final topTopics = parsedQuestions.take(3).map((q) => q.title).join(', ');
      await cRepo.isar.writeTxn(() async {
        currentCourse.examStrategy = '${currentCourse.examStrategy ?? ''}\n\nSTRATEGY: Focus on $topTopics. Prioritise Part B units with the highest ⭐ ratings.';
        await cRepo.isar.collection<Course>().put(currentCourse);
      });

      if (mounted) _showSuccessDialog(added: added, skipped: skipped, total: parsedQuestions.length, units: units);
    } catch (e, st) {
      debugPrint('PasteBuildSheet error: $e\n$st');
      if (mounted) _snack('Error: $e', color: Colors.red);
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  // ---------------------------------------------------------------------------
  // Success dialog
  // ---------------------------------------------------------------------------
  void _showSuccessDialog({required int added, required int skipped, required int total, required List<Unit> units}) {
    if (!widget.isEmbedded) Navigator.pop(context);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF141414),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: const BorderSide(color: Colors.white12)),
        title: Row(
          children: [
            Icon(added > 0 ? Icons.check_circle_outline_rounded : Icons.info_outline_rounded,
                color: added > 0 ? Colors.greenAccent : Colors.white54, size: 22),
            const SizedBox(width: 10),
            Expanded(child: Text(added > 0 ? 'Checklist Built!' : 'Nothing New Added',
                style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold))),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _StatRow(label: 'Questions parsed', value: '$total'),
            const SizedBox(height: 6),
            _StatRow(label: 'Added to checklist', value: '$added', valueColor: Colors.greenAccent),
            if (skipped > 0) ...[
              const SizedBox(height: 6),
              _StatRow(label: 'Skipped (duplicates)', value: '$skipped', valueColor: Colors.orange),
            ],
            const SizedBox(height: 14),
            Text(
              added > 0
                  ? 'Distributed across ${units.length} units. Open any unit to start revising!'
                  : 'All parsed questions already exist in this course.',
              style: const TextStyle(color: Colors.white54, fontSize: 13, height: 1.4),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)), elevation: 0),
            onPressed: () => Navigator.pop(ctx),
            child: const Text('DONE', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 0.5)),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Generate ChatGPT Prompt
  // ---------------------------------------------------------------------------
  void _generatePrompt() {
    final text = _textController.text.trim();
    if (text.isEmpty) {
      _snack('Paste your raw questions first, then tap "For ChatGPT".', color: Colors.orange);
      return;
    }

    final prompt = '''I am providing you with my syllabus or past exam papers. Extract the most important questions and format them STRICTLY as shown below. Output ONLY the questions — no introductions, conclusions, or extra text.

FORMATTING RULES
─────────────────
PART A — Short Answers (Questions 1 to 10)
  • Generate exactly 10 questions, numbered 1. to 10.
  • These will be automatically split equally across 5 syllabus units.
  • Add ⭐ stars (1–5) after the question title to show exam priority.

PART B — Essay / Long Answers (Questions 11 to 15)
  • Q11 → Unit I  |  Q12 → Unit II  |  Q13 → Unit III  |  Q14 → Unit IV  |  Q15 → Unit V
  • Sub-parts: write as  11(a). ... ⭐⭐⭐  then  11(b). ... ⭐⭐  on separate lines.
  • Add ⭐ stars per question/sub-part.

PART C — Case Study / Application (Question 16)
  • 1 question only, numbered 16. with ⭐⭐⭐⭐⭐.

EXAMPLE FORMAT
──────────────
1. Define cloud computing and list its key characteristics. ⭐⭐
Cloud = on-demand delivery of IT resources via the internet.

11(a). Explain the architecture of AWS with a diagram. ⭐⭐⭐⭐
Cover: EC2, S3, VPC, IAM, Availability Zones, Load Balancers.

11(b). Compare AWS vs Azure vs GCP. ⭐⭐⭐
Focus on pricing, global reach, and enterprise adoption.

16. Design a highly available architecture for an e-commerce platform. ⭐⭐⭐⭐⭐
Use multi-AZ, auto-scaling groups, ELB, RDS failover, and CDN.

─────────────────
MY STUDY MATERIAL:

$text''';

    showDialog(
      context: context,
      builder: (ctx) => _PromptDialog(prompt: prompt),
    );
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------
  void _snack(String msg, {Color color = Colors.black87}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg, style: const TextStyle(color: Colors.white)), backgroundColor: color, behavior: SnackBarBehavior.floating),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Helper Widgets
// ─────────────────────────────────────────────────────────────────────────────

class _StepLabel extends StatelessWidget {
  final String step;
  final String label;
  const _StepLabel({required this.step, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 20, height: 20,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.1), shape: BoxShape.circle),
          child: Text(step, style: const TextStyle(color: Colors.white60, fontSize: 11, fontWeight: FontWeight.bold)),
        ),
        const SizedBox(width: 8),
        Text(label, style: const TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.w600)),
      ],
    );
  }
}

class _StatRow extends StatelessWidget {
  final String label;
  final String value;
  final Color valueColor;
  const _StatRow({required this.label, required this.value, this.valueColor = Colors.white});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: Colors.white54, fontSize: 13)),
        Text(value, style: TextStyle(color: valueColor, fontSize: 13, fontWeight: FontWeight.bold)),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Prompt Dialog — stateful COPY button with visual tick feedback
// ─────────────────────────────────────────────────────────────────────────────

class _PromptDialog extends StatefulWidget {
  final String prompt;
  const _PromptDialog({required this.prompt});

  @override
  State<_PromptDialog> createState() => _PromptDialogState();
}

class _PromptDialogState extends State<_PromptDialog> {
  bool _copied = false;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF141414),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: const BorderSide(color: Colors.white12)),
      title: const Row(
        children: [
          Icon(Icons.smart_toy_outlined, color: Colors.blueAccent, size: 20),
          SizedBox(width: 8),
          Expanded(child: Text('ChatGPT Prompt Ready', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold))),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'We combined your content with strict formatting rules. Send it to ChatGPT, then paste the response back to build your checklist.',
            style: TextStyle(color: Colors.white60, fontSize: 13, height: 1.5),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.white10)),
            child: const Row(
              children: [
                Icon(Icons.info_outline_rounded, color: Colors.white30, size: 14),
                SizedBox(width: 6),
                Expanded(child: Text('Prompt is auto-copied when you tap Open ChatGPT.', style: TextStyle(color: Colors.white38, fontSize: 11, height: 1.4))),
              ],
            ),
          ),
        ],
      ),
      actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('CANCEL', style: TextStyle(color: Colors.white38, fontWeight: FontWeight.w600, fontSize: 12)),
        ),
        const Spacer(),
        // COPY with tick feedback
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            foregroundColor: _copied ? Colors.greenAccent : Colors.blueAccent,
            side: BorderSide(color: _copied ? Colors.greenAccent : Colors.blueAccent),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          onPressed: () {
            Clipboard.setData(ClipboardData(text: widget.prompt));
            setState(() => _copied = true);
            Future.delayed(const Duration(seconds: 2), () { if (mounted) setState(() => _copied = false); });
          },
          icon: Icon(_copied ? Icons.check_rounded : Icons.copy_outlined, size: 14),
          label: Text(_copied ? 'COPIED!' : 'COPY', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
        ),
        const SizedBox(width: 8),
        // OPEN CHATGPT
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blueAccent, foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)), elevation: 0,
          ),
          onPressed: () async {
            await Clipboard.setData(ClipboardData(text: widget.prompt));
            final url = Uri.parse('https://chatgpt.com/?q=${Uri.encodeComponent(widget.prompt)}');
            if (await canLaunchUrl(url)) {
              await launchUrl(url, mode: LaunchMode.externalApplication);
              if (context.mounted) Navigator.pop(context);
            } else {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                  content: Text('Could not open browser — prompt copied instead.'),
                  backgroundColor: Colors.orange, behavior: SnackBarBehavior.floating,
                ));
              }
            }
          },
          icon: const Icon(Icons.open_in_new_rounded, size: 14),
          label: const Text('OPEN CHATGPT', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
        ),
      ],
    );
  }
}



