import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/app_colors.dart';
import '../widgets/design_system.dart';

class ProfileScreen extends StatefulWidget {
  final String role;
  const ProfileScreen({
    super.key,
    this.role = 'citizen',
  });

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  File? _pickedPhoto;
  bool _isPickingPhoto = false;
  bool _photoLoaded = false;

  String get _uid => FirebaseAuth.instance.currentUser?.uid ?? '';
  String get _photoPrefsKey => 'profile_photo_path_$_uid';

  @override
  void initState() {
    super.initState();
    _loadSavedPhoto();
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
                  leading: const Icon(Icons.photo_library_outlined, color: AppColors.primary),
                  title: const Text('Choose from Gallery'),
                  onTap: () {
                    Navigator.pop(context);
                    _pickPhoto(ImageSource.gallery);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.photo_camera_outlined, color: AppColors.primary),
                  title: const Text('Take a Photo'),
                  onTap: () {
                    Navigator.pop(context);
                    _pickPhoto(ImageSource.camera);
                  },
                ),
                if (_pickedPhoto != null)
                  ListTile(
                    leading: const Icon(Icons.delete_outline, color: AppColors.warning),
                    title: const Text('Remove Photo', style: TextStyle(color: AppColors.warning)),
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
        future: _loadProfileData(uid, widget.role),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting || !_photoLoaded) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            );
          }
          final data = snapshot.data ?? {};

          final name = (data['name'] ?? data['fullname'] ?? data['responder_name'] ?? 'Profile').toString();
          final email = (data['email'] ?? '-').toString();
          final contact = (data['contactNumber'] ?? '-').toString();
          final barangay = (data['barangay'] ?? '-').toString();
          final municipality = (data['municipality'] ?? 'Lal-lo').toString();
          final province = (data['province'] ?? 'Cagayan').toString();
          final accountStatus = (data['accountStatus'] ?? data['verificationStatus'] ?? 'active').toString();
          final roleLabel = widget.role == 'responder' ? 'Responder' : 'Citizen';
          final isVerified = accountStatus != 'pending' && accountStatus != 'rejected';

          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 112),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // === HEADER CARD ===
                _headerCard(name, roleLabel, isVerified),
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
                      _detailRow(Icons.email_outlined, 'Email Address', email),
                      const SizedBox(height: 16),
                      _detailRow(Icons.phone_outlined, 'Mobile Number', contact),
                      const SizedBox(height: 16),
                      _detailRow(Icons.person_outline, 'Account Role', roleLabel),
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
                        _detailRow(Icons.location_city_outlined, 'Barangay', barangay),
                        const SizedBox(height: 16),
                        _detailRow(Icons.business_outlined, 'Municipality / City', municipality),
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
                              color: isVerified ? AppColors.completed : AppColors.warning,
                              size: 22,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                isVerified
                                    ? '✅ Your account is verified and fully active.'
                                    : '⏳ Your account is still under review.',
                                style: TextStyle(
                                  color: isVerified ? AppColors.completed : AppColors.warning,
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
    final userDoc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
    final userData = userDoc.data() ?? {};
    if (role == 'citizen') {
      final citizenSnap = await FirebaseFirestore.instance
          .collection('citizens')
          .where('userID', isEqualTo: uid)
          .limit(1)
          .get();
      if (citizenSnap.docs.isNotEmpty) {
        return {...userData, ...citizenSnap.docs.first.data()};
      }
    } else {
      final responderSnap = await FirebaseFirestore.instance
          .collection('responders')
          .where('userID', isEqualTo: uid)
          .limit(1)
          .get();
      if (responderSnap.docs.isNotEmpty) {
        return {...userData, ...responderSnap.docs.first.data()};
      }
    }
    return userData;
  }

  Widget _headerCard(String name, String roleLabel, bool isVerified) {
    return GlassCard(
      color: AppColors.primary,
      radius: 24,
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
      child: Column(
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
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
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
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                const Icon(Icons.shield_outlined, color: Colors.white70, size: 18),
                const SizedBox(width: 8),
                Text(
                  isVerified ? 'Account verified' : 'Verification in progress',
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
            backgroundImage: _pickedPhoto != null ? FileImage(_pickedPhoto!) : null,
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

  Widget _detailRow(IconData icon, String label, String value) {
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
        ],
      ),
    );
  }
}