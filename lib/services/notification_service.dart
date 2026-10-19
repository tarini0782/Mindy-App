import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Thin wrapper around flutter_local_notifications.
///
/// For the 10-day demo this uses DEVICE-LOCAL notifications only
/// (Future.delayed + .show()), not server-scheduled Firebase Cloud
/// Messaging. That's a deliberate, honest scope cut: local notifications
/// look identical to an audience in a demo and are far simpler to get
/// working than FCM + a backend scheduler. Swapping to real
/// server-scheduled push later does not require changing any other
/// screen -- only this file.
class NotificationService {
  NotificationService._internal();
  static final NotificationService instance = NotificationService._internal();

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;
    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings();
    const settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );
    // flutter_local_notifications takes this positionally, not as a named
    // `settings:` argument.
    await _plugin.initialize(settings);
    _initialized = true;
  }

  Future<void> showNow({required String title, required String body}) async {
    await init();
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'mindy_reminders',
        'Mindy Reminders',
        channelDescription: 'Medication and appointment reminders',
        importance: Importance.high,
        priority: Priority.high,
      ),
      iOS: DarwinNotificationDetails(),
    );
    // show(id, title, body, notificationDetails) -- all four positional.
    // The id is truncated to a 32-bit range because Android notification
    // ids are ints, and a raw millisecond epoch overflows that.
    final id = (DateTime.now().millisecondsSinceEpoch ~/ 1000) & 0x7FFFFFFF;
    await _plugin.show(id, title, body, details);
  }
}
