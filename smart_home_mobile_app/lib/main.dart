import 'package:flutter/material.dart';
import 'package:smart_home_mobile_app/pages/dashboard_page.dart';
import 'package:smart_home_mobile_app/pages/history_page.dart';
import 'package:smart_home_mobile_app/pages/settings_page.dart';
import 'pages/login_page.dart';
import 'pages/signup_page.dart';
import 'package:firebase_core/firebase_core.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter App',
      theme: ThemeData.dark(), // Use dark theme
      initialRoute: '/',
      routes: {
        '/': (context) => const LoginPage(),
        '/signup': (context) => const SignUpPage(),
        '/dashboard': (context) => const DashboardPage(),
        '/history': (context) => const HistoryPage(),
        '/settings': (context) =>
            const SettingsPage(), // Add route for settings
      },
    );
  }
}
