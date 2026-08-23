import 'package:flutter/material.dart';

import '../../constants/app_colors.dart';
import '../../services/auth_service.dart';
import '../../widgets/design_system.dart';
import '../citizen/citizen_dashboard.dart';
import '../responder/responder_dashboard.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _authService = AuthService();

  bool _isLoading = false;
  bool _obscurePass = true;
  bool _rememberMe = false;
  String? _errorMessage;
  int _failedAttempts = 0;
  DateTime? _lockedUntil;

  Future<void> _login() async {
    final lockedUntil = _lockedUntil;
    if (lockedUntil != null && DateTime.now().isBefore(lockedUntil)) {
      setState(() {
        _errorMessage =
            'Too many failed attempts. Try again after the cooldown.';
      });
      return;
    }
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final error = await _authService.login(
      sanitizeInput(_emailCtrl.text),
      _passwordCtrl.text,
    );

    if (error != null) {
      setState(() {
        _failedAttempts += 1;
        if (_failedAttempts >= 5) {
          _lockedUntil = DateTime.now().add(const Duration(minutes: 2));
        }
        _isLoading = false;
        _errorMessage = error;
      });
      return;
    }

    final role = await _authService.getUserRole();
    if (!mounted) return;

    setState(() {
      _failedAttempts = 0;
      _isLoading = false;
    });

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) =>
            role == 'responder' ? const ResponderDashboard() : const CitizenDashboard(),
      ),
    );
  }

  Future<void> _forgotPassword() async {
    final emailCtrl = TextEditingController(text: _emailCtrl.text.trim());
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Forgot Password'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: emailCtrl,
              keyboardType: TextInputType.emailAddress,
              decoration: rescueInputDecoration(
                  'Email address', Icons.email_outlined),
            ),
            const SizedBox(height: 10),
            const Text(
              'Tip: the reset email often lands in Spam/Junk — check there if it doesn\'t appear in your inbox.',
              style: TextStyle(fontSize: 12, color: AppColors.textGray),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, emailCtrl.text),
            child: const Text('Send Link'),
          ),
        ],
      ),
    );
    emailCtrl.dispose();

    if (result == null) return;
    if (result.trim().isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter your email address first.')),
      );
      return;
    }

    final error = await _authService.sendPasswordReset(result);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          error ?? 'Reset link sent. Check your inbox or spam/junk folder.',
        ),
        backgroundColor: error == null ? AppColors.completed : AppColors.primary,
        duration: const Duration(seconds: 5),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return RescueGradientScaffold(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(22),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.75),
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.8)),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.08),
                        blurRadius: 18,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Column(
                    children: const [
                      RescueLogo(size: 82),
                      SizedBox(height: 18),
                      Text(
                        'RESCUE 35',
                        style: TextStyle(
                          color: AppColors.dark,
                          fontSize: 30,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      SizedBox(height: 6),
                      Text(
                        'Official Emergency Medical Transport Platform',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: AppColors.textGray,
                          fontSize: 14,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 22),
                GlassCard(
                  padding: const EdgeInsets.all(20),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: const [
                            Icon(
                              Icons.lock_outline_rounded,
                              color: AppColors.primary,
                            ),
                            SizedBox(width: 10),
                            Text(
                              'Sign in to continue',
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w900,
                                color: AppColors.dark,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),
                        TextFormField(
                          controller: _emailCtrl,
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.next,
                          decoration: rescueInputDecoration(
                            'Email address',
                            Icons.email_outlined,
                          ),
                          validator: validateEmail,
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: _passwordCtrl,
                          obscureText: _obscurePass,
                          decoration: rescueInputDecoration(
                            'Password',
                            Icons.lock_outline,
                          ).copyWith(
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscurePass
                                    ? Icons.visibility_off_outlined
                                    : Icons.visibility_outlined,
                              ),
                              onPressed: () => setState(
                                () => _obscurePass = !_obscurePass,
                              ),
                            ),
                          ),
                          validator: (v) =>
                              (v ?? '').isEmpty ? 'Password is required' : null,
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Checkbox(
                              value: _rememberMe,
                              onChanged: (v) =>
                                  setState(() => _rememberMe = v ?? false),
                            ),
                            const Expanded(child: Text('Remember me')),
                            TextButton(
                              onPressed: _forgotPassword,
                              child: const Text('Forgot Password'),
                            ),
                          ],
                        ),
                        if (_errorMessage != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            _errorMessage!,
                            style: const TextStyle(
                              color: AppColors.primary,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                        const SizedBox(height: 16),
                        PrimaryButton(
                          label: 'Login',
                          icon: Icons.login_rounded,
                          loading: _isLoading,
                          onPressed: _login,
                        ),
                        const SizedBox(height: 14),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text(
                              "Don't have an account? ",
                              style: TextStyle(color: AppColors.textGray),
                            ),
                            TextButton(
                              onPressed: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const RegisterScreen(),
                                ),
                              ),
                              child: const Text('Register'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }
}