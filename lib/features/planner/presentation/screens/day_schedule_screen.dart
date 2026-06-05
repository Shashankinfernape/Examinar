import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/gestures.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/database/isar_provider.dart';
import 'package:isar/isar.dart';
import '../../domain/models/planner_event.dart';
import '../../../course/domain/models/course.dart';
import '../../../course/domain/models/unit.dart';
import '../../../course/domain/models/question.dart';
import '../widgets/task_action_sheet.dart';

final selectedDateProvider = StateProvider<DateTime>((ref) => DateTime.now());
final reschedulingEventProvider = StateProvider<PlannerEvent?>((ref) => null);

// ══════════════════════════════════════════════════════════════
//  DAY SCHEDULE SCREEN
// ══════════════════════════════════════════════════════════════

class DayScheduleScreen extends ConsumerStatefulWidget {
  const DayScheduleScreen({super.key});
  @override
  ConsumerState<DayScheduleScreen> createState() => _DayScheduleScreenState();
}

class _DayScheduleScreenState extends ConsumerState<DayScheduleScreen> {
  @override
  Widget build(BuildContext context) {
    final date = ref.watch(selectedDateProvider);
    final isarAsync = ref.watch(isarProvider);
    final bool isToday = date.year == DateTime.now().year &&
        date.month == DateTime.now().month &&
        date.day == DateTime.now().day;

    return Scaffold(
      backgroundColor: AppTheme.black,
      // ── Standard AppBar ──────────────────────────────────────────────
      appBar: AppBar(
        backgroundColor: AppTheme.black,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18, color: AppTheme.textPrimary),
          onPressed: () => context.pop(),
        ),
        title: Column(
          children: [
            Text(
              ref.watch(reschedulingEventProvider) != null 
                  ? 'SELECT NEW TIME' 
                  : DateFormat('EEEE d MMMM').format(date).toUpperCase(),
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: Colors.white,
                letterSpacing: 1.5,
              ),
            ),
            if (isToday)
              const Text(
                'Today',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.samsungBlue,
                ),
              ),
          ],
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: const Color(0xFF1A1A28), height: 1),
        ),
        actions: [
          isarAsync.when(
            data: (isar) => IconButton(
              icon: const Icon(Icons.refresh, color: AppTheme.textSecondary, size: 20),
              onPressed: () async {
                final events = await isar.plannerEvents.where().findAll();
                final dayEvents = events.where((e) => e.startTime.year == date.year && e.startTime.month == date.month && e.startTime.day == date.day).toList();
                await isar.writeTxn(() async {
                  for (var e in dayEvents) {
                    await isar.plannerEvents.delete(e.id);
                  }
                });
              },
            ),
            loading: () => const SizedBox(),
            error: (_, __) => const SizedBox(),
          )
        ],
      ),

      // ── Body ─────────────────────────────────────────────────────────
      body: isarAsync.when(
        data: (isar) => StreamBuilder<void>(
          stream: isar.plannerEvents.watchLazy(fireImmediately: true),
          builder: (_, __) => FutureBuilder<List<PlannerEvent>>(
            future: isar.plannerEvents.where().findAll(),
            builder: (ctx, snapshot) {
              final allEvents = snapshot.data ?? [];
              final events = allEvents
                  .where((e) =>
                      e.startTime.year == date.year &&
                      e.startTime.month == date.month &&
                      e.startTime.day == date.day &&
                      !e.title.startsWith('EXAM:') &&
                      e.colorHex != const Color(0xFFF28B82).value.toRadixString(16))
                  .toList();

              return _ScheduleList(events: events, date: date, isar: isar);
            },
          ),
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, s) => Center(child: Text('Error: $e')),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
//  SCHEDULE LIST — Isolates drag state so DB isn't requeried
// ══════════════════════════════════════════════════════════════

class _ScheduleList extends ConsumerStatefulWidget {
  final List<PlannerEvent> events;
  final DateTime date;
  final Isar isar;
  const _ScheduleList({required this.events, required this.date, required this.isar});

  @override
  ConsumerState<_ScheduleList> createState() => _ScheduleListState();
}

class _ScheduleListState extends ConsumerState<_ScheduleList> {
  final ScrollController _scrollController = ScrollController();
  final List<GlobalKey> _hourKeys = List.generate(24, (_) => GlobalKey());

  int? _dragStartHour;
  int? _dragCurrentHour;
  bool _isSelectionMode = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(8 * 80.0);
      }
    });
  }

  int? _getHourFromOffset(Offset globalOffset) {
    for (int i = 0; i < 24; i++) {
      final key = _hourKeys[i];
      final RenderBox? box = key.currentContext?.findRenderObject() as RenderBox?;
      if (box != null) {
        final pos = box.localToGlobal(Offset.zero);
        if (globalOffset.dy >= pos.dy && globalOffset.dy <= pos.dy + box.size.height) {
          return i;
        }
      }
    }
    return null;
  }

  void _onLongPressStart(LongPressStartDetails details) {
    final h = _getHourFromOffset(details.globalPosition);
    if (h != null) {
      HapticFeedback.heavyImpact();
      setState(() {
        _isSelectionMode = true;
        _dragStartHour = h;
        _dragCurrentHour = h;
      });
    }
  }

  void _onPointerMove(PointerMoveEvent event) {
    if (!_isSelectionMode) return;
    final h = _getHourFromOffset(event.position);
    if (h != null && h != _dragCurrentHour) {
      HapticFeedback.selectionClick();
      setState(() => _dragCurrentHour = h);
    }
  }

  void _onPointerUp(PointerUpEvent event) {
    if (_isSelectionMode && _dragStartHour != null && _dragCurrentHour != null) {
      final minH = math.min(_dragStartHour!, _dragCurrentHour!);
      final maxH = math.max(_dragStartHour!, _dragCurrentHour!) + 1;
      setState(() {
        _isSelectionMode = false;
        _dragStartHour = null;
        _dragCurrentHour = null;
      });
      final reschedulingEvent = ref.read(reschedulingEventProvider);

      if (reschedulingEvent != null) {
        final newStart = DateTime(widget.date.year, widget.date.month, widget.date.day, minH);
        final newEnd = DateTime(widget.date.year, widget.date.month, widget.date.day, maxH);
        
        // Capture context state synchronously before the async gap!
        final bool shouldPop = GoRouterState.of(context).uri.path == '/planner/day';
        final bool canPop = Navigator.canPop(context);

        () async {
          try {
            await widget.isar.writeTxn(() async {
              reschedulingEvent.startTime = newStart;
              reschedulingEvent.endTime = newEnd;
              await widget.isar.plannerEvents.put(reschedulingEvent);
            });
          } catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error rescheduling: $e')));
            }
          } finally {
            if (mounted) {
              ref.read(reschedulingEventProvider.notifier).state = null;
            }
          }
        }();
        return;
      }
      
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => _ScheduleWizard(
          startTime: DateTime(widget.date.year, widget.date.month, widget.date.day, minH),
          endTime: DateTime(widget.date.year, widget.date.month, widget.date.day, maxH),
          isar: widget.isar,
        ),
      );
    }
  }

  String _timeLabel(int i) {
    if (i == 0) return '12 AM';
    if (i < 12) return '$i AM';
    if (i == 12) return '12 PM';
    return '${i - 12} PM';
  }

  @override
  Widget build(BuildContext context) {
    int? minSel, maxSel;
    if (_isSelectionMode && _dragStartHour != null && _dragCurrentHour != null) {
      minSel = math.min(_dragStartHour!, _dragCurrentHour!);
      maxSel = math.max(_dragStartHour!, _dragCurrentHour!);
    }

    return Listener(
      behavior: HitTestBehavior.opaque,
      onPointerMove: _onPointerMove,
      onPointerUp: _onPointerUp,
      child: SingleChildScrollView(
        controller: _scrollController,
        physics: const BouncingScrollPhysics(),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onLongPressStart: _onLongPressStart,
          // We rely on Listener for move/up to bypass scroll arena cancellation
          child: Column(
          children: List.generate(24, (i) {
            final hourEvents = widget.events.where((e) {
              if (e.startTime.hour == i) return true;
              if (i > e.startTime.hour && i < e.endTime.hour) return true;
              if (i == e.endTime.hour && e.endTime.minute > 0) return true;
              return false;
            }).toList();

            final bool isSelected = minSel != null && i >= minSel && i <= maxSel!;
            final bool isTopSel = isSelected && i == minSel;
            final bool isBotSel = isSelected && i == maxSel;

            return _AgendaHourRow(
              key: _hourKeys[i],
              hour: i,
              label: _timeLabel(i),
              events: hourEvents,
              isar: widget.isar,
              isSelected: isSelected,
              isSelectionTop: isTopSel,
              isSelectionBottom: isBotSel,
              onMouseDragStart: () {
                HapticFeedback.heavyImpact();
                setState(() {
                  _isSelectionMode = true;
                  _dragStartHour = i;
                  _dragCurrentHour = i;
                });
              },
            );
          }),
        ),
      ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
//  AGENDA HOUR ROW — Expands natively
// ══════════════════════════════════════════════════════════════

class _AgendaHourRow extends StatelessWidget {
  final int hour;
  final String label;
  final List<PlannerEvent> events;
  final Isar isar;
  final bool isSelected;
  final bool isSelectionTop;
  final bool isSelectionBottom;
  final VoidCallback? onMouseDragStart;

  const _AgendaHourRow({
    super.key,
    required this.hour,
    required this.label,
    required this.events,
    required this.isar,
    this.isSelected = false,
    this.isSelectionTop = false,
    this.isSelectionBottom = false,
    this.onMouseDragStart,
  });

  @override
  Widget build(BuildContext context) {
    // Dynamic selection styling (Samsung Blue)
    final bgColor = isSelected 
        ? AppTheme.samsungBlue.withOpacity(0.12)
        : Colors.transparent;
        
    final borderColor = isSelected 
        ? AppTheme.samsungBlue.withOpacity(0.4)
        : const Color(0xFF1C1C1E);

    final borderRadius = BorderRadius.vertical(
      top: isSelectionTop ? const Radius.circular(12) : Radius.zero,
      bottom: isSelectionBottom ? const Radius.circular(12) : Radius.zero,
    );

    final bool hasEventContinuingNextHour = events.any((e) => 
      e.endTime.hour > hour + 1 || (e.endTime.hour == hour + 1 && e.endTime.minute > 0)
    );
    final bool hasEventContinuingFromPreviousHour = events.any((e) => hour > e.startTime.hour);

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Time Column - Centered Vertically with Bottom Border
          Listener(
            onPointerDown: (e) {
              if (e.kind == PointerDeviceKind.mouse) onMouseDragStart?.call();
            },
            child: Container(
              width: 85,
              decoration: BoxDecoration(
                border: Border(bottom: hasEventContinuingNextHour ? BorderSide.none : const BorderSide(color: Color(0xFF1C1C1E), width: 1)),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      color: isSelected ? AppTheme.samsungBlue : const Color(0xFF8E8E93),
                      fontSize: 12,
                      letterSpacing: 1.5,
                      fontWeight: isSelected ? FontWeight.w900 : FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          // Vertical divider
          Container(
            width: 1,
            color: const Color(0xFF1C1C1E),
          ),

          // Content Column
          Expanded(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              margin: EdgeInsets.zero, // Zero margin to span fully
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: borderRadius,
                border: isSelected 
                  ? Border(
                      left: BorderSide(color: borderColor, width: 1.5),
                      right: BorderSide(color: borderColor, width: 1.5),
                      top: isSelectionTop ? BorderSide(color: borderColor, width: 1.5) : BorderSide.none,
                      bottom: isSelectionBottom ? BorderSide(color: borderColor, width: 1.5) : BorderSide.none,
                    )
                  : Border(bottom: hasEventContinuingNextHour ? BorderSide.none : const BorderSide(color: Color(0xFF1C1C1E), width: 1)),
              ),
              child: Container(
                constraints: const BoxConstraints(minHeight: 56), // Much more compact default
                padding: EdgeInsets.fromLTRB(10, hasEventContinuingFromPreviousHour ? 0 : 6, 12, hasEventContinuingNextHour ? 0 : 6),
                child: events.isEmpty
                    ? Listener(
                        onPointerDown: (e) {
                          if (e.kind == PointerDeviceKind.mouse) onMouseDragStart?.call();
                        },
                        child: Container(color: Colors.transparent),
                      ) // Empty slot
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: events.map((e) {
                          final isContinuation = hour > e.startTime.hour;
                          final isLastSegment = e.endTime.hour == hour || (e.endTime.hour == hour + 1 && e.endTime.minute == 0);
                          
                          return Padding(
                            padding: EdgeInsets.only(bottom: isLastSegment ? 6.0 : 0.0),
                            child: FutureBuilder<List<Question?>>(
                              future: e.questionIds != null && e.questionIds!.isNotEmpty
                                  ? isar.questions.getAll(e.questionIds!)
                                  : Future.value([]),
                              builder: (_, snap) {
                                final qs = snap.data?.whereType<Question>().toList() ?? [];
                                
                                // Visually distribute tasks across the multi-hour span
                                int durationInHours = e.endTime.difference(e.startTime).inHours;
                                if (durationInHours < 1) durationInHours = 1;
                                int currentHourIndex = hour - e.startTime.hour;
                                if (currentHourIndex < 0) currentHourIndex = 0;
                                if (currentHourIndex >= durationInHours) currentHourIndex = durationInHours - 1;

                                int baseTasks = qs.length ~/ durationInHours;
                                int remainder = qs.length % durationInHours;
                                int startIndex = 0;
                                for (int i = 0; i < currentHourIndex; i++) {
                                  startIndex += baseTasks + (i < remainder ? 1 : 0);
                                }
                                int taskCount = baseTasks + (currentHourIndex < remainder ? 1 : 0);
                                List<Question> hourQs = qs.sublist(startIndex, startIndex + taskCount);

                                return _EventCard(
                                  event: e, 
                                  questions: hourQs,
                                  isContinuation: isContinuation,
                                  isLastSegment: isLastSegment,
                                  onTap: () {
                                    showModalBottomSheet(
                                      context: context,
                                      isScrollControlled: true,
                                      backgroundColor: Colors.transparent,
                                      builder: (_) => _EventDetailSheet(event: e, isar: isar),
                                    );
                                  },
                                  onLongPress: () {
                                    HapticFeedback.heavyImpact();
                                    showModalBottomSheet(
                                      context: context,
                                      isScrollControlled: true,
                                      backgroundColor: Colors.transparent,
                                      builder: (_) => TaskActionSheet(
                                        event: e, 
                                        isar: isar,
                                        currentPath: GoRouterState.of(context).uri.path,
                                      ),
                                    );
                                  },
                                );
                              },
                            ),
                          );
                        }).toList(),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
//  EVENT CARD — Naturally expands with tasks
// ══════════════════════════════════════════════════════════════

class _EventCard extends StatelessWidget {
  final PlannerEvent event;
  final List<Question> questions;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final bool isContinuation;
  final bool isLastSegment;

  const _EventCard({
    required this.event,
    required this.questions,
    required this.onTap,
    required this.onLongPress,
    this.isContinuation = false,
    this.isLastSegment = true,
  });

  @override
  Widget build(BuildContext context) {
    final String hexString = event.colorHex ?? '0xFFFFFFFF';
    final Color subjectColor = Color(int.tryParse(hexString) ?? 0xFFFFFFFF);

    final cardRadius = BorderRadius.vertical(
      top: isContinuation ? Radius.zero : const Radius.circular(10),
      bottom: isLastSegment ? const Radius.circular(10) : Radius.zero,
    );

    final bool isMerged = isContinuation || !isLastSegment;

    double minH = 44;
    if (!isContinuation && !isLastSegment) minH = 50; // First hour (padding bottom 0)
    else if (isContinuation && isLastSegment) minH = 50; // Last hour (padding top 0)
    else if (isContinuation && !isLastSegment) minH = 56; // Middle hour (padding top 0, bottom 0)

    return Transform.translate(
      offset: Offset(0, isContinuation ? -0.5 : 0),
      child: Material(
        color: Colors.black, // OLED Black
        elevation: isMerged ? 0 : 4,
        shadowColor: isMerged ? Colors.transparent : Colors.black45,
        shape: RoundedRectangleBorder(borderRadius: cardRadius),
        child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        borderRadius: cardRadius,
        child: Container(
          constraints: BoxConstraints(minHeight: minH), // Dynamic height mapping perfectly to cell boundary without extending
          padding: EdgeInsets.fromLTRB(14, isContinuation ? 4 : 8, 14, isLastSegment ? 8 : 4), // Reduced vertical padding
          decoration: BoxDecoration(
            color: Colors.transparent, // Ensure OLED black material is visible without tint
            borderRadius: cardRadius,
            border: Border(
              top: !isContinuation ? BorderSide(color: subjectColor.withValues(alpha: 0.25), width: 1.5) : BorderSide.none,
              bottom: isLastSegment ? BorderSide(color: subjectColor.withValues(alpha: 0.25), width: 1.5) : BorderSide.none,
              left: BorderSide(color: subjectColor.withValues(alpha: 0.25), width: 1.5),
              right: BorderSide(color: subjectColor.withValues(alpha: 0.25), width: 1.5),
            ),
          ),
          child: Builder(
            builder: (context) {
              final contentWidget = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (!isContinuation) ...[
                    IntrinsicWidth(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            event.title,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w400,
                              color: subjectColor,
                            ),
                          ),
                          Container(
                            margin: const EdgeInsets.only(top: 4, bottom: 8),
                            height: 1,
                            color: subjectColor.withValues(alpha: 0.3),
                          ),
                        ],
                      ),
                    ),
                    if (questions.isNotEmpty) const SizedBox(height: 2),
                  ],
                  ...questions.map((q) => _TaskLine(q: q)),
                ],
              );

              return contentWidget;
            },
          ),
        ),
      ),
    ),
    );
  }
}

class _TaskLine extends StatelessWidget {
  final Question q;
  const _TaskLine({required this.q});

  String _cleanTitle(String raw) {
    String cleaned = raw.replaceAll(RegExp(r'[★☆⭐🌟\*]'), '');
    return cleaned.split('\n').first.trim();
  }

  @override
  Widget build(BuildContext context) {
    final done = q.status == QuestionStatus.completed;
    final cleanedTitle = _cleanTitle(q.title);

    return InkWell(
      onTap: () {
        HapticFeedback.lightImpact();
        context.push('/question/${q.id}');
      },
      borderRadius: BorderRadius.circular(6),
      child: Container(
        margin: const EdgeInsets.only(bottom: 2), // Reduced margin
        padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 2), // Reduced padding
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 12,
              height: 12,
              margin: const EdgeInsets.only(right: 10, top: 4),
              decoration: BoxDecoration(
                color: done ? AppTheme.completedColor.withOpacity(0.2) : Colors.transparent,
                shape: BoxShape.circle,
                border: Border.all(
                  color: done ? AppTheme.completedColor : const Color(0xFF5C5C60),
                  width: 1.5,
                ),
              ),
              child: done 
                ? const Icon(Icons.check, size: 8, color: AppTheme.completedColor)
                : null,
            ),
            Expanded(
              child: Text(
                cleanedTitle,
                style: TextStyle(
                  fontSize: 13, // Smaller task font
                  color: done ? const Color(0xFF8E8E93) : const Color(0xFFE0E0E0),
                  decoration: done ? TextDecoration.lineThrough : null,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
//  EVENT DETAIL SHEET
// ══════════════════════════════════════════════════════════════

class _EventDetailSheet extends StatelessWidget {
  final PlannerEvent event;
  final Isar isar;
  const _EventDetailSheet({required this.event, required this.isar});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 28,
      ),
      decoration: const BoxDecoration(
        color: AppTheme.cardSurface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        border: Border(top: BorderSide(color: Color(0xFF1E1E2E), width: 1)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 3,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                  color: const Color(0xFF2E2E42),
                  borderRadius: BorderRadius.circular(2)),
            ),
          ),
          Row(
            children: [
              Container(
                  width: 3,
                  height: 24,
                  decoration: BoxDecoration(
                      color: AppTheme.samsungBlue,
                      borderRadius: BorderRadius.circular(2))),
              const SizedBox(width: 12),
              Expanded(
                child: Text(event.title,
                    style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary)),
              ),
              GestureDetector(
                onTap: () async {
                  await isar.writeTxn(
                      () async => isar.plannerEvents.delete(event.id));
                  if (context.mounted) Navigator.pop(context);
                },
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.urgentColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.delete_outline,
                      color: AppTheme.urgentColor, size: 18),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.only(left: 15),
            child: Text(
              '${DateFormat('h:mm a').format(event.startTime)}  –  ${DateFormat('h:mm a').format(event.endTime)}',
              style: const TextStyle(
                  fontSize: 12,
                  color: AppTheme.textSecondary,
                  fontWeight: FontWeight.w500),
            ),
          ),
          const SizedBox(height: 20),
          if (event.questionIds != null && event.questionIds!.isNotEmpty)
            FutureBuilder<List<Question?>>(
              future: isar.questions.getAll(event.questionIds!),
              builder: (_, snap) {
                final qs = snap.data?.whereType<Question>().toList() ?? [];
                if (qs.isEmpty) return const SizedBox.shrink();
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('ASSIGNED TASKS',
                        style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            color: AppTheme.textSecondary,
                            letterSpacing: 1.5)),
                    const SizedBox(height: 10),
                    ...qs.map((q) => _DetailTaskRow(q: q)),
                  ],
                );
              },
            )
          else
            const Text('No tasks assigned.',
                style: TextStyle(color: Color(0xFF3A3A52), fontSize: 13)),
        ],
      ),
    );
  }
}

class _DetailTaskRow extends StatelessWidget {
  final Question q;
  const _DetailTaskRow({required this.q});

  @override
  Widget build(BuildContext context) {
    final done = q.status == QuestionStatus.completed;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Container(
            width: 18,
            height: 18,
            decoration: BoxDecoration(
              color: done
                  ? AppTheme.completedColor.withOpacity(0.15)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(5),
              border: Border.all(
                color: done
                    ? AppTheme.completedColor
                    : const Color(0xFF2E2E42),
                width: 1.5,
              ),
            ),
            child: done
                ? const Icon(Icons.check, size: 10, color: AppTheme.completedColor)
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(q.title.replaceAll(RegExp(r'[★☆⭐🌟\*]'), '').split('\n').first.trim(),
                style: TextStyle(
                    fontSize: 14,
                    color: done ? const Color(0xFF8E8E93) : AppTheme.textPrimary,
                    decoration: done ? TextDecoration.lineThrough : null,
                    fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
//  SCHEDULE WIZARD — 3-step bottom sheet
// ══════════════════════════════════════════════════════════════

class _ScheduleWizard extends StatefulWidget {
  final DateTime startTime, endTime;
  final Isar isar;
  const _ScheduleWizard(
      {required this.startTime, required this.endTime, required this.isar});

  @override
  State<_ScheduleWizard> createState() => _ScheduleWizardState();
}

class _ScheduleWizardState extends State<_ScheduleWizard> {
  int _step = 0;
  Course? _course;
  Unit? _unit;
  List<int> _selectedIds = [];
  List<Course> _courses = [];
  List<Unit> _units = [];
  List<Question> _questions = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadCourses();
  }

  Future<void> _loadCourses() async {
    setState(() => _loading = true);
    _courses = await widget.isar.courses.where().findAll();
    setState(() => _loading = false);
  }

  Future<void> _pickCourse(Course c) async {
    setState(() => _loading = true);
    await c.units.load();
    setState(() {
      _course = c;
      _units = c.units.toList();
      _step = 1;
      _loading = false;
    });
  }

  Future<void> _pickUnit(Unit u) async {
    setState(() => _loading = true);
    _questions = await widget.isar.questions
        .where()
        .filter()
        .unitIdEqualTo(u.id)
        .findAll();
    setState(() {
      _unit = u;
      _step = 2;
      _loading = false;
    });
  }

  Future<void> _save() async {
    if (_course == null) return;
    
    if (_selectedIds.isNotEmpty) {
      List<Question> selectedQuestions = await widget.isar.questions.getAll(_selectedIds).then((list) => list.whereType<Question>().toList());
      final completedQuestions = selectedQuestions.where((q) => q.status == QuestionStatus.completed).toList();
      
      if (completedQuestions.isNotEmpty) {
        final bool? shouldRevise = await showDialog<bool>(
          context: context,
          useRootNavigator: false,
          builder: (ctx) => Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: const EdgeInsets.all(16),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 380),
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFF000000), // Solid opaque background
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.white24, width: 1),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('ARE YOU SURE?', style: TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 2.0)),
                  const SizedBox(height: 8),
                  Text(
                    completedQuestions.length == 1 
                        ? 'This task is already completed!' 
                        : '${completedQuestions.length} of the selected tasks are already completed!',
                    style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w600, letterSpacing: -0.5),
                  ),
                  const SizedBox(height: 32),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Colors.white24),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                          onPressed: () => Navigator.pop(ctx, false),
                          child: Text('Cancel', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 16, letterSpacing: -0.3)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: Colors.black,
                            elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                          onPressed: () => Navigator.pop(ctx, true),
                          child: Text('Revise', style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 16, letterSpacing: -0.3)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );

        if (shouldRevise == null || !shouldRevise) return; // User aborted

        // If Revise, update their status to revisionNeeded
        await widget.isar.writeTxn(() async {
          for (var q in completedQuestions) {
            q.status = QuestionStatus.revisionNeeded;
            await widget.isar.questions.put(q);
          }
        });
      }
    }

    await widget.isar.writeTxn(() async {
      if (_selectedIds.isEmpty) {
        final e = PlannerEvent()
          ..title = _course!.name
          ..startTime = widget.startTime
          ..endTime = widget.endTime;
        await widget.isar.plannerEvents.put(e);
      } else {
        int durationInHours = widget.endTime.difference(widget.startTime).inHours;
        
        if (durationInHours > 1 && _selectedIds.length >= durationInHours) {
          // Mathematical chunking!
          int base = _selectedIds.length ~/ durationInHours;
          int remainder = _selectedIds.length % durationInHours;
          int index = 0;
          for (int i = 0; i < durationInHours; i++) {
            int count = base + (i < remainder ? 1 : 0);
            if (count > 0) {
              final chunkStart = widget.startTime.add(Duration(hours: i));
              final chunkEnd = widget.startTime.add(Duration(hours: i + 1));
              
              final existingEvents = await widget.isar.plannerEvents
                  .filter()
                  .startTimeEqualTo(chunkStart)
                  .titleEqualTo(_course!.name)
                  .findAll();
                  
              if (existingEvents.isNotEmpty) {
                final existing = existingEvents.first;
                if (existing.endTime.isBefore(chunkEnd)) existing.endTime = chunkEnd; 
                existing.questionIds = [...(existing.questionIds ?? []), ..._selectedIds.sublist(index, index + count)];
                await widget.isar.plannerEvents.put(existing);
              } else {
                final e = PlannerEvent()
                  ..title = _course!.name
                  ..startTime = chunkStart
                  ..endTime = chunkEnd
                  ..colorHex = _course!.colorTag
                  ..questionIds = _selectedIds.sublist(index, index + count);
                await widget.isar.plannerEvents.put(e);
              }
              index += count;
            }
          }
        } else {
          // ONE single event spanning the selected duration (shared tab).
          final existingEvents = await widget.isar.plannerEvents
              .filter()
              .startTimeEqualTo(widget.startTime)
              .titleEqualTo(_course!.name)
              .findAll();
              
          if (existingEvents.isNotEmpty) {
            final existing = existingEvents.first;
            existing.endTime = widget.endTime; // Extend duration
            existing.questionIds = [...(existing.questionIds ?? []), ..._selectedIds];
            await widget.isar.plannerEvents.put(existing);
          } else {
            final e = PlannerEvent()
              ..title = _course!.name
              ..startTime = widget.startTime
              ..endTime = widget.endTime
              ..colorHex = _course!.colorTag
              ..questionIds = _selectedIds;
            await widget.isar.plannerEvents.put(e);
          }
        }
      }
    });

    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final timeStr =
        '${DateFormat('h:mm a').format(widget.startTime)} – ${DateFormat('h:mm a').format(widget.endTime)}';

    return Container(
      constraints:
          BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.80),
      decoration: const BoxDecoration(
        color: AppTheme.cardSurface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        border: Border(top: BorderSide(color: Color(0xFF1E1E2E), width: 1)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 10, bottom: 4),
              width: 36,
              height: 3,
              decoration: BoxDecoration(
                  color: const Color(0xFF2E2E42),
                  borderRadius: BorderRadius.circular(2)),
            ),
          ),

          // ── Header ─────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                IconButton(
                  onPressed: () {
                    if (_step > 0) {
                      setState(() => _step--);
                    } else {
                      Navigator.pop(context);
                    }
                  },
                  icon: const Icon(Icons.arrow_back_ios_new, size: 18, color: Color(0xFF8888A0)),
                  padding: const EdgeInsets.only(right: 12, bottom: 4),
                  constraints: const BoxConstraints(),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _step == 0
                            ? 'STEP 1: SUBJECT'
                            : _step == 1
                                ? 'STEP 2: UNIT'
                                : 'STEP 3: TASKS',
                        style: const TextStyle(
                          fontSize: 12, 
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textSecondary,
                          letterSpacing: 1.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        timeStr,
                        style: const TextStyle(
                          fontSize: 22, 
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
                // Step indicator dots
                Row(
                  children: List.generate(3, (i) => AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    margin: const EdgeInsets.only(left: 6),
                    width: i == _step ? 24 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: i <= _step
                          ? AppTheme.samsungBlue
                          : const Color(0xFF2E2E42),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  )),
                ),
              ],
            ),
          ),

          // Breadcrumb
          if (_course != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
              child: Row(
                children: [
                  _WizardChip(_course!.name, Colors.white, Icons.menu_book_rounded, AppTheme.samsungBlue),
                  if (_unit != null) ...[
                    const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 10),
                        child: Icon(Icons.arrow_forward_ios,
                            size: 10, color: Color(0xFF5C5C60))),
                    _WizardChip(_unit!.name, Colors.white, Icons.segment_rounded, AppTheme.samsungBlue),
                  ],
                ],
              ),
            ),

          const SizedBox(height: 12),
          const Divider(height: 1, color: Color(0xFF1A1A28)),

          // ── List content ────────────────────────────────────────────
          Flexible(
            child: _loading
                ? const Center(
                    child: Padding(
                    padding: EdgeInsets.all(40),
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: AppTheme.samsungBlue),
                  ))
                : _buildList(),
          ),

          // Save button (step 1 or 2)
          if (_step > 0)
            Padding(
              padding: EdgeInsets.fromLTRB(
                  20, 12, 20, MediaQuery.of(context).padding.bottom + 16),
              child: GestureDetector(
                onTap: _save,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  decoration: BoxDecoration(
                    color: AppTheme.samsungBlue.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppTheme.samsungBlue.withOpacity(0.4), width: 1.5),
                  ),
                  child: Center(
                    child: Text(
                      _selectedIds.isEmpty
                          ? 'SAVE SESSION'
                          : 'SAVE  ·  ${_selectedIds.length} TASK${_selectedIds.length == 1 ? '' : 'S'}',
                      style: const TextStyle(
                          color: AppTheme.samsungBlue,
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                          letterSpacing: 2.0),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildList() {
    if (_step == 0) {
      if (_courses.isEmpty) {
        return const Center(
            child: Padding(
          padding: EdgeInsets.all(40),
          child: Text('No subjects yet.',
              style: TextStyle(color: Color(0xFF3A3A52))),
        ));
      }
      return ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        itemCount: _courses.length,
        itemBuilder: (_, i) => _WizardRow(
          label: _courses[i].name,
          onTap: () => _pickCourse(_courses[i]),
          accent: AppTheme.samsungBlue,
          icon: Icons.menu_book_rounded,
        ),
      );
    }
    if (_step == 1) {
      if (_units.isEmpty) {
        return const Center(
            child: Text('No units.',
                style: TextStyle(color: Color(0xFF3A3A52))));
      }
      return ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        itemCount: _units.length,
        itemBuilder: (_, i) => _WizardRow(
          label: _units[i].name,
          onTap: () => _pickUnit(_units[i]),
          accent: AppTheme.samsungBlue,
          icon: Icons.segment_rounded,
        ),
      );
    }
    // Step 2: tasks
    if (_questions.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('No tasks in this unit.',
                style: TextStyle(color: Color(0xFF3A3A52)),
                textAlign: TextAlign.center),
            const SizedBox(height: 16),
            TextButton(
              onPressed: _save,
              child: const Text('Save without tasks'),
            ),
          ],
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      itemCount: _questions.length,
      itemBuilder: (_, i) {
        final q = _questions[i];
        final sel = _selectedIds.contains(q.id);
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Material(
            color: sel ? AppTheme.samsungBlue.withOpacity(0.08) : Colors.transparent,
            elevation: 0,
            shadowColor: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(
                color: sel ? AppTheme.samsungBlue.withOpacity(0.4) : Colors.white.withOpacity(0.05),
                width: 1.0,
              ),
            ),
            child: InkWell(
              onTap: () => setState(() =>
                  sel ? _selectedIds.remove(q.id) : _selectedIds.add(q.id)),
              borderRadius: BorderRadius.circular(10),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: sel ? AppTheme.samsungBlue : Colors.transparent,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: sel ? AppTheme.samsungBlue : AppTheme.textSecondary.withOpacity(0.5),
                          width: 1.5,
                        ),
                      ),
                      child: Icon(Icons.check, size: 10, color: sel ? Colors.white : Colors.transparent),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(q.title.replaceAll(RegExp(r'[★☆⭐🌟\*]'), '').split('\n').first.trim(),
                          style: TextStyle(
                              fontSize: 14,
                              fontWeight: sel ? FontWeight.w600 : FontWeight.w500,
                              color: AppTheme.textPrimary)),
                    ),
                if (q.status == QuestionStatus.completed)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppTheme.completedColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text('DONE',
                        style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.completedColor,
                            letterSpacing: 0.8)),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  },
);
  }
}

class _WizardChip extends StatelessWidget {
  final String label;
  final Color textColor;
  final IconData icon;
  final Color iconColor;
  const _WizardChip(this.label, this.textColor, this.icon, this.iconColor);

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: iconColor),
          const SizedBox(width: 6),
          Text(label,
              style: TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w700, color: textColor, letterSpacing: 0.2)),
        ],
      );
}

class _WizardRow extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final Color accent;
  final IconData icon;
  const _WizardRow(
      {required this.label, required this.onTap, required this.accent, required this.icon});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Material(
          color: Colors.transparent,
          elevation: 0,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: Colors.white.withOpacity(0.05), width: 1.0)),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(10),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Icon(icon, size: 20, color: accent),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(label,
                        style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                            color: AppTheme.textPrimary)),
                  ),
                  const Icon(Icons.arrow_forward_ios,
                      size: 14, color: AppTheme.textSecondary),
                ],
              ),
            ),
          ),
        ),
      );
}
