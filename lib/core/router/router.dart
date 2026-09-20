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
import '../../features/course/presentation/screens/splash_screen.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/auth/data/auth_service.dart';
import 'main_scaffold.dart';

part 'router.g.dart';

final GlobalKey<NavigatorState> _rootNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'root');

@riverpod
GoRouter router(RouterRef ref) {
  final authState = ref.watch(authStateProvider);

  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/',
    redirect: (context, state) {
      final isAuth = authState.valueOrNull != null;
      final isSplash = state.uri.path == '/';
      final isLogin = state.uri.path == '/login';

      if (authState.isLoading) return null; // Wait for auth to resolve
      
      // If we are on splash screen, we wait for its internal timer to finish
      if (isSplash) return null;

      if (!isAuth && !isLogin) return '/login';
      if (isAuth && isLogin) return '/home';

      return null;
    },
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return MainScaffold(navigationShell: navigationShell);
        },
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/home',
                builder: (context, state) => const HomeScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/courses',
                builder: (context, state) => const CoursesScreen(),
              ),
              GoRoute(
                path: '/question/:id',
                builder: (context, state) {
                  final id = state.pathParameters['id']!;
                  return QuestionDetailScreen(questionId: id);
                },
              ),
              GoRoute(
                path: '/course/:id',
                builder: (context, state) {
                  final id = state.pathParameters['id']!;
                  return CourseDetailScreen(courseId: id);
                },
              ),
              GoRoute(
                path: '/unit/:id',
                builder: (context, state) {
                  final id = state.pathParameters['id']!;
                  return UnitDetailsScreen(unitId: id);
                },
              ),
              GoRoute(
                path: '/revision-loop',
                builder: (context, state) {
                  final ids = state.extra as List<String>;
                  return RevisionLoopScreen(questionIds: ids);
                },
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/planner',
                builder: (context, state) => const PlannerScreen(),
              ),
              GoRoute(
                path: '/planner/day',
                builder: (context, state) => const DayScheduleScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/profile',
                builder: (context, state) => const ProfileScreen(),
              ),
            ],
          ),
        ],
      ),
    ],
  );
}
