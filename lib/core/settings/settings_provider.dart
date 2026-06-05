import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

// --- State Class ---
class SettingsState {
  final String userName;
  final int themeIndex;

  const SettingsState({
    this.userName = 'Student',
    this.themeIndex = 2, // Default to 2 (Pure White / Black Theme)
  });

  SettingsState copyWith({String? userName, int? themeIndex}) {
    return SettingsState(
      userName: userName ?? this.userName,
      themeIndex: themeIndex ?? this.themeIndex,
    );
  }
}

// --- Notifier ---
class SettingsNotifier extends StateNotifier<SettingsState> {
  final SharedPreferences prefs;

  SettingsNotifier(this.prefs) : super(const SettingsState()) {
    _loadSettings();
  }

  void _loadSettings() {
    final name = prefs.getString('userName') ?? 'Student';
    final theme = prefs.getInt('themeIndex') ?? 2;
    state = SettingsState(userName: name, themeIndex: theme);
  }

  Future<void> setUserName(String name) async {
    await prefs.setString('userName', name);
    state = state.copyWith(userName: name);
  }

  Future<void> setThemeIndex(int index) async {
    await prefs.setInt('themeIndex', index);
    state = state.copyWith(themeIndex: index);
  }
}

// --- Providers ---

// Needs to be overridden in main() after SharedPreferences.getInstance()
final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('sharedPreferencesProvider must be overridden');
});

final settingsProvider = StateNotifierProvider<SettingsNotifier, SettingsState>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return SettingsNotifier(prefs);
});
