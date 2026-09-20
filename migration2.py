import re

with open('lib/features/planner/presentation/screens/day_schedule_screen.dart', 'r', encoding='utf-8') as f:
    content = f.read()

content = content.replace('class _ScheduleWizard extends StatefulWidget', 'class _ScheduleWizard extends ConsumerStatefulWidget')
content = content.replace('State<_ScheduleWizard> createState() => _ScheduleWizardState();', 'ConsumerState<_ScheduleWizard> createState() => _ScheduleWizardState();')
content = content.replace('class _ScheduleWizardState extends State<_ScheduleWizard>', 'class _ScheduleWizardState extends ConsumerState<_ScheduleWizard>')
content = content.replace('List<int> _selectedIds = [];', 'List<String> _selectedIds = [];')

# Load courses
content = content.replace('_courses = await widget.isar.courses.where().findAll();', '_courses = await ref.read(courseRepositoryProvider).getAllCourses();')

# Pick course
content = content.replace('''    await c.units.load();
    setState(() {
      _course = c;
      _units = c.units.toList();''', '''    final firestore = ref.read(courseRepositoryProvider).firestore;
    final unitsSnap = await firestore.collection('users').doc(ref.read(courseRepositoryProvider).uid).collection('units').where('courseId', isEqualTo: c.id).get();
    final units = unitsSnap.docs.map((d) => Unit.fromMap(d.data(), d.id)).toList();
    setState(() {
      _course = c;
      _units = units;''')

# Pick unit
content = content.replace('''    _questions = await widget.isar.questions
        .where()
        .filter()
        .unitIdEqualTo(u.id)
        .findAll();''', '''    _questions = await ref.read(questionRepositoryProvider).getQuestionsForUnit(u.id);''')

# save
save_old = '''    if (_selectedIds.isNotEmpty) {
      List<Question> selectedQuestions = await widget.isar.questions.getAll(_selectedIds).then((list) => list.whereType<Question>().toList());'''
save_new = '''    if (_selectedIds.isNotEmpty) {
      List<Question> selectedQuestions = [];
      for (var id in _selectedIds) {
        final doc = await ref.read(questionRepositoryProvider).firestore.collection('users').doc(ref.read(questionRepositoryProvider).uid).collection('questions').doc(id).get();
        if (doc.exists) selectedQuestions.add(Question.fromMap(doc.data()!, doc.id));
      }'''
content = content.replace(save_old, save_new)

revise_old = '''        await widget.isar.writeTxn(() async {
          for (var q in completedQuestions) {
            q.status = QuestionStatus.revisionNeeded;
            await widget.isar.questions.put(q);
          }
        });'''
revise_new = '''          for (var q in completedQuestions) {
            await ref.read(questionRepositoryProvider).updateStatus(q.id, QuestionStatus.revisionNeeded);
          }'''
content = content.replace(revise_old, revise_new)

save_event_old = '''    await widget.isar.writeTxn(() async {
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
    });'''

save_event_new = '''      if (_selectedIds.isEmpty) {
        final e = PlannerEvent(
          id: '',
          title: _course!.name,
          startTime: widget.startTime,
          endTime: widget.endTime,
        );
        await ref.read(plannerRepositoryProvider).addEvent(e);
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
              
              final existingSnap = await ref.read(plannerRepositoryProvider).firestore.collection('users').doc(ref.read(plannerRepositoryProvider).uid).collection('plannerEvents').where('startTime', isEqualTo: chunkStart.toIso8601String()).where('title', isEqualTo: _course!.name).get();
              final existingEvents = existingSnap.docs.map((d) => PlannerEvent.fromMap(d.data(), d.id)).toList();
                  
              if (existingEvents.isNotEmpty) {
                final existing = existingEvents.first;
                if (existing.endTime.isBefore(chunkEnd)) existing.endTime = chunkEnd; 
                existing.questionIds = [...(existing.questionIds ?? []), ..._selectedIds.sublist(index, index + count)];
                await ref.read(plannerRepositoryProvider).updateEvent(existing);
              } else {
                final e = PlannerEvent(
                  id: '',
                  title: _course!.name,
                  startTime: chunkStart,
                  endTime: chunkEnd,
                  colorHex: _course!.colorTag,
                  questionIds: _selectedIds.sublist(index, index + count),
                );
                await ref.read(plannerRepositoryProvider).addEvent(e);
              }
              index += count;
            }
          }
        } else {
          // ONE single event spanning the selected duration (shared tab).
          final existingSnap = await ref.read(plannerRepositoryProvider).firestore.collection('users').doc(ref.read(plannerRepositoryProvider).uid).collection('plannerEvents').where('startTime', isEqualTo: widget.startTime.toIso8601String()).where('title', isEqualTo: _course!.name).get();
          final existingEvents = existingSnap.docs.map((d) => PlannerEvent.fromMap(d.data(), d.id)).toList();
              
          if (existingEvents.isNotEmpty) {
            final existing = existingEvents.first;
            existing.endTime = widget.endTime; // Extend duration
            existing.questionIds = [...(existing.questionIds ?? []), ..._selectedIds];
            await ref.read(plannerRepositoryProvider).updateEvent(existing);
          } else {
            final e = PlannerEvent(
              id: '',
              title: _course!.name,
              startTime: widget.startTime,
              endTime: widget.endTime,
              colorHex: _course!.colorTag,
              questionIds: _selectedIds,
            );
            await ref.read(plannerRepositoryProvider).addEvent(e);
          }
        }
      }'''

content = content.replace(save_event_old, save_event_new)

# Consumer widgets need build(BuildContext context, WidgetRef ref)
# So let's replace build(BuildContext context, WidgetRef ref) with build(BuildContext context, WidgetRef ref) for ConsumerWidget, but ConsumerState uses build(BuildContext context).
# I'll just change back to build(BuildContext context) inside the file, then change the ones for ConsumerWidget properly.
content = content.replace('Widget build(BuildContext context, WidgetRef ref) {', 'Widget build(BuildContext context) {')
content = content.replace('class _EventDetailSheet extends ConsumerWidget {\n  final PlannerEvent event;\n  const _EventDetailSheet({required this.event});\n\n  @override\n  Widget build(BuildContext context) {', 'class _EventDetailSheet extends ConsumerWidget {\n  final PlannerEvent event;\n  const _EventDetailSheet({required this.event});\n\n  @override\n  Widget build(BuildContext context, WidgetRef ref) {')
content = content.replace('class _AgendaHourRow extends ConsumerWidget {', 'class _AgendaHourRow extends ConsumerWidget {')
content = content.replace('''  const _AgendaHourRow({
    super.key,
    required this.hour,
    required this.label,
    required this.events,
    this.isSelected = false,
    this.isSelectionTop = false,
    this.isSelectionBottom = false,
    this.onMouseDragStart,
  });

  @override
  Widget build(BuildContext context) {''', '''  const _AgendaHourRow({
    super.key,
    required this.hour,
    required this.label,
    required this.events,
    this.isSelected = false,
    this.isSelectionTop = false,
    this.isSelectionBottom = false,
    this.onMouseDragStart,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {''')

content = content.replace('.withOpacity(', '.withValues(alpha: ')

with open('lib/features/planner/presentation/screens/day_schedule_screen.dart', 'w', encoding='utf-8') as f:
    f.write(content)
