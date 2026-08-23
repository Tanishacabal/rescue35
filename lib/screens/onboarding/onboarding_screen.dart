import 'package:flutter/material.dart';

import '../../constants/app_colors.dart';
import '../../widgets/design_system.dart';
import '../auth/login_screen.dart';
import 'terms_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  static const List<_OnboardingData> _pages = [
    _OnboardingData(
      badge: 'Emergency',
      badgeColor: Color(0xFFFAECE7),
      badgeTextColor: Color(0xFF993C1D),
      illustrationIcon: Icons.airport_shuttle_rounded,
      illustrationColor: Color(0xFFD85A30),
      illustrationBg: Color(0xFFFAECE7),
      title: 'Emergency Medical Response',
      subtitle: 'Request emergency medical transport anytime, anywhere.',
    ),
    _OnboardingData(
      badge: 'OCR',
      badgeColor: Color(0xFFE6F1FB),
      badgeTextColor: Color(0xFF185FA5),
      illustrationIcon: Icons.document_scanner_rounded,
      illustrationColor: Color(0xFF185FA5),
      illustrationBg: Color(0xFFE6F1FB),
      title: 'OCR Patient Care Reporting',
      subtitle:
          'Convert paper reports into digital records instantly using OCR.',
    ),
    _OnboardingData(
      badge: 'Live',
      badgeColor: Color(0xFFE1F5EE),
      badgeTextColor: Color(0xFF0F6E56),
      illustrationIcon: Icons.notifications_active_rounded,
      illustrationColor: Color(0xFF1D9E75),
      illustrationBg: Color(0xFFE1F5EE),
      title: 'Real-Time Notifications',
      subtitle:
          'Stay updated with transport status and responder notifications.',
    ),
    _OnboardingData(
      badge: 'Smart',
      badgeColor: Color(0xFFEEEDFE),
      badgeTextColor: Color(0xFF534AB7),
      illustrationIcon: Icons.dashboard_rounded,
      illustrationColor: Color(0xFF534AB7),
      illustrationBg: Color(0xFFEEEDFE),
      title: 'Smart Emergency Management',
      subtitle:
          'Manage ambulances, schedules, and patient records efficiently.',
    ),
  ];

  void _nextPage() {
    if (_currentPage < _pages.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
      );
    } else {
      _goToTerms();
    }
  }

  void _goToTerms() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => const TermsScreen(next: LoginScreen()),
      ),
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RescueGradientScaffold(
      child: SafeArea(
        child: Column(
          children: [
            // Skip button
            Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.only(top: 8, right: 20),
                child: TextButton(
                  onPressed: _goToTerms,
                  child: const Text(
                    'Skip',
                    style: TextStyle(
                      color: AppColors.textGray,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
            ),

            // Page content
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: (index) =>
                    setState(() => _currentPage = index),
                itemCount: _pages.length,
                itemBuilder: (context, index) =>
                    _OnboardingPage(data: _pages[index]),
              ),
            ),

            // Dots indicator
            Padding(
              padding: const EdgeInsets.only(bottom: 24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  _pages.length,
                  (index) => AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: _currentPage == index ? 20 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: _currentPage == index
                          ? AppColors.primary
                          : AppColors.secondary.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              ),
            ),

            // Next / Get Started button
            Padding(
              padding: const EdgeInsets.fromLTRB(28, 0, 28, 36),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _nextPage,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    _currentPage == _pages.length - 1 ? 'Get Started' : 'Next',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.4,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Single page ────────────────────────────────────────────────────────────────

class _OnboardingPage extends StatelessWidget {
  final _OnboardingData data;

  const _OnboardingPage({required this.data});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Illustration circle
          Container(
            width: 180,
            height: 180,
            decoration: BoxDecoration(
              color: data.illustrationBg,
              shape: BoxShape.circle,
            ),
            child: Icon(
              data.illustrationIcon,
              size: 86,
              color: data.illustrationColor,
            ),
          ),
          const SizedBox(height: 36),

          // Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
            decoration: BoxDecoration(
              color: data.badgeColor,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              data.badge,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: data.badgeTextColor,
                letterSpacing: 0.5,
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Title
          Text(
            data.title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: AppColors.dark,
              height: 1.25,
            ),
          ),
          const SizedBox(height: 12),

          // Subtitle
          Text(
            data.subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.textGray,
              height: 1.55,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Data model ─────────────────────────────────────────────────────────────────

class _OnboardingData {
  final String badge;
  final Color badgeColor;
  final Color badgeTextColor;
  final IconData illustrationIcon;
  final Color illustrationColor;
  final Color illustrationBg;
  final String title;
  final String subtitle;

  const _OnboardingData({
    required this.badge,
    required this.badgeColor,
    required this.badgeTextColor,
    required this.illustrationIcon,
    required this.illustrationColor,
    required this.illustrationBg,
    required this.title,
    required this.subtitle,
  });
}