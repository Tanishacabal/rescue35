import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../screens/citizen/my_requests_screen.dart';

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

  // ── Initialize — i-call ito sa main.dart ────────────────
  Future<void> initialize() async {
    final settings = await _fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );
    debugPrint('Notification permission: ${settings.authorizationStatus}');

    await _initLocalNotifications();

    // Para ipakita ang notification kahit foreground ang app (iOS)
    await FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    await _saveToken();
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
        final user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          navigatorKey.currentState?.push(
            MaterialPageRoute(builder: (_) => const MyRequestsScreen()),
          );
        }
      },
    );

    // Gumawa ng Android notification channel (kailangan ito para
    // gumana ang high-priority / lockscreen display sa Android 8+)
    await _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_androidChannel);
  }

  // ── Save FCM token sa Firestore ──────────────────────────
  Future<void> _saveToken() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final token = await _fcm.getToken();
    if (token == null) return;

    await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .update({'fcmToken': token});

    debugPrint('FCM Token saved: $token');
  }

  // ── Update token kapag nag-refresh ──────────────────────
  Future<void> _updateToken(String token) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .update({'fcmToken': token});
  }

  // ── Handle foreground message ────────────────────────────
  // Dito na natin ipapakita bilang totoong system notification
  // (lalabas sa tray/lockscreen) sa halip na SnackBar na lang.
  void _handleForegroundMessage(RemoteMessage message) {
    debugPrint('Foreground message: ${message.notification?.title}');

    final notification = message.notification;
    if (notification == null) return;

    _localNotifications.show(
      message.hashCode,
      notification.title,
      notification.body,
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
      payload: message.data.toString(),
    );
  }

  // ── Handle notification tap ──────────────────────────────
  void _handleNotificationTap(RemoteMessage message) {
    debugPrint('Notification tapped: ${message.data}');

    // Lahat ng notification sa citizen app → MyRequestsScreen
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      navigatorKey.currentState?.push(
        MaterialPageRoute(builder: (_) => const MyRequestsScreen()),
      );
    }
  }

  // ── Public method — i-call after login ──────────────────
  Future<void> saveTokenAfterLogin() async {
    await _saveToken();
  }
}