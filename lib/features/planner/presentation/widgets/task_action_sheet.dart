import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:isar/isar.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/models/planner_event.dart';
import '../screens/day_schedule_screen.dart'; // To access reschedulingEventProvider

class TaskActionSheet extends ConsumerWidget {
  final PlannerEvent event;
  final Isar isar;

  const TaskActionSheet({super.key, required this.event, required this.isar});

  Future<void> _addAnHourCascade(BuildContext context) async {
    final originalEndTime = event.endTime;
    final dayStart = DateTime(originalEndTime.year, originalEndTime.month, originalEndTime.day);
    final dayEnd = DateTime(originalEndTime.year, originalEndTime.month, originalEndTime.day, 23, 59, 59);

    final dayEvents = isar.plannerEvents.where()
        .filter()
        .startTimeBetween(dayStart, dayEnd)
        .findAllSync();

    // The events that need to be shifted are those starting AT or AFTER the original end time.
    final eventsToShift = dayEvents.where((e) => 
      (e.startTime.isAfter(originalEndTime) || e.startTime.isAtSameMomentAs(originalEndTime)) && e.id != event.id
    ).toList();

    await isar.writeTxn(() async {
      // 1. Extend the current event
      event.endTime = event.endTime.add(const Duration(hours: 1));
      await isar.plannerEvents.put(event);

      // 2. Cascade shift all subsequent events
      for (var e in eventsToShift) {
        e.startTime = e.startTime.add(const Duration(hours: 1));
        e.endTime = e.endTime.add(const Duration(hours: 1));
        await isar.plannerEvents.put(e);
      }
    });

    if (context.mounted) {
      context.pop();
    }
  }

  void _triggerResession(BuildContext context, WidgetRef ref) {
    // Set the global provider to track this event
    ref.read(reschedulingEventProvider.notifier).state = event;
    
    // Pop the sheet
    context.pop();
    
    // Ensure we are on the day schedule screen
    final location = GoRouterState.of(context).uri.path;
    if (location != '/planner/day') {
      context.push('/planner/day');
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      decoration: const BoxDecoration(
        color: AppTheme.black,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Manage Session', style: GoogleFonts.spaceGrotesk(fontSize: 20, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 1.0)),
            const SizedBox(height: 8),
            Text('Select an action for "${event.title}"', style: GoogleFonts.inter(fontSize: 14, color: Colors.white54)),
            const SizedBox(height: 24),
            
            // Resession Button
            InkWell(
              onTap: () => _triggerResession(context, ref),
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppTheme.cardSurface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppTheme.samsungBlue.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: AppTheme.samsungBlue.withOpacity(0.1), shape: BoxShape.circle),
                      child: const Icon(Icons.edit_calendar, color: AppTheme.samsungBlue),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Resession', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white)),
                          const SizedBox(height: 4),
                          Text('Move this task to a completely new time slot.', style: GoogleFonts.inter(fontSize: 13, color: Colors.white54)),
                        ]
                      )
                    )
                  ]
                )
              )
            ),
            
            const SizedBox(height: 16),
            
            // Add An Hour Button
            InkWell(
              onTap: () => _addAnHourCascade(context),
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppTheme.cardSurface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.orange.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: Colors.orange.withOpacity(0.1), shape: BoxShape.circle),
                      child: const Icon(Icons.more_time, color: Colors.orange),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Add an hour', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white)),
                          const SizedBox(height: 4),
                          Text('Extend this session and push all following tasks forward.', style: GoogleFonts.inter(fontSize: 13, color: Colors.white54)),
                        ]
                      )
                    )
                  ]
                )
              )
            ),
          ]
        )
      )
    );
  }
}
