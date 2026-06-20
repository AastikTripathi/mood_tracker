import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();
  bool _isInitialized = false;

  Future<void> initialize() async {
    if (_isInitialized) return;

    // Initialize Timezone Database (required for timezone-aware local notification scheduling)
    tz.initializeTimeZones();

    // Android Initialization settings
    const AndroidInitializationSettings androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');

    // iOS Initialization settings
    const DarwinInitializationSettings iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const InitializationSettings settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notificationsPlugin.initialize(
      settings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        // Handle notification click if needed
      },
    );

    _isInitialized = true;
  }

  Future<void> requestPermissions() async {
    final androidImplementation = _notificationsPlugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (androidImplementation != null) {
      await androidImplementation.requestNotificationsPermission();
    }
  }

  Future<void> scheduleDailyReminder({int hour = 20, int minute = 0}) async {
    if (!_isInitialized) await initialize();

    // Configure details
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'daily_checkin_channel',
      'Daily Check-in Reminders',
      channelDescription: 'Gentle, comforting daily check-in reminders for your sanctuary.',
      importance: Importance.low,
      priority: Priority.low,
      playSound: true,
    );

    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const NotificationDetails platformDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    // Cancel existing reminder
    await _notificationsPlugin.cancel(42);

    // Schedule tz-aware notification
    final tz.TZDateTime scheduledTime = _nextInstanceOfTime(hour, minute);

    final List<String> gentlePrompts = [
      "Your garden is here. Care to share a quiet thought? 🌿",
      "Time for a cozy check-in with your sanctuary. 🍵",
      "How was your day? Settle down and write a little note. 🌸",
      "Take a deep breath. Let's water your botanical companion. 💧",
      "Unburden your mind before sleeping. 🛌",
    ];
    final String prompt = gentlePrompts[DateTime.now().millisecond % gentlePrompts.length];

    await _notificationsPlugin.zonedSchedule(
      42,
      'Botanical Sanctuary',
      prompt,
      scheduledTime,
      platformDetails,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time, // Repeats daily at this time!
    );
  }

  tz.TZDateTime _nextInstanceOfTime(int hour, int minute) {
    final tz.TZDateTime now = tz.TZDateTime.now(tz.local);
    tz.TZDateTime scheduledDate = tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }
    return scheduledDate;
  }
}
