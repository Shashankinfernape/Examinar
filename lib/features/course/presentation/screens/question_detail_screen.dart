import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories/question_repository.dart';
import '../../data/repositories/course_repository.dart';
import '../../domain/models/question.dart';
import '../../domain/models/course.dart';
import 'package:exam_command_center/core/theme/app_theme.dart';
import 'package:image_picker/image_picker.dart';
import 'package:super_drag_and_drop/super_drag_and_drop.dart';
import 'package:super_clipboard/super_clipboard.dart' as sc;
import 'package:http/http.dart' as http;
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
import 'package:file_picker/file_picker.dart';
import 'package:image/image.dart' as img;

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
  final _scrollController = ScrollController();
  final GlobalKey _resourcesKey = GlobalKey();
  final List<NoteItem> _noteItems = [];
  String? _selectedImageId;
  bool _isDraggingImage = false;
  String? _draggedImageId;
  String? _draggedAssetPath;
  bool _hasInitializedNotes = false;
  bool _hasInitializedQuestion = false;
  bool _isDraggingResources = false;
  bool _isDraggingNotebook = false;
  bool _isIngestingImage = false;
  Offset? _lastPointerPosition;
  Timer? _debounce;
  Timer? _questionDebounce;
  Question? _currentQuestion;
  static const _platformChannel = MethodChannel('com.examcommandcenter.direct_share');

  String? _hoveredTextItemId;
  int? _hoveredCharIndex;
  Offset? _hoveredCaretOffset;
  String? _hoveredImageItemId;
  bool _hoveredImageTopHalf = true;
  final Map<String, GlobalKey> _textItemKeys = {};

  GlobalKey _getTextItemKey(String id) {
    return _textItemKeys.putIfAbsent(id, () => GlobalKey());
  }

  final Map<String, GlobalKey> _imageItemKeys = {};

  GlobalKey _getImageItemKey(String id) {
    return _imageItemKeys.putIfAbsent(id, () => GlobalKey());
  }

  final Set<String> _knownStorageDirs = {};

  String? _resolveLocalImagePath(String path, Question? question) {
    if (path.isEmpty) return null;
    if (io.File(path).existsSync()) return path;

    final fileName = path.split(RegExp(r'[/\\]')).last;
    if (fileName.isEmpty) return null;

    // 1. Check question.images
    if (question?.images != null) {
      for (final img in question!.images!) {
        if (io.File(img).existsSync() && (img.endsWith('/$fileName') || img.endsWith('\\$fileName') || img == fileName)) {
          return img;
        }
      }
    }

    // 2. Check candidate local storage directories
    for (final dirPath in _knownStorageDirs) {
      final direct = io.File('$dirPath/$fileName');
      if (direct.existsSync()) return direct.path;
      final examinar = io.File('$dirPath/ExaminarImages/$fileName');
      if (examinar.existsSync()) return examinar.path;
    }

    return null;
  }

  @override
  void initState() {
    super.initState();
    _questionFocusNode.addListener(() {
      if (mounted) setState(() {});
    });
    getApplicationDocumentsDirectory().then((d) {
      _knownStorageDirs.add(d.path);
      _knownStorageDirs.add('${d.path}/ExaminarImages');
      if (mounted) setState(() {});
    });
    getApplicationSupportDirectory().then((d) {
      _knownStorageDirs.add(d.path);
      _knownStorageDirs.add('${d.path}/ExaminarImages');
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
    _platformChannel.setMethodCallHandler(null);
    _scrollController.dispose();
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
    final supportDir = await getApplicationSupportDirectory();
    final cleanExt = extension.replaceAll('.', '').toLowerCase();
    final fileName = '${const Uuid().v4()}.$cleanExt';
    final imagesDir = io.Directory('${supportDir.path}${io.Platform.pathSeparator}examinar_images');
    if (!await imagesDir.exists()) {
      await imagesDir.create(recursive: true);
    }
    final savedFile = io.File('${imagesDir.path}${io.Platform.pathSeparator}$fileName');
    await savedFile.writeAsBytes(bytes);
    return savedFile.path.replaceAll('\\', '/');
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

          return Scaffold(
              backgroundColor: AppTheme.black,
              body: Listener(
                onPointerMove: (pointerEvent) {
                  _lastPointerPosition = pointerEvent.position;
                  if (_isDraggingImage) {
                    final screenHeight = MediaQuery.of(context).size.height;
                    final dy = pointerEvent.position.dy;
                    if (dy < 180 && _scrollController.hasClients && _scrollController.offset > 0) {
                      _scrollController.jumpTo((_scrollController.offset - 14).clamp(0.0, _scrollController.position.maxScrollExtent));
                    } else if (dy > screenHeight - 180 && _scrollController.hasClients && _scrollController.offset < _scrollController.position.maxScrollExtent) {
                      _scrollController.jumpTo((_scrollController.offset + 14).clamp(0.0, _scrollController.position.maxScrollExtent));
                    }
                  }
                },
                child: GestureDetector(
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
                    controller: _scrollController,
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
                                child: _buildActionPill(
                                  icon: Icons.check,
                                  label: 'DONE',
                                  onPressed: () {
                                    _unfocusAllNotes();
                                    FocusScope.of(context).unfocus();
                                    if (_selectedImageId != null) {
                                      setState(() => _selectedImageId = null);
                                    }
                                    _saveNotes(question);
                                  },
                                  backgroundColor: Colors.white.withOpacity(0.12),
                                ),
                              ),
                            _buildActionPill(
                              icon: Icons.add_photo_alternate_outlined,
                              onPressed: () => _pickImageIntoNotebook(question),
                            ),
                            const SizedBox(width: 6),
                            _buildActionPill(
                              icon: Icons.content_paste_rounded,
                              label: 'PASTE',
                              onPressed: () => _pasteIntoNotebook(question),
                            ),
                            const SizedBox(width: 6),
                            _buildActionPill(
                              icon: Icons.auto_awesome,
                              label: 'Generate',
                              foregroundColor: AppTheme.primaryColor,
                              backgroundColor: AppTheme.primaryColor.withOpacity(0.12),
                              onPressed: () => _askChatGPT(question),
                            ),
                          ],
                        ),
                        padding: const EdgeInsets.all(16),
                        child: _buildNotebookContent(question),
                      ),

                      const SizedBox(height: 16),

                      // 5. ANSWER RESOURCES (ATTACHMENTS)
                      _buildAnswerResourcesSection(context, question),

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

  Future<void> _processDroppedItem(DropItem item, Future<void> Function(Uint8List bytes, String ext) onData) async {
    final reader = item.dataReader;
    if (reader == null) return;
    
    if (reader.canProvide(Formats.fileUri)) {
      reader.getValue<Uri>(Formats.fileUri, (uri) async {
        if (uri != null) {
          try {
            String p = uri.toFilePath(windows: io.Platform.isWindows);
            final file = io.File(p);
            if (await file.exists()) {
              final bytes = await file.readAsBytes();
              final ext = p.split('.').last.toLowerCase();
              await onData(bytes, ext);
            }
          } catch (e) {
            debugPrint('Failed to process fileUri: $e');
          }
        }
      });
    } else {
      reader.getFile(null, (file) async {
        try {
          final bytes = await file.readAll();
          if (bytes.isNotEmpty) {
            String ext = 'jpg';
            final lowerName = (file.fileName ?? '').toLowerCase();
            if (lowerName.contains('.')) {
              ext = lowerName.split('.').last;
            }
            await onData(bytes, ext);
          }
        } catch (e) {
          debugPrint('Failed to process getFile: $e');
        }
      });
    }
  }

  Widget _buildActionPill({
    required IconData icon,
    String? label,
    required VoidCallback onPressed,
    Color? backgroundColor,
    Color? foregroundColor,
    bool isLoading = false,
  }) {
    final fg = foregroundColor ?? Colors.white;
    final bg = backgroundColor ?? Colors.white.withOpacity(0.08);

    return TextButton(
      onPressed: isLoading ? null : onPressed,
      style: TextButton.styleFrom(
        backgroundColor: bg,
        padding: EdgeInsets.symmetric(horizontal: label == null ? 8 : 12, vertical: 0),
        minimumSize: Size(label == null ? 30 : 0, 30),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isLoading)
            SizedBox(width: 13, height: 13, child: CircularProgressIndicator(strokeWidth: 2, color: fg))
          else
            Icon(icon, size: label == null ? 15 : 13, color: fg),
          if (label != null) ...[
            const SizedBox(width: 6),
            Text(label, style: TextStyle(color: fg, fontWeight: FontWeight.w800, fontSize: 11, letterSpacing: 0.5)),
          ],
        ],
      ),
    );
  }

  Widget _buildAnswerResourcesSection(BuildContext context, Question question) {
    final innerResourcesCard = DragTarget<Object>(
      key: _resourcesKey,
      onWillAcceptWithDetails: (details) {
        if (_draggedAssetPath != null) return false;
        return true;
      },
      onAcceptWithDetails: (details) async {
        HapticFeedback.mediumImpact();
        final data = details.data;
        String? imagePath;
        if (data is String) {
          if (io.File(data).existsSync()) {
            imagePath = data;
          } else {
            final match = _noteItems.firstWhere(
              (it) => it.id == data,
              orElse: () => NoteTextItem(id: '', initialText: ''),
            );
            if (match is NoteImageItem) {
              imagePath = match.imagePath;
            }
          }
        }
        if (imagePath != null) {
          final repo = await ref.read(questionRepositoryProvider.future);
          await repo.isar.writeTxn(() async {
            final q = await repo.isar.questions.get(question.id);
            if (q != null) {
              final images = List<String>.from(q.images ?? []);
              if (!images.contains(imagePath)) {
                images.add(imagePath!);
                q.images = images;
                await repo.isar.collection<Question>().put(q);
              }
            }
          });
          if (mounted) setState(() {});
        }
      },
      builder: (context, candidateData, rejectedData) {
        final isHovered = candidateData.isNotEmpty;
        return Stack(
          children: [
            _buildOneUICard(
              title: 'Answer Resources',
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildActionPill(
                    icon: Icons.content_paste_rounded,
                    label: 'PASTE',
                    isLoading: _isIngestingImage,
                    onPressed: () => _pasteImage(question),
                  ),
                  const SizedBox(width: 6),
                  _buildActionPill(
                    icon: Icons.add_photo_alternate_outlined,
                    onPressed: () {
                      if (io.Platform.isWindows || io.Platform.isMacOS || io.Platform.isLinux) {
                        _addAssetViaPicker(question);
                      } else {
                        _showAttachmentOptions(context, question);
                      }
                    },
                  ),
                  if (question.images != null && question.images!.isNotEmpty) ...[
                    const SizedBox(width: 6),
                    _buildActionPill(
                      icon: Icons.delete_outline,
                      foregroundColor: AppTheme.urgentColor,
                      backgroundColor: AppTheme.urgentColor.withOpacity(0.12),
                      onPressed: () async {
                        final repo = await ref.read(questionRepositoryProvider.future);
                        await repo.isar.writeTxn(() async {
                          final q = await repo.isar.questions.get(question.id);
                          if (q != null) {
                            q.images = [];
                            await repo.isar.collection<Question>().put(q);
                          }
                        });
                        if (mounted) setState(() {});
                      },
                    ),
                  ],
                ],
              ),
              child: Container(
                width: double.infinity,
                constraints: const BoxConstraints(minHeight: 120),
                child: Column(
                  children: [
                    if (question.images == null || question.images!.isEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 24),
                        width: double.infinity,
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.white12, width: 1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.photo_library_outlined, color: Colors.white24, size: 28),
                              SizedBox(height: 8),
                              Text(
                                'Drag images here, use PASTE or click +',
                                style: TextStyle(color: Colors.white38, fontSize: 13),
                              ),
                            ],
                          ),
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
            if (isHovered || _isDraggingResources)
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E1E1E).withValues(alpha: 0.92),
                    borderRadius: BorderRadius.circular(AppTheme.cardRadius),
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.file_download_outlined, size: 40, color: Colors.white),
                        SizedBox(height: 8),
                        Text('Drop Image into Answer Resources', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );

    return DropRegion(
      formats: Formats.standardFormats,
      onDropOver: (event) {
        if (!_isDraggingResources && mounted) {
          setState(() => _isDraggingResources = true);
        }
        return DropOperation.copy;
      },
      onDropLeave: (event) {
        if (_isDraggingResources && mounted) {
          setState(() => _isDraggingResources = false);
        }
      },
      onPerformDrop: (event) async {
        if (mounted) setState(() => _isDraggingResources = false);
        HapticFeedback.mediumImpact();
        for (final item in event.session.items) {
          await _processDroppedItem(item, (bytes, ext) async {
            try {
              final destPath = await _saveFilePermanently(bytes, ext);
              final repo = await ref.read(questionRepositoryProvider.future);
              await repo.isar.writeTxn(() async {
                final q = await repo.isar.questions.get(question.id);
                if (q != null) {
                  final images = List<String>.from(q.images ?? []);
                  if (!images.contains(destPath)) {
                    images.add(destPath);
                    q.images = images;
                    await repo.isar.collection<Question>().put(q);
                  }
                }
              });
              if (mounted) setState(() {});
            } catch (e) {
              debugPrint('Failed to save dropped file into resources: $e');
            }
          });
        }
      },
      child: innerResourcesCard,
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
    final imageCard = Container(
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
            child: const Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.broken_image_outlined, size: 32, color: Colors.white54),
                SizedBox(height: 8),
                Text('Image not found on this device', style: TextStyle(color: Colors.white54, fontSize: 12)),
              ],
            ),
          );
        },
      ),
    );

    return Stack(
      children: [
        _buildAdaptiveDraggable<String>(
          data: path,
          onDragStarted: () {
            HapticFeedback.lightImpact();
            setState(() {
              _isDraggingImage = true;
              _draggedImageId = null;
              _draggedAssetPath = path;
            });
          },
          onDragEnd: (_) {
            setState(() {
              _isDraggingImage = false;
              _draggedAssetPath = null;
              _hoveredTextItemId = null;
              _hoveredCharIndex = null;
              _hoveredCaretOffset = null;
            });
          },
          onDraggableCanceled: () {
            setState(() {
              _isDraggingImage = false;
              _draggedAssetPath = null;
              _hoveredTextItemId = null;
              _hoveredCharIndex = null;
              _hoveredCaretOffset = null;
            });
          },
          feedback: _buildWordDragPointerBadge(imagePath: path),
          childWhenDragging: Opacity(
            opacity: 0.2,
            child: imageCard,
          ),
          child: GestureDetector(
            onTap: () => _openFullscreenImage(context, path),
            child: imageCard,
          ),
        ),
        Positioned(
          top: 8,
          right: 88,
          child: GestureDetector(
            onTap: () {
              _insertImageAtNotebookEnd(path, question.id);
              HapticFeedback.lightImpact();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Image inserted into Notebook!'),
                    backgroundColor: Colors.white24,
                    duration: Duration(seconds: 2),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: const BoxDecoration(color: Colors.black87, shape: BoxShape.circle),
              child: const Icon(Icons.note_add_outlined, size: 16, color: Colors.white),
            ),
          ),
        ),
        Positioned(
          top: 8,
          right: 48,
          child: GestureDetector(
            onTap: () => _showUniversalImageSheet(
              context: context,
              imagePath: path,
              question: question,
              isFromNotebook: false,
            ),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: const BoxDecoration(color: Colors.black87, shape: BoxShape.circle),
              child: const Icon(Icons.share_outlined, size: 16, color: Colors.white),
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

  Future<Uint8List?> _getWindowsClipboardImage() async {
    if (!io.Platform.isWindows) return null;
    try {
      final tempOut = '${io.Directory.systemTemp.path}\\examinar_clip_${DateTime.now().millisecondsSinceEpoch}.png';
      final script = '''
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
\$img = [System.Windows.Forms.Clipboard]::GetImage()
if (\$null -ne \$img) {
  \$img.Save('$tempOut', [System.Drawing.Imaging.ImageFormat]::Png)
  \$img.Dispose()
  Write-Output 'IMAGE'
  exit 0
}
\$files = [System.Windows.Forms.Clipboard]::GetFileDropList()
if (\$null -ne \$files -and \$files.Count -gt 0) {
  Write-Output "FILE:\$(\$files[0])"
  exit 0
}
Write-Output 'EMPTY'
''';
      final result = await io.Process.run(
        'powershell',
        ['-Sta', '-WindowStyle', 'Hidden', '-NoProfile', '-NonInteractive', '-ExecutionPolicy', 'Bypass', '-Command', script],
      );
      final stdout = (result.stdout as String?)?.trim() ?? '';
      if (stdout.contains('IMAGE')) {
        final f = io.File(tempOut);
        if (await f.exists()) {
          final bytes = await f.readAsBytes();
          try { await f.delete(); } catch (_) {}
          if (bytes.isNotEmpty) return bytes;
        }
      } else if (stdout.contains('FILE:')) {
        final line = stdout.split('\n').firstWhere((l) => l.trim().startsWith('FILE:'), orElse: () => '');
        if (line.isNotEmpty) {
          final filePath = line.trim().substring(5).trim();
          final lower = filePath.toLowerCase();
          if (lower.endsWith('.jpg') ||
              lower.endsWith('.jpeg') ||
              lower.endsWith('.png') ||
              lower.endsWith('.webp') ||
              lower.endsWith('.bmp') ||
              lower.endsWith('.gif')) {
            final f = io.File(filePath);
            if (await f.exists()) {
              final bytes = await f.readAsBytes();
              if (bytes.isNotEmpty) return bytes;
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Windows clipboard extraction error: $e');
    }
    return null;
  }

  Future<List<String>> _ingestClipboardImages() async {
    final savedPaths = <String>[];

    Future<void> saveBytes(List<int> bytes, String ext) async {
      if (bytes.isNotEmpty) {
        final p = await _saveFilePermanently(bytes, ext);
        if (!savedPaths.contains(p)) savedPaths.add(p);
      }
    }

    // TIER 1: super_clipboard (Rust-backed Win32 OLE on Windows, native clipboard on Android)
    try {
      final clipboard = sc.SystemClipboard.instance;
      if (clipboard != null) {
        final reader = await clipboard.read();
        for (final item in reader.items) {
          if (item.canProvide(sc.Formats.png)) {
            final completer = Completer<Uint8List?>();
            item.getFile(sc.Formats.png, (file) async {
              try {
                final b = await file.readAll();
                if (!completer.isCompleted) completer.complete(b);
              } catch (_) {
                if (!completer.isCompleted) completer.complete(null);
              }
            }, onError: (_) {
              if (!completer.isCompleted) completer.complete(null);
            });
            final b = await completer.future.timeout(const Duration(milliseconds: 2000), onTimeout: () => null);
            if (b != null && b.isNotEmpty) {
              await saveBytes(b, 'png');
            }
          } else if (item.canProvide(sc.Formats.jpeg)) {
            final completer = Completer<Uint8List?>();
            item.getFile(sc.Formats.jpeg, (file) async {
              try {
                final b = await file.readAll();
                if (!completer.isCompleted) completer.complete(b);
              } catch (_) {
                if (!completer.isCompleted) completer.complete(null);
              }
            }, onError: (_) {
              if (!completer.isCompleted) completer.complete(null);
            });
            final b = await completer.future.timeout(const Duration(milliseconds: 2000), onTimeout: () => null);
            if (b != null && b.isNotEmpty) {
              await saveBytes(b, 'jpg');
            }
          } else if (item.canProvide(sc.Formats.fileUri)) {
            try {
              final uri = await item.readValue(sc.Formats.fileUri);
              if (uri != null) {
                final filePath = uri.toFilePath();
                final lower = filePath.toLowerCase();
                if (lower.endsWith('.jpg') ||
                    lower.endsWith('.jpeg') ||
                    lower.endsWith('.png') ||
                    lower.endsWith('.webp') ||
                    lower.endsWith('.bmp') ||
                    lower.endsWith('.gif')) {
                  final f = io.File(filePath);
                  if (await f.exists()) {
                    final b = await f.readAsBytes();
                    final ext = lower.split('.').last;
                    await saveBytes(b, ext);
                  }
                }
              }
            } catch (e) {
              debugPrint('Error reading fileUri from clipboard: $e');
            }
          }
        }
      }
    } catch (e) {
      debugPrint('super_clipboard error in _ingestClipboardImages: $e');
    }

    if (savedPaths.isNotEmpty) return savedPaths;

    // TIER 2: Native Android MethodChannel (Samsung content:// URIs)
    if (io.Platform.isAndroid) {
      try {
        final nativeBytes = await _getNativeClipboardImage();
        if (nativeBytes != null && nativeBytes.isNotEmpty) {
          await saveBytes(nativeBytes, 'jpg');
          return savedPaths;
        }
      } catch (e) {
        debugPrint('Native Android clipboard error: $e');
      }
    }

    // TIER 3: Windows STA PowerShell Direct Extraction
    if (io.Platform.isWindows) {
      try {
        final winBytes = await _getWindowsClipboardImage();
        if (winBytes != null && winBytes.isNotEmpty) {
          await saveBytes(winBytes, 'png');
          return savedPaths;
        }
      } catch (e) {
        debugPrint('Windows STA clipboard error: $e');
      }
    }

    // TIER 4: Pasteboard Fallback (CF_DIB / Pasteboard.files)
    try {
      final imageBytes = await Pasteboard.image;
      if (imageBytes != null && imageBytes.isNotEmpty) {
        List<int> bytesToSave = imageBytes;
        String ext = 'jpg';
        if (imageBytes.length > 2 && imageBytes[0] == 0x42 && imageBytes[1] == 0x4D) {
          try {
            final decoded = img.decodeBmp(imageBytes);
            if (decoded != null) {
              bytesToSave = img.encodePng(decoded);
              ext = 'png';
            }
          } catch (_) {
            ext = 'bmp';
          }
        }
        await saveBytes(bytesToSave, ext);
        return savedPaths;
      }

      final files = await Pasteboard.files();
      if (files.isNotEmpty) {
        for (final p in files) {
          if (p.startsWith('content://') || p.startsWith('file://')) {
            final b = await _readBytesFromNativeUri(p);
            if (b != null && b.isNotEmpty) await saveBytes(b, 'jpg');
          } else {
            final lower = p.toLowerCase();
            if (lower.endsWith('.jpg') ||
                lower.endsWith('.jpeg') ||
                lower.endsWith('.png') ||
                lower.endsWith('.webp') ||
                lower.endsWith('.bmp') ||
                lower.endsWith('.gif')) {
              final f = io.File(p);
              if (await f.exists()) {
                final b = await f.readAsBytes();
                final ext = lower.split('.').last;
                await saveBytes(b, ext);
              }
            }
          }
        }
        if (savedPaths.isNotEmpty) return savedPaths;
      }
    } catch (e) {
      debugPrint('Pasteboard error in _ingestClipboardImages: $e');
    }

    // TIER 5: Text / URL / Base64 / File Path
    try {
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      if (data != null && data.text != null && data.text!.isNotEmpty) {
        final text = data.text!.trim();
        if (text.startsWith('content://') || text.startsWith('file://')) {
          final b = await _readBytesFromNativeUri(text);
          if (b != null && b.isNotEmpty) await saveBytes(b, 'jpg');
        } else if (text.startsWith('data:image/') && text.contains('base64,')) {
          final base64String = text.substring(text.indexOf('base64,') + 7).trim();
          final b = base64Decode(base64String);
          if (b.isNotEmpty) {
            final ext = text.contains('image/png') ? 'png' : 'jpg';
            await saveBytes(b, ext);
          }
        } else if (text.startsWith('http://') || text.startsWith('https://')) {
          final uri = Uri.tryParse(text);
          if (uri != null) {
            final lowerPath = uri.path.toLowerCase();
            if (lowerPath.endsWith('.jpg') ||
                lowerPath.endsWith('.jpeg') ||
                lowerPath.endsWith('.png') ||
                lowerPath.endsWith('.webp') ||
                lowerPath.endsWith('.gif')) {
              try {
                final resp = await http.get(uri).timeout(const Duration(seconds: 4));
                if (resp.statusCode == 200 && resp.bodyBytes.isNotEmpty) {
                  final ext = lowerPath.split('.').last;
                  await saveBytes(resp.bodyBytes, ext);
                }
              } catch (_) {}
            }
          }
        } else {
          final cleanText = text.replaceAll('"', '').trim();
          final lowerClean = cleanText.toLowerCase();
          if (lowerClean.endsWith('.jpg') ||
              lowerClean.endsWith('.jpeg') ||
              lowerClean.endsWith('.png') ||
              lowerClean.endsWith('.webp') ||
              lowerClean.endsWith('.bmp') ||
              lowerClean.endsWith('.gif')) {
            final f = io.File(cleanText);
            if (await f.exists()) {
              final b = await f.readAsBytes();
              final ext = lowerClean.split('.').last;
              await saveBytes(b, ext);
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Text clipboard error in _ingestClipboardImages: $e');
    }

    return savedPaths;
  }

  Future<List<String>> _pickImagesAdaptive() async {
    final savedPaths = <String>[];
    try {
      if (io.Platform.isWindows || io.Platform.isMacOS || io.Platform.isLinux) {
        final result = await FilePicker.pickFiles(
          type: FileType.custom,
          allowedExtensions: ['jpg', 'jpeg', 'png', 'webp', 'bmp', 'gif', 'jfif'],
          allowMultiple: true,
          withData: false,
        );
        if (result != null && result.files.isNotEmpty) {
          for (final f in result.files) {
            Uint8List? bytes;
            final filePath = f.path;
            if (filePath != null) {
              final localFile = io.File(filePath);
              if (await localFile.exists()) {
                bytes = await localFile.readAsBytes();
              }
            }
            if (bytes != null && bytes.isNotEmpty) {
              final ext = (f.extension ?? 'jpg').toLowerCase();
              final savedPath = await _saveFilePermanently(bytes, ext);
              savedPaths.add(savedPath);
            }
          }
        }
      } else {
        final picker = ImagePicker();
        final imagesList = await picker.pickMultiImage();
        if (imagesList.isNotEmpty) {
          for (final img in imagesList) {
            final bytes = await img.readAsBytes();
            if (bytes.isNotEmpty) {
              final ext = img.name.split('.').last.toLowerCase();
              final savedPath = await _saveFilePermanently(bytes, ext.isEmpty ? 'jpg' : ext);
              savedPaths.add(savedPath);
            }
          }
        }
      }
    } catch (e) {
      debugPrint('pickImagesAdaptive error: $e');
    }
    return savedPaths;
  }

  Future<void> _addAssetViaPicker(Question question) async {
    final paths = await _pickImagesAdaptive();
    if (paths.isNotEmpty) {
      final repo = await ref.read(questionRepositoryProvider.future);
      await repo.isar.writeTxn(() async {
        final q = await repo.isar.questions.get(question.id);
        if (q != null) {
          final images = List<String>.from(q.images ?? []);
          for (final p in paths) {
            if (!images.contains(p)) images.add(p);
          }
          q.images = images;
          await repo.isar.collection<Question>().put(q);
        }
      });
      HapticFeedback.lightImpact();
      if (mounted) setState(() {});
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
      String path = match.group(2) ?? '';
      final resolved = _resolveLocalImagePath(path, question);
      if (resolved != null) {
        path = resolved;
      }
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
    if (_isIngestingImage) return;
    setState(() => _isIngestingImage = true);
    try {
      // 1. Try ingesting image(s) from clipboard (5-tier engine)
      final imagePaths = await _ingestClipboardImages();
      if (imagePaths.isNotEmpty) {
        for (final p in imagePaths) {
          _insertImageItemAtCursorOrEnd(p, question);
        }
        _unfocusAllNotes();
        if (mounted) FocusScope.of(context).unfocus();
        setState(() => _selectedImageId = null);
        HapticFeedback.lightImpact();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Pasted ${imagePaths.length} image(s) into Notebook!'),
              backgroundColor: Colors.white24,
              duration: const Duration(seconds: 2),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        return;
      }

      // 2. If no image found, fallback to plain human text
      final textData = await Clipboard.getData(Clipboard.kTextPlain);
      if (textData != null && textData.text != null && textData.text!.trim().isNotEmpty) {
        _insertTextItemAtCursorOrEnd(textData.text!, question);
        _unfocusAllNotes();
        if (mounted) FocusScope.of(context).unfocus();
        setState(() => _selectedImageId = null);
        HapticFeedback.lightImpact();
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
    } finally {
      if (mounted) setState(() => _isIngestingImage = false);
    }
  }

  Future<void> _pickImageIntoNotebook(Question question) async {
    final paths = await _pickImagesAdaptive();
    if (paths.isNotEmpty) {
      for (final p in paths) {
        _insertImageItemAtCursorOrEnd(p, question);
      }
      _unfocusAllNotes();
      if (mounted) FocusScope.of(context).unfocus();
      setState(() => _selectedImageId = null);
      HapticFeedback.lightImpact();
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

  Widget _buildAdaptiveDraggable<T extends Object>({
    required T data,
    required Widget child,
    required Widget feedback,
    required Widget childWhenDragging,
    required VoidCallback onDragStarted,
    required void Function(DraggableDetails) onDragEnd,
    required VoidCallback onDraggableCanceled,
  }) {
    final isDesktop = io.Platform.isWindows || io.Platform.isMacOS || io.Platform.isLinux;
    if (isDesktop) {
      return Draggable<T>(
        data: data,
        dragAnchorStrategy: pointerDragAnchorStrategy,
        onDragStarted: onDragStarted,
        onDragEnd: onDragEnd,
        onDraggableCanceled: (_, __) => onDraggableCanceled(),
        feedback: feedback,
        childWhenDragging: childWhenDragging,
        child: child,
      );
    } else {
      return LongPressDraggable<T>(
        data: data,
        delay: const Duration(milliseconds: 150),
        dragAnchorStrategy: pointerDragAnchorStrategy,
        onDragStarted: onDragStarted,
        onDragEnd: onDragEnd,
        onDraggableCanceled: (_, __) => onDraggableCanceled(),
        feedback: feedback,
        childWhenDragging: childWhenDragging,
        child: child,
      );
    }
  }

  Widget _buildWordDragPointerBadge({String? imagePath}) {
    return Material(
      color: Colors.transparent,
      child: Transform.translate(
        offset: const Offset(12, 12),
        child: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E22).withValues(alpha: 0.95),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.white.withValues(alpha: 0.85), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.6),
                blurRadius: 10,
                spreadRadius: 2,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              if (imagePath != null && io.File(imagePath).existsSync())
                Opacity(
                  opacity: 0.35,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: Image.file(
                      io.File(imagePath),
                      width: 34,
                      height: 34,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              const Icon(
                Icons.image_outlined,
                color: Colors.white,
                size: 20,
              ),
              Positioned(
                right: 2,
                bottom: 2,
                child: Container(
                  width: 10,
                  height: 10,
                  decoration: const BoxDecoration(
                    color: AppTheme.samsungBlue,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.arrow_downward_rounded, size: 7, color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _handleCaretMoveOverTextItem(NoteTextItem item, Offset globalPos) {
    final actualGlobalPos = _lastPointerPosition ?? globalPos;
    final text = item.controller.text;
    if (text.isEmpty) {
      if (_hoveredTextItemId != item.id || _hoveredCharIndex != 0) {
        setState(() {
          _hoveredTextItemId = item.id;
          _hoveredCharIndex = 0;
          _hoveredCaretOffset = Offset.zero;
        });
      }
      return;
    }

    final key = _getTextItemKey(item.id);
    final renderBox = key.currentContext?.findRenderObject() as RenderBox?;
    final width = renderBox?.hasSize == true ? renderBox!.size.width : 400.0;
    final localPos = (renderBox != null && renderBox.hasSize)
        ? renderBox.globalToLocal(actualGlobalPos)
        : Offset.zero;

    final textPainter = TextPainter(
      text: TextSpan(
        text: text,
        style: GoogleFonts.inter(
          fontSize: 15,
          fontWeight: FontWeight.w400,
          color: AppTheme.textPrimary,
          height: 1.6,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout(maxWidth: width);

    final localY = (localPos.dy - 4.0).clamp(0.0, textPainter.height);
    final localX = localPos.dx.clamp(0.0, width);
    final textPos = textPainter.getPositionForOffset(Offset(localX, localY));
    final charIdx = textPos.offset.clamp(0, text.length);
    final caretOffset = textPainter.getOffsetForCaret(
      TextPosition(offset: charIdx),
      Rect.zero,
    );

    if (_hoveredTextItemId != item.id ||
        _hoveredCharIndex != charIdx ||
        _hoveredCaretOffset != caretOffset) {
      setState(() {
        _hoveredTextItemId = item.id;
        _hoveredCharIndex = charIdx;
        _hoveredCaretOffset = caretOffset;
      });
    }
  }

  int _getCharIndexForOffset(NoteTextItem item, Offset globalPos) {
    final actualGlobalPos = _lastPointerPosition ?? globalPos;
    final text = item.controller.text;
    if (text.isEmpty) return 0;

    final key = _getTextItemKey(item.id);
    final renderBox = key.currentContext?.findRenderObject() as RenderBox?;
    final width = renderBox?.hasSize == true ? renderBox!.size.width : 400.0;
    final localPos = (renderBox != null && renderBox.hasSize)
        ? renderBox.globalToLocal(actualGlobalPos)
        : Offset.zero;

    final textPainter = TextPainter(
      text: TextSpan(
        text: text,
        style: GoogleFonts.inter(
          fontSize: 15,
          fontWeight: FontWeight.w400,
          color: AppTheme.textPrimary,
          height: 1.6,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout(maxWidth: width);

    final localY = (localPos.dy - 4.0).clamp(0.0, textPainter.height);
    final localX = localPos.dx.clamp(0.0, width);
    final textPos = textPainter.getPositionForOffset(Offset(localX, localY));
    return textPos.offset.clamp(0, text.length);
  }

  void _splitTextAndInsertImage({
    required NoteTextItem textItem,
    required int charIndex,
    required dynamic dragData,
    required Question question,
  }) {
    String? imagePath;
    String? draggedId;

    if (dragData is String) {
      final existingIndex = _noteItems.indexWhere((it) => it.id == dragData);
      if (existingIndex != -1) {
        draggedId = dragData;
      } else {
        imagePath = dragData;
      }
    }

    if (draggedId == null && imagePath == null) {
      if (_draggedImageId != null) {
        draggedId = _draggedImageId;
      } else if (_draggedAssetPath != null) {
        imagePath = _draggedAssetPath;
      }
    }

    NoteImageItem imageToPlace;
    if (draggedId != null) {
      final imgIdx = _noteItems.indexWhere((it) => it.id == draggedId);
      if (imgIdx == -1) return;
      imageToPlace = _noteItems.removeAt(imgIdx) as NoteImageItem;
    } else if (imagePath != null) {
      imageToPlace = NoteImageItem(
        id: const Uuid().v4(),
        imagePath: imagePath,
        widthPercent: 100,
      );
    } else {
      return;
    }

    final targetIndex = _noteItems.indexOf(textItem);
    if (targetIndex == -1) {
      _noteItems.add(imageToPlace);
    } else {
      final fullText = textItem.controller.text;
      if (charIndex <= 0) {
        _noteItems.insert(targetIndex, imageToPlace);
      } else if (charIndex >= fullText.length) {
        _noteItems.insert(targetIndex + 1, imageToPlace);
      } else {
        // MS Word style: split into paragraph above and paragraph below
        final textBefore = fullText.substring(0, charIndex);
        final textAfter = fullText.substring(charIndex);

        textItem.controller.text = textBefore;

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

        _noteItems.insert(targetIndex + 1, imageToPlace);
        _noteItems.insert(targetIndex + 2, afterTextItem);
      }
    }

    _consolidateAdjacentTextItems();
    _ensureTrailingTextItem(question);

    _isDraggingImage = false;
    _draggedImageId = null;
    _draggedAssetPath = null;
    _hoveredTextItemId = null;
    _hoveredCharIndex = null;
    _hoveredCaretOffset = null;

    _saveNotes(question, text: _serializeNotes(), silent: true);
    HapticFeedback.mediumImpact();
    setState(() {});
  }

  void _insertImageNearImageItem({
    required NoteImageItem targetItem,
    required double dropY,
    required dynamic dragData,
    required Question question,
  }) {
    String? imagePath;
    String? draggedId;

    if (dragData is String) {
      final existingIndex = _noteItems.indexWhere((it) => it.id == dragData);
      if (existingIndex != -1) {
        draggedId = dragData;
      } else {
        imagePath = dragData;
      }
    }

    if (draggedId == null && imagePath == null) {
      if (_draggedImageId != null) {
        draggedId = _draggedImageId;
      } else if (_draggedAssetPath != null) {
        imagePath = _draggedAssetPath;
      }
    }

    NoteImageItem imageToPlace;
    if (draggedId != null) {
      if (draggedId == targetItem.id) return;
      final imgIdx = _noteItems.indexWhere((it) => it.id == draggedId);
      if (imgIdx == -1) return;
      imageToPlace = _noteItems.removeAt(imgIdx) as NoteImageItem;
    } else if (imagePath != null) {
      imageToPlace = NoteImageItem(
        id: const Uuid().v4(),
        imagePath: imagePath,
        widthPercent: 100,
      );
    } else {
      return;
    }

    final targetIndex = _noteItems.indexOf(targetItem);
    if (targetIndex == -1) {
      _noteItems.add(imageToPlace);
    } else {
      if (dropY < 60) {
        _noteItems.insert(targetIndex, imageToPlace);
      } else {
        _noteItems.insert(targetIndex + 1, imageToPlace);
      }
    }

    _consolidateAdjacentTextItems();
    _ensureTrailingTextItem(question);

    _isDraggingImage = false;
    _draggedImageId = null;
    _draggedAssetPath = null;
    _hoveredTextItemId = null;
    _hoveredCharIndex = null;
    _hoveredCaretOffset = null;

    _saveNotes(question, text: _serializeNotes(), silent: true);
    HapticFeedback.mediumImpact();
    setState(() {});
  }

  void _insertImageAtNotebookEnd(dynamic dragData, int questionId) {
    String? imagePath;
    String? draggedId;

    if (dragData is String) {
      final existingIndex = _noteItems.indexWhere((it) => it.id == dragData);
      if (existingIndex != -1) {
        draggedId = dragData;
      } else {
        imagePath = dragData;
      }
    }

    if (draggedId == null && imagePath == null) {
      if (_draggedImageId != null) {
        draggedId = _draggedImageId;
      } else if (_draggedAssetPath != null) {
        imagePath = _draggedAssetPath;
      }
    }

    NoteImageItem imageToPlace;
    if (draggedId != null) {
      final imgIdx = _noteItems.indexWhere((it) => it.id == draggedId);
      if (imgIdx == -1) return;
      imageToPlace = _noteItems.removeAt(imgIdx) as NoteImageItem;
    } else if (imagePath != null) {
      imageToPlace = NoteImageItem(
        id: const Uuid().v4(),
        imagePath: imagePath,
        widthPercent: 100,
      );
    } else {
      return;
    }

    _noteItems.add(imageToPlace);
    _consolidateAdjacentTextItems();
    if (_currentQuestion != null) {
      _ensureTrailingTextItem(_currentQuestion!);
      _saveNotes(_currentQuestion!, text: _serializeNotes(), silent: true);
    }

    _isDraggingImage = false;
    _draggedImageId = null;
    _draggedAssetPath = null;
    _hoveredTextItemId = null;
    _hoveredCharIndex = null;
    _hoveredCaretOffset = null;

    HapticFeedback.mediumImpact();
    setState(() {});
  }

  Widget _buildDraggingTextItem(NoteTextItem item, Question question) {
    final key = _getTextItemKey(item.id);
    final text = item.controller.text;
    final isHovered = _hoveredTextItemId == item.id && _hoveredCaretOffset != null;

    return Container(
      key: key,
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Text(
            text.isEmpty ? ' ' : text,
            style: GoogleFonts.inter(
              fontSize: 15,
              fontWeight: FontWeight.w400,
              color: AppTheme.textPrimary,
              height: 1.6,
            ),
          ),
          if (isHovered)
            Positioned(
              left: _hoveredCaretOffset!.dx - 1.25,
              top: _hoveredCaretOffset!.dy,
              child: Container(
                width: 2.5,
                height: 24.0,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(1.25),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.white.withValues(alpha: 0.9),
                      blurRadius: 4,
                      spreadRadius: 1,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTextItemDragTarget(NoteTextItem item, int index, Question question) {
    return DragTarget<String>(
      onWillAcceptWithDetails: (details) => true,
      onMove: (details) {
        _handleCaretMoveOverTextItem(item, details.offset);
      },
      onLeave: (data) {
        if (_hoveredTextItemId == item.id) {
          setState(() {
            _hoveredTextItemId = null;
            _hoveredCharIndex = null;
            _hoveredCaretOffset = null;
          });
        }
      },
      onAcceptWithDetails: (details) {
        final charIdx = _getCharIndexForOffset(item, details.offset);
        _splitTextAndInsertImage(
          textItem: item,
          charIndex: charIdx,
          dragData: details.data,
          question: question,
        );
      },
      builder: (context, candidateData, rejectedData) {
        if (_isDraggingImage) {
          return _buildDraggingTextItem(item, question);
        } else {
          return _buildNoteTextField(item, question);
        }
      },
    );
  }

  Widget _buildImageItemDragTarget(NoteImageItem item, int index, Question question) {
    final key = _getImageItemKey(item.id);
    return DragTarget<String>(
      key: key,
      onWillAcceptWithDetails: (details) => details.data != item.id,
      onMove: (details) {
        final actualGlobalPos = _lastPointerPosition ?? details.offset;
        final renderBox = key.currentContext?.findRenderObject() as RenderBox?;
        if (renderBox != null && renderBox.hasSize) {
          final localPos = renderBox.globalToLocal(actualGlobalPos);
          final isTopHalf = localPos.dy < (renderBox.size.height / 2);
          if (_hoveredImageItemId != item.id || _hoveredImageTopHalf != isTopHalf) {
            setState(() {
              _hoveredImageItemId = item.id;
              _hoveredImageTopHalf = isTopHalf;
            });
          }
        }
      },
      onLeave: (details) {
        if (_hoveredImageItemId == item.id) {
          setState(() {
            _hoveredImageItemId = null;
          });
        }
      },
      onAcceptWithDetails: (details) {
        setState(() {
          _hoveredImageItemId = null;
        });
        final renderBox = key.currentContext?.findRenderObject() as RenderBox?;
        final localPos = (renderBox != null && renderBox.hasSize)
            ? renderBox.globalToLocal(details.offset)
            : Offset.zero;
        _insertImageNearImageItem(
          targetItem: item,
          dropY: localPos.dy,
          dragData: details.data,
          question: question,
        );
      },
      builder: (context, candidateData, rejectedData) {
        final isHovered = _hoveredImageItemId == item.id;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (isHovered && _hoveredImageTopHalf)
              Container(
                height: 4,
                margin: const EdgeInsets.only(bottom: 4),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(2)),
              ),
            _buildNoteImageWidget(item, index, question),
            if (isHovered && !_hoveredImageTopHalf)
              Container(
                height: 4,
                margin: const EdgeInsets.only(top: 4),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(2)),
              ),
          ],
        );
      },
    );
  }

  Widget _buildTrailingNotebookDropZone(Question question) {
    return DragTarget<String>(
      onWillAcceptWithDetails: (details) => true,
      onAcceptWithDetails: (details) {
        _insertImageAtNotebookEnd(details.data, question.id);
      },
      builder: (context, candidateData, rejectedData) {
        final isHovered = candidateData.isNotEmpty;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: double.infinity,
          height: isHovered ? 56 : (_isDraggingImage ? 40 : 16),
          margin: const EdgeInsets.only(top: 8),
          decoration: BoxDecoration(
            color: isHovered ? Colors.white.withOpacity(0.08) : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: isHovered
                ? Border.all(color: Colors.white, width: 1.5)
                : (_isDraggingImage ? Border.all(color: Colors.white12, width: 1.0) : null),
          ),
          child: isHovered
              ? const Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.add_photo_alternate_outlined, color: Colors.white, size: 18),
                      SizedBox(width: 8),
                      Text(
                        'Drop at end of notebook',
                        style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                )
              : null,
        );
      },
    );
  }

  Widget _buildNotebookContent(Question question) {
    final innerNotebookContent = Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.black.withOpacity(0.4),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (int i = 0; i < _noteItems.length; i++) ...[
            if (_noteItems[i] is NoteTextItem)
              _buildTextItemDragTarget(_noteItems[i] as NoteTextItem, i, question)
            else if (_noteItems[i] is NoteImageItem)
              _buildImageItemDragTarget(_noteItems[i] as NoteImageItem, i, question),
          ],
          _buildTrailingNotebookDropZone(question),
        ],
      ),
    );

    Widget notebookWidget = DropRegion(
      formats: Formats.standardFormats,
      onDropOver: (event) {
        if (!_isDraggingNotebook && mounted) {
          setState(() => _isDraggingNotebook = true);
        }
        return DropOperation.copy;
      },
      onDropLeave: (event) {
        if (_isDraggingNotebook && mounted) {
          setState(() => _isDraggingNotebook = false);
        }
      },
      onPerformDrop: (event) async {
        if (mounted) setState(() => _isDraggingNotebook = false);
        HapticFeedback.mediumImpact();
        for (final item in event.session.items) {
          await _processDroppedItem(item, (bytes, ext) async {
            try {
              final destPath = await _saveFilePermanently(bytes, ext);

              final repo = await ref.read(questionRepositoryProvider.future);
              await repo.isar.writeTxn(() async {
                final q = await repo.isar.questions.get(question.id);
                if (q != null) {
                  final images = List<String>.from(q.images ?? []);
                  if (!images.contains(destPath)) {
                    images.add(destPath);
                    q.images = images;
                    await repo.isar.collection<Question>().put(q);
                  }
                }
              });

              if (_hoveredTextItemId != null && _hoveredCharIndex != null) {
                final targetItem = _noteItems.firstWhere(
                  (it) => it.id == _hoveredTextItemId,
                  orElse: () => NoteTextItem(id: '', initialText: ''),
                );
                if (targetItem is NoteTextItem && targetItem.id.isNotEmpty) {
                  _splitTextAndInsertImage(
                    textItem: targetItem,
                    charIndex: _hoveredCharIndex!,
                    dragData: destPath,
                    question: question,
                  );
                } else {
                  _insertImageAtNotebookEnd(destPath, question.id);
                }
              } else {
                _insertImageAtNotebookEnd(destPath, question.id);
              }
              if (mounted) setState(() {});
            } catch (e) {
              debugPrint('Failed to save dropped file into notebook: $e');
            }
          });
        }
      },
      child: innerNotebookContent,
    );

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyV, control: true): () => _pasteIntoNotebook(question),
        const SingleActivator(LogicalKeyboardKey.keyV, meta: true): () => _pasteIntoNotebook(question),
      },
      child: Actions(
        actions: <Type, Action<Intent>>{
          PasteTextIntent: CallbackAction<PasteTextIntent>(
            onInvoke: (intent) async {
              await _pasteIntoNotebook(question);
              return null;
            },
          ),
        },
        child: notebookWidget,
      ),
    );
  }

  Widget _buildNoteTextField(NoteTextItem item, Question question) {
    return Theme(
      data: Theme.of(context).copyWith(
        textSelectionTheme: const TextSelectionThemeData(
          cursorColor: Colors.white,
          selectionHandleColor: Colors.transparent, // Completely hides the water drop teardrop handle
          selectionColor: Colors.white24,
        ),
      ),
      child: TextField(
        key: ValueKey(item.id),
        controller: item.controller,
        focusNode: item.focusNode,
        cursorColor: Colors.white,
        cursorWidth: 2.0,
        cursorRadius: const Radius.circular(1.0),
        maxLines: null,
        minLines: 1,
        textInputAction: TextInputAction.newline,
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
      ),
    );
  }

  Widget _buildNoteImageWidget(NoteImageItem item, int index, Question question) {
    final isSelected = _selectedImageId == item.id;
    final factor = (item.widthPercent / 100.0).clamp(0.15, 1.0);

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
          errorBuilder: (_, __, ___) {
            final resolved = _resolveLocalImagePath(item.imagePath, question);
            if (resolved != null && resolved != item.imagePath) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) {
                  setState(() {
                    item.imagePath = resolved;
                    _saveNotes(question, text: _serializeNotes(), silent: true);
                  });
                }
              });
              return Image.file(io.File(resolved), fit: BoxFit.fitWidth);
            }
            return Container(
              height: 120,
              color: Colors.white10,
              child: const Center(
                child: Text('Image file not found', style: TextStyle(color: Colors.white54, fontSize: 12)),
              ),
            );
          },
        ),
      ),
    );

    return Container(
      key: ValueKey(item.id),
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildAdaptiveDraggable<String>(
            data: item.id,
            onDragStarted: () {
              HapticFeedback.lightImpact();
              setState(() {
                _isDraggingImage = true;
                _draggedImageId = item.id;
                _draggedAssetPath = null;
              });
            },
            onDragEnd: (_) {
              setState(() {
                _isDraggingImage = false;
                _draggedImageId = null;
                _draggedAssetPath = null;
                _hoveredTextItemId = null;
                _hoveredCharIndex = null;
                _hoveredCaretOffset = null;
              });
            },
            onDraggableCanceled: () {
              setState(() {
                _isDraggingImage = false;
                _draggedImageId = null;
                _draggedAssetPath = null;
                _hoveredTextItemId = null;
                _hoveredCharIndex = null;
                _hoveredCaretOffset = null;
              });
            },
            feedback: _buildWordDragPointerBadge(imagePath: item.imagePath),
            childWhenDragging: Opacity(
              opacity: 0.2,
              child: imageCard,
            ),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                setState(() {
                  _selectedImageId = isSelected ? null : item.id;
                });
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white24, width: 1.0),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Padding(
            padding: EdgeInsets.only(left: 4, right: 2),
            child: Icon(Icons.photo_size_select_large_rounded, size: 16, color: Colors.white70),
          ),
          SizedBox(
            width: 120,
            height: 32,
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 6.0,
                activeTrackColor: Colors.white,
                inactiveTrackColor: Colors.white12,
                thumbColor: Colors.white,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6, elevation: 2),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
                overlayColor: Colors.white10,
              ),
              child: Slider(
                value: item.widthPercent.toDouble().clamp(15.0, 100.0),
                min: 15.0,
                max: 100.0,
                onChanged: (val) {
                  final newPct = val.round();
                  if ((newPct - item.widthPercent).abs() >= 1) {
                    if (newPct % 25 == 0) HapticFeedback.selectionClick();
                    setState(() {
                      item.widthPercent = newPct;
                    });
                  }
                },
                onChangeEnd: (val) {
                  _saveNotes(question, text: _serializeNotes());
                },
              ),
            ),
          ),
          SizedBox(
            width: 38,
            child: Text(
              '${item.widthPercent}%',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.3,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(width: 4),
          Container(width: 1, height: 16, color: Colors.white24),
          const SizedBox(width: 4),
          IconButton(
            icon: const Icon(Icons.folder_shared_outlined, size: 16, color: Colors.white70),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
            tooltip: 'Copy to Answer Resources',
            onPressed: () async {
              final repo = await ref.read(questionRepositoryProvider.future);
              await repo.isar.writeTxn(() async {
                final q = await repo.isar.questions.get(question.id);
                if (q != null) {
                  final images = List<String>.from(q.images ?? []);
                  if (!images.contains(item.imagePath)) {
                    images.add(item.imagePath);
                    q.images = images;
                    await repo.isar.collection<Question>().put(q);
                  }
                }
              });
              HapticFeedback.lightImpact();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Image copied to Answer Resources!'),
                    backgroundColor: Colors.white24,
                    duration: Duration(seconds: 2),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
              setState(() {});
            },
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

                    // 4. Insert into Notebook (when viewed from Answer Resources)
                    if (!isFromNotebook) ...[
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppTheme.samsungBlue.withOpacity(0.15),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.note_add_outlined, color: AppTheme.samsungBlue, size: 20),
                        ),
                        title: const Text(
                          'Insert into Notebook',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15),
                        ),
                        subtitle: const Text(
                          'Add this image directly to your notes',
                          style: TextStyle(color: Colors.white54, fontSize: 12),
                        ),
                        onTap: () {
                          Navigator.pop(sheetContext);
                          _insertImageAtNotebookEnd(imagePath, question.id);
                          HapticFeedback.lightImpact();
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Image inserted into Notebook!'),
                                backgroundColor: Colors.white24,
                                duration: Duration(seconds: 2),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          }
                        },
                      ),
                    ],

                    // 5. Notebook Sizing Percentile
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
    if (source == ImageSource.camera) {
      final picker = ImagePicker();
      final image = await picker.pickImage(source: source);
      if (image != null) {
        final bytes = await image.readAsBytes();
        final savedPath = await _saveFilePermanently(bytes, 'jpg');
        final repo = await ref.read(questionRepositoryProvider.future);
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
        if (mounted) setState(() {});
      }
    } else {
      _addAssetViaPicker(question);
    }
  }

  Future<void> _pasteImage(Question question) async {
    if (_isIngestingImage) return;
    setState(() => _isIngestingImage = true);
    try {
      final paths = await _ingestClipboardImages();
      if (paths.isNotEmpty) {
        final repo = await ref.read(questionRepositoryProvider.future);
        await repo.isar.writeTxn(() async {
          final q = await repo.isar.questions.get(question.id);
          if (q != null) {
            final images = List<String>.from(q.images ?? []);
            for (final p in paths) {
              if (!images.contains(p)) images.add(p);
            }
            q.images = images;
            await repo.isar.collection<Question>().put(q);
          }
        });
        HapticFeedback.vibrate();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Pasted ${paths.length} image(s) into Answer Resources!'),
              backgroundColor: Colors.white24,
              duration: const Duration(seconds: 2),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        if (mounted) setState(() {});
        return;
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No image found in clipboard'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isIngestingImage = false);
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
