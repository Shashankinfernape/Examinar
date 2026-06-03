import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/router/router.dart';
import 'core/theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  runApp(
    const ProviderScope(
      child: ExamCommandCenter(),
    ),
  );
}

class ExamCommandCenter extends ConsumerWidget {
  const ExamCommandCenter({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    
    return MaterialApp.router(
      title: 'Examinar',
      theme: AppTheme.lightTheme(),
      darkTheme: AppTheme.darkTheme(),
      themeMode: ThemeMode.system, // Will implement explicit theme switching later
      routerConfig: router,
      debugShowCheckedModeBanner: false,
    );
  }
}
