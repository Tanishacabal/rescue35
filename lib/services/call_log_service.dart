import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';
import 'activity_log_service.dart';

class CallLogService {
  static final _db = FirebaseFirestore.instance;
  static final _auth = FirebaseAuth.instance;

  /// Itatala ang tawag sa `call_logs` at bubuksan agad ang dialer
  /// (Android at iOS). Hindi hinihintay ang pagsusulat ng log para hindi
  /// maantala ang emergency call, at hindi rin mapipigilan ng log error
  /// ang tawag. Ibinabalik ang `true` kung nabuksan ang dialer.
  static Future<bool> callAndLog({
    required String calleeNumber,
    String calleeName = '',
    String calleeRole = '',
    String? relatedRequestId,
  }) async {
    final number = calleeNumber.trim();
    if (number.isEmpty || number == '-') return false;

    unawaited(
      _writeLog(
        calleeNumber: number,
        calleeName: calleeName,
        calleeRole: calleeRole,
        relatedRequestId: relatedRequestId,
      ),
    );

    // Tanggalin ang spaces, dashes, at parentheses; panatilihin ang + at digits
    final dialable = number.replaceAll(RegExp(r'[^\d+]'), '');
    if (dialable.isEmpty) return false;

    try {
      final uri = Uri(scheme: 'tel', path: dialable);
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!ok) debugPrint('Dialer could not be opened for $dialable');
      return ok;
    } catch (e) {
      debugPrint('Unable to open dialer: $e');
      return false;
    }
  }

  static Future<void> _writeLog({
    required String calleeNumber,
    required String calleeName,
    required String calleeRole,
    String? relatedRequestId,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      String callerName = user.displayName ?? '';
      String callerNumber = '';
      String callerRole = '';

      final userDoc = await _db.collection('users').doc(user.uid).get();
      final data = userDoc.data();
      if (data != null) {
        callerName = (data['name'] as String?) ?? callerName;
        callerNumber = (data['contactNumber'] as String?) ?? '';
        callerRole = (data['role'] as String?) ?? '';
      }

      await _db.collection('call_logs').add({
        'userID': user.uid,
        'callerName': callerName,
        'callerNumber': callerNumber,
        'callerRole': callerRole,
        'calleeName': calleeName,
        'calleeNumber': calleeNumber,
        'calleeRole': calleeRole,
        'relatedRequestId': relatedRequestId ?? '',
        'createdAt': FieldValue.serverTimestamp(),
      });
      await ActivityLogService.log(
        action: 'phone_call_started',
        description: 'Called ${calleeName.isEmpty ? calleeNumber : calleeName}',
        entityType: 'call_log',
        entityId: relatedRequestId ?? '',
        metadata: {
          'calleeNumber': calleeNumber,
          'calleeName': calleeName,
          'calleeRole': calleeRole,
          'relatedRequestId': relatedRequestId ?? '',
        },
      );
    } catch (e) {
      debugPrint('Call log write failed: $e');
    }
  }
}
