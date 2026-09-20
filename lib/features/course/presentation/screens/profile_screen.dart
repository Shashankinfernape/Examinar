import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/settings/settings_provider.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../features/auth/data/auth_service.dart';
import '../../../../features/auth/presentation/screens/login_screen.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);

    return Scaffold(
      backgroundColor: AppTheme.black,
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: AppTheme.black,
      ),
      body: ListView(
        padding: const EdgeInsets.all(24.0),
        children: [
          // Name Settings
          const Text(
            'USER PROFILE',
            style: TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.5),
          ),
          const SizedBox(height: 16),
          _buildNameEditor(context, settings.userName, notifier),
          
          const SizedBox(height: 32),
          const Text(
            'CLOUD SYNC',
            style: TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.5),
          ),
          const SizedBox(height: 16),
          _buildCloudSyncSection(context, ref, settings),
        ],
      ),
    );
  }

  Widget _buildNameEditor(BuildContext context, String currentName, SettingsNotifier notifier) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white24, width: 1.5),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        leading: const Icon(Icons.person, color: Colors.white),
        title: const Text('Display Name', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
        subtitle: Text(currentName, style: const TextStyle(color: Colors.white54)),
        trailing: const Icon(Icons.edit, color: Colors.white30, size: 20),
        onTap: () => _showNameEditDialog(context, currentName, notifier),
      ),
    );
  }

  void _showNameEditDialog(BuildContext context, String currentName, SettingsNotifier notifier) {
    final controller = TextEditingController(text: currentName);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.cardSurface,
        title: const Text('Edit Name', style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: controller,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: 'Enter your name',
            hintStyle: TextStyle(color: Colors.white30),
            enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
            focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white)),
          ),
          textCapitalization: TextCapitalization.words,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                notifier.setUserName(controller.text.trim());
              }
              Navigator.pop(context);
            },
            child: const Text('Save', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildCloudSyncSection(BuildContext context, WidgetRef ref, SettingsState settings) {
    final authService = ref.read(authServiceProvider);
    final authState = ref.watch(authStateProvider);
    final user = authState.value;

    return Container(
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white24, width: 1.5),
      ),
      child: Column(
        children: [
          if (user != null)
            ListTile(
              contentPadding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              leading: const Icon(Icons.cloud_done, color: AppTheme.completedColor),
              title: const Text('Connected', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
              subtitle: Text(user.email ?? 'Logged in', style: const TextStyle(color: Colors.white54)),
              trailing: TextButton(
                onPressed: () async {
                  await authService.signOut();
                  ref.read(settingsProvider.notifier).setLastSyncedAt(DateTime.fromMillisecondsSinceEpoch(0)); // Reset
                },
                child: const Text('Disconnect', style: TextStyle(color: AppTheme.urgentColor)),
              ),
            )
          else
            ListTile(
              contentPadding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              leading: const Icon(Icons.cloud_off, color: Colors.white54),
              title: const Text('Not Connected', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
              subtitle: const Text('Log in to enable cloud backup', style: TextStyle(color: Colors.white54)),
              trailing: ElevatedButton(
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (context) => Dialog(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      clipBehavior: Clip.hardEdge,
                      backgroundColor: AppTheme.black,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 400, maxHeight: 600),
                        child: const LoginScreen(),
                      ),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.samsungBlue,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Login', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
              ),
            ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
