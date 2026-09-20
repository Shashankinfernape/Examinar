import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_theme.dart';
import '../../data/auth_service.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  bool _isLoading = false;
  String? _errorMessage;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.black,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 48.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              const Align(
                alignment: Alignment.center,
                child: Icon(Icons.cloud_sync_rounded, size: 84, color: AppTheme.samsungBlue),
              ),
              const SizedBox(height: 32),
              Text(
                'Welcome to Examinar',
                textAlign: TextAlign.center,
                style: GoogleFonts.spaceGrotesk(fontSize: 28, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: -0.5),
              ),
              const SizedBox(height: 12),
              const Text(
                \'Sign in seamlessly to sync your study data across all your devices securely.\',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 16, height: 1.4),
              ),
              const SizedBox(height: 48),
              
              if (_errorMessage != null)
                Container(
                  padding: const EdgeInsets.all(16),
                  margin: const EdgeInsets.only(bottom: 24),
                  decoration: BoxDecoration(
                    color: AppTheme.urgentColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.urgentColor.withValues(alpha: 0.5)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline, color: AppTheme.urgentColor),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(color: AppTheme.urgentColor, fontWeight: FontWeight.w500),
                        ),
                      ),
                    ],
                  ),
                ),

              ElevatedButton(
                onPressed: _isLoading ? null : () async {
                  setState(() {
                    _isLoading = true;
                    _errorMessage = null;
                  });
                  try {
                    final authService = ref.read(authServiceProvider);
                    final user = await authService.signInWithGoogle();
                    if (user != null && mounted) {
                      // Handled automatically by GoRouter redirect
                    } else if (mounted) {
                       setState(() => _isLoading = false);
                    }
                  } catch (e) {
                    if (mounted) {
                      setState(() {
                        _isLoading = false;
                        _errorMessage = 'Authentication canceled or failed. Please try again.';
                      });
                    }
                  }
                },
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: _isLoading 
                    ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 3, color: Colors.black))
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Using a simple Material icon since we might not have a google logo asset
                          const Icon(Icons.login, size: 24),
                          const SizedBox(width: 12),
                          Text('Continue with Google', style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.w800, fontSize: 18)),
                        ],
                      ),
              ),
              const Spacer(flex: 2),
            ],
          ),
        ),
      ),
    );
  }
}
