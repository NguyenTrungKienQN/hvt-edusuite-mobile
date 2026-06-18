import 'dart:io';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'api_service.dart';

Future<void> _saveNotificationLocally(String title, String body) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final String? data = prefs.getString('saved_notifications');
    List<dynamic> notifications = [];
    if (data != null) {
      notifications = jsonDecode(data);
    }
    notifications.add({
      'title': title,
      'body': body,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });
    // Keep only the last 100 notifications to prevent memory bloat
    if (notifications.length > 100) {
      notifications = notifications.sublist(notifications.length - 100);
    }
    await prefs.setString('saved_notifications', jsonEncode(notifications));
  } catch (e) {
    if (kDebugMode) print('Failed to save notification: $e');
  }
}

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    // Initialize Firebase if not already initialized
    await Firebase.initializeApp();
    if (kDebugMode) {
      print('Background message received: ${message.messageId}');
    }
    if (message.notification != null) {
      await _saveNotificationLocally(
        message.notification!.title ?? 'Thông báo mới',
        message.notification!.body ?? '',
      );
    }
  } catch (e) {
    if (kDebugMode) {
      print('Firebase background init failed: $e');
    }
  }
}

class NotificationService {
  static final NotificationService instance = NotificationService._();
  NotificationService._();

  FirebaseMessaging get _fcm => FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();
  bool _initialized = false;
  bool _firebaseAvailable = false;

  Future<void> init() async {
    if (_initialized) return;

    try {
      // 1. Initialize Firebase Core (required before messaging)
      await Firebase.initializeApp();
      _firebaseAvailable = true;

      // 2. Set Background message handler
      FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

      // 3. Setup local notifications for foreground alerts
      const AndroidInitializationSettings androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
      const DarwinInitializationSettings iosSettings = DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      );

      const InitializationSettings initSettings = InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      );

      await _localNotifications.initialize(
        settings: initSettings,
        onDidReceiveNotificationResponse: (NotificationResponse response) {
          // Handle notification tap action here
        },
      );

      // 4. Create Notification Channel for Android 8.0+
      if (Platform.isAndroid) {
        const AndroidNotificationChannel channel = AndroidNotificationChannel(
          'edusuite_attendance_channel', // id
          'Điểm danh & Tin tức', // name
          description: 'Nhận thông báo điểm danh của học sinh tức thời.', // description
          importance: Importance.max,
          playSound: true,
        );

        await _localNotifications
            .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
            ?.createNotificationChannel(channel);
      }

      // 5. Handle foreground messages
      if (_firebaseAvailable) {
        FirebaseMessaging.onMessage.listen((RemoteMessage message) {
          RemoteNotification? notification = message.notification;
          AndroidNotification? android = message.notification?.android;

          if (notification != null) {
            _showLocalNotification(notification, android);
            _saveNotificationLocally(
              notification.title ?? 'Thông báo mới',
              notification.body ?? '',
            );
          }
        });
      }

      _initialized = true;
      if (kDebugMode) {
        print('NotificationService initialized successfully (Firebase available: $_firebaseAvailable).');
      }
    } catch (e) {
      // If Firebase initialization failed, we still mark initialized to prevent loops, but _firebaseAvailable remains false
      _initialized = true;
      if (kDebugMode) {
        print('Error initializing Firebase messaging: $e. Local notification fallback only.');
      }
    }
  }

  Future<void> requestPermissionsAndRegisterToken() async {
    if (!_firebaseAvailable) {
      if (kDebugMode) {
        print('FCM not available: skipping permission request and token registration.');
      }
      return;
    }
    try {
      // 1. Request OS Permission
      NotificationSettings settings = await _fcm.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        if (kDebugMode) {
          print('Notification Permission Granted.');
        }

        // 2. Fetch FCM Token
        String? token = await _fcm.getToken();
        if (token != null) {
          if (kDebugMode) {
            print('FCM Token: $token');
          }
          // 3. Register to Backend
          final String deviceType = Platform.isIOS ? 'ios' : 'android';
          await apiService.registerFCMToken(token, deviceType);
          if (kDebugMode) {
            print('FCM Token registered to backend.');
          }
        }
      } else {
        if (kDebugMode) {
          print('Notification Permission Denied or Restricted.');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error registering notification token: $e');
      }
    }
  }

  void _showLocalNotification(RemoteNotification notification, AndroidNotification? android) {
    _localNotifications.show(
      id: notification.hashCode,
      title: notification.title,
      body: notification.body,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          'edusuite_attendance_channel',
          'Điểm danh & Tin tức',
          channelDescription: 'Nhận thông báo điểm danh của học sinh tức thời.',
          icon: android?.smallIcon ?? '@mipmap/ic_launcher',
          importance: Importance.max,
          priority: Priority.high,
          playSound: true,
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
    );
  }
}
