import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:sirr/models/prayer_time_model.dart';
import 'package:intl/intl.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:universal_html/html.dart' as html;

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
  bool _isInitialized = false;
  late SharedPreferences _prefs;

  // Track which prayers have notifications enabled. By default all are enabled.
  final Set<String> _enabledPrayers = {'Fajr', 'Sunrise', 'Dhuhr', 'Asr', 'Maghrib', 'Isha'};

  Future<void> init() async {
    if (_isInitialized) return;
    
    _prefs = await SharedPreferences.getInstance();
    _loadSettings();

    if (!kIsWeb) {
      tz.initializeTimeZones();

      const AndroidInitializationSettings initializationSettingsAndroid = AndroidInitializationSettings('@mipmap/ic_launcher');
      const DarwinInitializationSettings initializationSettingsIOS = DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
      );
      const InitializationSettings initializationSettings = InitializationSettings(
          android: initializationSettingsAndroid,
          iOS: initializationSettingsIOS);

      await _flutterLocalNotificationsPlugin.initialize(
        settings: initializationSettings,
      );
    }
    
    _isInitialized = true;
  }
  
  void _loadSettings() {
    final saved = _prefs.getStringList('enabledPrayers');
    if (saved != null) {
      _enabledPrayers.clear();
      _enabledPrayers.addAll(saved);
    }
  }

  bool isNotificationEnabled(String prayerName) {
    return _enabledPrayers.contains(prayerName);
  }

  Future<void> toggleNotification(String prayerName) async {
    if (_enabledPrayers.contains(prayerName)) {
      _enabledPrayers.remove(prayerName);
    } else {
      _enabledPrayers.add(prayerName);
    }
    await _prefs.setStringList('enabledPrayers', _enabledPrayers.toList());
  }

  Future<void> requestPermissions() async {
    if (kIsWeb) {
      if (html.Notification.permission != 'granted') {
        await html.Notification.requestPermission();
      }
      return;
    }
    
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      await _flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );
    } else if (defaultTargetPlatform == TargetPlatform.android) {
      final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
          _flutterLocalNotificationsPlugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      await androidImplementation?.requestNotificationsPermission();
      await androidImplementation?.requestExactAlarmsPermission();
    }
  }

  // Triggered manually in foreground for web (and potentially mobile if not scheduled)
  void triggerForegroundNotification(String title, String body) {
    if (kIsWeb) {
      if (html.Notification.permission == 'granted') {
        html.Notification(title, body: body, icon: 'icons/Icon-192.png');
      }
    }
  }

  Future<void> schedulePrayerNotifications(Map<String, PrayerTimings> cache) async {
    if (!_isInitialized || kIsWeb) return;
    
    await _flutterLocalNotificationsPlugin.cancelAll();
    
    int id = 0;
    
    for (var dateString in cache.keys) {
      final timings = cache[dateString]!;
      final prayers = [
        {'name': 'Fajr', 'start': timings.fajr, 'nextName': 'Sunrise', 'next': timings.sunrise},
        {'name': 'Dhuhr', 'start': timings.dhuhr, 'nextName': 'Asr', 'next': timings.asr},
        {'name': 'Asr', 'start': timings.asr, 'nextName': 'Maghrib', 'next': timings.maghrib},
        {'name': 'Maghrib', 'start': timings.maghrib, 'nextName': 'Isha', 'next': timings.isha},
      ];

      final date = DateFormat('yyyy-MM-dd').parse(dateString);

      for (var p in prayers) {
        final prayerName = p['name'] as String;
        if (!isNotificationEnabled(prayerName)) continue;

        final startTiming = p['start'] as Prayertime;
        final nextTiming = p['next'] as Prayertime;
        final startTime = startTiming.dateTime(date);
        final nextTime = nextTiming.dateTime(date);
        
        if (startTime.isAfter(DateTime.now())) {
           final diff = nextTime.difference(startTime);
           final hours = diff.inHours;
           final minutes = diff.inMinutes.remainder(60);
           
           String timeLeftStr = "";
           if (hours > 0) timeLeftStr += "$hours hours ";
           timeLeftStr += "$minutes minutes";

           String message = "Time for $prayerName! You have $timeLeftStr left until ${p['nextName']}.";

           await _scheduleNotification(id++, "Time to Pray $prayerName", message, startTime);
        }
      }
      
      if (isNotificationEnabled('Isha')) {
        final ishaStartTime = timings.isha.dateTime(date);
        if (ishaStartTime.isAfter(DateTime.now())) {
            await _scheduleNotification(id++, "Time to Pray Isha", "Time for Isha! Make sure to pray before Fajr tomorrow.", ishaStartTime);
        }
      }
    }
  }

  Future<void> _scheduleNotification(int id, String title, String body, DateTime scheduledTime) async {
    await _flutterLocalNotificationsPlugin.zonedSchedule(
        id: id,
        title: title,
        body: body,
        scheduledDate: tz.TZDateTime.from(scheduledTime, tz.local),
        notificationDetails: const NotificationDetails(
            android: AndroidNotificationDetails(
                'prayer_channel_id', 'Prayer Times',
                channelDescription: 'Notifications for daily prayer times',
                importance: Importance.max,
                priority: Priority.high,
                icon: '@mipmap/ic_launcher')),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle);
  }
}
