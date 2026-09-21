import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'notification_service.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  static const _cloudName = 'eaxfy6jh';
  static const _uploadPreset = 'citizen_proofs';

  // ── Kumuha ng current user ──────────────────────────────
  User? get currentUser => _auth.currentUser;

  // ── Phone helpers ───────────────────────────────────────
  // Ginagawang 09XXXXXXXXX ang kahit anong PH mobile format
  String _normalizePhone(String input) {
    final digits = input.replaceAll(RegExp(r'\D'), '');
    if (digits.length < 10) return input.trim();
    return '0${digits.substring(digits.length - 10)}';
  }

  // Lahat ng posibleng format na naka-save sa Firestore
  List<String> _phoneVariants(String input) {
    final digits = input.replaceAll(RegExp(r'\D'), '');
    if (digits.length < 10) return [];
    final n = digits.substring(digits.length - 10); // 9XXXXXXXXX
    return ['0$n', '+63$n', '63$n', n];
  }

  // ── Hanapin LAHAT ng email na naka-link sa number ───────
  // Nagta-throw ng FirebaseException kapag nag-error ang query
  Future<List<String>> _queryEmailsByPhone(String input) async {
    final variants = _phoneVariants(input);
    if (variants.isEmpty) return [];

    final snap = await _db
        .collection('users')
        .where('contactNumber', whereIn: variants)
        .limit(10)
        .get();
    debugPrint('Phone lookup variants: $variants, found: ${snap.docs.length}');

    final emails = <String>[];
    for (final d in snap.docs) {
      final email = (d.data()['email'] as String?)?.trim() ?? '';
      if (email.isNotEmpty && !emails.contains(email)) emails.add(email);
    }
    return emails;
  }

  // Unang email lang (para sa forgot password). Null kapag wala o nag-error.
  Future<String?> getEmailByPhone(String input) async {
    try {
      final emails = await _queryEmailsByPhone(input);
      return emails.isEmpty ? null : emails.first;
    } catch (e) {
      debugPrint('Phone lookup error: $e');
      return null;
    }
  }

  // ── Login gamit ang mobile number ───────────────────────
  // Kung maraming account ang may parehong number, susubukan
  // ang password sa bawat isa hanggang may tumugma.
  Future<String?> loginWithPhone(String phone, String password) async {
    List<String> emails;
    try {
      emails = await _queryEmailsByPhone(phone);
    } on FirebaseException catch (e) {
      debugPrint('Phone lookup error: ${e.code} ${e.message}');
      if (e.code == 'permission-denied') {
        return 'Lookup blocked by Firestore rules (permission-denied). '
            'Update the rules for the users collection.';
      }
      return 'Lookup error: ${e.code}';
    } catch (e) {
      debugPrint('Phone lookup error: $e');
      return 'Lookup error: $e';
    }

    if (emails.isEmpty) {
      return 'No account found with that mobile number.';
    }

    String? lastError;
    for (final email in emails) {
      final error = await login(email, password);
      if (error == null) return null; // success

      // Kapag mali lang ang password, subukan ang susunod na account.
      // Ibang error (pending, rejected, disabled, admin) = tumugma ang
      // password, kaya ibalik agad ang mensahe.
      final isPasswordMismatch = error == 'Wrong password. Please try again.' ||
          error == 'Login failed. Please try again.';
      if (!isPasswordMismatch) return error;
      lastError = error;
    }
    return lastError ?? 'Wrong password. Please try again.';
  }

  // ── Login ───────────────────────────────────────────────
  Future<String?> login(String email, String password) async {
    try {
      final cred = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password.trim(),
      );
      final doc = await _db.collection('users').doc(cred.user!.uid).get();
      final status = doc.data()?['accountStatus'] ?? 'verified';
      final role = doc.data()?['role'] ?? 'citizen';
      if (role == 'admin') {
        await _auth.signOut();
        return 'Admin accounts cannot log in on this mobile app.';
      }
      if (status == 'pending') {
        await _auth.signOut();
        return 'Your account is pending MDRRMO verification.';
      }
      if (status == 'rejected') {
        await _auth.signOut();
        return 'Your account was rejected. Please contact MDRRMO Lal-lo.';
      }
      if (status == 'disabled') {
        await _auth.signOut();
        return 'This account is disabled.';
      }
      unawaited(NotificationService().saveTokenAfterLogin());
      return null; // null = walang error
    } on FirebaseAuthException catch (e) {
      if (e.code == 'user-not-found') {
        return 'Email not found. Please register first.';
      } else if (e.code == 'wrong-password') {
        return 'Wrong password. Please try again.';
      }
      return 'Login failed. Please try again.';
    }
  }

  Future<String?> sendPasswordReset(String email) async {
    try {
      final cleanEmail = email.trim();
      if (cleanEmail.isEmpty) {
        return 'Enter your email address.';
      }
      final userSnap = await _db
          .collection('users')
          .where('email', isEqualTo: cleanEmail)
          .limit(1)
          .get();
      if (userSnap.docs.isEmpty) {
        return 'Email not found.';
      }

      await _auth.sendPasswordResetEmail(email: cleanEmail);
      return null;
    } on FirebaseAuthException catch (e) {
      if (e.code == 'user-not-found') {
        return 'Email not found.';
      } else if (e.code == 'invalid-email') {
        return 'Enter a valid email address.';
      }
      return 'Unable to send reset link. Please try again.';
    }
  }

  // ── Register ────────────────────────────────────────────
  Future<String?> register({
    required String name,
    required String email,
    required String password,
    required String contact,
    required String role, // 'citizen' or 'responder'
    required String barangay,
    String proofType = '',
    String proofFile = '',
    String proofFilePath = '',
  }) async {
    try {
      // Step 0: Siguraduhing unique ang mobile number
      final variants = _phoneVariants(contact);
      if (variants.isNotEmpty) {
        final existing = await _db
            .collection('users')
            .where('contactNumber', whereIn: variants)
            .limit(1)
            .get();
        if (existing.docs.isNotEmpty) {
          return 'Mobile number already registered.';
        }
      }

      // Step 1: Gumawa ng Firebase Auth account
      final cred = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password.trim(),
      );
      final uid = cred.user!.uid;

      // Step 2: I-save sa users collection
      await _db.collection('users').doc(uid).set({
        'userID': uid,
        'name': name.trim(),
        'email': email.trim(),
        'contactNumber': _normalizePhone(contact),
        'role': role,
        'accountStatus': role == 'citizen' ? 'pending' : 'verified',
        'createdAt': FieldValue.serverTimestamp(),
        'fcmToken': '',
      });

      // Step 3: Kung citizen, mag-add sa citizens collection
      if (role == 'citizen') {
        final proofFileUrl = proofFilePath.isEmpty
            ? ''
            : await _uploadCitizenProof(
                uid: uid,
                filePath: proofFilePath,
                fileName: proofFile,
              );

        await _db.collection('citizens').add({
          'userID': uid,
          'fullname': name.trim(),
          'barangay': barangay.trim(),
          'municipality': 'Lal-lo',
          'province': 'Cagayan',
          'proofType': proofType,
          'proofFile': proofFile,
          'proofFileUrl': proofFileUrl,
          'verificationStatus': 'pending',
        });
      }

      // Step 4: Kung responder, mag-add sa responders collection
      if (role == 'responder') {
        await _db.collection('responders').add({
          'userID': uid,
          'responder_name': name.trim(),
        });
      }

      return null; // null = walang error
    } on FirebaseAuthException catch (e) {
      if (e.code == 'email-already-in-use') {
        return 'Email already registered.';
      } else if (e.code == 'weak-password') {
        return 'Password too weak. Use at least 6 characters.';
      }
      return 'Registration failed. Please try again.';
    } catch (_) {
      return 'Unable to upload verification document. Please try again.';
    }
  }

  Future<String> _uploadCitizenProof({
    required String uid,
    required String filePath,
    required String fileName,
  }) async {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final safeName = fileName.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
    final publicId = 'citizen_proofs/$uid/${timestamp}_$safeName';

    final isPdf = fileName.toLowerCase().endsWith('.pdf');
    final resourceType = isPdf ? 'raw' : 'image';

    final uri = Uri.parse(
      'https://api.cloudinary.com/v1_1/$_cloudName/$resourceType/upload',
    );

    final request = http.MultipartRequest('POST', uri)
      ..fields['upload_preset'] = _uploadPreset
      ..fields['public_id'] = publicId
      ..files.add(await http.MultipartFile.fromPath('file', filePath));

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode != 200) {
      throw Exception('Cloudinary upload failed: ${response.body}');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return data['secure_url'] as String;
  }

  // ── Kumuha ng role ng current user ───────────────────────
  Future<String> getUserRole() async {
    final uid = _auth.currentUser!.uid;
    final doc = await _db
        .collection('users')
        .doc(uid)
        .get()
        .timeout(
          const Duration(seconds: 8),
          onTimeout: () => throw TimeoutException(
            'Timed out while loading the user role.',
            const Duration(seconds: 8),
          ),
        );
    return doc.data()?['role'] ?? 'citizen';
  }

  // ── Logout ───────────────────────────────────────────────
  Future<void> logout() async {
    await _auth.signOut();
  }
}