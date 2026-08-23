import 'dart:ui';

import 'package:flutter/material.dart';

import '../constants/app_colors.dart';

class RescueGradientScaffold extends StatelessWidget {
  final Widget child;
  final bool safeArea;

  const RescueGradientScaffold({
    super.key,
    required this.child,
    this.safeArea = true,
  });

  @override
  Widget build(BuildContext context) {
    final content = DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFF8FAFC),
            Color(0xFFF2F7FF),
            Color(0xFFFDF3F3),
          ],
        ),
      ),
      child: child,
    );
    return Scaffold(
      backgroundColor: AppColors.background,
      body: safeArea ? SafeArea(child: content) : content,
    );
  }
}

class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final double radius;
  final Color? color;

  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.margin,
    this.radius = 20,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              color: color ?? Colors.white.withValues(alpha: 0.9),
              borderRadius: BorderRadius.circular(radius),
              border: Border.all(color: AppColors.border, width: 1.1),
              boxShadow: [
                BoxShadow(
                  color: AppColors.dark.withValues(alpha: 0.06),
                  blurRadius: 30,
                  offset: const Offset(0, 14),
                ),
              ],
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// The official MDRRMO Lal-lo "Rescue 35" seal, loaded from
/// assets/images/rescue35_logo.png (with @2.0x/@3.0x variants for
/// higher-density screens). Falls back to a heart-monitor icon if the
/// asset is ever missing, so the app never crashes over a logo swap.
class RescueLogo extends StatelessWidget {
  final double size;

  const RescueLogo({super.key, this.size = 64});

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/images/rescue35_logo.png',
      width: size,
      height: size,
      fit: BoxFit.contain,
      errorBuilder: (context, error, stackTrace) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: AppColors.primary,
          borderRadius: BorderRadius.circular(size * 0.28),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.28),
              blurRadius: 24,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Icon(
          Icons.monitor_heart_rounded,
          color: Colors.white,
          size: size * 0.52,
        ),
      ),
    );
  }
}

class PrimaryButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final bool loading;

  const PrimaryButton({
    super.key,
    required this.label,
    this.icon,
    this.onPressed,
    this.loading = false,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton.icon(
        onPressed: loading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 18),
        ),
        icon: loading
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : Icon(icon ?? Icons.arrow_forward_rounded, size: 20),
        label: Text(
          label,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

InputDecoration rescueInputDecoration(String label, IconData icon,
    {String? hint}) {
  return InputDecoration(
    labelText: label,
    hintText: hint,
    prefixIcon: Icon(icon, color: AppColors.textGray, size: 20),
    filled: true,
    fillColor: Colors.white.withValues(alpha: 0.96),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    labelStyle: const TextStyle(color: AppColors.textGray),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: const BorderSide(color: AppColors.border),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: const BorderSide(color: AppColors.border),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: const BorderSide(color: AppColors.secondary, width: 1.6),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: const BorderSide(color: AppColors.primary, width: 1.4),
    ),
  );
}

String? validateEmail(String? value) {
  final text = value?.trim() ?? '';
  if (text.isEmpty) return 'Email is required';
  final ok = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(text);
  return ok ? null : 'Enter a valid email address';
}

String? validatePhilippineMobile(String? value) {
  final text = value?.trim() ?? '';
  if (text.isEmpty) return 'Mobile number is required';
  return RegExp(r'^09\d{9}$').hasMatch(text)
      ? null
      : 'Use 09XXXXXXXXX format';
}

String? validateName(String? value) {
  final text = value?.trim() ?? '';
  if (text.isEmpty) return 'Name is required';
  if (text.length < 2) return 'Name must be at least 2 characters';
  if (text.length > 100) return 'Name must not exceed 100 characters';
  final ok = RegExp(r"^[a-zA-Z\s.'-]+$").hasMatch(text);
  return ok ? null : 'Name can only contain letters, spaces, dots, and hyphens';
}

String? validateAge(String? value) {
  final text = value?.trim() ?? '';
  if (text.isEmpty) return 'Age is required';
  final age = int.tryParse(text);
  if (age == null) return 'Age must be a valid number';
  if (age < 0 || age > 150) return 'Age must be between 0 and 150';
  return null;
}

String? validatePhoneNumber(String? value) {
  final text = value?.trim() ?? '';
  if (text.isEmpty) return 'Phone number is required';
  final clean = text.replaceAll(RegExp(r'[^\d]'), '');
  if (clean.length < 7) return 'Phone number too short';
  return null;
}

String? validateAddress(String? value) {
  final text = value?.trim() ?? '';
  if (text.isEmpty) return 'Address is required';
  if (text.length < 5) return 'Address must be at least 5 characters';
  if (text.length > 200) return 'Address must not exceed 200 characters';
  return null;
}

String? validateNonEmpty(String? value) {
  final text = value?.trim() ?? '';
  return text.isEmpty ? 'This field is required' : null;
}

String sanitizeInput(String value) {
  return value
      .trim()
      .replaceAll(RegExp(r'<[^>]*>'), '')
      .replaceAll(RegExp(r'[{}$]'), '');
}