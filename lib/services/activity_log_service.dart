import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// Records user-initiated events for the admin Activity Logs screen.
/// A logging failure never prevents the original app action from succeeding.
class ActivityLogService {
  ActivityLogService._();

  static final _db = FirebaseFirestore.instance;
  static final _auth = FirebaseAuth.instance;

  static Future<void> log({
    required String action,
    required String description,
    String entityType = '',
    String entityId = '',
    Map<String, dynamic>? metadata,
    String? userId,
    String? userName,
    String? userRole,
  }) async {
    try {
      final user = _auth.currentUser;
      final uid = userId ?? user?.uid ?? '';
      var name = userName ?? user?.displayName ?? '';
      var role = userRole ?? '';

      if (uid.isNotEmpty && (name.isEmpty || role.isEmpty)) {
        final snapshot = await _db.collection('users').doc(uid).get();
        final data = snapshot.data();
        name = name.isNotEmpty
            ? name
            : (data?['name'] ?? data?['fullName'] ?? '').toString();
        role = role.isNotEmpty ? role : (data?['role'] ?? '').toString();
      }

      await _db.collection('activity_logs').add({
        'userID': uid,
        'userName': name,
        'userRole': role,
        'action': action,
        'description': description,
        'entityType': entityType,
        'entityID': entityId,
        'metadata': metadata ?? <String, dynamic>{},
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (error) {
      debugPrint('Activity log write failed: $error');
    }
  }
}
