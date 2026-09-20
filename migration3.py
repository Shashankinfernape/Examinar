import re

def fix():
    with open('lib/features/planner/presentation/screens/day_schedule_screen.dart', 'r', encoding='utf-8') as f:
        lines = f.readlines()
        
    for i in range(len(lines)):
        line = lines[i]
        
        # fix value deprecated
        if 'Color(0xFFF28B82).value.toRadixString(16)' in line:
            lines[i] = line.replace('Color(0xFFF28B82).value.toRadixString(16)', 'Color(0xFFF28B82).toARGB32().toRadixString(16)')
            
        # shouldPop, canPop unused
        if 'final bool shouldPop = GoRouterState.of(context).uri.path == \'/planner/day\';' in line:
            lines[i] = ''
        if 'final bool canPop = Navigator.canPop(context);' in line:
            lines[i] = ''
            
        # ProviderScope in showModalBottomSheet
        if 'builder: (_) => ProviderScope(parent: ProviderScope.containerOf(context), child: _ScheduleWizard(' in line:
            lines[i] = line.replace('builder: (_) => ProviderScope(parent: ProviderScope.containerOf(context), child: _ScheduleWizard(', 'builder: (_) => _ScheduleWizard(')
        if 'endTime: DateTime(widget.date.year, widget.date.month, widget.date.day, maxH),\n        ),' in line:
            lines[i] = line.replace('endTime: DateTime(widget.date.year, widget.date.month, widget.date.day, maxH),\n        ),', 'endTime: DateTime(widget.date.year, widget.date.month, widget.date.day, maxH),\n        )')
            
        if 'builder: (_) => ProviderScope(parent: ProviderScope.containerOf(context), child: TaskActionSheet(' in line:
            lines[i] = line.replace('builder: (_) => ProviderScope(parent: ProviderScope.containerOf(context), child: TaskActionSheet(', 'builder: (_) => TaskActionSheet(')
        if 'currentPath: GoRouterState.of(context).uri.path,\n                                      ),' in line:
            lines[i] = line.replace('currentPath: GoRouterState.of(context).uri.path,\n                                      ),', 'currentPath: GoRouterState.of(context).uri.path,\n                                      )')
            
        # _AgendaHourRow.build needs ref
        if 'class _AgendaHourRow extends ConsumerWidget {' in lines[i-1:i] or 'class _AgendaHourRow extends ConsumerWidget {' in line:
            pass # just a check
        if 'Widget build(BuildContext context) {' in line and '_AgendaHourRow' in ''.join(lines[i-15:i]):
            lines[i] = line.replace('Widget build(BuildContext context) {', 'Widget build(BuildContext context, WidgetRef ref) {')
            
        # _EventDetailSheet.build needs ref
        if 'Widget build(BuildContext context) {' in line and '_EventDetailSheet' in ''.join(lines[i-15:i]):
            lines[i] = line.replace('Widget build(BuildContext context) {', 'Widget build(BuildContext context, WidgetRef ref) {')
            
        # _ScheduleWizard.build should NOT have WidgetRef if it's State
        if 'Widget build(BuildContext context) {' in line and '_ScheduleWizardState' in ''.join(lines[i-15:i]):
            # actually it's fine, ConsumerState's build only takes BuildContext
            pass
        if '_ScheduleWizardState.build' in line:
            pass
        if 'Widget build(BuildContext context, WidgetRef ref) {' in line and '_ScheduleWizard' in ''.join(lines[i-15:i]):
            lines[i] = line.replace('Widget build(BuildContext context, WidgetRef ref) {', 'Widget build(BuildContext context) {')
            
        # List<Question?> to List<Question> assignment issue
        if 'final qs = snap.data ?? [];' in line:
            lines[i] = line.replace('final qs = snap.data ?? [];', 'final qs = snap.data?.whereType<Question>().toList() ?? [];')
            
        # isar in _EventDetailSheet constructor
        if 'required this.isar' in line and '_EventDetailSheet' in ''.join(lines[i-5:i+5]):
            lines[i] = line.replace(', required this.isar', '')
            
        # isar in TaskActionSheet constructor
        if 'isar: isar,' in line and 'TaskActionSheet' in ''.join(lines[i-10:i+10]):
            lines[i] = line.replace('isar: isar,', '')
            
        # isar in _ScheduleWizard constructor
        if 'required this.isar' in line and '_ScheduleWizard' in ''.join(lines[i-5:i+5]):
            lines[i] = line.replace(', required this.isar', '')
            
    # Now let's just write and then fix trailing commas or parentheses using regex
    with open('lib/features/planner/presentation/screens/day_schedule_screen.dart', 'w', encoding='utf-8') as f:
        f.writelines(lines)

fix()

with open('lib/features/planner/presentation/screens/day_schedule_screen.dart', 'r', encoding='utf-8') as f:
    content = f.read()
    
content = content.replace('endTime: DateTime(widget.date.year, widget.date.month, widget.date.day, maxH),\n        ),', 'endTime: DateTime(widget.date.year, widget.date.month, widget.date.day, maxH),\n        )')
content = content.replace('currentPath: GoRouterState.of(context).uri.path,\n                                      ),', 'currentPath: GoRouterState.of(context).uri.path,\n                                      )')
content = content.replace('builder: (_) => ProviderScope(parent: ProviderScope.containerOf(context), child: _ScheduleWizard(', 'builder: (_) => _ScheduleWizard(')
content = content.replace('builder: (_) => ProviderScope(parent: ProviderScope.containerOf(context), child: TaskActionSheet(', 'builder: (_) => TaskActionSheet(')
content = content.replace('Widget build(BuildContext context, WidgetRef ref) {', 'Widget build(BuildContext context) {')
content = content.replace('class _EventDetailSheet extends ConsumerWidget {\\n  final PlannerEvent event;\\n  const _EventDetailSheet({required this.event});\\n\\n  @override\\n  Widget build(BuildContext context) {', 'class _EventDetailSheet extends ConsumerWidget {\\n  final PlannerEvent event;\\n  const _EventDetailSheet({required this.event});\\n\\n  @override\\n  Widget build(BuildContext context, WidgetRef ref) {')
content = content.replace('class _AgendaHourRow extends ConsumerWidget {', 'class _AgendaHourRow extends ConsumerWidget {')

# Fix build methods manually
content = re.sub(r'(class _EventDetailSheet extends ConsumerWidget \{.*?@override\s*)Widget build\(BuildContext context\)', r'\1Widget build(BuildContext context, WidgetRef ref)', content, flags=re.DOTALL)
content = re.sub(r'(class _AgendaHourRow extends ConsumerWidget \{.*?@override\s*)Widget build\(BuildContext context\)', r'\1Widget build(BuildContext context, WidgetRef ref)', content, flags=re.DOTALL)
content = re.sub(r'(class _ScheduleWizardState extends ConsumerState<_ScheduleWizard> \{.*?@override\s*)Widget build\(BuildContext context, WidgetRef ref\)', r'\1Widget build(BuildContext context)', content, flags=re.DOTALL)

with open('lib/features/planner/presentation/screens/day_schedule_screen.dart', 'w', encoding='utf-8') as f:
    f.write(content)
