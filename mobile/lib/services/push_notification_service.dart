import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'api_service.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  debugPrint('FCM background message: ${message.messageId}');
}

String _detectPlatform() {
  switch (defaultTargetPlatform) {
    case TargetPlatform.android:
      return 'android';
    case TargetPlatform.iOS:
      return 'ios';
    default:
      return 'unknown';
  }
}

class PushNotificationService {
  PushNotificationService._();
  static final PushNotificationService instance = PushNotificationService._();

  FirebaseMessaging? _messaging;
  FlutterLocalNotificationsPlugin? _localNotifications;

  bool _initialized = false;
  String? _currentToken;

  String? get currentToken => _currentToken;

  final _foregroundMessages = StreamController<RemoteMessage>.broadcast();
  Stream<RemoteMessage> get foregroundMessages => _foregroundMessages.stream;

  Future<void> initialize() async {
    if (_initialized || kIsWeb) return;

    try {
      _messaging = FirebaseMessaging.instance;
      _localNotifications = FlutterLocalNotificationsPlugin();

      FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

      final settings = await _messaging!.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      if (settings.authorizationStatus == AuthorizationStatus.denied) {
        debugPrint('FCM: user denied notification permission');
        _initialized = true;
        return;
      }

      const androidChannel = AndroidNotificationChannel(
        'luharide_default',
        'LuhaRide Notifications',
        description: 'Ride bookings, approvals and updates',
        importance: Importance.high,
      );

      await _localNotifications!
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(androidChannel);

      const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
      const darwinInit = DarwinInitializationSettings();
      await _localNotifications!.initialize(
        const InitializationSettings(android: androidInit, iOS: darwinInit),
      );

      FirebaseMessaging.onMessage.listen(_showForegroundNotification);

      _currentToken = await _messaging!.getToken();
      debugPrint('FCM token: $_currentToken');

      _messaging!.onTokenRefresh.listen((newToken) {
        _currentToken = newToken;
        _registerTokenWithBackend(newToken);
      });

      _initialized = true;
    } catch (e) {
      debugPrint('FCM initialization failed: $e');
    }
  }

  void _showForegroundNotification(RemoteMessage message) {
    _foregroundMessages.add(message);

    final notification = message.notification;
    if (notification == null || _localNotifications == null) return;

    _localNotifications!.show(
      notification.hashCode,
      notification.title,
      notification.body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'luharide_default',
          'LuhaRide Notifications',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
    );
  }

  Future<void> registerToken() async {
    if (kIsWeb || _currentToken == null) return;
    await _registerTokenWithBackend(_currentToken!);
  }

  Future<void> _registerTokenWithBackend(String token) async {
    try {
      await ApiService().post(
        '/notifications/fcm-token',
        data: {
          'token': token,
          'platform': _detectPlatform(),
        },
      );
    } catch (e) {
      debugPrint('FCM token register failed: $e');
    }
  }

  Future<void> unregisterToken() async {
    if (kIsWeb || _currentToken == null) return;
    try {
      await ApiService().delete(
        '/notifications/fcm-token',
        data: {'token': _currentToken},
      );
    } catch (e) {
      debugPrint('FCM token unregister failed: $e');
    }
  }
}
