import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:isar/isar.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import '../../domain/models/planner_event.dart';
import '../../../course/domain/models/course.dart';
import 'package:exam_command_center/core/database/isar_provider.dart';
import 'package:exam_command_center/core/theme/app_theme.dart';
import 'day_schedule_screen.dart';

class PlannerScreen extends ConsumerStatefulWidget {
  const PlannerScreen({super.key});
  @override
  ConsumerState<PlannerScreen> createState() => _PlannerScreenState();
}

class _PlannerScreenState extends ConsumerState<PlannerScreen> {
  DateTime _focusedDay = DateTime.now();

  @override
  Widget build(BuildContext context) {
    final isarAsync = ref.watch(isarProvider);
    final double screenWidth = MediaQuery.of(context).size.width;
    final bool isTablet = screenWidth > 720;

    return Scaffold(
      backgroundColor: AppTheme.black,
      resizeToAvoidBottomInset: false, // Prevents background calendar from overflowing when keyboard opens
      body: isarAsync.when(
        data: (isar) => StreamBuilder<void>(
          stream: isar.plannerEvents.watchLazy(fireImmediately: true),
          builder: (context, _) => FutureBuilder(
            future: Future.wait([
              isar.plannerEvents.where().findAll(),
              isar.courses.where().findAll(),
            ]),
            builder: (context, AsyncSnapshot<List<dynamic>> snapshot) {
              final events =
                  (snapshot.data?[0] as List<PlannerEvent>?) ?? [];
              final courses =
                  (snapshot.data?[1] as List<Course>?) ?? [];
              return _buildBody(events, courses, isTablet, isar);
            },
          ),
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, s) => Center(child: Text('Error: $e')),
      ),
    );
  }

  Widget _buildBody(List<PlannerEvent> events, List<Course> courses,
      bool isTablet, Isar isar) {
    final hPad = isTablet ? 32.0 : 16.0;

    // Only show Course Exams on the calendar (Data Isolation)
    final allEvents = [
      ...courses
          .where((c) => c.examDate != null)
          .map((c) => PlannerEvent()
            ..title = 'EXAM: ${c.name}'
            ..startTime = c.examDate!
            ..endTime = c.examDate!.add(const Duration(hours: 3))
            ..colorHex = AppTheme.urgentColor.value.toRadixString(16)),
    ];

    // Index by date key
    final Map<String, List<PlannerEvent>> byDay = {};
    for (final e in allEvents) {
      final k = _key(e.startTime);
      byDay.putIfAbsent(k, () => []).add(e);
    }

    final focused = _focusedDay;

    return Column(
      children: [
        // ── Header — month & year on the SAME LINE ─────────────────────
        Container(
          color: AppTheme.black,
          padding: EdgeInsets.fromLTRB(
              hPad, MediaQuery.of(context).padding.top + 14, hPad, 18),
          child: Stack(
            alignment: Alignment.center,
            children: [
              // STUDY PLAN TITLE REMOVED
              Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    DateFormat('MMMM').format(focused),
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w300,
                      color: AppTheme.textPrimary,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    DateFormat('yyyy').format(focused),
                    style: const TextStyle(
                      fontSize: 26, // Matched with month
                      fontWeight: FontWeight.w300,
                      color: Color(0xFF6E6E73), // Lighter color
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        // ── Calendar ───────────────────────────────────────────────────
        Expanded(
          child: Padding(
            padding: EdgeInsets.fromLTRB(hPad, 24.0, hPad, 0),
            child: SingleChildScrollView(
              child: TableCalendar(
              firstDay: DateTime.utc(2020, 1, 1),
              lastDay: DateTime.utc(2030, 12, 31),
              focusedDay: focused,
              onPageChanged: (focusedDay) {
                setState(() {
                  _focusedDay = focusedDay;
                });
              },
              calendarFormat: CalendarFormat.month,
              rowHeight: 75.0,
              daysOfWeekHeight: 20.0,
              headerVisible: false,
              availableGestures: AvailableGestures.horizontalSwipe,
              calendarStyle: CalendarStyle(
                todayDecoration: const BoxDecoration(
                  color: Colors.transparent,
                  shape: BoxShape.circle,
                ),
                selectedDecoration: BoxDecoration(
                  color: Colors.transparent,
                  border: Border.all(color: const Color(0xFFE0E0E0), width: 1.5),
                  shape: BoxShape.circle,
                ),
                defaultDecoration: const BoxDecoration(shape: BoxShape.circle),
                weekendDecoration: const BoxDecoration(shape: BoxShape.circle),
                outsideDecoration: const BoxDecoration(shape: BoxShape.circle),
                defaultTextStyle: const TextStyle(color: Color(0xFFE0E0E0), fontSize: 18, fontWeight: FontWeight.w500),
                weekendTextStyle: const TextStyle(color: Color(0xFFE0E0E0), fontSize: 18, fontWeight: FontWeight.w500),
                outsideTextStyle: const TextStyle(color: Color(0xFF6E6E73), fontSize: 18, fontWeight: FontWeight.w500),
                markersAlignment: Alignment.bottomCenter,
                markersMaxCount: 3,
                cellMargin: const EdgeInsets.all(4),
              ),
              daysOfWeekStyle: const DaysOfWeekStyle(
                weekdayStyle: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF6E6E73), letterSpacing: 1.0),
                weekendStyle: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF6E6E73), letterSpacing: 1.0),
              ),
              calendarBuilders: CalendarBuilders(
                todayBuilder: (context, date, events) {
                  return Center(
                    child: Container(
                      decoration: const BoxDecoration(
                        border: Border(bottom: BorderSide(color: AppTheme.samsungBlue, width: 2.5)),
                      ),
                      padding: const EdgeInsets.only(bottom: 2),
                      child: Text(
                        '${date.day}',
                        style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800),
                      ),
                    ),
                  );
                },
                markerBuilder: (context, date, events) {
                  final dayEvents = byDay[_key(date)] ?? [];
                  if (dayEvents.isEmpty) return const SizedBox();
                  return Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: dayEvents.take(3).map((e) {
                      final String hexString = e.colorHex ?? '0xFF3E82F7';
                      final Color markerColor = Color(int.tryParse(hexString) ?? 0xFF3E82F7);
                      return Container(
                        width: 6,
                        height: 6,
                        margin: const EdgeInsets.symmetric(horizontal: 2),
                        decoration: BoxDecoration(
                          color: markerColor,
                          shape: BoxShape.circle,
                        ),
                      );
                    }).toList(),
                  );
                },
              ),
              onDaySelected: (selectedDay, focusedDay) {
                ref.read(selectedDateProvider.notifier).state = selectedDay;
                context.push('/planner/day');
              },
              onDayLongPressed: (selectedDay, focusedDay) {
                _showDayEditor(context, selectedDay, byDay, isar);
              },
            ),
            ),
          ),
        ),
        const SizedBox(height: 100),
      ],
    );
  }

  String _key(DateTime d) => '${d.year}-${d.month}-${d.day}';

  void _showDayEditor(BuildContext context, DateTime date,
      Map<String, List<PlannerEvent>> byDay, Isar isar) {
    final dayEvents = (byDay[_key(date)] ?? []).where((e) => !e.title.startsWith('EXAM:')).toList();
    showDialog(
      context: context,
      useRootNavigator: false,
      builder: (_) => Align(
        alignment: Alignment.center,
        child: Padding(
          padding: EdgeInsets.only(
            left: 16, 
            right: 16, 
            bottom: MediaQuery.of(context).viewInsets.bottom + 16
          ),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Material(
              color: Colors.transparent,
              child: _DayEditorSheet(
                date: date,
                existingEvents: dayEvents,
                isar: isar,
              ),
            ),
          ),
        ),
      ),
    );
  }
}


// ── Day Editor Sheet (long press) ───────────────────────────────────────────

class _DayEditorSheet extends StatefulWidget {
  final DateTime date;
  final List<PlannerEvent> existingEvents;
  final Isar isar;
  const _DayEditorSheet(
      {required this.date,
      required this.existingEvents,
      required this.isar});

  @override
  State<_DayEditorSheet> createState() => _DayEditorSheetState();
}

class _DayEditorSheetState extends State<_DayEditorSheet> {
  final _ctrl = TextEditingController();
  bool _isExam = true;
  bool _saving = false;
  List<Course> _courses = [];
  Course? _selectedCourse;

  @override
  void initState() {
    super.initState();
    _loadCourses();
  }

  Future<void> _loadCourses() async {
    final courses = await widget.isar.courses.where().findAll();
    if (mounted) {
      setState(() {
        _courses = courses;
        if (_courses.isNotEmpty) {
          _selectedCourse = _courses.first;
        }
      });
    }
  }

  Future<void> _save() async {
    if (_isExam) {
      if (_selectedCourse == null) return;
      setState(() => _saving = true);
      await widget.isar.writeTxn(() async {
        _selectedCourse!.examDate = widget.date;
        await widget.isar.courses.put(_selectedCourse!);
      });
      if (mounted) Navigator.pop(context);
    } else {
      if (_ctrl.text.trim().isEmpty) return;
      setState(() => _saving = true);
      final name = _ctrl.text.trim();
      final event = PlannerEvent()
        ..title = name
        ..startTime = DateTime(widget.date.year, widget.date.month, widget.date.day, 9)
        ..endTime = DateTime(widget.date.year, widget.date.month, widget.date.day, 12)
        ..colorHex = Colors.white.value.toRadixString(16); 
      await widget.isar.writeTxn(
          () async => widget.isar.plannerEvents.put(event));
      if (mounted) Navigator.pop(context);
    }
  }

  Future<void> _clearDay() async {
    setState(() => _saving = true);
    final courses = await widget.isar.courses.where().findAll();
    final examCourses = courses.where((c) => c.examDate?.year == widget.date.year && c.examDate?.month == widget.date.month && c.examDate?.day == widget.date.day).toList();
    
    final allEvents = await widget.isar.plannerEvents.where().findAll();
    final dayEvents = allEvents.where((e) => e.startTime.year == widget.date.year && e.startTime.month == widget.date.month && e.startTime.day == widget.date.day).toList();
    
    await widget.isar.writeTxn(() async {
      for (var c in examCourses) {
        c.examDate = null;
        await widget.isar.courses.put(c);
      }
      for (var e in dayEvents) {
        await widget.isar.plannerEvents.delete(e.id);
      }
    });
    if (mounted) Navigator.pop(context);
  }



  @override
  Widget build(BuildContext context) {
    final dateStr = DateFormat('EEE, d MMM').format(widget.date);
    return SingleChildScrollView(
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF000000), // Solid opaque background
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white24, width: 1),
        ),
        child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(dateStr.toUpperCase(),
                                style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white54,
                                    letterSpacing: 2.0)),
                            const SizedBox(height: 4),
                            const Text('Set Target',
                                style: TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                    letterSpacing: -0.5)),
                          ],
                        ),
                        IconButton(
                          icon: const Icon(Icons.refresh, color: Colors.white),
                          onPressed: _clearDay,
                          tooltip: 'Clear Target',
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Type toggle B&W
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.white10,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        children: [
                          _TypeBtn(
                              label: 'EXAM',
                              icon: Icons.event_busy_outlined,
                              selected: _isExam,
                              onTap: () => setState(() => _isExam = true)),
                          _TypeBtn(
                              label: 'EVENT',
                              icon: Icons.event_note_outlined,
                              selected: !_isExam,
                              onTap: () => setState(() => _isExam = false)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Name input or Course Dropdown
                    if (_isExam)
                      LayoutBuilder(
                        builder: (context, constraints) {
                          return PopupMenuButton<Course>(
                            initialValue: _selectedCourse,
                            onSelected: (c) => setState(() => _selectedCourse = c),
                            position: PopupMenuPosition.under,
                            color: const Color(0xFF1E1E1E),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            constraints: BoxConstraints(minWidth: constraints.maxWidth, maxWidth: constraints.maxWidth, maxHeight: 300),
                            itemBuilder: (context) => _courses.map((c) => PopupMenuItem<Course>(
                              value: c,
                              child: Text(c.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                            )).toList(),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.05),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: Colors.white24),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(_selectedCourse?.name ?? 'Select Subject', style: TextStyle(color: _selectedCourse == null ? Colors.white54 : Colors.white, fontWeight: FontWeight.w600, fontSize: 16)),
                                  const Icon(Icons.arrow_drop_down, color: Colors.white54),
                                ],
                              ),
                            ),
                          );
                        }
                      )
                    else
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: Colors.white24),
                        ),
                        child: TextField(
                          controller: _ctrl,
                          autofocus: true,
                          style: const TextStyle(
                              fontSize: 16,
                              color: Colors.white,
                              fontWeight: FontWeight.w600),
                          decoration: const InputDecoration(
                            border: InputBorder.none,
                            contentPadding:
                                EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                            hintText: 'Input objective...',
                            hintStyle: TextStyle(color: Colors.white54),
                          ),
                        ),
                      ),
                    const SizedBox(height: 24),

                    // Existing events
                    if (widget.existingEvents.isNotEmpty) ...[
                      const Text('ACTIVE TARGETS',
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: Colors.white54,
                              letterSpacing: 1.5)),
                      const SizedBox(height: 12),
                      ...widget.existingEvents.map((e) => _ExistingEventRow(event: e, isar: widget.isar)),
                      const SizedBox(height: 24),
                    ],

                    // Save B&W
                    SizedBox(
                      width: double.infinity,
                      child: GestureDetector(
                        onTap: _saving ? null : _save,
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Center(
                            child: _saving
                                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2))
                                : Text(
                                    'ADD ${_isExam ? 'EXAM' : 'EVENT'}',
                                    style: const TextStyle(
                                        color: Colors.black,
                                        fontWeight: FontWeight.w800,
                                        fontSize: 14,
                                        letterSpacing: 1.5),
                                  ),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: MediaQuery.of(context).padding.bottom + 24),
                  ],
                ),
              ),
            ],
          ),
        ),
    );
  }
}

class _TypeBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  const _TypeBtn({required this.label, required this.icon, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) => Expanded(
        child: GestureDetector(
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: selected ? Colors.white : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
              border: selected ? Border.all(color: Colors.white) : null,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 16, color: selected ? Colors.black : Colors.white54),
                const SizedBox(width: 8),
                Text(label,
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: selected ? Colors.black : Colors.white54,
                        letterSpacing: 1.0)),
              ],
            ),
          ),
        ),
      );
}

class _ExistingEventRow extends StatelessWidget {
  final PlannerEvent event;
  final Isar isar;
  const _ExistingEventRow({required this.event, required this.isar});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
              width: 4,
              height: 24,
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(2))),
          const SizedBox(width: 12),
          Expanded(
              child: Text(event.title,
                  style: const TextStyle(
                      fontSize: 15,
                      color: Colors.white,
                      fontWeight: FontWeight.w600))),
          GestureDetector(
            onTap: () async {
              await isar.writeTxn(() async => isar.plannerEvents.delete(event.id));
              if (context.mounted) Navigator.pop(context);
            },
            child: const Icon(Icons.close, size: 18, color: Colors.white54),
          ),
        ],
      ),
    );
  }
}
