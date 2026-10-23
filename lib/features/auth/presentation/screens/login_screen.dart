import 'package:go_router/go_router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
                'Sign in seamlessly to sync your study data across all your devices securely.',
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
                      context.go('/home');
                    } else if (mounted) {
                      setState(() {
                        _isLoading = false;
                        if (authService.lastError != null) {
                          _errorMessage = authService.lastError;
                        }
                      });
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
                          const CustomPaint(
                            size: Size(22, 22),
                            painter: _GoogleLogoPainter(),
                          ),
                          const SizedBox(width: 14),
                          Text('Continue with Google', style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.w700, fontSize: 17, color: Colors.black87)),
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


class _GoogleLogoPainter extends CustomPainter {
  const _GoogleLogoPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / 24.0;
    canvas.scale(scale, scale);

    // Blue
    final bluePaint = Paint()..color = const Color(0xFF4285F4);
    final bluePath = Path()
      ..moveTo(23.745, 12.27)
      ..cubicTo(23.745, 11.48, 23.68, 10.73, 23.55, 10.0)
      ..lineTo(12.0, 10.0)
      ..lineTo(12.0, 14.51)
      ..lineTo(18.6, 14.51)
      ..cubicTo(18.31, 16.03, 17.46, 17.33, 16.2, 18.19)
      ..lineTo(16.2, 21.24)
      ..lineTo(20.08, 21.24)
      ..cubicTo(22.35, 19.15, 23.745, 16.07, 23.745, 12.27)
      ..close();
    canvas.drawPath(bluePath, bluePaint);

    // Green
    final greenPaint = Paint()..color = const Color(0xFF34A853);
    final greenPath = Path()
      ..moveTo(12.0, 24.0)
      ..cubicTo(15.24, 24.0, 17.95, 22.92, 19.93, 21.09)
      ..lineTo(16.05, 18.04)
      ..cubicTo(14.97, 18.76, 13.6, 19.2, 12.0, 19.2)
      ..cubicTo(8.88, 19.2, 6.23, 17.1, 5.28, 14.27)
      ..lineTo(1.24, 14.27)
      ..lineTo(1.24, 17.42)
      ..cubicTo(3.26, 21.36, 7.33, 24.0, 12.0, 24.0)
      ..close();
    canvas.drawPath(greenPath, greenPaint);

    // Yellow
    final yellowPaint = Paint()..color = const Color(0xFFFBBC05);
    final yellowPath = Path()
      ..moveTo(5.28, 14.27)
      ..cubicTo(5.03, 13.56, 4.9, 12.79, 4.9, 12.0)
      ..cubicTo(4.9, 11.21, 5.03, 10.44, 5.28, 9.73)
      ..lineTo(5.28, 6.58)
      ..lineTo(1.24, 6.58)
      ..cubicTo(0.45, 8.16, 0.0, 9.99, 0.0, 12.0)
      ..cubicTo(0.0, 14.01, 0.45, 15.84, 1.24, 17.42)
      ..lineTo(5.28, 14.27)
      ..close();
    canvas.drawPath(yellowPath, yellowPaint);

    // Red
    final redPaint = Paint()..color = const Color(0xFFEA4335);
    final redPath = Path()
      ..moveTo(12.0, 4.75)
      ..cubicTo(13.77, 4.75, 15.35, 5.36, 16.6, 6.55)
      ..lineTo(20.02, 3.13)
      ..cubicTo(17.95, 1.19, 15.24, 0.0, 12.0, 0.0)
      ..cubicTo(7.33, 0.0, 3.26, 2.64, 1.24, 6.58)
      ..lineTo(5.28, 9.73)
      ..cubicTo(6.23, 6.9, 8.88, 4.75, 12.0, 4.75)
      ..close();
    canvas.drawPath(redPath, redPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
