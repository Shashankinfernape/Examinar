import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_theme.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _rotation;
  late Animation<double> _scale;
  late Animation<double> _fadeOut;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    );

    // Smooth spin: starts from the tilted position (-0.2 rad) and does a full rotation
    _rotation = Tween<double>(begin: -0.2, end: -0.2 + (3.14159 * 2))
        .animate(CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.75, curve: Curves.easeInOutCubic),
    ));

    // Pulse: starts at 0.8, grows to 1.1 mid-spin, settles back to 1.0
    _scale = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 0.8, end: 1.1)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 40,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 1.1, end: 1.0)
            .chain(CurveTween(curve: Curves.easeInOut)),
        weight: 35,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 1.0, end: 1.0),
        weight: 25,
      ),
    ]).animate(_controller);

    // Fade out at the very end for a seamless transition
    _fadeOut = Tween<double>(begin: 1.0, end: 0.0).animate(CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.82, 1.0, curve: Curves.easeIn),
    ));

    _controller.forward();

    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed && mounted) {
        context.go('/home');
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.black,
      body: Center(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return Opacity(
              opacity: _fadeOut.value,
              child: Transform.scale(
                scale: _scale.value,
                child: Transform.rotate(
                  angle: _rotation.value,
                  child: child,
                ),
              ),
            );
          },
          child: const Icon(
            Icons.hourglass_bottom_rounded,
            size: 100,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}
