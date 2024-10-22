import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:myapp/pages/history_page.dart';
import 'package:myapp/pages/profile_page.dart';
import 'package:myapp/services/firebase_service.dart';
import 'package:myapp/services/mqtt_service.dart';
import 'package:myapp/services/sensor_service.dart'; // For sensor service
import 'package:provider/provider.dart';
import 'models/device_data.dart';
import 'themes/theme_provider.dart'; 
import '/pages/login_page.dart';
import '/pages/signup_page.dart';
import '/pages/dashboard_page.dart';
import '/pages/settings_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (!kIsWeb) {
    await Firebase.initializeApp();
    if (kDebugMode) {
      print('Firebase initialized successfully');
    }
  }

  runApp(
    MultiProvider(
      providers: [
        Provider(create: (context) => FirebaseService()),
        Provider<MqttService>(
          create: (context) {
            final mqttService = MqttService(broker: 'broker.hivemq.com', clientId: 'Client_FlutterBossHamoooo');
            mqttService.connect();
            return mqttService;
          },
        ),
        ChangeNotifierProvider(create: (context) => DeviceData()), // Device data
        ChangeNotifierProvider(create: (context) => ThemeProvider()), // For dark/light mode
        ChangeNotifierProvider(create: (context) => SensorService()), // Sensor service
      ],
      child: const MyApp(),
    ),
  );
}


class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return MaterialApp(
      title: 'Smart Home',
      theme: ThemeData.light(),
      darkTheme: ThemeData.dark(),
      themeMode: themeProvider.themeMode,
      initialRoute: '/login',
      routes: {
        '/login': (context) => const LoginPage(),
        '/signup': (context) => const SignupPage(),
        '/dashboard': (context) => const DashboardPage(),
        '/settings': (context) => const SettingsPage(),
        '/history': (context) => const HistoryPage(),
        '/profile': (context) => const ProfilePage(),
      },
    );
  }
}
