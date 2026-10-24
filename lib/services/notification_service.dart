import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../screens/notifications/notifications_screen.dart';

// ── Background message handler ───────────────────────────────
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('Background message: ${message.messageId}');
}

// ── Global navigator key ─────────────────────────────────────
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

// ── Local notifications plugin (para lumabas sa tray/lockscreen
//    kahit foreground ang app) ─────────────────────────────────
final FlutterLocalNotificationsPlugin _localNotifications =
    FlutterLocalNotificationsPlugin();

// Android notification channel — dapat match ang channel id na ito
// sa gagamitin mo sa Firebase Console / server payload kung meron.
const AndroidNotificationChannel _androidChannel = AndroidNotificationChannel(
  'high_importance_channel', // id
  'Mahahalagang Abiso', // channel name na makikita ng user sa settings
  description: 'Ginagamit para sa mahahalagang notification ng app.',
  importance: Importance.max,
);

class NotificationService {
  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>?
  _liveRequestSubscription;
  final Map<String, String?> _knownRequestStatuses = {};
  final Set<String> _shownLiveAlerts = {};
  bool _initialized = false;

  // ── Initialize — i-call ito sa main.dart ────────────────
  Future<void> initialize() async {
    if (_initialized) return;

    final settings = await _fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );
    debugPrint('Notification permission: ${settings.authorizationStatus}');

    await _initLocalNotifications();

    await _fcm.setForegroundNotificationPresentationOptions(
      alert: false,
      badge: false,
      sound: false,
    );

    FirebaseAuth.instance.authStateChanges().listen((user) {
      _liveRequestSubscription?.cancel();
      _knownRequestStatuses.clear();
      _shownLiveAlerts.clear();
      if (user != null) {
        _saveToken();
        _listenForLiveRequestAlerts(user);
      }
    });
    _fcm.onTokenRefresh.listen(_updateToken);
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
    FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);

    // Handle tap kapag terminated ang app
    final initial = await _fcm.getInitialMessage();
    if (initial != null) {
      Future.delayed(const Duration(milliseconds: 500), () {
        _handleNotificationTap(initial);
      });
    }
    _initialized = true;
  }

  // ── Setup ng flutter_local_notifications ─────────────────
  Future<void> _initLocalNotifications() async {
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidInit,
      iOS: iosInit,
    );

    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (response) {
        // Tap sa local notification habang foreground/background (Android)
        debugPrint('Local notification tapped, payload: ${response.payload}');
        _openNotifications();
      },
    );

    // Gumawa ng Android notification channel (kailangan ito para
    // gumana ang high-priority / lockscreen display sa Android 8+)
    await _localNotifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(_androidChannel);
  }

  // ── Save FCM token sa Firestore ──────────────────────────
  Future<void> _saveToken() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final token = await _fcm.getToken();
    if (token == null) return;

    await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
      'fcmToken': token,
      'fcmTokens': FieldValue.arrayUnion([token]),
    }, SetOptions(merge: true));
  }

  // ── Update token kapag nag-refresh ──────────────────────
  Future<void> _updateToken(String token) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
      'fcmToken': token,
      'fcmTokens': FieldValue.arrayUnion([token]),
    }, SetOptions(merge: true));
  }

  // ── Handle foreground message ────────────────────────────
  // Dito na natin ipapakita bilang totoong system notification
  // (lalabas sa tray/lockscreen) sa halip na SnackBar na lang.
  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    debugPrint('Foreground message: ${message.notification?.title}');

    final notification = message.notification;
    if (notification == null) return;

    await _showLocalNotification(
      id: message.hashCode,
      title: notification.title,
      body: notification.body,
      payload: message.data.toString(),
    );
  }

  Future<void> _showLocalNotification({
    required int id,
    required String? title,
    required String? body,
    String? payload,
  }) async {
    await _localNotifications.show(
      id,
      title,
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _androidChannel.id,
          _androidChannel.name,
          channelDescription: _androidChannel.description,
          importance: Importance.max,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      payload: payload,
    );
  }

  Future<void> _listenForLiveRequestAlerts(User user) async {
    final db = FirebaseFirestore.instance;
    try {
      final userSnapshot = await db.collection('users').doc(user.uid).get();
      if (FirebaseAuth.instance.currentUser?.uid != user.uid) return;
      final isResponder = userSnapshot.data()?['role'] == 'responder';
      final query = isResponder
          ? db
                .collection('transport_requests')
                .where('status', isEqualTo: 'pending')
          : db
                .collection('transport_requests')
                .where('userID', isEqualTo: user.uid);

      var isInitialSnapshot = true;
      _liveRequestSubscription = query.snapshots().listen(
        (snapshot) {
          if (isInitialSnapshot) {
            for (final request in snapshot.docs) {
              _knownRequestStatuses[request.id] = request
                  .data()['status']
                  ?.toString();
            }
            isInitialSnapshot = false;
            return;
          }

          for (final change in snapshot.docChanges) {
            final requestId = change.doc.id;
            final data = change.doc.data();
            final status = data?['status']?.toString();

            if (isResponder && change.type == DocumentChangeType.added) {
              _showLiveAlert(
                key: 'new-request:$requestId',
                title: 'New transport request',
                body: 'A new request needs attention.',
              );
            } else if (!isResponder &&
                change.type == DocumentChangeType.added) {
              _showLiveAlert(
                key: 'request-received:$requestId',
                title: 'Request submitted',
                body: 'Your transport request was added to the Alerts list.',
              );
            } else if (!isResponder &&
                change.type == DocumentChangeType.modified &&
                _knownRequestStatuses[requestId] != status) {
              _showLiveAlert(
                key: 'request-status:$requestId:$status',
                title: 'Transport request update',
                body: 'Your request is now ${_displayStatus(status)}.',
              );
            }

            _knownRequestStatuses[requestId] = status;
          }
        },
        onError: (Object error, StackTrace stackTrace) {
          debugPrint('Live request notifications failed: $error');
          debugPrintStack(stackTrace: stackTrace);
        },
      );
    } on FirebaseException catch (error, stackTrace) {
      debugPrint(
        'Unable to start live request notifications: '
        '${error.code} ${error.message}',
      );
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  void _showLiveAlert({
    required String key,
    required String title,
    required String body,
  }) {
    if (!_shownLiveAlerts.add(key)) return;
    unawaited(
      _showLocalNotification(
        id: key.hashCode,
        title: title,
        body: body,
        payload: key,
      ),
    );
  }

  String _displayStatus(String? status) {
    if (status == null || status.isEmpty) return 'updated';
    return status
        .replaceAll('-', ' ')
        .split(' ')
        .map(
          (word) => word.isEmpty
              ? word
              : '${word[0].toUpperCase()}${word.substring(1)}',
        )
        .join(' ');
  }

  // ── Handle notification tap ──────────────────────────────
  void _handleNotificationTap(RemoteMessage message) {
    debugPrint('Notification tapped: ${message.data}');

    _openNotifications();
  }

  void _openNotifications() {
    if (FirebaseAuth.instance.currentUser == null) return;
    navigatorKey.currentState?.push(
      MaterialPageRoute(builder: (_) => const NotificationsScreen()),
    );
  }

  // ── Public method — i-call after login ──────────────────
  Future<void> saveTokenAfterLogin() async {
    await _saveToken();
  }

  Future<void> removeTokenBeforeLogout() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final token = await _fcm.getToken();
    if (token == null) return;

    final userRef = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid);
    final userSnapshot = await userRef.get();
    final updates = <String, Object>{
      'fcmTokens': FieldValue.arrayRemove([token]),
    };
    if (userSnapshot.data()?['fcmToken'] == token) {
      updates['fcmToken'] = '';
    }
    await userRef.set(updates, SetOptions(merge: true));
  }
}
