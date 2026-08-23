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
  // The photo itself lives only on this device — in the app's local
  // documents folder, with just the file path remembered in
  // SharedPreferences (also local, on-device). Nothing is uploaded or
  // written to Firestore/any backend database.
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
      setState(() => _photoLoaded = true);
      return;
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      final path = prefs.getString(_photoPrefsKey);
      if (path != null && await File(path).exists()) {
        if (mounted) setState(() => _pickedPhoto = File(path));
      }
    } catch (_) {
      // If loading fails, just fall back to the default avatar icon.
    } finally {
      if (mounted) setState(() => _photoLoaded = true);
    }
  }

  Future<void> _pickPhoto(ImageSource source) async {
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
        SnackBar(content: Text('Unable to open photo: $e')),
      );
    } finally {
      if (mounted) setState(() => _isPickingPhoto = false);
    }
  }

  /// Copies the picked image into the app's own documents folder (so it
  /// survives app restarts, unlike the picker's temp cache path) and
  /// remembers the path in SharedPreferences. Uses a fresh, timestamped
  /// filename each time and deletes the previous local copy — this avoids
  /// both disk buildup and Flutter's FileImage caching a stale photo under
  /// a reused path.
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
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
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
                  title: const Text('Remove Photo'),
                  onTap: () {
                    Navigator.pop(context);
                    _removePhoto();
                  },
                ),
            ],
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
            style: TextStyle(color: AppColors.textGray),
          ),
        ),
      );
    }

    return RescueGradientScaffold(
      child: FutureBuilder<Map<String, dynamic>>(
        future: _loadProfileData(uid, widget.role),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting || !_photoLoaded) {
            return const Center(child: CircularProgressIndicator());
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

          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              _headerCard(context, name, roleLabel, isVerified),
              const SizedBox(height: 18),
              GlassCard(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Profile Details',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: AppColors.dark,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _detailRow('Full Name', name),
                    _detailRow('Email', email),
                    _detailRow('Mobile Number', contact),
                    _detailRow('Role', roleLabel),
                    if (widget.role == 'citizen') ...[
                      _detailRow('Barangay', barangay),
                      _detailRow('Municipality', municipality),
                      _detailRow('Province', province),
                    ],
                    _detailRow('Status', accountStatus.toUpperCase()),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              GlassCard(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Account Status',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: AppColors.dark,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Icon(
                          isVerified ? Icons.verified_user_rounded : Icons.pending_actions_rounded,
                          color: isVerified ? AppColors.completed : AppColors.warning,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            isVerified
                              ? 'Your account is active and ready for assistance.'
                              : 'Your account is still under review for verification.',
                            style: const TextStyle(
                              color: AppColors.textGray,
                              height: 1.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
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

  Widget _headerCard(BuildContext context, String name, String roleLabel, bool isVerified) {
    return GlassCard(
      color: AppColors.primary,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _avatar(roleLabel),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(99),
                      ),
                      child: Text(
                        roleLabel,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close_rounded, color: Colors.white),
                tooltip: 'Back',
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              const Icon(Icons.shield_outlined, color: Colors.white70, size: 18),
              const SizedBox(width: 8),
              Text(
                isVerified ? 'Account verified' : 'Verification in progress',
                style: const TextStyle(
                  color: Colors.white70,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Avatar with a small edit badge. Tapping it opens the gallery/camera
  /// picker; the photo is copied into local app storage and remembered
  /// via SharedPreferences (see `_savePhotoLocally`), so it now survives
  /// navigating away or restarting the app — still device-only, never
  /// sent to a database.
  Widget _avatar(String roleLabel) {
    return GestureDetector(
      onTap: _isPickingPhoto ? null : _showPhotoSourceSheet,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: Colors.white.withValues(alpha: 0.2),
            backgroundImage: _pickedPhoto != null ? FileImage(_pickedPhoto!) : null,
            child: _isPickingPhoto
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : (_pickedPhoto == null
                    ? Icon(
                        roleLabel == 'Responder' ? Icons.medical_services_rounded : Icons.person_rounded,
                        size: 28,
                        color: Colors.white,
                      )
                    : null),
          ),
          Positioned(
            bottom: -2,
            right: -2,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.primary, width: 1.5),
              ),
              child: const Icon(
                Icons.camera_alt_rounded,
                size: 12,
                color: AppColors.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: AppColors.textGray,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              color: AppColors.dark,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}