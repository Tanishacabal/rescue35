import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';

import '../../constants/app_colors.dart';
import '../../services/auth_service.dart';
import '../../widgets/design_system.dart';

/// Forces whatever the user types into ALL CAPS as they type it.
class _UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    return newValue.copyWith(
      text: newValue.text.toUpperCase(),
      selection: newValue.selection,
    );
  }
}

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _personalKey = GlobalKey<FormState>();
  final _residencyKey = GlobalKey<FormState>();
  final _lastNameCtrl = TextEditingController();
  final _firstNameCtrl = TextEditingController();
  final _middleInitialCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _confirmPassCtrl = TextEditingController();
  final _contactCtrl = TextEditingController();
  final _authService = AuthService();
  final _imagePicker = ImagePicker();

  int _step = 0;
  bool _isLoading = false;
  bool _obscurePass = true;
  String _barangay = 'Centro';
  String _proofType = 'Government ID';
  String _proofFile = '';
  String _proofFilePath = '';
  String _proofSource = '';
  String? _errorMessage;

  final _barangays = const [
  'Abagao',
  'Alaguia',
  'Bagumbayan',
  'Bangag',
  'Bical',
  'Bicud',
  'Binag',
  'Cabayabasan',
  'Cagoran',
  'Cambong',
  'Catayauan',
  'Catugan',
  'Centro',
  'Cullit',
  'Dagupan',
  'Dalaya',
  'Fabrica',
  'Fusina',
  'Lalafugan',
  'Logac',
  'Magallungon',
  'Magapit',
  'Malanao',
  'Maxingal',
  'Naguilian',
  'Paranum',
  'Rosario',
  'San Antonio',
  'San Jose',
  'San Juan',
  'San Lorenzo',
  'San Mariano',
  'Santa Maria',
  'Tucalana',
];

  /// Builds the consistent, database-ready full name in
  /// "LASTNAME, FIRSTNAME MI." format from the three separate fields.
  String get _fullName {
    final last = sanitizeInput(_lastNameCtrl.text).trim();
    final first = sanitizeInput(_firstNameCtrl.text).trim();
    final middle = sanitizeInput(_middleInitialCtrl.text).trim();
    final middlePart = middle.isEmpty ? '' : ' ${middle.replaceAll('.', '')}.';
    return '$last, $first$middlePart';
  }

  Future<void> _register() async {
    // NOTE: _personalKey / _residencyKey are already unmounted once we're on
    // Step 3 (AnimatedSwitcher only keeps one step's Form in the tree at a
    // time), so re-validating them here would hit a null currentState and
    // crash. Those steps are already enforced by _next() before the user can
    // even reach Step 3, so we only need to guard the proof file here.
    if (_proofFile.isEmpty) {
      setState(() {
        _step = 1;
        _errorMessage = 'Upload or enter one verification document first.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final error = await _authService.register(
      name: _fullName,
      email: sanitizeInput(_emailCtrl.text),
      password: _passCtrl.text,
      contact: sanitizeInput(_contactCtrl.text),
      role: 'citizen',
      barangay: _barangay,
      proofType: _proofType,
      proofFile: sanitizeInput(_proofFile),
      proofFilePath: _proofFilePath,
    );

    if (error != null) {
      setState(() {
        _isLoading = false;
        _errorMessage = error;
      });
      return;
    }

    if (!mounted) return;
    setState(() => _isLoading = false);
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        icon: const Icon(
          Icons.verified_user_outlined,
          color: AppColors.completed,
          size: 44,
        ),
        title: const Text('Verification Submitted'),
        content: const Text(
          'Your account is pending verification by MDRRMO Lal-lo.',
          textAlign: TextAlign.center,
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Done'),
          ),
        ],
      ),
    );
    if (mounted) Navigator.pop(context);
  }

  void _next() {
    if (_step == 0 && !_personalKey.currentState!.validate()) return;
    if (_step == 1) {
      if (!_residencyKey.currentState!.validate()) return;
      if (_proofFile.isEmpty) {
        setState(() => _errorMessage = 'Verification document is required.');
        return;
      }
    }
    setState(() {
      _errorMessage = null;
      _step = (_step + 1).clamp(0, 2);
    });
  }

  Future<void> _takeProofPhoto() async {
    final photo = await _imagePicker.pickImage(
      source: ImageSource.camera,
      imageQuality: 90,
      preferredCameraDevice: CameraDevice.rear,
    );
    if (photo == null) return;

    final size = await photo.length();
    if (size > 5 * 1024 * 1024) {
      setState(() => _errorMessage = 'File must be 5 MB or smaller.');
      return;
    }

    setState(() {
      _proofFile = photo.name;
      _proofFilePath = photo.path;
      _proofSource = 'Camera photo';
      _errorMessage = null;
    });
    _residencyKey.currentState?.validate();
  }

  Future<void> _pickProofFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['jpg', 'jpeg', 'png', 'pdf'],
      withData: false,
    );
    final file = result?.files.single;
    if (file == null) return;

    if (file.path == null || file.path!.isEmpty) {
      setState(() => _errorMessage = 'Unable to read selected file.');
      return;
    }
    if (file.size > 5 * 1024 * 1024) {
      setState(() => _errorMessage = 'File must be 5 MB or smaller.');
      return;
    }

    setState(() {
      _proofFile = file.name;
      _proofFilePath = file.path!;
      _proofSource = 'Selected file';
      _errorMessage = null;
    });
    _residencyKey.currentState?.validate();
  }

  @override
  Widget build(BuildContext context) {
    return RescueGradientScaffold(
      child: Column(
        children: [
          AppBar(
            title: const Text('Citizen Registration'),
            actions: [
              IconButton(
                tooltip: 'Back',
                icon: const Icon(Icons.close_rounded),
                onPressed: () => Navigator.maybePop(context),
              ),
            ],
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                GlassCard(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      const RescueLogo(size: 52),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const [
                            Text(
                              'Create your account',
                              style: TextStyle(
                                color: AppColors.dark,
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Complete the steps below for MDRRMO verification.',
                              style: TextStyle(
                                color: AppColors.textGray,
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _progress(),
                const SizedBox(height: 16),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  child: [
                    _personalStep(),
                    _residencyStep(),
                    _reviewStep(),
                  ][_step],
                ),
                if (_errorMessage != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _errorMessage!,
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
                const SizedBox(height: 18),
                Row(
                  children: [
                    if (_step > 0)
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => setState(() => _step -= 1),
                          icon: const Icon(Icons.arrow_back_rounded),
                          label: const Text('Back'),
                        ),
                      ),
                    if (_step > 0) const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: PrimaryButton(
                        label: _step == 2 ? 'Create Account' : 'Continue',
                        icon: _step == 2
                            ? Icons.verified_outlined
                            : Icons.arrow_forward_rounded,
                        loading: _isLoading,
                        onPressed: _step == 2 ? _register : _next,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _progress() {
    final labels = ['Personal', 'Residency', 'Review'];
    return Row(
      children: List.generate(labels.length, (index) {
        final active = index <= _step;
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: index == labels.length - 1 ? 0 : 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  height: 6,
                  decoration: BoxDecoration(
                    color: active ? AppColors.primary : AppColors.border,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  labels[index],
                  style: TextStyle(
                    color: active ? AppColors.dark : AppColors.textGray,
                    fontWeight: active ? FontWeight.w800 : FontWeight.w500,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        );
      }),
    );
  }

  Widget _personalStep() {
    return GlassCard(
      key: const ValueKey('personal'),
      child: Form(
        key: _personalKey,
        child: Column(
          children: [
            _stepTitle('Step 1', 'Personal Information'),
            // Last Name gets its own full-width row so the label never
            // gets truncated, regardless of screen width.
            _field(
              _lastNameCtrl,
              'Last Name',
              Icons.person_outline,
              textCapitalization: TextCapitalization.characters,
              inputFormatters: [_UpperCaseTextFormatter()],
              validator: (v) {
                final text = (v ?? '').trim();
                if (text.isEmpty) return 'Last name is required';
                if (text.length < 2) return 'Minimum 2 characters';
                return RegExp(r"^[a-zA-Z\s.'-]+$").hasMatch(text)
                    ? null
                    : 'Letters only';
              },
            ),
            _gap(),
            _field(
              _firstNameCtrl,
              'First Name',
              Icons.person_outline,
              textCapitalization: TextCapitalization.characters,
              inputFormatters: [_UpperCaseTextFormatter()],
              validator: (v) {
                final text = (v ?? '').trim();
                if (text.isEmpty) return 'First name is required';
                if (text.length < 2) return 'Minimum 2 characters';
                return RegExp(r"^[a-zA-Z\s.'-]+$").hasMatch(text)
                    ? null
                    : 'Letters only';
              },
            ),
            _gap(),
            _field(
              _middleInitialCtrl,
              'Middle Initial',
              Icons.short_text_rounded,
              textCapitalization: TextCapitalization.characters,
              inputFormatters: [
                _UpperCaseTextFormatter(),
                LengthLimitingTextInputFormatter(1),
              ],
              required: false,
              validator: (v) {
                final text = (v ?? '').trim();
                if (text.isEmpty) return null;
                return RegExp(r"^[A-Z]$").hasMatch(text) ? null : '1 letter';
              },
            ),
            _gap(),
            _field(
              _emailCtrl,
              'Email',
              Icons.email_outlined,
              inputType: TextInputType.emailAddress,
              validator: validateEmail,
            ),
            _gap(),
            _field(
              _contactCtrl,
              'Mobile Number',
              Icons.phone_outlined,
              inputType: TextInputType.phone,
              validator: validatePhilippineMobile,
            ),
            _gap(),
            TextFormField(
              controller: _passCtrl,
              obscureText: _obscurePass,
              onChanged: (_) => setState(() {}),
              decoration: rescueInputDecoration('Password', Icons.lock_outline)
                  .copyWith(
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePass
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                      ),
                      onPressed: () =>
                          setState(() => _obscurePass = !_obscurePass),
                    ),
                  ),
              validator: _validatePassword,
            ),
            const SizedBox(height: 10),
            _passwordStrength(),
            _gap(),
            TextFormField(
              controller: _confirmPassCtrl,
              obscureText: true,
              decoration: rescueInputDecoration(
                'Confirm Password',
                Icons.lock_reset_outlined,
              ),
              validator: (v) => v == _passCtrl.text
                  ? null
                  : 'Confirm password must match password',
            ),
          ],
        ),
      ),
    );
  }

  Widget _residencyStep() {
    return GlassCard(
      key: const ValueKey('residency'),
      child: Form(
        key: _residencyKey,
        child: Column(
          children: [
            _stepTitle('Step 2', 'Residency Verification'),
            DropdownButtonFormField<String>(
              initialValue: _barangay,
              decoration: rescueInputDecoration(
                'Barangay',
                Icons.location_city_outlined,
              ),
              items: _barangays
                  .map((b) => DropdownMenuItem(value: b, child: Text(b)))
                  .toList(),
              onChanged: (v) => setState(() => _barangay = v ?? _barangay),
            ),
            _gap(),
            _readonly('Municipality', 'Lal-lo'),
            _gap(),
            _readonly('Province', 'Cagayan'),
            _gap(),
            DropdownButtonFormField<String>(
              initialValue: _proofType,
              decoration: rescueInputDecoration(
                'Verification Document',
                Icons.badge_outlined,
              ),
              items: const [
                'Government ID',
                'Barangay Certificate',
              ].map((b) => DropdownMenuItem(value: b, child: Text(b))).toList(),
              onChanged: (v) => setState(() => _proofType = v ?? _proofType),
            ),
            _gap(),
            FormField<String>(
              initialValue: _proofFile,
              validator: (_) => _proofFile.isEmpty
                  ? 'One document is required'
                  : _isAllowedProofFile(_proofFile)
                  ? null
                  : 'Allowed: JPG, PNG, PDF. Maximum 5 MB.',
              builder: (field) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _takeProofPhoto,
                          icon: const Icon(Icons.camera_alt_outlined),
                          label: const Text('Take Photo'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _pickProofFile,
                          icon: const Icon(Icons.upload_file_outlined),
                          label: const Text('Choose File'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.86),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: field.hasError
                            ? AppColors.primary
                            : AppColors.border,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          _proofFile.isEmpty
                              ? Icons.description_outlined
                              : Icons.check_circle_outline,
                          color: _proofFile.isEmpty
                              ? AppColors.textGray
                              : AppColors.completed,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _proofFile.isEmpty
                                    ? 'No proof selected'
                                    : _proofFile,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _proofFile.isEmpty
                                    ? 'JPG, PNG, or PDF up to 5 MB'
                                    : _proofSource,
                                style: const TextStyle(
                                  color: AppColors.textGray,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (field.hasError) ...[
                    const SizedBox(height: 6),
                    Text(
                      field.errorText!,
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _reviewStep() {
    return GlassCard(
      key: const ValueKey('review'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _stepTitle('Step 3', 'Review'),
          _summary('Full Name', _fullName),
          _summary('Email', _emailCtrl.text.trim()),
          _summary('Mobile', _contactCtrl.text.trim()),
          _summary('Barangay', _barangay),
          _summary('Municipality', 'Lal-lo, Cagayan'),
          _summary('Document', '$_proofType - $_proofFile'),
          const SizedBox(height: 12),
          const Text(
            'Account status after submission: Pending MDRRMO verification.',
            style: TextStyle(color: AppColors.textGray, height: 1.35),
          ),
        ],
      ),
    );
  }

  Widget _stepTitle(String eyebrow, String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          const RescueLogo(size: 42),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                eyebrow,
                style: const TextStyle(
                  color: AppColors.secondary,
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                ),
              ),
              Text(
                title,
                style: const TextStyle(
                  color: AppColors.dark,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _field(
    TextEditingController ctrl,
    String label,
    IconData icon, {
    TextInputType inputType = TextInputType.text,
    TextCapitalization textCapitalization = TextCapitalization.none,
    List<TextInputFormatter>? inputFormatters,
    bool required = true,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: ctrl,
      keyboardType: inputType,
      textCapitalization: textCapitalization,
      inputFormatters: inputFormatters,
      decoration: rescueInputDecoration(label, icon, required: required),
      validator: validator,
    );
  }

  Widget _readonly(String label, String value) {
    return TextFormField(
      initialValue: value,
      enabled: false,
      decoration: rescueInputDecoration(label, Icons.lock_outline),
    );
  }

  Widget _passwordStrength() {
    final text = _passCtrl.text;
    final checks = [
      text.length >= 8,
      RegExp(r'[A-Z]').hasMatch(text),
      RegExp(r'[a-z]').hasMatch(text),
      RegExp(r'\d').hasMatch(text),
      RegExp(r'[!@#\$%^&*(),.?":{}|<>]').hasMatch(text),
    ];
    final passed = checks.where((c) => c).length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LinearProgressIndicator(
          value: passed / checks.length,
          minHeight: 6,
          borderRadius: BorderRadius.circular(99),
          color: passed == checks.length
              ? AppColors.completed
              : AppColors.warning,
          backgroundColor: AppColors.border,
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: [
            _check('8 chars', checks[0]),
            _check('Uppercase', checks[1]),
            _check('Lowercase', checks[2]),
            _check('Number', checks[3]),
            _check('Special', checks[4]),
          ],
        ),
      ],
    );
  }

  Widget _check(String text, bool ok) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          ok ? Icons.check_circle_rounded : Icons.radio_button_unchecked,
          size: 15,
          color: ok ? AppColors.completed : AppColors.textLight,
        ),
        const SizedBox(width: 4),
        Text(text, style: const TextStyle(fontSize: 11)),
      ],
    );
  }

  Widget _summary(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 112,
            child: Text(
              label,
              style: const TextStyle(
                color: AppColors.textGray,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(child: Text(value.isEmpty ? '-' : value)),
        ],
      ),
    );
  }

  Widget _gap() => const SizedBox(height: 14);

  bool _isAllowedProofFile(String fileName) {
    return RegExp(
      r'\.(jpg|jpeg|png|pdf)$',
      caseSensitive: false,
    ).hasMatch(fileName);
  }

  String? _validatePassword(String? value) {
    final text = value ?? '';
    if (text.isEmpty) return 'Password is required';
    if (text.length < 8) return 'Minimum 8 characters';
    if (!RegExp(r'[A-Z]').hasMatch(text)) return 'Add uppercase letter';
    if (!RegExp(r'[a-z]').hasMatch(text)) return 'Add lowercase letter';
    if (!RegExp(r'\d').hasMatch(text)) return 'Add number';
    if (!RegExp(r'[!@#\$%^&*(),.?":{}|<>]').hasMatch(text)) {
      return 'Add special character';
    }
    return null;
  }

  @override
  void dispose() {
    _lastNameCtrl.dispose();
    _firstNameCtrl.dispose();
    _middleInitialCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _confirmPassCtrl.dispose();
    _contactCtrl.dispose();
    super.dispose();
  }
}