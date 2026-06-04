import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../../core/theme/app_theme.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 1200), () {
      if (mounted) {
        context.go('/home');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.black,
      body: Center(
        child: const Icon(
          Icons.hourglass_bottom_rounded,
          size: 100,
          color: Colors.white,
        )
        .animate(onPlay: (controller) => controller.repeat())
        // Fast spin: completed in 1000ms
        .rotate(begin: -0.125, end: 0.875, duration: 1000.ms, curve: Curves.easeInOutBack)
        .scale(begin: const Offset(1.0, 1.0), end: const Offset(1.2, 1.2), duration: 500.ms, curve: Curves.easeInOut)
        .then()
        .scale(begin: const Offset(1.2, 1.2), end: const Offset(1.0, 1.0), duration: 500.ms, curve: Curves.easeInOut),
      ),
    );
  }
}
