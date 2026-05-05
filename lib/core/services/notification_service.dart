import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'api_service.dart'; // ✅ IMPORT THIS

class NotificationService {
  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  Future<void> init() async {
    // ✅ Request permission (important for Android 13+)
    NotificationSettings settings =
        await _firebaseMessaging.requestPermission();

    print("Permission: ${settings.authorizationStatus}");

    // ✅ Get FCM Token
    String? token = await _firebaseMessaging.getToken();
    print("FCM TOKEN: $token");

    // ✅ SEND TOKEN TO LARAVEL (MOST IMPORTANT FIX)
    if (token != null) {
      try {
        await ApiService().sendFcmToken(token);
        print("FCM Token sent to server");
      } catch (e) {
        print("Error sending token: $e");
      }
    }

    // ✅ Handle token refresh (VERY IMPORTANT)
    FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
      print("New FCM Token: $newToken");
      await ApiService().sendFcmToken(newToken);
    });

    // ✅ Local notification setup
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings initSettings =
        InitializationSettings(android: androidSettings);

    await _localNotifications.initialize(initSettings);

    // ✅ Foreground notification
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print("Foreground Message: ${message.notification?.title}");
      _showNotification(message);
    });

    // ✅ When user clicks notification (APP OPENED)
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      print("Notification clicked");

      String? projectId = message.data['project_id'];

      // 👉 You can navigate using navigatorKey later
      print("Project ID: $projectId");
    });

    // ✅ When app is opened from terminated state
    RemoteMessage? initialMessage =
        await FirebaseMessaging.instance.getInitialMessage();

    if (initialMessage != null) {
      print("App opened from terminated state");
    }
  }

  // ✅ SHOW LOCAL NOTIFICATION
  Future<void> _showNotification(RemoteMessage message) async {
    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      'default_channel',
      'General Notifications',
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
    );

    const NotificationDetails details =
        NotificationDetails(android: androidDetails);

    await _localNotifications.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      message.notification?.title ?? "Notification",
      message.notification?.body ?? "",
      details,
    );
  }
}