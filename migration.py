import re

def migrate():
    with open('lib/features/planner/presentation/screens/day_schedule_screen.dart', 'r', encoding='utf-8') as f:
        content = f.read()

    # Imports
    content = content.replace("import '../../../../core/theme/app_theme.dart';", "import '../../../../core/theme/app_theme.dart';\nimport '../../data/repositories/planner_repository.dart';\nimport '../../../course/data/repositories/question_repository.dart';\nimport '../../../course/data/repositories/course_repository.dart';")
    
    # Provider references
    content = content.replace("final isarAsync = ref.watch(isarProvider);", "final plannerRepo = ref.watch(plannerRepositoryProvider);")
    
    # AppBar action
    action_old = """          isarAsync.when(
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
          )"""
    action_new = """          IconButton(
            icon: const Icon(Icons.refresh, color: AppTheme.textSecondary, size: 20),
            onPressed: () async {
              final events = await plannerRepo.getAllEvents();
              final dayEvents = events.where((e) => e.startTime.year == date.year && e.startTime.month == date.month && e.startTime.day == date.day).toList();
              for (var e in dayEvents) {
                await plannerRepo.deleteEvent(e.id);
              }
            },
          )"""
    content = content.replace(action_old, action_new)

    # Body
    body_old = """      body: isarAsync.when(
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
      ),"""
    body_new = """      body: StreamBuilder<List<PlannerEvent>>(
        stream: plannerRepo.watchAllEvents(),
        builder: (ctx, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          final allEvents = snapshot.data ?? [];
          final events = allEvents
              .where((e) =>
                  e.startTime.year == date.year &&
                  e.startTime.month == date.month &&
                  e.startTime.day == date.day &&
                  !e.title.startsWith('EXAM:') &&
                  e.colorHex != const Color(0xFFF28B82).value.toRadixString(16))
              .toList();

          return _ScheduleList(events: events, date: date);
        },
      ),"""
    content = content.replace(body_old, body_new)

    # ScheduleList constructor
    content = content.replace("final Isar isar;", "")
    content = content.replace("const _ScheduleList({required this.events, required this.date, required this.isar});", "const _ScheduleList({required this.events, required this.date});")
    content = content.replace("isar: widget.isar,", "")
    content = content.replace("isar: isar,", "")

    # Reschedule put
    put_old = """        () async {
          try {
            await widget.isar.writeTxn(() async {
              reschedulingEvent.startTime = newStart;
              reschedulingEvent.endTime = newEnd;
              await widget.isar.plannerEvents.put(reschedulingEvent);
            });
          } catch (e) {"""
    put_new = """        () async {
          try {
            reschedulingEvent.startTime = newStart;
            reschedulingEvent.endTime = newEnd;
            await ref.read(plannerRepositoryProvider).updateEvent(reschedulingEvent);
          } catch (e) {"""
    content = content.replace(put_old, put_new)

    # Wizard
    content = content.replace("builder: (_) => _ScheduleWizard(", "builder: (_) => ProviderScope(parent: ProviderScope.containerOf(context), child: _ScheduleWizard(")
    content = content.replace("isar: widget.isar", "")
    content = content.replace("          startTime: DateTime(widget.date.year, widget.date.month, widget.date.day, minH),\n          endTime: DateTime(widget.date.year, widget.date.month, widget.date.day, maxH),\n          \n        ),", "          startTime: DateTime(widget.date.year, widget.date.month, widget.date.day, minH),\n          endTime: DateTime(widget.date.year, widget.date.month, widget.date.day, maxH),\n        ),")
    
    # AgendaHourRow constructor
    content = content.replace("required this.isar,", "")

    # Detail sheet constructor
    content = content.replace("class _EventDetailSheet extends StatelessWidget {", "class _EventDetailSheet extends ConsumerWidget {")
    content = content.replace("final Isar isar;", "")
    content = content.replace("const _EventDetailSheet({required this.event, required this.isar});", "const _EventDetailSheet({required this.event});")
    content = content.replace("Widget build(BuildContext context) {", "Widget build(BuildContext context, WidgetRef ref) {")
    
    # Event delete
    del_old = """                onTap: () async {
                  await isar.writeTxn(
                      () async => isar.plannerEvents.delete(event.id));
                  if (context.mounted) Navigator.pop(context);
                },"""
    del_new = """                onTap: () async {
                  await ref.read(plannerRepositoryProvider).deleteEvent(event.id);
                  if (context.mounted) Navigator.pop(context);
                },"""
    content = content.replace(del_old, del_new)
    
    # Questions getAll in detail sheet
    content = content.replace("future: isar.questions.getAll(event.questionIds!),", "future: Future.wait(event.questionIds!.map((id) => ref.read(questionRepositoryProvider).firestore.collection('users').doc(ref.read(questionRepositoryProvider).uid).collection('questions').doc(id).get().then((doc) => Question.fromMap(doc.data()!, doc.id)))),")
    content = content.replace("final qs = snap.data?.whereType<Question>().toList() ?? [];", "final qs = snap.data ?? [];")

    # Questions getAll in _AgendaHourRow
    content = content.replace("class _AgendaHourRow extends StatelessWidget {", "class _AgendaHourRow extends ConsumerWidget {")
    content = content.replace("Widget build(BuildContext context) {", "Widget build(BuildContext context, WidgetRef ref) {")
    content = content.replace("future: e.questionIds != null && e.questionIds!.isNotEmpty\n                                  ? isar.questions.getAll(e.questionIds!)\n                                  : Future.value([]),", "future: e.questionIds != null && e.questionIds!.isNotEmpty\n                                  ? Future.wait(e.questionIds!.map((id) => ref.read(questionRepositoryProvider).firestore.collection('users').doc(ref.read(questionRepositoryProvider).uid).collection('questions').doc(id).get().then((doc) => doc.exists ? Question.fromMap(doc.data()!, doc.id) : null)))\n                                  : Future.value([]),")
    content = content.replace("final qs = snap.data?.whereType<Question>().toList() ?? [];", "final qs = snap.data?.whereType<Question>().toList() ?? [];")
    
    # TaskActionSheet
    content = content.replace("builder: (_) => TaskActionSheet(", "builder: (_) => ProviderScope(parent: ProviderScope.containerOf(context), child: TaskActionSheet(")
    
    with open('lib/features/planner/presentation/screens/day_schedule_screen.dart', 'w', encoding='utf-8') as f:
        f.write(content)

if __name__ == '__main__':
    migrate()
