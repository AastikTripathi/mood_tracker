import 'package:flutter/material.dart';
import 'screens/navigation_shell.dart';
import 'services/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize and schedule offline daily check-in reminders (e.g., at 8:00 PM)
  final notifications = NotificationService();
  await notifications.initialize();
  await notifications.requestPermissions();
  await notifications.scheduleDailyReminder(hour: 20, minute: 0);

  runApp(const BotanicalCompanionApp());
}

class BotanicalCompanionApp extends StatelessWidget {
  const BotanicalCompanionApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Botanical Sanctuary',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        colorSchemeSeed: Colors.teal,
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorSchemeSeed: Colors.indigo,
      ),
      themeMode: ThemeMode.system, // Automatically adapts to her device's system dark/light mode toggle
      home: const NavigationShell(), // Boots directly into your persistent navigation shell container
    );
  }
}