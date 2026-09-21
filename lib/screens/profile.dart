import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/app_colors.dart';
import '../widgets/design_system.dart';
import '../services/activity_log_service.dart';

class ProfileScreen extends StatefulWidget {
  final String role;
  const ProfileScreen({super.key, this.role = 'citizen'});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  File? _pickedPhoto;
  bool _isPickingPhoto = false;
  bool _photoLoaded = false;

  // Kept stable across rebuilds (instead of re-created inside build) so
  // opening/saving the edit sheet doesn't trigger a duplicate Firestore
  // read or reset the sheet mid-edit.
  late Future<Map<String, dynamic>> _profileFuture;

  // Reference to the citizens/responders doc backing this profile, if one
  // exists. Populated by _loadProfileData and used by _saveProfileEdits.
  DocumentReference<Map<String, dynamic>>? _roleDocRef;

  String get _uid => FirebaseAuth.instance.currentUser?.uid ?? '';
  String get _photoPrefsKey => 'profile_photo_path_$_uid';

  @override
  void initState() {
    super.initState();
    _loadSavedPhoto();
    _profileFuture = _loadProfileData(_uid, widget.role);
  }

  void _refreshProfile() {
    setState(() {
      _profileFuture = _loadProfileData(_uid, widget.role);
    });
  }

  Future<void> _loadSavedPhoto() async {
    if (_uid.isEmpty) {
      if (mounted) setState(() => _photoLoaded = true);
      return;
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      final path = prefs.getString(_photoPrefsKey);
      if (path != null && await File(path).exists()) {
        if (mounted) setState(() => _pickedPhoto = File(path));
      }
    } catch (_) {
      // Fallback to default avatar
    } finally {
      if (mounted) setState(() => _photoLoaded = true);
    }
  }

  Future<void> _pickPhoto(ImageSource source) async {
    if (!mounted) return;
    setState(() => _isPickingPhoto = true);
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: source,
        maxWidth: 800,
        imageQuality: 85,
      );
      if (picked != null) {
        final savedFile = await _savePhotoLocally(picked.path);
        if (mounted) setState(() => _pickedPhoto = savedFile);
        await ActivityLogService.log(
          action: 'profile_photo_updated',
          description: 'Updated profile photo.',
          entityType: 'user',
          entityId: _uid,
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unable to open photo: $e'),
          backgroundColor: AppColors.warning,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _isPickingPhoto = false);
    }
  }

  Future<File> _savePhotoLocally(String sourcePath) async {
    final docsDir = await getApplicationDocumentsDirectory();
    final ext = sourcePath.split('.').last;
    final newPath =
        '${docsDir.path}/profile_photo_${_uid}_${DateTime.now().millisecondsSinceEpoch}.$ext';
    final prefs = await SharedPreferences.getInstance();
    final oldPath = prefs.getString(_photoPrefsKey);
    if (oldPath != null) {
      final oldFile = File(oldPath);
      if (await oldFile.exists()) await oldFile.delete();
    }
    final newFile = await File(sourcePath).copy(newPath);
    await prefs.setString(_photoPrefsKey, newPath);
    return newFile;
  }

  Future<void> _removePhoto() async {
    final prefs = await SharedPreferences.getInstance();
    final path = prefs.getString(_photoPrefsKey);
    if (path != null) {
      final file = File(path);
      if (await file.exists()) await file.delete();
      await prefs.remove(_photoPrefsKey);
    }
    if (mounted) setState(() => _pickedPhoto = null);
    await ActivityLogService.log(
      action: 'profile_photo_removed',
      description: 'Removed profile photo.',
      entityType: 'user',
      entityId: _uid,
    );
  }

  void _showPhotoSourceSheet() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Profile Photo',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                ListTile(
                  leading: const Icon(
                    Icons.photo_library_outlined,
                    color: AppColors.primary,
                  ),
                  title: const Text('Choose from Gallery'),
                  onTap: () {
                    Navigator.pop(context);
                    _pickPhoto(ImageSource.gallery);
                  },
                ),
                ListTile(
                  leading: const Icon(
                    Icons.photo_camera_outlined,
                    color: AppColors.primary,
                  ),
                  title: const Text('Take a Photo'),
                  onTap: () {
                    Navigator.pop(context);
                    _pickPhoto(ImageSource.camera);
                  },
                ),
                if (_pickedPhoto != null)
                  ListTile(
                    leading: const Icon(
                      Icons.delete_outline,
                      color: AppColors.warning,
                    ),
                    title: const Text(
                      'Remove Photo',
                      style: TextStyle(color: AppColors.warning),
                    ),
                    onTap: () {
                      Navigator.pop(context);
                      _removePhoto();
                    },
                  ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Opens the edit sheet prefilled with the current profile `data`.
  /// Email is intentionally left out of this form — it's never editable
  /// from here, only shown as a read-only detail row on the main screen.
  void _showEditProfileSheet(Map<String, dynamic> data) {
    final nameCtrl = TextEditingController(
      text: (data['name'] ?? data['fullname'] ?? data['responder_name'] ?? '')
          .toString(),
    );
    final contactCtrl = TextEditingController(
      text: (data['contactNumber'] ?? '').toString(),
    );
    final barangayCtrl = TextEditingController(
      text: (data['barangay'] ?? '').toString(),
    );
    final municipalityCtrl = TextEditingController(
      text: (data['municipality'] ?? 'Lal-lo').toString(),
    );
    final provinceCtrl = TextEditingController(
      text: (data['province'] ?? 'Cagayan').toString(),
    );
    final formKey = GlobalKey<FormState>();
    final isCitizen = widget.role == 'citizen';

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      showDragHandle: true,
      builder: (sheetContext) {
        bool isSaving = false;
        return StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 8,
                bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 20,
              ),
              child: SingleChildScrollView(
                child: Form(
                  key: formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Edit Profile',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: AppColors.dark,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Hindi puwedeng baguhin ang email address dito.',
                        style: TextStyle(
                          color: AppColors.textGray,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: nameCtrl,
                        textCapitalization: TextCapitalization.words,
                        decoration: rescueInputDecoration(
                          'Full Name',
                          Icons.badge_outlined,
                        ),
                        validator: (v) => (v == null || v.trim().length < 2)
                            ? 'Enter your full name'
                            : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: contactCtrl,
                        keyboardType: TextInputType.phone,
                        decoration: rescueInputDecoration(
                          'Mobile Number',
                          Icons.phone_outlined,
                        ),
                        validator: (v) {
                          final text = (v ?? '').trim();
                          if (text.isEmpty) return 'Mobile number is required';
                          return null;
                        },
                      ),
                      if (isCitizen) ...[
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: barangayCtrl,
                          decoration: rescueInputDecoration(
                            'Barangay',
                            Icons.location_city_outlined,
                          ),
                          validator: (v) => (v == null || v.trim().isEmpty)
                              ? 'Barangay is required'
                              : null,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: municipalityCtrl,
                          decoration: rescueInputDecoration(
                            'Municipality / City',
                            Icons.business_outlined,
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: provinceCtrl,
                          decoration: rescueInputDecoration(
                            'Province',
                            Icons.map_outlined,
                          ),
                        ),
                      ],
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        child: PrimaryButton(
                          label: 'Save Changes',
                          icon: Icons.check_rounded,
                          loading: isSaving,
                          onPressed: isSaving
                              ? null
                              : () async {
                                  if (!formKey.currentState!.validate()) return;
                                  setSheetState(() => isSaving = true);
                                  try {
                                    await _saveProfileEdits(
                                      name: nameCtrl.text.trim(),
                                      contactNumber: contactCtrl.text.trim(),
                                      barangay: barangayCtrl.text.trim(),
                                      municipality: municipalityCtrl.text
                                          .trim(),
                                      province: provinceCtrl.text.trim(),
                                    );
                                    if (sheetContext.mounted) {
                                      Navigator.pop(sheetContext);
                                    }
                                    _refreshProfile();
                                  } catch (e) {
                                    setSheetState(() => isSaving = false);
                                    if (!mounted) return;
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('Unable to save: $e'),
                                      ),
                                    );
                                  }
                                },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  /// Writes the edited fields back to `users` and, when it exists, the
  /// role-specific (`citizens`/`responders`) doc. Email is never touched
  /// here — it's excluded from both the form and this write.
  Future<void> _saveProfileEdits({
    required String name,
    required String contactNumber,
    required String barangay,
    required String municipality,
    required String province,
  }) async {
    final uid = _uid;

    await FirebaseFirestore.instance.collection('users').doc(uid).set({
      'fullName': name,
      'phoneNumber': contactNumber,
    }, SetOptions(merge: true));

    if (_roleDocRef != null) {
      final roleUpdate = <String, dynamic>{
        'name': name,
        'contactNumber': contactNumber,
      };
      if (widget.role == 'citizen') {
        roleUpdate['barangay'] = barangay;
        roleUpdate['municipality'] = municipality;
        roleUpdate['province'] = province;
      }
      await _roleDocRef!.set(roleUpdate, SetOptions(merge: true));
    }
    await ActivityLogService.log(
      action: 'profile_updated',
      description: 'Updated profile information.',
      entityType: 'user',
      entityId: uid,
      metadata: {'role': widget.role},
    );
  }

  @override
  Widget build(BuildContext context) {
    final uid = _uid;
    if (uid.isEmpty) {
      return RescueGradientScaffold(
        child: const Center(
          child: Text(
            'No user is currently signed in.',
            style: TextStyle(color: AppColors.textGray, fontSize: 16),
          ),
        ),
      );
    }

    return RescueGradientScaffold(
      child: FutureBuilder<Map<String, dynamic>>(
        future: _profileFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting ||
              !_photoLoaded) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            );
          }
          final data = snapshot.data ?? {};

          final name =
              (data['name'] ??
                      data['fullname'] ??
                      data['responder_name'] ??
                      'Profile')
                  .toString();
          final email = (data['email'] ?? '-').toString();
          final contact = (data['contactNumber'] ?? '-').toString();
          final barangay = (data['barangay'] ?? '-').toString();
          final municipality = (data['municipality'] ?? 'Lal-lo').toString();
          final province = (data['province'] ?? 'Cagayan').toString();
          final accountStatus =
              (data['accountStatus'] ?? data['verificationStatus'] ?? 'active')
                  .toString();
          final roleLabel = widget.role == 'responder'
              ? 'Responder'
              : 'Citizen';
          final isVerified =
              accountStatus != 'pending' && accountStatus != 'rejected';

          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 112),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // === HEADER CARD ===
                _headerCard(
                  name,
                  roleLabel,
                  isVerified,
                  onEditTap: () => _showEditProfileSheet(data),
                ),
                const SizedBox(height: 28),

                // === PERSONAL INFORMATION ===
                _groupTitle(Icons.person_outline, 'Personal Information'),
                const SizedBox(height: 10),
                GlassCard(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      _detailRow(Icons.badge_outlined, 'Full Name', name),
                      const SizedBox(height: 16),
                      _detailRow(
                        Icons.email_outlined,
                        'Email Address',
                        email,
                        locked: true,
                      ),
                      const SizedBox(height: 16),
                      _detailRow(
                        Icons.phone_outlined,
                        'Mobile Number',
                        contact,
                      ),
                      const SizedBox(height: 16),
                      _detailRow(
                        Icons.person_outline,
                        'Account Role',
                        roleLabel,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // === LOCATION DETAILS (CITIZEN ONLY) ===
                if (widget.role == 'citizen') ...[
                  _groupTitle(Icons.location_on_outlined, 'Location Details'),
                  const SizedBox(height: 10),
                  GlassCard(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        _detailRow(
                          Icons.location_city_outlined,
                          'Barangay',
                          barangay,
                        ),
                        const SizedBox(height: 16),
                        _detailRow(
                          Icons.business_outlined,
                          'Municipality / City',
                          municipality,
                        ),
                        const SizedBox(height: 16),
                        _detailRow(Icons.map_outlined, 'Province', province),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                ],

                // === ACCOUNT STATUS ===
                _groupTitle(Icons.info_outline, 'Account Status'),
                const SizedBox(height: 10),
                GlassCard(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _detailRow(
                        Icons.verified_outlined,
                        'Current Status',
                        accountStatus.toUpperCase(),
                      ),
                      const SizedBox(height: 16),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: isVerified
                              ? AppColors.completed.withValues(alpha: 0.10)
                              : AppColors.warning.withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              isVerified
                                  ? Icons.verified_user_rounded
                                  : Icons.pending_actions_rounded,
                              color: isVerified
                                  ? AppColors.completed
                                  : AppColors.warning,
                              size: 22,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                isVerified
                                    ? '✅ Your account is verified and fully active.'
                                    : '⏳ Your account is still under review.',
                                style: TextStyle(
                                  color: isVerified
                                      ? AppColors.completed
                                      : AppColors.warning,
                                  fontWeight: FontWeight.w600,
                                  height: 1.5,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _groupTitle(IconData icon, String title) {
    return Row(
      children: [
        Icon(icon, size: 20, color: AppColors.primary),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: AppColors.primary,
          ),
        ),
      ],
    );
  }

  Future<Map<String, dynamic>> _loadProfileData(String uid, String role) async {
    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .get();
    final userData = userDoc.data() ?? {};
    final collectionName = role == 'citizen' ? 'citizens' : 'responders';
    final roleSnap = await FirebaseFirestore.instance
        .collection(collectionName)
        .where('userID', isEqualTo: uid)
        .limit(1)
        .get();
    if (roleSnap.docs.isNotEmpty) {
      _roleDocRef = roleSnap.docs.first.reference;
      return {...userData, ...roleSnap.docs.first.data()};
    }
    _roleDocRef = null;
    return userData;
  }

  Widget _headerCard(
    String name,
    String roleLabel,
    bool isVerified, {
    required VoidCallback onEditTap,
  }) {
    return GlassCard(
      color: AppColors.primary,
      radius: 24,
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Column(
            children: [
              _avatar(roleLabel),
              const SizedBox(height: 14),
              Text(
                name,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  roleLabel,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.shield_outlined,
                      color: Colors.white70,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      isVerified
                          ? 'Account verified'
                          : 'Verification in progress',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          Positioned(
            top: -6,
            right: -6,
            child: Material(
              color: Colors.white.withValues(alpha: 0.16),
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: onEditTap,
                child: const Padding(
                  padding: EdgeInsets.all(9),
                  child: Icon(
                    Icons.edit_outlined,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _avatar(String roleLabel) {
    return GestureDetector(
      onTap: _isPickingPhoto ? null : _showPhotoSourceSheet,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          CircleAvatar(
            radius: 32,
            backgroundColor: Colors.white.withValues(alpha: 0.2),
            backgroundImage: _pickedPhoto != null
                ? FileImage(_pickedPhoto!)
                : null,
            child: _isPickingPhoto
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: Colors.white,
                    ),
                  )
                : (_pickedPhoto == null
                      ? Icon(
                          roleLabel == 'Responder'
                              ? Icons.medical_services_rounded
                              : Icons.person_rounded,
                          size: 28,
                          color: Colors.white,
                        )
                      : null),
          ),
          Positioned(
            bottom: -2,
            right: -2,
            child: Container(
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.primary, width: 1.5),
              ),
              child: const Icon(
                Icons.camera_alt_rounded,
                size: 14,
                color: AppColors.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _detailRow(
    IconData icon,
    String label,
    String value, {
    bool locked = false,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: AppColors.primary, size: 19),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: AppColors.textGray,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.dark,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          if (locked) ...[
            const SizedBox(width: 8),
            const Icon(
              Icons.lock_outline_rounded,
              size: 16,
              color: AppColors.textGray,
            ),
          ],
        ],
      ),
    );
  }
}
