import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories/question_repository.dart';
import '../../domain/models/question.dart';
import 'package:exam_command_center/core/theme/app_theme.dart';
import 'package:image_picker/image_picker.dart';
import 'package:desktop_drop/desktop_drop.dart';
import 'dart:io' as io;
import 'dart:async';
import '../widgets/difficulty_stars.dart';
import 'package:pasteboard/pasteboard.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/cupertino.dart';

class QuestionDetailScreen extends ConsumerStatefulWidget {
  final int questionId;

  const QuestionDetailScreen({super.key, required this.questionId});

  @override
  ConsumerState<QuestionDetailScreen> createState() => _QuestionDetailScreenState();
}

class _QuestionDetailScreenState extends ConsumerState<QuestionDetailScreen> {
  final _notesController = TextEditingController();
  final _questionController = TextEditingController();
  bool _hasInitializedNotes = false;
  bool _hasInitializedQuestion = false;
  bool _isDragging = false;
  Timer? _debounce;
  Timer? _questionDebounce;
  Question? _currentQuestion;

  @override
  void dispose() {
    if (_debounce?.isActive ?? false) {
      _debounce!.cancel();
      if (_currentQuestion != null) {
        _saveNotes(_currentQuestion!, text: _notesController.text, silent: true);
      }
    }
    if (_questionDebounce?.isActive ?? false) {
      _questionDebounce!.cancel();
      if (_currentQuestion != null) {
        _saveQuestionNotes(_currentQuestion!, text: _questionController.text, silent: true);
      }
    }
    _notesController.dispose();
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
            _notesController.text = question.userNotes ?? '';
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
              body: CustomScrollView(
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
                          maxLines: null,
                          minLines: 1,
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
                        padding: const EdgeInsets.all(16),
                        child: TextField(
                          controller: _notesController,
                          maxLines: null,
                          minLines: 1,
                          style: GoogleFonts.inter(
                            fontSize: 15, 
                            fontWeight: FontWeight.w400, 
                            color: AppTheme.textPrimary, 
                            height: 1.6,
                          ),
                          onChanged: (val) {
                            if (_debounce?.isActive ?? false) _debounce!.cancel();
                            _debounce = Timer(const Duration(milliseconds: 300), () {
                              _saveNotes(question, text: val, silent: true);
                            });
                          },
                          decoration: InputDecoration(
                            hintText: 'Paste or type your notes here...',
                            hintStyle: const TextStyle(color: Colors.white38),
                            filled: true,
                            fillColor: AppTheme.black.withOpacity(0.4),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                            contentPadding: const EdgeInsets.all(12),
                          ),
                        ),
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
        Container(
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
      default:
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

  Color _getStatusThumbColor(QuestionStatus status) {
    switch (status) {
      case QuestionStatus.completed:
        return AppTheme.completedColor.withOpacity(0.25);
      case QuestionStatus.revisionNeeded:
        return AppTheme.inProgressColor.withOpacity(0.25);
      case QuestionStatus.incomplete:
      default:
        return Colors.white.withOpacity(0.2);
    }
  }

  void _updateStatus(QuestionStatus status) async {
    final repo = await ref.read(questionRepositoryProvider.future);
    await repo.updateStatus(widget.questionId, status);
    HapticFeedback.mediumImpact();
  }

  void _saveNotes(Question question, {String? text, bool silent = false}) async {
    final textToSave = text ?? _notesController.text;
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
