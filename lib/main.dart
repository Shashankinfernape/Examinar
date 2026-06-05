import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'core/router/router.dart';
import 'core/theme/app_theme.dart';
import 'core/settings/settings_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  final prefs = await SharedPreferences.getInstance();
  
  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
      child: const ExamCommandCenter(),
    ),
  );
}

class ExamCommandCenter extends ConsumerWidget {
  const ExamCommandCenter({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final settings = ref.watch(settingsProvider);
    return MaterialApp.router(
      title: 'Examinar',
      theme: AppTheme.amoledTheme(),
      darkTheme: AppTheme.amoledTheme(),
      themeMode: ThemeMode.dark, // Force Dark OLED
      routerConfig: router,
      debugShowCheckedModeBanner: false,
    );
  }
}
