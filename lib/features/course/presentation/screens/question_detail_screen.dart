import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories/question_repository.dart';
import '../../domain/models/question.dart';
import 'package:exam_command_center/core/theme/app_theme.dart';
import 'package:image_picker/image_picker.dart';
import 'package:desktop_drop/desktop_drop.dart';
import 'dart:io' as io;
import '../widgets/difficulty_stars.dart';

class QuestionDetailScreen extends ConsumerStatefulWidget {
  final int questionId;

  const QuestionDetailScreen({super.key, required this.questionId});

  @override
  ConsumerState<QuestionDetailScreen> createState() => _QuestionDetailScreenState();
}

class _QuestionDetailScreenState extends ConsumerState<QuestionDetailScreen> {
  final _notesController = TextEditingController();
  bool _isEditingNotes = false;
  bool _isDragging = false;

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
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
          
          if (!_isEditingNotes) {
            _notesController.text = question.userNotes ?? '';
          }

          String bannerTitle = question.title;
          bool isPartA = false;
          if (bannerTitle.startsWith(RegExp(r'^\[Unit \d+\]'))) {
            isPartA = true;
            bannerTitle = 'PART A';
          }

          return DropTarget(
            onDragDone: (detail) async {
              setState(() => _isDragging = false);
              if (detail.files.isEmpty) return;
              
              final repo = await ref.read(questionRepositoryProvider.future);
              await repo.isar.writeTxn(() async {
                final q = await repo.isar.questions.get(widget.questionId);
                if (q != null) {
                  final images = List<String>.from(q.images ?? []);
                  for (final file in detail.files) {
                    final p = file.path.toLowerCase();
                    if (p.endsWith('.jpg') || p.endsWith('.jpeg') || p.endsWith('.png') || p.endsWith('.webp')) {
                      images.add(file.path);
                    }
                  }
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
                        const SizedBox(height: 8),
                        Text('MISSION OBJECTIVE DETAILS', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
                      ],
                    ),
                  ),
                ),

                SliverPadding(
                  padding: EdgeInsets.symmetric(horizontal: hPad),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      // 1. STATUS CARD
                      _buildOneUICard(
                        title: 'Operational Status',
                        child: Row(
                          children: [
                            _statusPill(context, question, QuestionStatus.incomplete, 'PENDING', Icons.radio_button_unchecked, AppTheme.textSecondary),
                            const SizedBox(width: 8),
                            _statusPill(context, question, QuestionStatus.revisionNeeded, 'REVISE', Icons.autorenew, AppTheme.inProgressColor),
                            const SizedBox(width: 8),
                            _statusPill(context, question, QuestionStatus.completed, 'COMPLETED', Icons.verified, AppTheme.completedColor),
                          ],
                        ),
                      ),

                      const SizedBox(height: 16),

                      const SizedBox(height: 16),

                      // 3. QUESTION CARD (AI Analysis Leftovers)
                      _buildOneUICard(
                        title: 'Question',
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: AppTheme.black.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Text(
                            isPartA 
                              ? '${question.title.replaceFirst(RegExp(r'^\[Unit \d+\]\s*'), '')}\n\n${question.notes ?? ""}'.trim()
                              : (question.notes?.isEmpty ?? true ? 'No question details available.' : question.notes!),
                            style: TextStyle(
                              fontSize: 15, 
                              height: 1.5, 
                              color: isPartA ? AppTheme.textPrimary : (question.notes?.isEmpty ?? true ? AppTheme.textSecondary : AppTheme.textPrimary),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 16),

                      // 4. NOTES CARD (User Notepad)
                      _buildOneUICard(
                        title: 'Notes',
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (_isEditingNotes)
                              IconButton(
                                icon: const Icon(Icons.delete_outline, color: AppTheme.urgentColor, size: 24),
                                onPressed: () {
                                  _notesController.clear();
                                  _saveNotes(question);
                                  setState(() => _isEditingNotes = false);
                                },
                              ),
                            if (_isEditingNotes)
                              IconButton(
                                icon: const Icon(Icons.check_circle, color: Colors.white, size: 24),
                                onPressed: () {
                                  _saveNotes(question);
                                  setState(() => _isEditingNotes = false);
                                },
                              ),
                          ],
                        ),
                        child: _isEditingNotes
                          ? TextField(
                              controller: _notesController,
                              maxLines: null,
                              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
                              decoration: InputDecoration(
                                hintText: 'Input notes...',
                                filled: true,
                                fillColor: AppTheme.black.withOpacity(0.4),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                                contentPadding: const EdgeInsets.all(16),
                              ),
                            )
                          : GestureDetector(
                              onDoubleTap: () => setState(() => _isEditingNotes = true),
                              child: Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                  color: AppTheme.black.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Text(
                                  question.userNotes?.isEmpty ?? true ? 'No notes available. Double tap to edit.' : question.userNotes!,
                                  style: TextStyle(
                                    fontSize: 15, 
                                    height: 1.5, 
                                    color: question.userNotes?.isEmpty ?? true ? AppTheme.textSecondary : AppTheme.textPrimary,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
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

  Widget _buildOneUICard({required String title, required Widget child, Widget? trailing}) {
    return Container(
      padding: const EdgeInsets.all(24),
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

  Widget _statusPill(BuildContext context, Question question, QuestionStatus status, String label, IconData icon, Color color) {
    final isSelected = question.status == status;
    return Expanded(
      child: InkWell(
        onTap: () => _updateStatus(status),
        borderRadius: BorderRadius.circular(16),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : Colors.transparent,
            border: Border.all(color: isSelected ? Colors.white : Colors.white24, width: 1.5),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              Icon(icon, color: isSelected ? Colors.black : Colors.white54, size: 24),
              const SizedBox(height: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  color: isSelected ? Colors.black : Colors.white54,
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

  void _saveNotes(Question question) async {
    final repo = await ref.read(questionRepositoryProvider.future);
    await repo.isar.writeTxn(() async {
      question.userNotes = _notesController.text;
      await repo.isar.collection<Question>().put(question);
    });
    HapticFeedback.vibrate();
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
        await repo.isar.writeTxn(() async {
          final q = await repo.isar.questions.get(question.id);
          if (q != null) {
            final images = List<String>.from(q.images ?? []);
            images.add(image.path);
            q.images = images;
            await repo.isar.questions.put(q);
          }
        });
        HapticFeedback.vibrate();
      }
    } else {
      final List<XFile> imagesList = await picker.pickMultiImage();
      if (imagesList.isNotEmpty) {
        await repo.isar.writeTxn(() async {
          final q = await repo.isar.questions.get(question.id);
          if (q != null) {
            final images = List<String>.from(q.images ?? []);
            for (var img in imagesList) {
              images.add(img.path);
            }
            q.images = images;
            await repo.isar.questions.put(q);
          }
        });
        HapticFeedback.vibrate();
      }
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
