import re
import sys

def main():
    file_path = "lib/features/planner/presentation/screens/planner_screen.dart"
    with open(file_path, "r", encoding="utf-8") as f:
        content = f.read()
    
    # Imports
    content = content.replace("import 'package:flutter/material.dart';", "import 'package:flutter/material.dart';\nimport 'package:exam_command_center/features/course/data/repositories/course_repository.dart';\nimport 'package:exam_command_center/features/planner/data/repositories/planner_repository.dart';")
    
    # Build method for _PlannerScreenState
    build_pattern = r"class _PlannerScreenState extends ConsumerState<PlannerScreen> \{[\s\S]*?  @override\n  Widget build\(BuildContext context\) \{[\s\S]*?    \);\n  \}"
    
    def repl_planner_build(m):
        return """class _PlannerScreenState extends ConsumerState<PlannerScreen> {
  DateTime _focusedDay = DateTime.now();

  @override
  Widget build(BuildContext context) {
    final plannerRepo = ref.watch(plannerRepositoryProvider);
    final courseRepo = ref.watch(courseRepositoryProvider);
    final double screenWidth = MediaQuery.of(context).size.width;
    final bool isTablet = screenWidth > 720;

    return Scaffold(
      backgroundColor: AppTheme.black,
      resizeToAvoidBottomInset: false, // Prevents background calendar from overflowing when keyboard opens
      body: StreamBuilder<List<PlannerEvent>>(
        stream: plannerRepo.watchAllEvents(),
        builder: (context, eventSnapshot) {
          return StreamBuilder<List<Course>>(
            stream: courseRepo.watchAllCourses(),
            builder: (context, courseSnapshot) {
              if (eventSnapshot.connectionState == ConnectionState.waiting || courseSnapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (eventSnapshot.hasError || courseSnapshot.hasError) {
                return Center(child: Text('Error: ${eventSnapshot.error ?? courseSnapshot.error}'));
              }
              final events = eventSnapshot.data ?? [];
              final courses = courseSnapshot.data ?? [];
              return _buildBody(events, courses, isTablet);
            }
          );
        }
      ),
    );
  }"""
    content = re.sub(build_pattern, repl_planner_build, content, count=1)
    
    # _buildBody signature
    content = content.replace("Widget _buildBody(List<PlannerEvent> events, List<Course> courses,\n      bool isTablet, Isar isar) {", "Widget _buildBody(List<PlannerEvent> events, List<Course> courses,\n      bool isTablet) {")
    content = content.replace("Widget _buildBody(List<PlannerEvent> events, List<Course> courses, bool isTablet, Isar isar) {", "Widget _buildBody(List<PlannerEvent> events, List<Course> courses, bool isTablet) {")
    content = content.replace("Widget _buildBody(List<PlannerEvent> events, List<Course> courses,\n      bool isTablet, Isar isar)", "Widget _buildBody(List<PlannerEvent> events, List<Course> courses, bool isTablet)")

    # mapped PlannerEvent
    content = content.replace("""map((c) => PlannerEvent()
            ..title = 'EXAM: ${c.name}'
            ..startTime = c.examDate!
            ..endTime = c.examDate!.add(const Duration(hours: 3))
            ..colorHex = AppTheme.urgentColor.value.toRadixString(16)),""", """map((c) => PlannerEvent(
            id: c.id,
            title: 'EXAM: ${c.name}',
            startTime: c.examDate!,
            endTime: c.examDate!.add(const Duration(hours: 3)),
            colorHex: (AppTheme.urgentColor.a.toInt() << 24 | AppTheme.urgentColor.r.toInt() << 16 | AppTheme.urgentColor.g.toInt() << 8 | AppTheme.urgentColor.b.toInt()).toRadixString(16),
          )),""")
          
    content = content.replace("AppTheme.urgentColor.value.toRadixString(16)", "(AppTheme.urgentColor.a.toInt() << 24 | AppTheme.urgentColor.r.toInt() << 16 | AppTheme.urgentColor.g.toInt() << 8 | AppTheme.urgentColor.b.toInt()).toRadixString(16)")
    
    # _showDayEditor call
    content = content.replace("_showDayEditor(context, selectedDay, byDay, isar);", "_showDayEditor(context, selectedDay, byDay);")
    
    # _showDayEditor signature
    content = content.replace("""  void _showDayEditor(BuildContext context, DateTime date,
      Map<String, List<PlannerEvent>> byDay, Isar isar) {""", """  void _showDayEditor(BuildContext context, DateTime date,
      Map<String, List<PlannerEvent>> byDay) {""")
      
    content = content.replace("""                existingEvents: dayEvents,
                isar: isar,""", """                existingEvents: dayEvents,""")
                
    content = content.replace("""      final Isar isar;
  const _DayEditorSheet(
      {required this.date,
      required this.existingEvents,
      required this.isar});""", """  const _DayEditorSheet(
      {required this.date,
      required this.existingEvents});""")

    # _DayEditorSheet
    editor_class = r"""class _DayEditorSheet extends StatefulWidget \{
  final DateTime date;
  final List<PlannerEvent> existingEvents;
  final Isar isar;
  const _DayEditorSheet\(
      \{required this\.date,
      required this\.existingEvents,
      required this\.isar\}\);

  @override
  State<_DayEditorSheet> createState\(\) => _DayEditorSheetState\(\);
\}"""
    editor_new = """class _DayEditorSheet extends ConsumerStatefulWidget {
  final DateTime date;
  final List<PlannerEvent> existingEvents;
  const _DayEditorSheet(
      {required this.date,
      required this.existingEvents});

  @override
  ConsumerState<_DayEditorSheet> createState() => _DayEditorSheetState();
}"""
    content = re.sub(editor_class, editor_new, content)

    # Convert _DayEditorSheetState to ConsumerState
    content = content.replace("class _DayEditorSheetState extends State<_DayEditorSheet> {", "class _DayEditorSheetState extends ConsumerState<_DayEditorSheet> {")

    # Load courses
    load_courses = r"""  Future<void> _loadCourses\(\) async \{
    final courses = await widget\.isar\.courses\.where\(\)\.findAll\(\);
    if \(mounted\) \{
      setState\(\(\) \{
        _courses = courses;
        if \(_courses\.isNotEmpty\) \{
          _selectedCourse = _courses\.first;
        \}
      \}\);
    \}
  \}"""
    load_courses_new = """  Future<void> _loadCourses() async {
    final courses = await ref.read(courseRepositoryProvider).getAllCourses();
    if (mounted) {
      setState(() {
        _courses = courses;
        if (_courses.isNotEmpty) {
          _selectedCourse = _courses.first;
        }
      });
    }
  }"""
    content = re.sub(load_courses, load_courses_new, content)
    
    # _save
    save_old = r"""  Future<void> _save\(\) async \{
    if \(_isExam\) \{
      if \(_selectedCourse == null\) return;
      setState\(\(\) => _saving = true\);
      await widget\.isar\.writeTxn\(\(\) async \{
        _selectedCourse!\.examDate = widget\.date;
        await widget\.isar\.courses\.put\(_selectedCourse!\);
      \}\);
      if \(mounted\) Navigator\.pop\(context\);
    \} else \{
      if \(_ctrl\.text\.trim\(\)\.isEmpty\) return;
      setState\(\(\) => _saving = true\);
      final name = _ctrl\.text\.trim\(\);
      final event = PlannerEvent\(\)
        \.\.title = name
        \.\.startTime = DateTime\(widget\.date\.year, widget\.date\.month, widget\.date\.day, 9\)
        \.\.endTime = DateTime\(widget\.date\.year, widget\.date\.month, widget\.date\.day, 12\)
        \.\.colorHex = Colors\.white\.value\.toRadixString\(16\); 
      await widget\.isar\.writeTxn\(
          \(\) async => widget\.isar\.plannerEvents\.put\(event\)\);
      if \(mounted\) Navigator\.pop\(context\);
    \}
  \}"""
    
    save_new = """  Future<void> _save() async {
    if (_isExam) {
      if (_selectedCourse == null) return;
      setState(() => _saving = true);
      _selectedCourse!.examDate = widget.date;
      await ref.read(courseRepositoryProvider).updateCourse(_selectedCourse!);
      if (mounted) Navigator.pop(context);
    } else {
      if (_ctrl.text.trim().isEmpty) return;
      setState(() => _saving = true);
      final name = _ctrl.text.trim();
      final event = PlannerEvent(
        id: '',
        title: name,
        startTime: DateTime(widget.date.year, widget.date.month, widget.date.day, 9),
        endTime: DateTime(widget.date.year, widget.date.month, widget.date.day, 12),
        colorHex: (Colors.white.a.toInt() << 24 | Colors.white.r.toInt() << 16 | Colors.white.g.toInt() << 8 | Colors.white.b.toInt()).toRadixString(16),
      );
      await ref.read(plannerRepositoryProvider).addEvent(event);
      if (mounted) Navigator.pop(context);
    }
  }"""
    content = re.sub(save_old, save_new, content)

    clear_day = r"""  Future<void> _clearDay\(\) async \{
    setState\(\(\) => _saving = true\);
    final courses = await widget\.isar\.courses\.where\(\)\.findAll\(\);
    final examCourses = courses\.where\(\(c\) => c\.examDate\?\.year == widget\.date\.year && c\.examDate\?\.month == widget\.date\.month && c\.examDate\?\.day == widget\.date\.day\)\.toList\(\);
    
    final allEvents = await widget\.isar\.plannerEvents\.where\(\)\.findAll\(\);
    final dayEvents = allEvents\.where\(\(e\) => e\.startTime\.year == widget\.date\.year && e\.startTime\.month == widget\.date\.month && e\.startTime\.day == widget\.date\.day\)\.toList\(\);
    
    await widget\.isar\.writeTxn\(\(\) async \{
      for \(var c in examCourses\) \{
        c\.examDate = null;
        await widget\.isar\.courses\.put\(c\);
      \}
      for \(var e in dayEvents\) \{
        await widget\.isar\.plannerEvents\.delete\(e\.id\);
      \}
    \}\);
    if \(mounted\) Navigator\.pop\(context\);
  \}"""
    clear_day_new = """  Future<void> _clearDay() async {
    setState(() => _saving = true);
    final courses = await ref.read(courseRepositoryProvider).getAllCourses();
    final examCourses = courses.where((c) => c.examDate?.year == widget.date.year && c.examDate?.month == widget.date.month && c.examDate?.day == widget.date.day).toList();
    
    final allEvents = await ref.read(plannerRepositoryProvider).getAllEvents();
    final dayEvents = allEvents.where((e) => e.startTime.year == widget.date.year && e.startTime.month == widget.date.month && e.startTime.day == widget.date.day).toList();
    
    for (var c in examCourses) {
      c.examDate = null;
      await ref.read(courseRepositoryProvider).updateCourse(c);
    }
    for (var e in dayEvents) {
      await ref.read(plannerRepositoryProvider).deleteEvent(e.id);
    }
    if (mounted) Navigator.pop(context);
  }"""
    content = re.sub(clear_day, clear_day_new, content)
    
    # Event row
    content = content.replace("...widget.existingEvents.map((e) => _ExistingEventRow(event: e, isar: widget.isar)),", "...widget.existingEvents.map((e) => _ExistingEventRow(event: e)),")

    content = content.replace("""class _ExistingEventRow extends StatelessWidget {
  final PlannerEvent event;
  final Isar isar;
  const _ExistingEventRow({required this.event, required this.isar});""", """class _ExistingEventRow extends ConsumerWidget {
  final PlannerEvent event;
  const _ExistingEventRow({required this.event});""")

    content = content.replace("Widget build(BuildContext context) {", "Widget build(BuildContext context, WidgetRef ref) {")
    content = content.replace("await isar.writeTxn(() async => isar.plannerEvents.delete(event.id));", "await ref.read(plannerRepositoryProvider).deleteEvent(event.id);")

    # Final replacements for value and withOpacity
    content = content.replace("e.colorHex ?? '0xFF3E82F7'", "e.colorHex ?? 'FF3E82F7'")
    content = content.replace("Color(int.tryParse(hexString) ?? 0xFF3E82F7)", "Color(int.tryParse(hexString, radix: 16) ?? 0xFF3E82F7)")
    content = content.replace("Color(int.tryParse(hexString, radix: 16) ?? 0xFF3E82F7)", "Color(int.tryParse(hexString.replaceFirst('0x', ''), radix: 16) ?? 0xFF3E82F7)")
    
    content = content.replace("Colors.white.withOpacity(0.05)", "Colors.white.withValues(alpha: 0.05)")

    with open(file_path, "w", encoding="utf-8") as f:
        f.write(content)

if __name__ == "__main__":
    main()
