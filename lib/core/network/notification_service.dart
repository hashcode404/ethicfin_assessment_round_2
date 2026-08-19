import 'dart:async';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final notificationServiceProvider = Provider<NotificationService>((ref) {
  return NotificationService();
});

class NotificationService {
  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final StreamController<RemoteMessage> _foregroundMessageController =
      StreamController<RemoteMessage>.broadcast();

  Stream<RemoteMessage> get onForegroundMessage => _foregroundMessageController.stream;

  Future<void> initialize() async {
    try {
      // 1. Request permissions
      final settings = await _fcm.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );

      debugPrint('User notification permission status: ${settings.authorizationStatus}');

      // 2. Get device token
      final token = await _fcm.getToken();
      debugPrint("FCM Registration Token: $token");

      // 3. Listen to foreground messages
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        debugPrint('FCM Foreground message received: ${message.messageId}');
        _foregroundMessageController.add(message);
      });

      // 4. Handle background messages
      FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    } catch (e) {
      debugPrint('Error initializing notification service: $e');
    }
  }
}

// Background messaging handler must be a top-level function
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint("FCM Background message received: ${message.messageId}");
}
