import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories/question_repository.dart';
import '../../data/repositories/course_repository.dart';
import '../../domain/models/question.dart';
import '../../domain/models/course.dart';
import 'package:exam_command_center/core/theme/app_theme.dart';
import 'package:image_picker/image_picker.dart';
import 'package:desktop_drop/desktop_drop.dart';
import 'dart:io' as io;
import 'dart:async';
import 'dart:convert';
import '../widgets/difficulty_stars.dart';
import 'package:pasteboard/pasteboard.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';

abstract class NoteItem {
  final String id;
  NoteItem(this.id);
}

class NoteTextItem extends NoteItem {
  final TextEditingController controller;
  final FocusNode focusNode;

  NoteTextItem({
    required String id,
    required String initialText,
  })  : controller = TextEditingController(text: initialText),
        focusNode = FocusNode(),
        super(id);

  void dispose() {
    controller.dispose();
    focusNode.dispose();
  }
}

class NoteImageItem extends NoteItem {
  String imagePath;
  int widthPercent; // 25, 50, 75, 100

  NoteImageItem({
    required String id,
    required this.imagePath,
    this.widthPercent = 100,
  }) : super(id);
}

class QuestionDetailScreen extends ConsumerStatefulWidget {
  final int questionId;

  const QuestionDetailScreen({super.key, required this.questionId});

  @override
  ConsumerState<QuestionDetailScreen> createState() => _QuestionDetailScreenState();
}

class _QuestionDetailScreenState extends ConsumerState<QuestionDetailScreen> {
  final _questionController = TextEditingController();
  final _questionFocusNode = FocusNode();
  final List<NoteItem> _noteItems = [];
  String? _selectedImageId;
  bool _isDraggingImage = false;
  String? _draggedImageId;
  bool _hasInitializedNotes = false;
  bool _hasInitializedQuestion = false;
  bool _isDragging = false;
  Timer? _debounce;
  Timer? _questionDebounce;
  Question? _currentQuestion;
  static const _platformChannel = MethodChannel('com.examcommandcenter.direct_share');

  @override
  void initState() {
    super.initState();
    _questionFocusNode.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void didUpdateWidget(covariant QuestionDetailScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.questionId != widget.questionId) {
      _hasInitializedNotes = false;
      _hasInitializedQuestion = false;
      for (final item in _noteItems) {
        if (item is NoteTextItem) item.dispose();
      }
      _noteItems.clear();
      _selectedImageId = null;
    }
  }

  @override
  void dispose() {
    if (_debounce?.isActive ?? false) {
      _debounce!.cancel();
      if (_currentQuestion != null) {
        _saveNotes(_currentQuestion!, silent: true);
      }
    }
    if (_questionDebounce?.isActive ?? false) {
      _questionDebounce!.cancel();
      if (_currentQuestion != null) {
        _saveQuestionNotes(_currentQuestion!, text: _questionController.text, silent: true);
      }
    }
    for (final item in _noteItems) {
      if (item is NoteTextItem) {
        item.dispose();
      }
    }
    _questionFocusNode.dispose();
    _questionController.dispose();
    super.dispose();
  }

  Future<String> _saveFilePermanently(List<int> bytes, String extension) async {
    final docsDir = await getApplicationDocumentsDirectory();
    final fileName = '${const Uuid().v4()}.$extension';
    final savedFile = io.File('${docsDir.path}/$fileName');
    await savedFile.writeAsBytes(bytes);
    return savedFile.path;
  }

  Future<void> _askChatGPT(Question question) async {
    final cRepo = await ref.read(courseRepositoryProvider.future);
    final course = await cRepo.isar.courses.get(question.courseId);
    final courseName = course?.name ?? 'the subject';
    
    await question.unitLink.load();
    final unitName = question.unitLink.value?.name ?? '';
    
    String marksStr = "13 marks";
    if (unitName.contains('Part A')) {
      marksStr = "2 marks";
    } else if (unitName.contains('Part C')) {
      marksStr = "16 marks";
    }
    
    final prompt = "This is a question for $courseName. It is an Anna University question.\n"
        "Since it is from $unitName, provide a $marksStr answer.\n\n"
        "Question:\n${question.title}\n\n"
        "Additional context (if any):\n${_questionController.text}\n\n"
        "Provide the answer in clean text without markdown code blocks so I can copy it easily.";
    
    final encodedPrompt = Uri.encodeComponent(prompt);
    final url = Uri.parse('https://chatgpt.com/?q=$encodedPrompt');
    
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('ChatGPT opened! Copy the answer and paste it into your Notebook.', style: TextStyle(color: Colors.white)), 
            backgroundColor: AppTheme.samsungBlue, 
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 4),
          ),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open browser.', style: TextStyle(color: Colors.white)), backgroundColor: Colors.redAccent, behavior: SnackBarBehavior.floating),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final repoAsync = ref.watch(questionRepositoryProvider);
    final double screenWidth = MediaQuery.of(context).size.width;
    final bool isTablet = screenWidth > 900;
    final double hPad = isTablet ? 32.0 : 16.0;

    return repoAsync.when(
      data: (repo) => StreamBuilder<Question?>(
        stream: repo.isar.questions.watchObject(widget.questionId, fireImmediately: true),
        builder: (context, snapshot) {
          final question = snapshot.data;
          if (question == null) return const Scaffold(body: Center(child: Text('Objective not found')));
          
          _currentQuestion = question;
          if (!_hasInitializedNotes) {
            _initializeNotes(question.userNotes ?? '', question);
            _hasInitializedNotes = true;
          }

          String bannerTitle = question.title;
          bool isPartA = false;
          if (bannerTitle.startsWith(RegExp(r'^\[Unit \d+\]'))) {
            isPartA = true;
            bannerTitle = 'PART A';
          }
          
          if (!_hasInitializedQuestion) {
            String initialText = question.notes ?? '';
            if (isPartA && initialText.isEmpty) {
              initialText = question.title.replaceFirst(RegExp(r'^\[Unit \d+\]\s*'), '');
            }
            _questionController.text = initialText;
            _hasInitializedQuestion = true;
          }

          return DropTarget(
            onDragDone: (detail) async {
              setState(() => _isDragging = false);
              if (detail.files.isEmpty) return;
              
              final orderedFiles = io.Platform.isWindows ? detail.files.reversed.toList() : detail.files.toList();
              
              final docsDir = await getApplicationDocumentsDirectory();
              final newPaths = <String>[];
              
              for (final file in orderedFiles) {
                try {
                  String ext = 'jpg';
                  final lowerPath = file.path.toLowerCase();
                  if (lowerPath.endsWith('.png')) ext = 'png';
                  else if (lowerPath.endsWith('.webp')) ext = 'webp';
                  
                  final fileName = '${const Uuid().v4()}.$ext';
                  final destPath = '${docsDir.path}/$fileName';
                  
                  await file.saveTo(destPath);
                  newPaths.add(destPath);
                } catch (e) {
                  debugPrint('Failed to save dropped file: $e');
                }
              }
              
              if (newPaths.isEmpty) return;

              final repo = await ref.read(questionRepositoryProvider.future);
              await repo.isar.writeTxn(() async {
                final q = await repo.isar.questions.get(widget.questionId);
                if (q != null) {
                  final images = List<String>.from(q.images ?? []);
                  images.addAll(newPaths);
                  q.images = images;
                  await repo.isar.collection<Question>().put(q);
                }
              });
              HapticFeedback.vibrate();
            },
            onDragEntered: (detail) => setState(() => _isDragging = true),
            onDragExited: (detail) => setState(() => _isDragging = false),
            child: Scaffold(
              backgroundColor: AppTheme.black,
              body: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: () {
                  _unfocusAllNotes();
                  _questionFocusNode.unfocus();
                  FocusScope.of(context).unfocus();
                  if (_selectedImageId != null) {
                    setState(() => _selectedImageId = null);
                  }
                },
                child: CustomScrollView(
                  keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                  physics: const BouncingScrollPhysics(),
                  slivers: [
                // ONE UI DYNAMIC HEADER
                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(hPad, 60, hPad, 32),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        GestureDetector(
                          onTap: () => Navigator.pop(context),
                          child: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), shape: BoxShape.circle),
                            child: const Icon(Icons.arrow_back_ios_new, size: 20, color: AppTheme.textPrimary),
                          ),
                        ),
                        const SizedBox(height: 24),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(
                                bannerTitle,
                                style: Theme.of(context).textTheme.displayLarge?.copyWith(fontSize: 28),
                              ),
                            ),
                            const SizedBox(width: 16),
                            DifficultyStars(question: question, size: 24),
                          ],
                        ),
                        const Text('MISSION OBJECTIVE DETAILS', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
                        const SizedBox(height: 16),
                        _buildIOSSegmentedControl(context, question),
                      ],
                    ),
                  ),
                ),

                SliverPadding(
                  padding: EdgeInsets.symmetric(horizontal: hPad),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      // 3. QUESTION CARD (AI Analysis Leftovers)
                      _buildOneUICard(
                        title: 'Question',
                        padding: const EdgeInsets.all(16),
                        child: TextField(
                          controller: _questionController,
                          focusNode: _questionFocusNode,
                          maxLines: null,
                          minLines: 1,
                          textInputAction: TextInputAction.done,
                          onEditingComplete: () {
                            _questionFocusNode.unfocus();
                            FocusScope.of(context).unfocus();
                            _saveQuestionNotes(question, text: _questionController.text);
                          },
                          contextMenuBuilder: (context, editableTextState) {
                            final List<ContextMenuButtonItem> buttonItems = editableTextState.contextMenuButtonItems;
                            final int pasteIndex = buttonItems.indexWhere((item) => item.type == ContextMenuButtonType.paste);
                            if (pasteIndex != -1) {
                              final originalPaste = buttonItems[pasteIndex].onPressed;
                              buttonItems[pasteIndex] = buttonItems[pasteIndex].copyWith(
                                onPressed: () {
                                  if (originalPaste != null) originalPaste();
                                  Future.microtask(() {
                                    _questionFocusNode.unfocus();
                                    FocusScope.of(context).unfocus();
                                    _saveQuestionNotes(question, text: _questionController.text);
                                  });
                                },
                              );
                            }
                            return AdaptiveTextSelectionToolbar.buttonItems(
                              anchors: editableTextState.contextMenuAnchors,
                              buttonItems: buttonItems,
                            );
                          },
                          style: GoogleFonts.inter(
                            fontSize: 15, 
                            fontWeight: FontWeight.w400, 
                            color: AppTheme.textPrimary, 
                            height: 1.6,
                          ),
                          onChanged: (val) {
                            if (_questionDebounce?.isActive ?? false) _questionDebounce!.cancel();
                            _questionDebounce = Timer(const Duration(milliseconds: 300), () {
                              _saveQuestionNotes(question, text: val, silent: true);
                            });
                          },
                          decoration: InputDecoration(
                            hintText: 'Paste or type question details here...',
                            hintStyle: const TextStyle(color: Colors.white38),
                            filled: true,
                            fillColor: AppTheme.black.withOpacity(0.4),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                            contentPadding: const EdgeInsets.all(12),
                          ),
                        ),
                      ),

                      const SizedBox(height: 16),

                      // 4. NOTES CARD (User Notepad)
                      _buildOneUICard(
                        title: 'Notebook',
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (_hasAnyNoteFocus() || _selectedImageId != null)
                              Padding(
                                padding: const EdgeInsets.only(right: 6),
                                child: TextButton(
                                  onPressed: () {
                                    _unfocusAllNotes();
                                    FocusScope.of(context).unfocus();
                                    if (_selectedImageId != null) {
                                      setState(() => _selectedImageId = null);
                                    }
                                    _saveNotes(question);
                                  },
                                  style: TextButton.styleFrom(
                                    backgroundColor: Colors.white.withOpacity(0.12),
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                                    minimumSize: const Size(0, 30),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                  ),
                                  child: const Text('DONE', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 11, letterSpacing: 0.5)),
                                ),
                              ),
                            IconButton(
                              onPressed: () => _pickImageIntoNotebook(question),
                              icon: const Icon(Icons.add_photo_alternate_outlined, size: 18, color: Colors.white),
                              tooltip: 'Insert Image',
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(minWidth: 32, minHeight: 30),
                            ),
                            const SizedBox(width: 4),
                            TextButton.icon(
                              onPressed: () => _pasteIntoNotebook(question),
                              icon: const Icon(Icons.content_paste_rounded, size: 13, color: Colors.white),
                              label: const Text('PASTE', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 11, letterSpacing: 0.5)),
                              style: TextButton.styleFrom(
                                backgroundColor: Colors.white.withOpacity(0.08),
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                                minimumSize: const Size(0, 30),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              ),
                            ),
                            const SizedBox(width: 6),
                            TextButton.icon(
                              onPressed: () => _askChatGPT(question),
                              icon: const Icon(Icons.auto_awesome, size: 13, color: Colors.white),
                              label: const Text('Generate', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 11, letterSpacing: 0.5)),
                              style: TextButton.styleFrom(
                                backgroundColor: Colors.white.withOpacity(0.08),
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                                minimumSize: const Size(0, 30),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              ),
                            ),
                          ],
                        ),
                        padding: const EdgeInsets.all(16),
                        child: _buildNotebookContent(question),
                      ),

                      const SizedBox(height: 16),

                      // 5. ANSWER RESOURCES (ATTACHMENTS)
                      Stack(
                        children: [
                          _buildOneUICard(
                            title: 'Answer Resources',
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (question.images != null && question.images!.isNotEmpty)
                              IconButton(
                                icon: const Icon(Icons.delete_outline, color: AppTheme.urgentColor, size: 24),
                                onPressed: () async {
                                  final repo = await ref.read(questionRepositoryProvider.future);
                                  await repo.isar.writeTxn(() async {
                                    final q = await repo.isar.questions.get(question.id);
                                    if (q != null) {
                                      q.images = [];
                                      await repo.isar.questions.put(q);
                                    }
                                  });
                                },
                              ),
                            IconButton(
                              icon: const Icon(Icons.add_photo_alternate_outlined, color: Colors.white, size: 24),
                              onPressed: () => _showAttachmentOptions(context, question),
                            ),
                          ],
                        ),
                        child: GestureDetector(
                          onDoubleTap: () => _showAttachmentOptions(context, question),
                          child: Column(
                            children: [
                              if (question.images == null || question.images!.isEmpty)
                                Padding(
                                  padding: const EdgeInsets.all(32.0),
                                  child: Column(
                                    children: [
                                      Icon(Icons.folder_open_outlined, size: 48, color: AppTheme.textSecondary.withOpacity(0.1)),
                                      const SizedBox(height: 12),
                                      const Text('No assets attached. Double tap to add.', style: TextStyle(color: AppTheme.textSecondary, fontWeight: FontWeight.w600, fontSize: 14)),
                                    ],
                                  ),
                                )
                              else
                                ListView.builder(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  itemCount: question.images!.length,
                                  itemBuilder: (context, index) {
                                    final path = question.images![index];
                                    return Padding(
                                      key: ValueKey(path),
                                      padding: const EdgeInsets.only(bottom: 16),
                                      child: _buildAssetTile(question, path, index),
                                    );
                                  },
                                ),
                            ],
                          ),
                        ),
                      ),
                      if (_isDragging)
                        Positioned.fill(
                          child: Container(
                            decoration: BoxDecoration(
                              color: AppTheme.sidebarSurface.withOpacity(0.9),
                              borderRadius: BorderRadius.circular(AppTheme.cardRadius),
                              border: Border.all(color: AppTheme.samsungBlue, width: 2),
                            ),
                            child: Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: const [
                                  Icon(Icons.file_download, size: 48, color: AppTheme.samsungBlue),
                                  SizedBox(height: 8),
                                  Text('Drop files to attach', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                                ],
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),

                      const SizedBox(height: 150),
                    ]),
                  ),
                ),
              ],
            ),
            ),
          ),
        );
        },
      ),
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, s) => Scaffold(body: Center(child: Text('Error: $e'))),
    );
  }

  Widget _buildOneUICard({required String title, required Widget child, Widget? trailing, EdgeInsetsGeometry? padding}) {
    return Container(
      padding: padding ?? const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.transparent, // Flat design
        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
        border: Border.all(color: Colors.white24, width: 1.5), // White flat border
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title.toUpperCase(), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Colors.white54, letterSpacing: 2.5)),
              if (trailing != null) trailing,
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }

  Widget _buildAssetTile(Question question, String path, int index) {
    return Stack(
      children: [
        GestureDetector(
          onTap: () => _openFullscreenImage(context, path),
          onLongPress: () => _showUniversalImageSheet(
            context: context,
            imagePath: path,
            question: question,
            isFromNotebook: false,
          ),
          child: Container(
            width: double.infinity,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withOpacity(0.05)),
            ),
            clipBehavior: Clip.antiAlias,
            child: Image.file(
              io.File(path), 
              fit: BoxFit.fitWidth,
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  height: 200, 
                  color: AppTheme.selectedTile, 
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Icon(Icons.broken_image_outlined, size: 32, color: Colors.white54),
                      SizedBox(height: 8),
                      Text('Image not found on this device', style: TextStyle(color: Colors.white54, fontSize: 12)),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
        Positioned(
          top: 8,
          right: 8,
          child: GestureDetector(
            onTap: () => _removeAttachment(question, index),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: const BoxDecoration(color: Colors.black87, shape: BoxShape.circle),
              child: const Icon(Icons.close, size: 16, color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildIOSSegmentedControl(BuildContext context, Question question) {
    int selectedIndex = 0;
    if (question.status == QuestionStatus.revisionNeeded) selectedIndex = 1;
    if (question.status == QuestionStatus.completed) selectedIndex = 2;

    Color thumbColor;
    switch (question.status) {
      case QuestionStatus.completed:
        thumbColor = AppTheme.completedColor.withOpacity(0.25);
        break;
      case QuestionStatus.revisionNeeded:
        thumbColor = AppTheme.inProgressColor.withOpacity(0.25);
        break;
      case QuestionStatus.incomplete:
        thumbColor = Colors.white.withOpacity(0.2);
        break;
    }

    return Container(
      width: double.infinity,
      height: 40,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(100),
      ),
      child: Stack(
        children: [
          // Sliding Thumb
          AnimatedAlign(
            alignment: Alignment(
              selectedIndex == 0 ? -1.0 : (selectedIndex == 1 ? 0.0 : 1.0),
              0.0,
            ),
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOutCubic,
            child: FractionallySizedBox(
              widthFactor: 1.0 / 3.0,
              heightFactor: 1.0,
              child: Padding(
                padding: const EdgeInsets.all(2.0),
                child: Container(
                  decoration: BoxDecoration(
                    color: thumbColor,
                    borderRadius: BorderRadius.circular(100),
                  ),
                ),
              ),
            ),
          ),
          // Segments
          Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildCustomSegment(
                label: 'PENDING',
                icon: Icons.radio_button_unchecked,
                isSelected: question.status == QuestionStatus.incomplete,
                activeColor: Colors.white,
                onTap: () => _updateStatus(QuestionStatus.incomplete),
              ),
              _buildCustomSegment(
                label: 'REVISE',
                icon: Icons.autorenew,
                isSelected: question.status == QuestionStatus.revisionNeeded,
                activeColor: AppTheme.inProgressColor,
                onTap: () => _updateStatus(QuestionStatus.revisionNeeded),
              ),
              _buildCustomSegment(
                label: 'COMPLETED',
                icon: Icons.verified,
                isSelected: question.status == QuestionStatus.completed,
                activeColor: AppTheme.completedColor,
                onTap: () => _updateStatus(QuestionStatus.completed),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCustomSegment({
    required String label,
    required IconData icon,
    required bool isSelected,
    required Color activeColor,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          color: Colors.transparent,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 12, color: isSelected ? activeColor : Colors.white54),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: isSelected ? activeColor : Colors.white54,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _updateStatus(QuestionStatus status) async {
    final repo = await ref.read(questionRepositoryProvider.future);
    await repo.updateStatus(widget.questionId, status);
    HapticFeedback.mediumImpact();
  }

  Future<Uint8List?> _readBytesFromNativeUri(String uriStr) async {
    try {
      final bytes = await _platformChannel.invokeMethod<Uint8List>('readUriBytes', {'uri': uriStr});
      return bytes;
    } catch (e) {
      debugPrint('readUriBytes error: $e');
      return null;
    }
  }

  Future<Uint8List?> _getNativeClipboardImage() async {
    try {
      final bytes = await _platformChannel.invokeMethod<Uint8List>('getClipboardImage');
      return bytes;
    } catch (e) {
      debugPrint('getClipboardImage error: $e');
      return null;
    }
  }

  void _ensureTrailingTextItem(Question question) {
    if (_noteItems.isEmpty || _noteItems.last is NoteImageItem) {
      _createAndAddTextItem('', question);
    }
  }

  void _initializeNotes(String rawNotes, Question question) {
    for (final item in _noteItems) {
      if (item is NoteTextItem) item.dispose();
    }
    _noteItems.clear();

    final matches = RegExp(r'<<IMG:(\d+):(.*?)>>').allMatches(rawNotes);
    int lastEnd = 0;

    for (final match in matches) {
      if (match.start > lastEnd) {
        final textPart = rawNotes.substring(lastEnd, match.start);
        _checkAndAddTextSegment(textPart, question);
      }
      final width = int.tryParse(match.group(1) ?? '100') ?? 100;
      final path = match.group(2) ?? '';
      _noteItems.add(NoteImageItem(
        id: const Uuid().v4(),
        imagePath: path,
        widthPercent: width,
      ));
      lastEnd = match.end;
    }

    if (lastEnd < rawNotes.length) {
      _checkAndAddTextSegment(rawNotes.substring(lastEnd), question);
    }

    _consolidateAdjacentTextItems();
    _ensureTrailingTextItem(question);
  }

  void _checkAndAddTextSegment(String text, Question question) {
    // Auto-heal any content:// URI that was pasted as raw text previously
    final uriMatch = RegExp(r'content://\S+').firstMatch(text);
    if (uriMatch != null) {
      final uriStr = uriMatch.group(0)!;
      final cleanedText = text.replaceFirst(uriStr, '').trim();
      if (cleanedText.isNotEmpty) {
        _createAndAddTextItem(cleanedText, question);
      }
      _readBytesFromNativeUri(uriStr).then((bytes) async {
        if (bytes != null && bytes.isNotEmpty) {
          final savedPath = await _saveFilePermanently(bytes, 'jpg');
          _noteItems.add(NoteImageItem(
            id: const Uuid().v4(),
            imagePath: savedPath,
            widthPercent: 100,
          ));
          _ensureTrailingTextItem(question);
          _saveNotes(question, text: _serializeNotes());
          if (mounted) setState(() {});
        }
      });
      return;
    }

    // Auto-heal any base64 data URI that was pasted as raw text
    if (text.startsWith('data:image/') && text.contains('base64,')) {
      try {
        final base64Str = text.substring(text.indexOf('base64,') + 7).trim();
        final bytes = base64Decode(base64Str);
        if (bytes.isNotEmpty) {
          _saveFilePermanently(bytes, 'jpg').then((savedPath) {
            _noteItems.add(NoteImageItem(
              id: const Uuid().v4(),
              imagePath: savedPath,
              widthPercent: 100,
            ));
            _ensureTrailingTextItem(question);
            _saveNotes(question, text: _serializeNotes());
            if (mounted) setState(() {});
          });
          return;
        }
      } catch (_) {}
    }

    _createAndAddTextItem(text, question);
  }

  NoteTextItem _createAndAddTextItem(String text, Question question) {
    final item = NoteTextItem(
      id: const Uuid().v4(),
      initialText: text,
    );
    item.focusNode.addListener(() {
      if (mounted) setState(() {});
    });
    item.controller.addListener(() {
      if (_debounce?.isActive ?? false) _debounce!.cancel();
      _debounce = Timer(const Duration(milliseconds: 300), () {
        if (_currentQuestion != null) {
          _saveNotes(_currentQuestion!, silent: true);
        }
      });
    });
    _noteItems.add(item);
    return item;
  }

  String _serializeNotes() {
    final sb = StringBuffer();
    for (final item in _noteItems) {
      if (item is NoteTextItem) {
        sb.write(item.controller.text);
      } else if (item is NoteImageItem) {
        sb.write('<<IMG:${item.widthPercent}:${item.imagePath}>>');
      }
    }
    return sb.toString();
  }

  bool _hasAnyNoteFocus() {
    for (final item in _noteItems) {
      if (item is NoteTextItem && item.focusNode.hasFocus) {
        return true;
      }
    }
    return false;
  }

  void _unfocusAllNotes() {
    for (final item in _noteItems) {
      if (item is NoteTextItem) {
        item.focusNode.unfocus();
      }
    }
  }

  Future<void> _pasteIntoNotebook(Question question) async {
    // 1. Try native Android ClipboardManager via MethodChannel (resolves content:// URIs directly!)
    try {
      final nativeBytes = await _getNativeClipboardImage();
      if (nativeBytes != null && nativeBytes.isNotEmpty) {
        final savedPath = await _saveFilePermanently(nativeBytes, 'jpg');
        _insertImageItemAtCursorOrEnd(savedPath, question);
        _unfocusAllNotes();
        FocusScope.of(context).unfocus();
        setState(() => _selectedImageId = null);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Image pasted into Notebook!'),
              backgroundColor: Colors.white24,
              duration: Duration(seconds: 2),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        return;
      }
    } catch (e) {
      debugPrint('Native clipboard check: $e');
    }

    // 2. Try Pasteboard.image
    try {
      final imageBytes = await Pasteboard.image;
      if (imageBytes != null && imageBytes.isNotEmpty) {
        final savedPath = await _saveFilePermanently(imageBytes, 'jpg');
        _insertImageItemAtCursorOrEnd(savedPath, question);
        _unfocusAllNotes();
        FocusScope.of(context).unfocus();
        setState(() => _selectedImageId = null);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Image pasted into Notebook!'),
              backgroundColor: Colors.white24,
              duration: Duration(seconds: 2),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        return;
      }
    } catch (e) {
      debugPrint('Pasteboard image check failed: $e');
    }

    // 3. Try Pasteboard.files()
    try {
      final files = await Pasteboard.files();
      if (files.isNotEmpty) {
        for (final p in files) {
          if (p.startsWith('content://') || p.startsWith('file://')) {
            final bytes = await _readBytesFromNativeUri(p);
            if (bytes != null && bytes.isNotEmpty) {
              final savedPath = await _saveFilePermanently(bytes, 'jpg');
              _insertImageItemAtCursorOrEnd(savedPath, question);
              _unfocusAllNotes();
              FocusScope.of(context).unfocus();
              setState(() => _selectedImageId = null);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Image pasted into Notebook!'),
                    backgroundColor: Colors.white24,
                    duration: Duration(seconds: 2),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
              return;
            }
          } else {
            final f = io.File(p);
            if (await f.exists()) {
              final bytes = await f.readAsBytes();
              final savedPath = await _saveFilePermanently(bytes, 'jpg');
              _insertImageItemAtCursorOrEnd(savedPath, question);
              _unfocusAllNotes();
              FocusScope.of(context).unfocus();
              setState(() => _selectedImageId = null);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Image pasted into Notebook!'),
                    backgroundColor: Colors.white24,
                    duration: Duration(seconds: 2),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
              return;
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Pasteboard file check failed: $e');
    }

    // 4. Fallback to Clipboard.getData(Clipboard.kTextPlain)
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data != null && data.text != null && data.text!.isNotEmpty) {
      final text = data.text!.trim();

      // Check if text is a content:// or file:// URI (Samsung keyboard image copy)
      if (text.startsWith('content://') || text.startsWith('file://')) {
        final bytes = await _readBytesFromNativeUri(text);
        if (bytes != null && bytes.isNotEmpty) {
          final savedPath = await _saveFilePermanently(bytes, 'jpg');
          _insertImageItemAtCursorOrEnd(savedPath, question);
          _unfocusAllNotes();
          FocusScope.of(context).unfocus();
          setState(() => _selectedImageId = null);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Image pasted into Notebook!'),
                backgroundColor: Colors.white24,
                duration: Duration(seconds: 2),
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
          return;
        }
      }

      // Check if text is a Base64 data URI
      if (text.startsWith('data:image/') && text.contains('base64,')) {
        try {
          final base64Str = text.substring(text.indexOf('base64,') + 7).trim();
          final bytes = base64Decode(base64Str);
          if (bytes.isNotEmpty) {
            final savedPath = await _saveFilePermanently(bytes, 'jpg');
            _insertImageItemAtCursorOrEnd(savedPath, question);
            _unfocusAllNotes();
            FocusScope.of(context).unfocus();
            setState(() => _selectedImageId = null);
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Image pasted into Notebook!'),
                  backgroundColor: Colors.white24,
                  duration: Duration(seconds: 2),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            }
            return;
          }
        } catch (e) {
          debugPrint('Base64 decode error: $e');
        }
      }

      // Plain human text!
      _insertTextItemAtCursorOrEnd(data.text!, question);
      _unfocusAllNotes();
      FocusScope.of(context).unfocus();
      setState(() => _selectedImageId = null);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Pasted and saved to Notebook!'),
            backgroundColor: Colors.white24,
            duration: Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Clipboard is empty!'),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _pickImageIntoNotebook(Question question) async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      final bytes = await image.readAsBytes();
      final savedPath = await _saveFilePermanently(bytes, 'jpg');
      _insertImageItemAtCursorOrEnd(savedPath, question);
      _unfocusAllNotes();
      FocusScope.of(context).unfocus();
      setState(() => _selectedImageId = null);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Image added to Notebook!'),
            backgroundColor: Colors.white24,
            duration: Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _insertImageItemAtCursorOrEnd(String imagePath, Question question) {
    int focusedIndex = -1;
    NoteTextItem? focusedTextItem;
    for (int i = 0; i < _noteItems.length; i++) {
      final it = _noteItems[i];
      if (it is NoteTextItem && it.focusNode.hasFocus) {
        focusedIndex = i;
        focusedTextItem = it;
        break;
      }
    }

    final newImageItem = NoteImageItem(
      id: const Uuid().v4(),
      imagePath: imagePath,
      widthPercent: 100,
    );

    if (focusedTextItem != null && focusedIndex != -1) {
      final text = focusedTextItem.controller.text;
      int offset = focusedTextItem.controller.selection.baseOffset;
      if (offset < 0 || offset > text.length) {
        offset = text.length;
      }

      int lineEnd = text.indexOf('\n', offset);
      if (lineEnd == -1) {
        lineEnd = text.length;
      } else {
        lineEnd += 1;
      }

      final textBefore = text.substring(0, lineEnd);
      final textAfter = text.substring(lineEnd);

      focusedTextItem.controller.text = textBefore;

      final afterTextItem = NoteTextItem(
        id: const Uuid().v4(),
        initialText: textAfter,
      );
      afterTextItem.focusNode.addListener(() { if (mounted) setState(() {}); });
      afterTextItem.controller.addListener(() {
        if (_debounce?.isActive ?? false) _debounce!.cancel();
        _debounce = Timer(const Duration(milliseconds: 300), () {
          if (_currentQuestion != null) _saveNotes(_currentQuestion!, silent: true);
        });
      });

      _noteItems.insert(focusedIndex + 1, newImageItem);
      _noteItems.insert(focusedIndex + 2, afterTextItem);
    } else {
      _noteItems.add(newImageItem);
      final afterTextItem = NoteTextItem(
        id: const Uuid().v4(),
        initialText: '',
      );
      afterTextItem.focusNode.addListener(() { if (mounted) setState(() {}); });
      afterTextItem.controller.addListener(() {
        if (_debounce?.isActive ?? false) _debounce!.cancel();
        _debounce = Timer(const Duration(milliseconds: 300), () {
          if (_currentQuestion != null) _saveNotes(_currentQuestion!, silent: true);
        });
      });
      _noteItems.add(afterTextItem);
    }

    _consolidateAdjacentTextItems();
    _saveNotes(question, text: _serializeNotes());
    setState(() {});
  }

  void _insertTextItemAtCursorOrEnd(String textToInsert, Question question) {
    NoteTextItem? focusedTextItem;
    for (int i = 0; i < _noteItems.length; i++) {
      final it = _noteItems[i];
      if (it is NoteTextItem && it.focusNode.hasFocus) {
        focusedTextItem = it;
        break;
      }
    }

    if (focusedTextItem != null) {
      final cur = focusedTextItem.controller.text;
      final sel = focusedTextItem.controller.selection;
      if (sel.isValid && sel.baseOffset >= 0) {
        final newText = cur.replaceRange(sel.start, sel.end, textToInsert);
        focusedTextItem.controller.text = newText;
      } else {
        focusedTextItem.controller.text = cur + textToInsert;
      }
    } else {
      if (_noteItems.isNotEmpty && _noteItems.last is NoteTextItem) {
        final last = _noteItems.last as NoteTextItem;
        if (last.controller.text.isEmpty) {
          last.controller.text = textToInsert;
        } else {
          last.controller.text = '${last.controller.text}\n$textToInsert';
        }
      } else {
        final item = NoteTextItem(id: const Uuid().v4(), initialText: textToInsert);
        item.focusNode.addListener(() { if (mounted) setState(() {}); });
        item.controller.addListener(() {
          if (_debounce?.isActive ?? false) _debounce!.cancel();
          _debounce = Timer(const Duration(milliseconds: 300), () {
            if (_currentQuestion != null) _saveNotes(_currentQuestion!, silent: true);
          });
        });
        _noteItems.add(item);
      }
    }

    _saveNotes(question, text: _serializeNotes());
    setState(() {});
  }

  void _updateNoteImageWidth(String noteImageId, int widthPercent, Question question) {
    for (final it in _noteItems) {
      if (it is NoteImageItem && it.id == noteImageId) {
        it.widthPercent = widthPercent;
        break;
      }
    }
    _saveNotes(question, text: _serializeNotes());
    setState(() {});
  }

  void _moveImageUp(int imageIndex, Question question) {
    if (imageIndex <= 0) return;

    final prevItem = _noteItems[imageIndex - 1];
    if (prevItem is NoteImageItem) {
      final img = _noteItems.removeAt(imageIndex);
      _noteItems.insert(imageIndex - 1, img);
    } else if (prevItem is NoteTextItem) {
      final text = prevItem.controller.text;
      final lines = text.split('\n');
      if (lines.length > 1) {
        String lineToMove = lines.removeLast();
        if (lineToMove.isEmpty && lines.isNotEmpty) {
          lineToMove = lines.removeLast();
        }
        prevItem.controller.text = lines.join('\n');

        if (imageIndex + 1 < _noteItems.length && _noteItems[imageIndex + 1] is NoteTextItem) {
          final nextText = _noteItems[imageIndex + 1] as NoteTextItem;
          final cur = nextText.controller.text;
          nextText.controller.text = cur.isEmpty ? lineToMove : '$lineToMove\n$cur';
        } else {
          final newItem = NoteTextItem(id: const Uuid().v4(), initialText: lineToMove);
          newItem.focusNode.addListener(() { if (mounted) setState(() {}); });
          newItem.controller.addListener(() {
            if (_debounce?.isActive ?? false) _debounce!.cancel();
            _debounce = Timer(const Duration(milliseconds: 300), () {
              if (_currentQuestion != null) _saveNotes(_currentQuestion!, silent: true);
            });
          });
          _noteItems.insert(imageIndex + 1, newItem);
        }
      } else {
        final img = _noteItems.removeAt(imageIndex);
        _noteItems.insert(imageIndex - 1, img);
      }
    }

    _consolidateAdjacentTextItems();
    if (_noteItems.isEmpty || _noteItems.last is NoteImageItem) {
      _createAndAddTextItem('', question);
    }
    _saveNotes(question, text: _serializeNotes());
    setState(() {});
  }

  void _moveImageDown(int imageIndex, Question question) {
    if (imageIndex >= _noteItems.length - 1) return;

    final nextItem = _noteItems[imageIndex + 1];
    if (nextItem is NoteImageItem) {
      final img = _noteItems.removeAt(imageIndex);
      _noteItems.insert(imageIndex + 1, img);
    } else if (nextItem is NoteTextItem) {
      final text = nextItem.controller.text;
      final lines = text.split('\n');
      if (lines.length > 1) {
        String lineToMove = lines.removeAt(0);
        nextItem.controller.text = lines.join('\n');

        if (imageIndex - 1 >= 0 && _noteItems[imageIndex - 1] is NoteTextItem) {
          final prevText = _noteItems[imageIndex - 1] as NoteTextItem;
          final cur = prevText.controller.text;
          prevText.controller.text = cur.isEmpty ? lineToMove : '$cur\n$lineToMove';
        } else {
          final newItem = NoteTextItem(id: const Uuid().v4(), initialText: lineToMove);
          newItem.focusNode.addListener(() { if (mounted) setState(() {}); });
          newItem.controller.addListener(() {
            if (_debounce?.isActive ?? false) _debounce!.cancel();
            _debounce = Timer(const Duration(milliseconds: 300), () {
              if (_currentQuestion != null) _saveNotes(_currentQuestion!, silent: true);
            });
          });
          _noteItems.insert(imageIndex, newItem);
        }
      } else {
        final img = _noteItems.removeAt(imageIndex);
        _noteItems.insert(imageIndex + 1, img);
      }
    }

    _consolidateAdjacentTextItems();
    if (_noteItems.isEmpty || _noteItems.last is NoteImageItem) {
      _createAndAddTextItem('', question);
    }
    _saveNotes(question, text: _serializeNotes());
    setState(() {});
  }

  void _consolidateAdjacentTextItems() {
    for (int i = 0; i < _noteItems.length - 1; i++) {
      if (_noteItems[i] is NoteTextItem && _noteItems[i + 1] is NoteTextItem) {
        final a = _noteItems[i] as NoteTextItem;
        final b = _noteItems[i + 1] as NoteTextItem;
        final sep = (a.controller.text.isNotEmpty && b.controller.text.isNotEmpty && !a.controller.text.endsWith('\n')) ? '\n' : '';
        a.controller.text = a.controller.text + sep + b.controller.text;
        b.dispose();
        _noteItems.removeAt(i + 1);
        i--;
      }
    }
  }

  void _deleteImageFromNote(String noteImageId, Question question) {
    final index = _noteItems.indexWhere((it) => it.id == noteImageId);
    if (index == -1) return;

    _noteItems.removeAt(index);
    _consolidateAdjacentTextItems();

    if (_selectedImageId == noteImageId) {
      _selectedImageId = null;
    }

    if (_noteItems.isEmpty || _noteItems.last is NoteImageItem) {
      _createAndAddTextItem('', question);
    }

    _saveNotes(question, text: _serializeNotes());
    setState(() {});
  }

  void _moveImageBetweenLines(String textItemId, int lineIndex, Question question) {
    if (_draggedImageId == null) return;

    final imageIndex = _noteItems.indexWhere((it) => it.id == _draggedImageId);
    final targetTextIndex = _noteItems.indexWhere((it) => it.id == textItemId);

    if (imageIndex == -1 || targetTextIndex == -1) {
      setState(() {
        _isDraggingImage = false;
        _draggedImageId = null;
      });
      return;
    }

    final targetTextItem = _noteItems[targetTextIndex] as NoteTextItem;
    final lines = targetTextItem.controller.text.split('\n');

    final img = _noteItems.removeAt(imageIndex);

    // Re-find targetTextIndex after removal
    final curTargetIndex = _noteItems.indexOf(targetTextItem);
    if (curTargetIndex == -1) {
      _noteItems.add(img);
    } else if (lineIndex <= 0) {
      // Place before the text item
      _noteItems.insert(curTargetIndex, img);
    } else if (lineIndex >= lines.length) {
      // Place after the text item
      _noteItems.insert(curTargetIndex + 1, img);
    } else {
      // Place between lines: split the text item into two
      final linesBefore = lines.sublist(0, lineIndex).join('\n');
      final linesAfter = lines.sublist(lineIndex).join('\n');

      targetTextItem.controller.text = linesBefore;

      final afterTextItem = NoteTextItem(
        id: const Uuid().v4(),
        initialText: linesAfter,
      );
      afterTextItem.focusNode.addListener(() { if (mounted) setState(() {}); });
      afterTextItem.controller.addListener(() {
        if (_debounce?.isActive ?? false) _debounce!.cancel();
        _debounce = Timer(const Duration(milliseconds: 300), () {
          if (_currentQuestion != null) _saveNotes(_currentQuestion!, silent: true);
        });
      });

      _noteItems.insert(curTargetIndex + 1, img);
      _noteItems.insert(curTargetIndex + 2, afterTextItem);
    }

    _consolidateAdjacentTextItems();
    if (_noteItems.isEmpty || _noteItems.last is NoteImageItem) {
      _createAndAddTextItem('', question);
    }

    _isDraggingImage = false;
    _draggedImageId = null;
    _saveNotes(question, text: _serializeNotes());
    setState(() {});
  }

  void _moveImageToItemIndex(int targetIndex, Question question) {
    if (_draggedImageId == null) return;
    final imageIndex = _noteItems.indexWhere((it) => it.id == _draggedImageId);
    if (imageIndex == -1) {
      setState(() {
        _isDraggingImage = false;
        _draggedImageId = null;
      });
      return;
    }

    final img = _noteItems.removeAt(imageIndex);
    final dest = targetIndex.clamp(0, _noteItems.length);
    _noteItems.insert(dest, img);

    _consolidateAdjacentTextItems();
    if (_noteItems.isEmpty || _noteItems.last is NoteImageItem) {
      _createAndAddTextItem('', question);
    }

    _isDraggingImage = false;
    _draggedImageId = null;
    _saveNotes(question, text: _serializeNotes());
    setState(() {});
  }

  Widget _buildDropTargetSlot({required VoidCallback onAccept, String label = 'PLACE IMAGE HERE'}) {
    return DragTarget<String>(
      onWillAcceptWithDetails: (details) => true,
      builder: (context, candidateData, rejectedData) {
        final isHovered = candidateData.isNotEmpty;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOut,
          margin: const EdgeInsets.symmetric(vertical: 4),
          padding: EdgeInsets.symmetric(vertical: isHovered ? 12 : 6, horizontal: 8),
          decoration: BoxDecoration(
            color: isHovered ? Colors.white.withOpacity(0.15) : Colors.white.withOpacity(0.04),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isHovered ? Colors.white : Colors.white24,
              width: isHovered ? 1.5 : 0.8,
            ),
          ),
          child: Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.add_circle_outline_rounded,
                  size: isHovered ? 14 : 11,
                  color: isHovered ? Colors.white : Colors.white54,
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    label,
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                    style: TextStyle(
                      color: isHovered ? Colors.white : Colors.white54,
                      fontSize: isHovered ? 11 : 9,
                      fontWeight: isHovered ? FontWeight.w700 : FontWeight.w500,
                      letterSpacing: 0.6,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
      onAcceptWithDetails: (details) {
        HapticFeedback.mediumImpact();
        onAccept();
      },
    );
  }

  Widget _buildDraggingTextItem(NoteTextItem item, Question question) {
    final text = item.controller.text;
    final lines = text.split('\n');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildDropTargetSlot(
          onAccept: () => _moveImageBetweenLines(item.id, 0, question),
          label: 'DROP BEFORE LINE 1',
        ),
        for (int l = 0; l < lines.length; l++) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 4),
            child: Text(
              lines[l].isEmpty ? ' ' : lines[l],
              style: GoogleFonts.inter(
                fontSize: 15,
                fontWeight: FontWeight.w400,
                color: AppTheme.textPrimary.withOpacity(0.85),
                height: 1.6,
              ),
            ),
          ),
          _buildDropTargetSlot(
            onAccept: () => _moveImageBetweenLines(item.id, l + 1, question),
            label: 'DROP AFTER: "${lines[l].length > 20 ? '${lines[l].substring(0, 20)}...' : lines[l]}"',
          ),
        ],
      ],
    );
  }

  Widget _buildNotebookContent(Question question) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.black.withOpacity(0.4),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_isDraggingImage) ...[
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  const Icon(Icons.touch_app_rounded, size: 14, color: Colors.white70),
                  const SizedBox(width: 6),
                  Text(
                    'Drop into any slot between lines to place image',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.white70,
                    ),
                  ),
                ],
              ),
            ),
            _buildDropTargetSlot(
              onAccept: () => _moveImageToItemIndex(0, question),
              label: 'DROP AT TOP OF NOTEBOOK',
            ),
          ],
          for (int i = 0; i < _noteItems.length; i++) ...[
            if (_noteItems[i] is NoteTextItem) ...[
              if (_isDraggingImage)
                _buildDraggingTextItem(_noteItems[i] as NoteTextItem, question)
              else
                _buildNoteTextField(_noteItems[i] as NoteTextItem, question),
            ] else if (_noteItems[i] is NoteImageItem) ...[
              _buildNoteImageWidget(_noteItems[i] as NoteImageItem, i, question),
            ],
          ],
          if (_isDraggingImage)
            _buildDropTargetSlot(
              onAccept: () => _moveImageToItemIndex(_noteItems.length, question),
              label: 'DROP AT BOTTOM OF NOTEBOOK',
            ),
        ],
      ),
    );
  }

  Widget _buildNoteTextField(NoteTextItem item, Question question) {
    return TextField(
      key: ValueKey(item.id),
      controller: item.controller,
      focusNode: item.focusNode,
      maxLines: null,
      minLines: 1,
      textInputAction: TextInputAction.newline,
      contentInsertionConfiguration: ContentInsertionConfiguration(
        allowedMimeTypes: const <String>['image/png', 'image/jpeg', 'image/gif', 'image/webp'],
        onContentInserted: (KeyboardInsertedContent value) async {
          if (value.data != null && value.data!.isNotEmpty) {
            final ext = value.mimeType.contains('png') ? 'png' : 'jpg';
            final savedPath = await _saveFilePermanently(value.data!, ext);
            _insertImageItemAtCursorOrEnd(savedPath, question);
          } else if (value.uri.isNotEmpty) {
            final bytes = await _readBytesFromNativeUri(value.uri);
            if (bytes != null && bytes.isNotEmpty) {
              final savedPath = await _saveFilePermanently(bytes, 'jpg');
              _insertImageItemAtCursorOrEnd(savedPath, question);
            }
          }
          _unfocusAllNotes();
          FocusScope.of(context).unfocus();
        },
      ),
      onEditingComplete: () {
        item.focusNode.unfocus();
        FocusScope.of(context).unfocus();
        _saveNotes(question, text: _serializeNotes());
      },
      contextMenuBuilder: (context, editableTextState) {
        final List<ContextMenuButtonItem> buttonItems = editableTextState.contextMenuButtonItems;
        final int pasteIndex = buttonItems.indexWhere((b) => b.type == ContextMenuButtonType.paste);
        if (pasteIndex != -1) {
          buttonItems[pasteIndex] = buttonItems[pasteIndex].copyWith(
            onPressed: () {
              _pasteIntoNotebook(question);
            },
          );
        }
        return AdaptiveTextSelectionToolbar.buttonItems(
          anchors: editableTextState.contextMenuAnchors,
          buttonItems: buttonItems,
        );
      },
      style: GoogleFonts.inter(
        fontSize: 15,
        fontWeight: FontWeight.w400,
        color: AppTheme.textPrimary,
        height: 1.6,
      ),
      decoration: InputDecoration(
        hintText: _noteItems.length <= 1 ? 'Paste or type your notes here...' : 'Continue notes here...',
        hintStyle: const TextStyle(color: Colors.white38),
        border: InputBorder.none,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(vertical: 4),
      ),
    );
  }

  Widget _buildNoteImageWidget(NoteImageItem item, int index, Question question) {
    final isSelected = _selectedImageId == item.id;
    final factor = (item.widthPercent / 100.0).clamp(0.25, 1.0);

    final imageCard = FractionallySizedBox(
      widthFactor: factor,
      alignment: Alignment.centerLeft,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? Colors.white : Colors.white24,
            width: isSelected ? 2.0 : 1.0,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: Image.file(
          io.File(item.imagePath),
          fit: BoxFit.fitWidth,
          errorBuilder: (_, __, ___) => Container(
            height: 120,
            color: Colors.white10,
            child: const Center(
              child: Text('Image file not found', style: TextStyle(color: Colors.white54, fontSize: 12)),
            ),
          ),
        ),
      ),
    );

    return Container(
      key: ValueKey(item.id),
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LongPressDraggable<String>(
            data: item.id,
            delay: const Duration(milliseconds: 250),
            onDragStarted: () {
              HapticFeedback.lightImpact();
              setState(() {
                _isDraggingImage = true;
                _draggedImageId = item.id;
              });
            },
            onDragEnd: (_) {
              setState(() {
                _isDraggingImage = false;
                _draggedImageId = null;
              });
            },
            onDraggableCanceled: (_, __) {
              setState(() {
                _isDraggingImage = false;
                _draggedImageId = null;
              });
            },
            feedback: Material(
              color: Colors.transparent,
              child: Opacity(
                opacity: 0.85,
                child: Container(
                  width: 220,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.5),
                        blurRadius: 16,
                        spreadRadius: 4,
                      ),
                    ],
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Image.file(io.File(item.imagePath), fit: BoxFit.fitWidth),
                ),
              ),
            ),
            childWhenDragging: Opacity(
              opacity: 0.25,
              child: imageCard,
            ),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                setState(() {
                  _selectedImageId = isSelected ? null : item.id;
                });
              },
              onLongPress: () {
                _showUniversalImageSheet(
                  context: context,
                  imagePath: item.imagePath,
                  question: question,
                  isFromNotebook: true,
                  noteImageId: item.id,
                );
              },
              child: imageCard,
            ),
          ),
          if (isSelected)
            _buildInlineImageControls(item, index, question),
        ],
      ),
    );
  }

  Widget _buildInlineImageControls(NoteImageItem item, int index, Question question) {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white24, width: 1.0),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ...([25, 50, 75, 100].map((pct) {
            final isCur = item.widthPercent == pct;
            return GestureDetector(
              onTap: () => _updateNoteImageWidth(item.id, pct, question),
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 3),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isCur ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$pct%',
                  style: TextStyle(
                    color: isCur ? Colors.black : Colors.white70,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            );
          })),
          const SizedBox(width: 6),
          Container(width: 1, height: 16, color: Colors.white24),
          const SizedBox(width: 4),
          Draggable<String>(
            data: item.id,
            onDragStarted: () {
              HapticFeedback.lightImpact();
              setState(() {
                _isDraggingImage = true;
                _draggedImageId = item.id;
              });
            },
            onDragEnd: (_) {
              setState(() {
                _isDraggingImage = false;
                _draggedImageId = null;
              });
            },
            onDraggableCanceled: (_, __) {
              setState(() {
                _isDraggingImage = false;
                _draggedImageId = null;
              });
            },
            feedback: Material(
              color: Colors.transparent,
              child: Opacity(
                opacity: 0.85,
                child: Container(
                  width: 220,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.5),
                        blurRadius: 16,
                        spreadRadius: 4,
                      ),
                    ],
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Image.file(io.File(item.imagePath), fit: BoxFit.fitWidth),
                ),
              ),
            ),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white12,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.drag_indicator_rounded, size: 14, color: Colors.white),
                  SizedBox(width: 2),
                  Text('DRAG', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.arrow_upward_rounded, size: 16, color: Colors.white),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
            tooltip: 'Move Up',
            onPressed: () => _moveImageUp(index, question),
          ),
          IconButton(
            icon: const Icon(Icons.arrow_downward_rounded, size: 16, color: Colors.white),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
            tooltip: 'Move Down',
            onPressed: () => _moveImageDown(index, question),
          ),
          IconButton(
            icon: const Icon(Icons.share_outlined, size: 16, color: Colors.white70),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
            tooltip: 'Share',
            onPressed: () => _showUniversalImageSheet(
              context: context,
              imagePath: item.imagePath,
              question: question,
              isFromNotebook: true,
              noteImageId: item.id,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close_rounded, size: 16, color: Colors.redAccent),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
            tooltip: 'Remove',
            onPressed: () => _deleteImageFromNote(item.id, question),
          ),
        ],
      ),
    );
  }

  void _showUniversalImageSheet({
    required BuildContext context,
    required String imagePath,
    required Question question,
    required bool isFromNotebook,
    String? noteImageId,
  }) {
    HapticFeedback.mediumImpact();

    int currentPercent = 100;
    if (isFromNotebook && noteImageId != null) {
      for (final it in _noteItems) {
        if (it is NoteImageItem && it.id == noteImageId) {
          currentPercent = it.widthPercent;
          break;
        }
      }
    }

    final fileName = io.File(imagePath).uri.pathSegments.last;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Container(
              decoration: const BoxDecoration(
                color: Color(0xFF1C1C1E),
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              ),
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
              child: SafeArea(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.white24,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Image.file(
                            io.File(imagePath),
                            width: 50,
                            height: 50,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              width: 50,
                              height: 50,
                              color: Colors.white10,
                              child: const Icon(Icons.broken_image, color: Colors.white38, size: 24),
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                fileName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                isFromNotebook ? 'Notebook Image' : 'Answer Resource',
                                style: const TextStyle(color: Colors.white54, fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.white54, size: 20),
                          onPressed: () => Navigator.pop(sheetContext),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Divider(color: Colors.white12, height: 1),
                    const SizedBox(height: 8),

                    // 1. Share Image (WhatsApp, Telegram, etc.)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppTheme.samsungBlue.withOpacity(0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.share_rounded, color: AppTheme.samsungBlue, size: 20),
                      ),
                      title: const Text(
                        'Share Image',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15),
                      ),
                      subtitle: const Text(
                        'Share to WhatsApp, Telegram, and other apps',
                        style: TextStyle(color: Colors.white54, fontSize: 12),
                      ),
                      onTap: () async {
                        Navigator.pop(sheetContext);
                        try {
                          await Share.shareXFiles(
                            [XFile(imagePath)],
                            text: question.title,
                          );
                        } catch (e) {
                          debugPrint('Share failed: $e');
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Failed to share: $e'), backgroundColor: Colors.redAccent),
                            );
                          }
                        }
                      },
                    ),

                    // 2. View Fullscreen
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.08),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.fullscreen_rounded, color: Colors.white, size: 20),
                      ),
                      title: const Text(
                        'View Fullscreen',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15),
                      ),
                      subtitle: const Text(
                        'Pinch to zoom and inspect details',
                        style: TextStyle(color: Colors.white54, fontSize: 12),
                      ),
                      onTap: () {
                        Navigator.pop(sheetContext);
                        _openFullscreenImage(context, imagePath);
                      },
                    ),

                    // 3. Copy Image
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.08),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.copy_rounded, color: Colors.white, size: 20),
                      ),
                      title: const Text(
                        'Copy Image',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15),
                      ),
                      subtitle: const Text(
                        'Copy image file to clipboard',
                        style: TextStyle(color: Colors.white54, fontSize: 12),
                      ),
                      onTap: () async {
                        Navigator.pop(sheetContext);
                        try {
                          await Pasteboard.writeFiles([imagePath]);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Image copied to clipboard!'),
                                backgroundColor: Colors.white24,
                                duration: Duration(seconds: 2),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          }
                        } catch (e) {
                          debugPrint('Copy failed: $e');
                        }
                      },
                    ),

                    // 4. Notebook Sizing Percentile
                    if (isFromNotebook && noteImageId != null) ...[
                      const SizedBox(height: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'IMAGE SIZE (PERCENTILE)',
                            style: TextStyle(
                              color: Colors.white54,
                              fontWeight: FontWeight.w800,
                              fontSize: 11,
                              letterSpacing: 1.0,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [25, 50, 75, 100].map((pct) {
                              final isCur = currentPercent == pct;
                              return Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 4),
                                  child: InkWell(
                                    onTap: () {
                                      setSheetState(() => currentPercent = pct);
                                      _updateNoteImageWidth(noteImageId, pct, question);
                                    },
                                    borderRadius: BorderRadius.circular(10),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(vertical: 10),
                                      decoration: BoxDecoration(
                                        color: isCur ? Colors.white : Colors.white.withOpacity(0.06),
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(
                                          color: isCur ? Colors.white : Colors.white24,
                                          width: 1.0,
                                        ),
                                      ),
                                      child: Center(
                                        child: Text(
                                          '$pct%',
                                          style: TextStyle(
                                            color: isCur ? Colors.black : Colors.white,
                                            fontWeight: FontWeight.w800,
                                            fontSize: 13,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ],
                      ),
                    ],

                    const SizedBox(height: 8),

                    // 5. Delete
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppTheme.urgentColor.withOpacity(0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.delete_outline_rounded, color: AppTheme.urgentColor, size: 20),
                      ),
                      title: const Text(
                        'Delete Image',
                        style: TextStyle(color: AppTheme.urgentColor, fontWeight: FontWeight.w700, fontSize: 15),
                      ),
                      subtitle: Text(
                        isFromNotebook ? 'Remove this image from notebook' : 'Delete attachment from resources',
                        style: const TextStyle(color: Colors.white54, fontSize: 12),
                      ),
                      onTap: () {
                        Navigator.pop(sheetContext);
                        if (isFromNotebook && noteImageId != null) {
                          _deleteImageFromNote(noteImageId, question);
                        } else {
                          final images = question.images ?? [];
                          final idx = images.indexOf(imagePath);
                          if (idx != -1) {
                            _removeAttachment(question, idx);
                          }
                        }
                      },
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _openFullscreenImage(BuildContext context, String path) {
    Navigator.push(
      context,
      PageRouteBuilder(
        opaque: false,
        barrierColor: Colors.black.withOpacity(0.92),
        pageBuilder: (context, anim1, anim2) {
          return Scaffold(
            backgroundColor: Colors.transparent,
            body: Stack(
              children: [
                Center(
                  child: InteractiveViewer(
                    minScale: 0.8,
                    maxScale: 5.0,
                    child: Image.file(
                      io.File(path),
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => const Center(
                        child: Text('Image file not found', style: TextStyle(color: Colors.white70)),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 50,
                  right: 20,
                  child: SafeArea(
                    child: GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white24),
                        ),
                        child: const Icon(Icons.close, color: Colors.white, size: 22),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _saveNotes(Question question, {String? text, bool silent = false}) async {
    final textToSave = text ?? _serializeNotes();
    final repo = await ref.read(questionRepositoryProvider.future);
    await repo.isar.writeTxn(() async {
      question.userNotes = textToSave;
      await repo.isar.collection<Question>().put(question);
    });
    if (!silent) HapticFeedback.vibrate();
  }

  void _saveQuestionNotes(Question question, {String? text, bool silent = false}) async {
    final textToSave = text ?? _questionController.text;
    final repo = await ref.read(questionRepositoryProvider.future);
    await repo.isar.writeTxn(() async {
      question.notes = textToSave;
      await repo.isar.collection<Question>().put(question);
    });
    if (!silent) HapticFeedback.vibrate();
  }

  void _showAttachmentOptions(BuildContext context, Question question) {
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
              const Text('Add Asset', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 24),
              _attachmentOption(Icons.camera_alt_outlined, 'CAPTURE IMAGE', () {
                Navigator.pop(context);
                _attachMedia(question, ImageSource.camera);
              }),
              _attachmentOption(Icons.photo_library_outlined, 'BROWSE GALLERY', () {
                Navigator.pop(context);
                _attachMedia(question, ImageSource.gallery);
              }),
              _attachmentOption(Icons.content_paste_outlined, 'PASTE IMAGE', () {
                Navigator.pop(context);
                _pasteImage(question);
              }),
            ],
          ),
        ),
      ),
    );
  }

  Widget _attachmentOption(IconData icon, String label, VoidCallback onTap) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 32, vertical: 8),
      leading: Icon(icon, color: AppTheme.textPrimary, size: 28),
      title: Text(label, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, letterSpacing: 1.0)),
      onTap: onTap,
    );
  }

  void _attachMedia(Question question, ImageSource source) async {
    final picker = ImagePicker();
    final repo = await ref.read(questionRepositoryProvider.future);
    
    if (source == ImageSource.camera) {
      final image = await picker.pickImage(source: source);
      if (image != null) {
        final bytes = await image.readAsBytes();
        final savedPath = await _saveFilePermanently(bytes, 'jpg');
        await repo.isar.writeTxn(() async {
          final q = await repo.isar.questions.get(question.id);
          if (q != null) {
            final images = List<String>.from(q.images ?? []);
            images.add(savedPath);
            q.images = images;
            await repo.isar.questions.put(q);
          }
        });
        HapticFeedback.vibrate();
      }
    } else {
      final List<XFile> imagesList = await picker.pickMultiImage();
      if (imagesList.isNotEmpty) {
        final newPaths = <String>[];
        final orderedImages = io.Platform.isWindows ? imagesList.reversed.toList() : imagesList.toList();
        for (var img in orderedImages) {
          final bytes = await img.readAsBytes();
          final p = await _saveFilePermanently(bytes, 'jpg');
          newPaths.add(p);
        }
        await repo.isar.writeTxn(() async {
          final q = await repo.isar.questions.get(question.id);
          if (q != null) {
            final images = List<String>.from(q.images ?? []);
            images.addAll(newPaths);
            q.images = images;
            await repo.isar.questions.put(q);
          }
        });
        HapticFeedback.vibrate();
      }
    }
  }

  void _pasteImage(Question question) async {
    final repo = await ref.read(questionRepositoryProvider.future);
    
    // 1. Try pasting raw image bytes (e.g., from Snipping Tool)
    final imageBytes = await Pasteboard.image;
    if (imageBytes != null && imageBytes.isNotEmpty) {
      final savedPath = await _saveFilePermanently(imageBytes, 'jpg');
      await repo.isar.writeTxn(() async {
        final q = await repo.isar.questions.get(question.id);
        if (q != null) {
          final images = List<String>.from(q.images ?? []);
          images.add(savedPath);
          q.images = images;
          await repo.isar.questions.put(q);
        }
      });
      HapticFeedback.vibrate();
      return;
    }
    
    // 2. Try pasting copied files (e.g., from Windows Explorer)
    final files = await Pasteboard.files();
    if (files.isNotEmpty) {
      final validPaths = <String>[];
      for (final p in files) {
        final lower = p.toLowerCase();
        if (lower.endsWith('.jpg') || lower.endsWith('.jpeg') || lower.endsWith('.png') || lower.endsWith('.webp')) {
          validPaths.add(p);
        }
      }
      
      if (validPaths.isNotEmpty) {
        final orderedPaths = io.Platform.isWindows ? validPaths.reversed.toList() : validPaths.toList();
        await repo.isar.writeTxn(() async {
          final q = await repo.isar.questions.get(question.id);
          if (q != null) {
            final images = List<String>.from(q.images ?? []);
            images.addAll(orderedPaths);
            q.images = images;
            await repo.isar.questions.put(q);
          }
        });
        HapticFeedback.vibrate();
        return;
      }
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No image or valid file found in clipboard')),
      );
    }
  }

  void _removeAttachment(Question question, int index) async {
    final repo = await ref.read(questionRepositoryProvider.future);
    await repo.isar.writeTxn(() async {
      final q = await repo.isar.questions.get(question.id);
      if (q != null) {
        final images = List<String>.from(q.images ?? []);
        images.removeAt(index);
        q.images = images;
        await repo.isar.questions.put(q);
      }
    });
  }
}
