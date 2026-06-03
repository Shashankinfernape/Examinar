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
    Future.delayed(const Duration(milliseconds: 2500), () {
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
        child: Image.asset(
          'assets/examinar_logo.png',
          width: 140,
          height: 140,
        )
        .animate(onPlay: (controller) => controller.repeat())
        .rotate(duration: 2000.ms, curve: Curves.easeInOutBack)
        .scale(begin: const Offset(0.8, 0.8), end: const Offset(1.0, 1.0), duration: 1000.ms, curve: Curves.easeInOut)
        .then()
        .scale(begin: const Offset(1.0, 1.0), end: const Offset(0.8, 0.8), duration: 1000.ms, curve: Curves.easeInOut),
      ),
    );
  }
}
