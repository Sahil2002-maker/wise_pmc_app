import 'package:flutter/material.dart';
import 'core/constants/app_colors.dart';
import 'core/services/auth_storage_service.dart';
import 'features/auth/presentation/pages/login_page.dart';
import 'features/dashboard/presentation/pages/dashboard_page.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:firebase_core/firebase_core.dart';
import 'core/services/notification_service.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

// ✅ Background handler (IMPORTANT)
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  print("Background Message: ${message.messageId}");
}
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  WebViewPlatform.instance = AndroidWebViewPlatform(); // ← add this

  // ✅ Initialize Firebase
  await Firebase.initializeApp();

  // ✅ REGISTER HANDLER
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  // ✅ Initialize Notification Service
  final NotificationService notificationService = NotificationService();
  await notificationService.init();
  
  final token = await AuthStorageService.getToken();

  runApp(
    MyApp(initialLoggedIn: token != null && token.isNotEmpty),
  );
}

class MyApp extends StatelessWidget {
  final bool initialLoggedIn;

  const MyApp({
    super.key,
    required this.initialLoggedIn,
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Wise Realty',
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: 'Arial',
        scaffoldBackgroundColor: AppColors.bgColor,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.primaryGreen,
        ),
      ),
      home: initialLoggedIn ? const DashboardPage() : const LoginPage(),
    );
  }
}