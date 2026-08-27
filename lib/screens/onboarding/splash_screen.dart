import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../constants/app_colors.dart';
import '../../services/auth_service.dart';
import '../../widgets/design_system.dart';
import '../citizen/citizen_dashboard.dart';
import '../responder/responder_dashboard.dart';
import 'onboarding_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3400),
    )..forward();
    Future.delayed(const Duration(milliseconds: 3600), _routeAfterSplash);
  }

  Future<void> _routeAfterSplash() async {
    if (!mounted) return;

    Widget nextScreen = const OnboardingScreen();
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final role = await AuthService().getUserRole();
        if (role == 'admin') {
          await AuthService().logout();
        } else {
          nextScreen = role == 'responder'
              ? const ResponderDashboard()
              : const CitizenDashboard();
        }
      }
    } catch (_) {
      nextScreen = const OnboardingScreen();
    }

    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => nextScreen),
    );
  }

  @override
  Widget build(BuildContext context) {
    return RescueGradientScaffold(
      safeArea: false,
      child: Center(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            final value = Curves.easeInOut.transform(_controller.value);
            return Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    height: 96,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        CustomPaint(
                          size: const Size(double.infinity, 70),
                          painter: _EcgPainter(progress: value),
                        ),
                        Transform.translate(
                          offset: Offset((value * 250) - 125, -6),
                          child: const Icon(
                            Icons.emergency_share_rounded,
                            color: AppColors.primary,
                            size: 34,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  Opacity(
                    opacity: (_controller.value * 1.4).clamp(0.0, 1.0),
                    child: const RescueLogo(size: 84),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'RESCUE 35',
                    style: TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.w900,
                      color: AppColors.dark,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'MDRRMO Lal-lo, Cagayan',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.secondary,
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'Faster Response. Better Care. Smarter Emergency Management.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.textGray, height: 1.4),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}

class _EcgPainter extends CustomPainter {
  final double progress;

  _EcgPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.secondary.withValues(alpha: 0.22)
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final activePaint = Paint()
      ..color = AppColors.primary
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final points = <Offset>[
      Offset(0, size.height * .56),
      Offset(size.width * .16, size.height * .56),
      Offset(size.width * .22, size.height * .30),
      Offset(size.width * .28, size.height * .78),
      Offset(size.width * .36, size.height * .20),
      Offset(size.width * .45, size.height * .56),
      Offset(size.width, size.height * .56),
    ];
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (final point in points.skip(1)) {
      path.lineTo(point.dx, point.dy);
    }
    canvas.drawPath(path, paint);
    final metric = path.computeMetrics().first;
    canvas.drawPath(
      metric.extractPath(0, metric.length * progress),
      activePaint,
    );
  }

  @override
  bool shouldRepaint(covariant _EcgPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
