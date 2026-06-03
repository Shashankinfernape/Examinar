import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../features/course/presentation/screens/home_screen.dart';
import '../../features/course/presentation/screens/question_detail_screen.dart';
import '../../features/course/presentation/screens/courses_screen.dart';
import '../../features/course/presentation/screens/course_detail_screen.dart';
import '../../features/course/presentation/screens/unit_details_screen.dart';
import '../../features/course/presentation/screens/revision_loop_screen.dart';
import '../../features/planner/presentation/screens/planner_screen.dart';
import '../../features/planner/presentation/screens/day_schedule_screen.dart';
import '../../features/course/presentation/screens/profile_screen.dart';
import 'main_scaffold.dart';

part 'router.g.dart';

final GlobalKey<NavigatorState> _rootNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'root');
final GlobalKey<NavigatorState> _shellNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'shell');

@riverpod
GoRouter router(RouterRef ref) {
  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/',
    routes: [
      ShellRoute(
        navigatorKey: _shellNavigatorKey,
        builder: (context, state, child) {
          return MainScaffold(child: child);
        },
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => const HomeScreen(),
          ),
          GoRoute(
            path: '/courses',
            builder: (context, state) => const CoursesScreen(),
          ),
          GoRoute(
            path: '/planner',
            builder: (context, state) => const PlannerScreen(),
          ),
          GoRoute(
            path: '/planner/day',
            builder: (context, state) => const DayScheduleScreen(),
          ),
          GoRoute(
            path: '/profile',
            builder: (context, state) => const ProfileScreen(),
          ),
          GoRoute(
            path: '/question/:id',
            builder: (context, state) {
              final id = int.parse(state.pathParameters['id']!);
              return QuestionDetailScreen(questionId: id);
            },
          ),
          GoRoute(
            path: '/course/:id',
            builder: (context, state) {
              final id = int.parse(state.pathParameters['id']!);
              return CourseDetailScreen(courseId: id);
            },
          ),
          GoRoute(
            path: '/unit/:id',
            builder: (context, state) {
              final id = int.parse(state.pathParameters['id']!);
              return UnitDetailsScreen(unitId: id);
            },
          ),
          GoRoute(
            path: '/revision-loop',
            builder: (context, state) {
              final ids = state.extra as List<int>;
              return RevisionLoopScreen(questionIds: ids);
            },
          ),
        ],
      ),
    ],
  );
}
