import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:super_drag_and_drop/super_drag_and_drop.dart';
import 'package:dotted_border/dotted_border.dart';
import 'package:file_picker/file_picker.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:pasteboard/pasteboard.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:io';
import '../../data/repositories/question_repository.dart';
import '../../data/repositories/course_repository.dart';
import '../../domain/models/unit.dart';
import '../../domain/models/course.dart';
import '../../domain/models/question.dart';

class PasteBuildSheet extends ConsumerStatefulWidget {
  final Unit? unit; // Optional: If null, we use intelligent mapping
  final Course? course; // Required for intelligent mapping
  final bool isEmbedded; // If true, do not pop Navigator on success

  const PasteBuildSheet({
    super.key,
    this.unit,
    this.course,
    this.isEmbedded = false,
  });

  @override
  ConsumerState<PasteBuildSheet> createState() => _PasteBuildSheetState();
}

class _PasteBuildSheetState extends ConsumerState<PasteBuildSheet> {
  final _textController = TextEditingController();
  final _gptResponseController = TextEditingController();
  bool _isProcessing = false;
  bool _isDragging = false;
  bool _promptSent = false; // true after ChatGPT is opened
  List<String> _attachments = [];

  @override
  void dispose() {
    _textController.dispose();
    _gptResponseController.dispose();
    super.dispose();
  }

  Future<void> _handleFileSelection() async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.any,
        allowMultiple: true,
      );
      if (result != null && result.files.isNotEmpty) {
        for (var file in result.files) {
          if (file.path != null) {
            await _addAttachment(file.path!);
          }
        }
      }
    } catch (e) {
      debugPrint("Error picking file: $e");
    }
  }

  Future<void> _handlePasteFromClipboard() async {
    try {
      final imageBytes = await Pasteboard.image;
      if (imageBytes != null && imageBytes.isNotEmpty) {
        final tempDir = await getTemporaryDirectory();
        final tempFile = File('${tempDir.path}/clipboard_image_${DateTime.now().millisecondsSinceEpoch}.png');
        await tempFile.writeAsBytes(imageBytes);
        await _addAttachment(tempFile.path);
        return;
      }

      final files = await Pasteboard.files();
      if (files.isNotEmpty) {
        for (var file in files) {
          await _addAttachment(file);
        }
        return;
      }

      final text = await Pasteboard.text;
      if (text != null && text.trim().isNotEmpty) {
        setState(() {
          _textController.text = text;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('📋 Pasted text from clipboard!'),
              backgroundColor: Color(0xFF3E82F7),
              duration: Duration(seconds: 2),
            ),
          );
        }
        return;
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Clipboard is empty! Copy an image or file first.'),
          backgroundColor: Colors.orange,
        ),
      );
    } catch (e) {
      debugPrint('Error pasting from clipboard: $e');
    }
  }

  Future<void> _addAttachment(String path) async {
    setState(() => _isProcessing = true);
    final fileName = path.split(Platform.pathSeparator).last;

    try {
      final ext = path.toLowerCase().split('.').last;

      if (ext == 'pdf') {
        final List<int> bytes = await File(path).readAsBytes();
        final PdfDocument document = PdfDocument(inputBytes: bytes);
        final String text = PdfTextExtractor(document).extractText();
        document.dispose();
        setState(() {
          _textController.text = text;
          _isProcessing = false;
        });
      } else if (ext == 'txt') {
        final String text = await File(path).readAsString();
        setState(() {
          _textController.text = text;
          _isProcessing = false;
        });
      } else {
        // Assume image/doc and add to attachments
        setState(() {
          _attachments.add(path);
          _isProcessing = false;
        });
      }
    } catch (e) {
      debugPrint('Error adding attachment: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error reading file: $e'), backgroundColor: Colors.redAccent),
        );
      }
      setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF000000), // Opaque background
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
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.0,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                widget.unit != null
                    ? 'Pasting into ${widget.unit!.name}'
                    : 'Intelligent Mapping Mode (Mapping 11->Unit I, 12->Unit II, etc.)',
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.white54,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 16),

              LayoutBuilder(
                builder: (context, constraints) {
                  final isDesktop = constraints.maxWidth > 600;

                  final pasteField = TextField(
                    controller: _textController,
                    maxLines: 7,
                    minLines: 7,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    decoration: InputDecoration(
                      hintText:
                          'Paste raw question paper OR ChatGPT output here...',
                      hintStyle: const TextStyle(color: Colors.white30),
                      filled: true,
                      fillColor: Colors.white.withValues(alpha: 0.05),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: const BorderSide(color: Colors.white10),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: const BorderSide(
                          color: Colors.white,
                          width: 1.5,
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: const BorderSide(color: Colors.white10),
                      ),
                    ),
                  );

                  final dropZone = GestureDetector(
                    onTap: _isProcessing ? null : _handleFileSelection,
                    child: DropRegion(
                      formats: Formats.standardFormats,
                      onDropOver: (event) {
                        if (!_isDragging && mounted) setState(() => _isDragging = true);
                        return DropOperation.copy;
                      },
                      onDropLeave: (event) {
                        if (_isDragging && mounted) setState(() => _isDragging = false);
                      },
                      onPerformDrop: (event) async {
                        if (mounted) setState(() => _isDragging = false);
                        if (event.session.items.isEmpty) return;
                        setState(() => _isProcessing = true);
                        int idx = 0;
                        for (final item in event.session.items) {
                          idx++;
                          final currentIdx = idx;
                          if (item.dataReader != null) {
                             item.dataReader!.getFile(null, (file) async {
                                try {
                                  final bytes = await file.readAll();
                                  final tempDir = await getTemporaryDirectory();
                                  final ext = file.fileName?.split('.').last ?? 'png';
                                  final tempFile = File('${tempDir.path}/drop_${DateTime.now().microsecondsSinceEpoch}_${currentIdx}_${file.fileName ?? "img"}.$ext');
                                  await tempFile.writeAsBytes(bytes);
                                  await _addAttachment(tempFile.path);
                                } catch (e) {
                                  debugPrint("Drop error: $e");
                                }
                             });
                          }
                        }
                      },
                      child: DottedBorder(
                        options: RoundedRectDottedBorderOptions(
                          color: _isDragging
                              ? Colors.blueAccent
                              : Colors.white24,
                          strokeWidth: 1.5,
                          dashPattern: const [8, 6],
                          radius: const Radius.circular(16),
                        ),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            vertical: 36,
                            horizontal: 16,
                          ),
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: _isDragging
                                ? Colors.blueAccent.withValues(alpha: 0.1)
                                : Colors.white.withValues(alpha: 0.02),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (_isProcessing)
                                const SizedBox(
                                  height: 40,
                                  width: 40,
                                  child: CircularProgressIndicator(
                                    color: Colors.blueAccent,
                                  ),
                                )
                              else
                                Icon(
                                  Icons.upload_file,
                                  size: 40,
                                  color: _isDragging
                                      ? Colors.blueAccent
                                      : Colors.white38,
                                ),
                              const SizedBox(height: 12),
                              RichText(
                                textAlign: TextAlign.center,
                                text: TextSpan(
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 14,
                                    height: 1.5,
                                  ),
                                  children: [
                                    TextSpan(
                                      text: _attachments.isEmpty ? 'Drag & Drop Images/PDF\n' : 'Add more Images/PDF\n',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                    const TextSpan(text: 'or click to browse files'),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 16),
                              OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.white,
                                  side: const BorderSide(color: Colors.white24),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 10,
                                  ),
                                ),
                                onPressed: _isProcessing ? null : _handlePasteFromClipboard,
                                icon: const Icon(Icons.content_paste_rounded, size: 16, color: Colors.blueAccent),
                                label: const Text(
                                  'Paste from Clipboard',
                                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                ),
                              ),
                              if (_attachments.isNotEmpty) ...[
                                const SizedBox(height: 24),
                                const Divider(color: Colors.white10),
                                const SizedBox(height: 12),
                                const Text("Attached Images", style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold)),
                                const SizedBox(height: 12),
                                Wrap(
                                  spacing: 12,
                                  runSpacing: 12,
                                  alignment: WrapAlignment.center,
                                  children: _attachments.map((path) {
                                    return Stack(
                                      clipBehavior: Clip.none,
                                      children: [
                                        ClipRRect(
                                          borderRadius: BorderRadius.circular(8),
                                          child: Image.file(
                                            File(path),
                                            width: 60,
                                            height: 60,
                                            fit: BoxFit.cover,
                                          ),
                                        ),
                                        Positioned(
                                          top: -6,
                                          right: -6,
                                          child: GestureDetector(
                                            onTap: () {
                                              setState(() => _attachments.remove(path));
                                            },
                                            child: Container(
                                              padding: const EdgeInsets.all(4),
                                              decoration: const BoxDecoration(
                                                color: Colors.redAccent,
                                                shape: BoxShape.circle,
                                              ),
                                              child: const Icon(Icons.close, size: 12, color: Colors.white),
                                            ),
                                          ),
                                        ),
                                      ],
                                    );
                                  }).toList(),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                  );

                  if (isDesktop) {
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: pasteField),
                        const SizedBox(width: 16),
                        Expanded(child: dropZone),
                      ],
                    );
                  } else {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        pasteField,
                        const SizedBox(height: 16),
                        dropZone,
                      ],
                    );
                  }
                },
              ),

              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Colors.white24),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: _generatePrompt,
                      child: const Text(
                        'GENERATE TEXT PROMPT',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 12,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  if (_attachments.isNotEmpty)
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blueAccent,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: _isProcessing ? null : () => _launchChatGptWithImages(_attachments),
                        child: _isProcessing
                            ? const SizedBox(
                                height: 16,
                                width: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Text(
                                'PROCEED (${_attachments.length})',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 12,
                                  letterSpacing: 0.5,
                                ),
                              ),
                      ),
                    )
                  else
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: _isProcessing ? null : _processPaste,
                        child: _isProcessing
                            ? const SizedBox(
                                height: 16,
                                width: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.black,
                                ),
                              )
                            : const Text(
                                'PARSE RESPONSE',
                                style: TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 14,
                                  letterSpacing: 1.0,
                                ),
                              ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 16),

              // --- Response Pane (shown after ChatGPT is opened) ---
              if (_promptSent) ...[
                const Divider(color: Colors.white10, thickness: 1),
                const SizedBox(height: 16),

                // Status message
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle_outline, color: Colors.greenAccent, size: 20),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text(
                          'Prompt is ready! Send it in ChatGPT, then copy the generated question pattern and paste it below.',
                          style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
                        ),
                      ),
                      TextButton(
                        onPressed: () => setState(() => _promptSent = false),
                        child: const Text('Reset', style: TextStyle(color: Colors.white38, fontSize: 12)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // GPT Response paste field
                TextField(
                  controller: _gptResponseController,
                  maxLines: 8,
                  minLines: 5,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'Paste ChatGPT\'s generated question paper here...',
                    hintStyle: const TextStyle(color: Colors.white30),
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: 0.04),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(color: Colors.white10),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(color: Colors.white, width: 1.5),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(color: Colors.white10),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Proceed button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF3E82F7),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    onPressed: _isProcessing ? null : _processPasteResponse,
                    icon: _isProcessing
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.auto_awesome, size: 18),
                    label: const Text(
                      'PROCEED — CREATE SUBJECT BLUEPRINT',
                      style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 0.6),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // Processes the GPT response pasted in the response field
  void _processPasteResponse() {
    final response = _gptResponseController.text.trim();
    if (response.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please paste ChatGPT\'s response first.', style: TextStyle(color: Colors.white)),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }
    // Pipe the GPT response into the main text controller and run _processPaste
    _textController.text = response;
    _processPaste();
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
        r'^[\s\*\-\#]*(?:Q\d+|\d{1,2}[\.\)]?\s*(?:\([a-z]\)|[a-z]\))?)',
        caseSensitive: false,
        multiLine: true,
      );

      final matches = questionRegex.allMatches(text).toList();
      final List<Map<String, dynamic>> parsedQuestions = [];

      if (matches.isEmpty) {
        parsedQuestions.add({
          'title': 'Pasted Content',
          'content': text,
          'unitIndex': 1,
          'difficulty': 3,
          'qNum': 1,
        });
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
          parsedQuestions.add({
            'title': 'Pasted Content',
            'content': text,
            'unitIndex': 1,
            'difficulty': 3,
            'qNum': 1,
          });
        } else {
          for (int i = 0; i < validMatches.length; i++) {
            final marker = validMatches[i].group(0)!.trim();
            final start = validMatches[i].start;
            final end = (i + 1 < validMatches.length)
                ? validMatches[i + 1].start
                : text.length;

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
      final partAQuestions = parsedQuestions
          .where((q) => q['unitIndex'] == 1)
          .toList();
      final n = partAQuestions.length;
      if (n > 0) {
        final questionsPerUnit = (n / 5).ceil();
        for (int i = 0; i < n; i++) {
          final logicalUnit =
              (i ~/ (questionsPerUnit > 0 ? questionsPerUnit : 1)) + 1;
          final displayUnit = logicalUnit > 5 ? 5 : logicalUnit;
          partAQuestions[i]['title'] =
              '[Unit $displayUnit] ${partAQuestions[i]['title']}';
        }
      }

      final qRepo = await ref.read(questionRepositoryProvider.future);
      final cRepo = await ref.read(courseRepositoryProvider.future);

      final currentCourse = widget.course ?? widget.unit?.course.value;
      if (currentCourse == null) return;

      await currentCourse.units.load();
      var units = currentCourse.units.toList()
        ..sort((a, b) => (a.index ?? 0).compareTo(b.index ?? 0));

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
            'Part C',
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
        units = currentCourse.units.toList()
          ..sort((a, b) => (a.index ?? 0).compareTo(b.index ?? 0));
      }

      for (final q in parsedQuestions) {
        final targetUnit =
            widget.unit ??
            (q['unitIndex'] <= units.length
                ? units[q['unitIndex'] - 1]
                : units.last);

        await qRepo.isar.writeTxn(() async {
          final question =
              qRepo.createQuestionObject(q['title']!, targetUnit.id)
                ..notes = q['content']!
                ..courseId = currentCourse.id
                ..difficulty = q['difficulty'] as int;

          await qRepo.isar.collection<Question>().put(question);
          question.unitLink.value = targetUnit;
          await question.unitLink.save();
        });
      }

      final importantTopics = parsedQuestions
          .map((q) => q['title'])
          .take(3)
          .join(', ');
      final strategy =
          "STRATEGY: Focus on $importantTopics. High probability of Part B appearance. "
          "Map these concepts to diagrams for maximum marks.";

      await cRepo.isar.writeTxn(() async {
        currentCourse.examStrategy =
            "${currentCourse.examStrategy ?? ""}\n\n$strategy";
        await cRepo.isar.collection<Course>().put(currentCourse);
      });

      if (mounted && !widget.isEmbedded) Navigator.pop(context);
    } catch (e, stackTrace) {
      debugPrint('Error processing paste: $e\n$stackTrace');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Error: $e',
              style: const TextStyle(color: Colors.white),
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  static const _channel = MethodChannel('com.examcommandcenter.direct_share');

  Future<bool> _shareDirectlyToApp(List<String> imagePaths, String preprompt, String packageName) async {
    try {
      final success = await _channel.invokeMethod<bool>('shareImage', {
        'imagePaths': imagePaths,
        'text': preprompt,
        'package': packageName,
      });
      return success ?? false;
    } catch (e) {
      debugPrint("Direct share error: $e");
      return false;
    }
  }

  Future<void> _showAiFallbackDialog(List<String> imagePaths, String preprompt) async {
    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E1E),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Text("ChatGPT App Not Found", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            ),
            ListTile(
              leading: const Icon(Icons.language, color: Colors.blue),
              title: const Text("Open ChatGPT in Browser", style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                final url = Uri.parse('https://chatgpt.com/?q=\${Uri.encodeComponent(preprompt)}');
                launchUrl(url, mode: LaunchMode.externalApplication);
              },
            ),
            ListTile(
              leading: const Icon(Icons.auto_awesome, color: Colors.purple),
              title: const Text("Open in Gemini", style: TextStyle(color: Colors.white)),
              onTap: () async {
                Navigator.pop(context);
                final success = await _shareDirectlyToApp(imagePaths, preprompt, 'com.google.android.apps.bard');
                if (!success && mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Gemini not found.')));
              },
            ),
            ListTile(
              leading: const Icon(Icons.psychology, color: Colors.orange),
              title: const Text("Open in Claude", style: TextStyle(color: Colors.white)),
              onTap: () async {
                Navigator.pop(context);
                final success = await _shareDirectlyToApp(imagePaths, preprompt, 'com.anthropic.claude');
                if (!success && mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Claude not found.')));
              },
            ),
            ListTile(
              leading: const Icon(Icons.search, color: Colors.teal),
              title: const Text("Open in Perplexity", style: TextStyle(color: Colors.white)),
              onTap: () async {
                Navigator.pop(context);
                final success = await _shareDirectlyToApp(imagePaths, preprompt, 'ai.perplexity.app.android');
                if (!success && mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Perplexity not found.')));
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _launchChatGptWithImages(List<String> imagePaths) async {
    if (_isProcessing) return;
    setState(() => _isProcessing = true);

    const preprompt =
        'I am providing you with a photo of my past exam paper. I need you to extract the most important questions and format them strictly according to the rules below. Do not output any conversational text, introductions, or conclusions. Only output the questions.\\n\\n'
        'FORMATTING RULES:\\n'
        '1. PART A (Short Answers): Number all short answer questions sequentially starting from 1. Give [2 Marks] for each question.\\n'
        '2. PART B (Essay Questions): Number the main questions from 11 to 15. Subsections like 11(a), 11(b), etc. Give [13 Marks] total.\\n'
        '3. PART C (Case Study/Application): Number the main question as 16. Give [15 Marks] total.\\n'
        '4. DIFFICULTY RATING: Append 1 to 5 stars (★) at the end of each question.\\n'
        '5. Provide a brief answer key or hints on the lines immediately below each question.\\n\\n'
        'The images I am attaching ARE the exam papers. Please read them carefully.';

    // 1. On Android: Try to open ChatGPT App directly. If not found, show custom AI fallback menu.
    if (Platform.isAndroid) {
      if (!mounted) return;
      setState(() => _promptSent = true);
      
      // Copy prompt to clipboard because some AI apps (like ChatGPT) drop the text when receiving an image intent
      await Clipboard.setData(const ClipboardData(text: preprompt));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Prompt copied! Please paste prompt into the AI app.')),
        );
      }
      
      // Try launching ChatGPT directly
      final success = await _shareDirectlyToApp(imagePaths, preprompt, 'com.openai.chatgpt');
      if (!success) {
        await _showAiFallbackDialog(imagePaths, preprompt);
      }
      return;
    }

    if (Platform.isIOS) {
      if (!mounted) return;
      setState(() => _promptSent = true);
      try {
        await Clipboard.setData(const ClipboardData(text: preprompt));
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Prompt copied! Sending image... Please paste prompt in ChatGPT.')),
          );
        }
        final xFiles = imagePaths.map((p) => XFile(p)).toList();
        await Share.shareXFiles(xFiles, subject: 'Exam Paper');
      } catch (e) {
        debugPrint('Share failed: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Share failed: $e')),
          );
        }
      }
      if (mounted) setState(() => _isProcessing = false); return; // Stop here for iOS
    }

    // Mark prompt as sent — UI will shift to response pane
    if (!mounted) return;
    setState(() => _promptSent = true);

    // 2. On Windows: Save PowerShell script to temp file and run it
    if (Platform.isWindows) {
      try {
        final tempDir = await getTemporaryDirectory();
        
        // Save preprompt to a text file to avoid PowerShell string escaping issues
        final textFile = File('${tempDir.path}\\chatgpt_preprompt.txt');
        await textFile.writeAsString(preprompt);
        final safeTextPath = textFile.path.replaceAll("'", "''");

        // Build PowerShell lines to add each image path sequentially
        final imagePasteBlocks = imagePaths.map((path) {
            final safePath = path.replaceAll('/', r'\').replaceAll("'", "''");
            return '''
  \$singleFile = New-Object System.Collections.Specialized.StringCollection
  \$singleFile.Add('$safePath')
  for (\$i=0; \$i -lt 10; \$i++) {
      try {
          [System.Windows.Forms.Clipboard]::SetFileDropList(\$singleFile)
          break
      } catch { Start-Sleep -Milliseconds 300 }
  }
    Start-Sleep -Milliseconds 500
    \$shell.SendKeys('^v')
    Start-Sleep -Milliseconds 2000
''';
        }).join('\n');

        final scriptFile = File('${tempDir.path}\\paste_sequence.ps1');
        
        final scriptContent = '''
Add-Type -AssemblyName System.Windows.Forms

# Open ChatGPT
Start-Process "https://chatgpt.com"

# Wait for browser window
\$shell = New-Object -ComObject WScript.Shell
\$maxWait = 60
\$elapsed = 0
\$activated = \$false
while (\$elapsed -lt \$maxWait) {
  Start-Sleep -Milliseconds 500
  \$elapsed += 0.5
  foreach (\$title in @('ChatGPT', 'Google Chrome', 'Microsoft Edge', 'Edge', 'Chrome', 'Brave', 'Firefox')) {
    if (\$shell.AppActivate(\$title)) {
      \$activated = \$true
      break
    }
  }
  if (\$activated) {
    break
  }
}

if (\$activated) {
  # Wait for page to fully load (increased for slower internet connections)
  Start-Sleep -Milliseconds 5000

  # Load text from file and copy to clipboard with retry loop
  \$text = [IO.File]::ReadAllText('$safeTextPath')
  for (\$i=0; \$i -lt 10; \$i++) {
      try {
          [System.Windows.Forms.Clipboard]::SetText(\$text)
          break
      } catch { Start-Sleep -Milliseconds 200 }
  }
  Start-Sleep -Milliseconds 300

  # Paste Text
  \$shell.SendKeys('^v')
  
  # Crucial: Wait for ChatGPT's React UI to finish parsing the massive text block before pasting images
  Start-Sleep -Milliseconds 2500

$imagePasteBlocks
}
''';
        await scriptFile.writeAsString(scriptContent);

        // Run the script asynchronously
        Process.start(
          'powershell',
          [
            '-STA',
            '-NoProfile',
            '-ExecutionPolicy', 'Bypass',
            '-WindowStyle', 'Hidden',
            '-File', scriptFile.path
          ],
          runInShell: false,
        );
      } catch (e) {
        debugPrint('PowerShell automation error: $e');
      }
      if (mounted) setState(() => _isProcessing = false); return; // Windows automation complete, exit method
    }

    // 3. Open ChatGPT with preprompt in URL (Desktop fallback / other platforms)
    final url = Uri.parse(
      'https://chatgpt.com/?q=\${Uri.encodeComponent(preprompt)}',
    );
    try {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } catch (e) {
      debugPrint('launchUrl direct failed: $e');
    }
  }

  void _generatePrompt([bool autoLaunch = false, String? imagePathForClipboard]) async {
    final text = _textController.text.trim();
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please paste your raw questions first.',
            style: TextStyle(color: Colors.white),
          ),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    final prompt =
        '''I am providing you with my syllabus/past exam papers. I need you to extract the most important questions and format them strictly according to the rules below. Do not output any conversational text, introductions, or conclusions. Only output the questions.

FORMATTING RULES:
1. PART A (Short Answers): Number all short answer questions sequentially starting from 1 (e.g. 1., 2., 3., etc.). Do NOT group them by units, just provide a continuous list. Give [2 Marks] for each question.
2. PART B (Essay Questions): Number the main questions from 11 to 15. 
   - Subsections MUST be clearly numbered at the start of the line like 11(a), 11(b), 12(a), 12(b)(i), etc.
   - Give [13 Marks] total for each main question (or explicitly split marks among sub-parts).
3. PART C (Case Study/Application): Number the main question as 16. 
   - If it has subsections, format them as 16(a), 16(b), etc.
   - Give [15 Marks] total for this section.
4. DIFFICULTY RATING: Analyze the difficulty/importance of EACH question or sub-part and append 1 to 5 stars (⭐) at the end of the text.
5. Provide a brief answer key or hints on the lines immediately below each question.

Here is my study material:
$text''';

    if (autoLaunch) {
      if (imagePathForClipboard != null) {
        await Pasteboard.writeFiles([imagePathForClipboard]);
      } else {
        Clipboard.setData(ClipboardData(text: prompt)); // Auto copy text just in case
      }
      
      final url = Uri.parse(
        'https://chatgpt.com/?q=${Uri.encodeComponent(prompt)}',
      );
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
        if (mounted) setState(() => _promptSent = true);
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open browser')),
        );
      }
    } else {
      showDialog(
        context: context,
        builder: (context) => _PromptDialog(prompt: prompt),
      );
    }
  }
}

class _PromptDialog extends StatelessWidget {
  final String prompt;
  const _PromptDialog({required this.prompt});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF1E1E1E),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: Colors.white10),
      ),
      title: const Row(
        children: [
          Icon(Icons.auto_awesome, color: Colors.blueAccent),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'ChatGPT Prompt Ready',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
      content: const Text(
        'We have combined your raw questions with our strict formatting rules. You can copy it or open ChatGPT directly. Once ChatGPT answers, paste the result back into the analyzer.',
        style: TextStyle(color: Colors.white70, fontSize: 14, height: 1.4),
      ),
      actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text(
            'CANCEL',
            style: TextStyle(
              color: Colors.white54,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        TextButton(
          onPressed: () {
            Clipboard.setData(ClipboardData(text: prompt));
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Prompt copied to clipboard!'),
                backgroundColor: Colors.green,
              ),
            );
          },
          child: const Text(
            'COPY',
            style: TextStyle(
              color: Colors.blueAccent,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blueAccent,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          onPressed: () async {
            Clipboard.setData(
              ClipboardData(text: prompt),
            ); // Auto copy just in case
            final url = Uri.parse(
              'https://chatgpt.com/?q=${Uri.encodeComponent(prompt)}',
            );
            if (await canLaunchUrl(url)) {
              await launchUrl(url, mode: LaunchMode.externalApplication);
            } else {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Could not open browser. Prompt copied instead.',
                    ),
                    backgroundColor: Colors.orange,
                  ),
                );
              }
            }
          },
          child: const Text(
            'OPEN IN CHATGPT',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }
}
