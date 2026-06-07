import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/settings/settings_provider.dart';
import '../../../../core/theme/app_theme.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import '../../../../features/auth/data/auth_service.dart';
import '../../../../features/auth/presentation/screens/login_screen.dart';
import '../../../../features/sync/data/cloud_sync_service.dart';

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
    
    String lastSyncText = 'Never synced';
    if (settings.lastSyncedAt != null) {
      lastSyncText = 'Last sync: ${DateFormat('MMM d, yyyy - h:mm a').format(settings.lastSyncedAt!)}';
    }

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
          
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: user == null ? null : () async {
                      try {
                        ScaffoldMessenger.of(context).clearSnackBars();
                        ScaffoldMessenger.of(context).showSnackBar(_buildPremiumSnackbar(context, 'Backing up to cloud...', Icons.cloud_upload_outlined, AppTheme.samsungBlue));
                        final syncService = await ref.read(cloudSyncServiceProvider.future);
                        await syncService.backupToCloud();
                        final now = DateTime.now();
                        ref.read(settingsProvider.notifier).setLastSyncedAt(now);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).clearSnackBars();
                          ScaffoldMessenger.of(context).showSnackBar(_buildPremiumSnackbar(context, 'Backup successful!', Icons.check_circle_outline, AppTheme.completedColor));
                        }
                      } catch (e) {
                         if (context.mounted) {
                          ScaffoldMessenger.of(context).clearSnackBars();
                          ScaffoldMessenger.of(context).showSnackBar(_buildPremiumSnackbar(context, 'Backup failed: ${e.toString().replaceAll('Exception: ', '')}', Icons.error_outline, AppTheme.urgentColor));
                        }
                      }
                    },
                    icon: const Icon(Icons.upload_rounded, size: 18),
                    label: const Text('Backup'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.cardSurface,
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Colors.white24),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: user == null ? null : () async {
                      try {
                        ScaffoldMessenger.of(context).clearSnackBars();
                        ScaffoldMessenger.of(context).showSnackBar(_buildPremiumSnackbar(context, 'Restoring from cloud...', Icons.cloud_download_outlined, AppTheme.samsungBlue));
                        final syncService = await ref.read(cloudSyncServiceProvider.future);
                        await syncService.restoreFromCloud();
                        final now = DateTime.now();
                        ref.read(settingsProvider.notifier).setLastSyncedAt(now);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).clearSnackBars();
                          ScaffoldMessenger.of(context).showSnackBar(_buildPremiumSnackbar(context, 'Restore successful!', Icons.check_circle_outline, AppTheme.completedColor));
                        }
                      } catch (e) {
                         if (context.mounted) {
                          ScaffoldMessenger.of(context).clearSnackBars();
                          ScaffoldMessenger.of(context).showSnackBar(_buildPremiumSnackbar(context, 'Restore failed.', Icons.error_outline, AppTheme.urgentColor));
                        }
                      }
                    },
                    icon: const Icon(Icons.download_rounded, size: 18),
                    label: const Text('Restore'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.cardSurface,
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Colors.white24),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Text(
              lastSyncText,
              style: const TextStyle(color: Colors.white30, fontSize: 12),
            ),
          )
        ],
      ),
    );
  }

  SnackBar _buildPremiumSnackbar(BuildContext context, String message, IconData icon, Color iconColor) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth > 720;
    
    // The sidebar is 260px wide. To make it stay in the main content area 
    // (right of the nav bar), we push the left margin past the sidebar.
    final double leftMargin = isTablet ? 260 + 24 : 24;

    return SnackBar(
      content: Row(
        children: [
          Icon(icon, color: iconColor, size: 24),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14),
            ),
          ),
        ],
      ),
      backgroundColor: AppTheme.cardSurface,
      behavior: SnackBarBehavior.floating,
      margin: EdgeInsets.only(bottom: 24, left: leftMargin, right: 24),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: iconColor.withOpacity(0.5), width: 1.5),
      ),
      elevation: 0,
      duration: const Duration(seconds: 3),
    );
  }
}
