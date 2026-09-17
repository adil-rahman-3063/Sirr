import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:sirr/models/prayer_time_model.dart';
import 'package:intl/intl.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sirr/services/web_permission.dart';
import 'package:sirr/services/cloud_push_service.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
  bool _isInitialized = false;
  late SharedPreferences _prefs;
  Map<String, PrayerTimings>? _lastCache;

  // Track which prayers have notifications enabled. By default all are disabled.
  final Set<String> _enabledPrayers = {};

  // Cached location parameters for Web Push background sync
  double? _lastLat;
  double? _lastLng;
  String? _lastTimezone;
  String? _lastCity;
  int _lastMethod = 3;

  Set<String> get enabledPrayers => Set.unmodifiable(_enabledPrayers);

  Future<void> init() async {
    if (_isInitialized) return;

    _prefs = await SharedPreferences.getInstance();
    _loadSettings();

    if (!kIsWeb) {
      tz.initializeTimeZones();
      try {
        final now = DateTime.now();
        for (final loc in tz.timeZoneDatabase.locations.values) {
          if (loc.currentTimeZone.offset == now.timeZoneOffset) {
            tz.setLocalLocation(loc);
            break;
          }
        }
      } catch (e) {
        debugPrint("Timezone configuration error: $e");
      }

      const AndroidInitializationSettings initializationSettingsAndroid = AndroidInitializationSettings('@mipmap/ic_launcher');
      const DarwinInitializationSettings initializationSettingsIOS = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );
      const InitializationSettings initializationSettings = InitializationSettings(
        android: initializationSettingsAndroid,
        iOS: initializationSettingsIOS,
      );

      await _flutterLocalNotificationsPlugin.initialize(
        settings: initializationSettings,
      );

      final androidImplementation = _flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      if (androidImplementation != null) {
        await androidImplementation.createNotificationChannel(
          const AndroidNotificationChannel(
            'prayer_channel_id',
            'Prayer Times',
            description: 'Notifications for daily prayer times',
            importance: Importance.max,
            playSound: true,
            enableVibration: true,
          ),
        );
      }
    }

    _isInitialized = true;
  }

  static const String _kNotificationMigrationKey = 'push_v2_reset_migration';

  void _loadSettings() {
    final hasMigrated = _prefs.getBool(_kNotificationMigrationKey) ?? false;
    if (!hasMigrated && kIsWeb) {
      // Force clear all previous notification toggles for web visitors
      _prefs.remove('enabledPrayers');
      _prefs.remove('last_push_endpoint');
      _enabledPrayers.clear();
      _prefs.setBool(_kNotificationMigrationKey, true);
    } else {
      final saved = _prefs.getStringList('enabledPrayers');
      if (saved != null) {
        _enabledPrayers.clear();
        _enabledPrayers.addAll(saved);
      }
    }

    _lastLat = _prefs.getDouble('last_known_lat');
    _lastLng = _prefs.getDouble('last_known_lng');
    _lastCity = _prefs.getString('last_known_city');
    _lastTimezone = _prefs.getString('last_known_timezone') ?? DateTime.now().timeZoneName;
    _lastMethod = _prefs.getInt('last_known_method') ?? 3;
  }

  bool isNotificationEnabled(String prayerName) {
    return _enabledPrayers.contains(prayerName);
  }

  /// Update active location and metadata for push delivery
  void updateLocationContext({
    required double lat,
    required double lng,
    String? timezone,
    String? city,
    int method = 3,
  }) {
    _lastLat = lat;
    _lastLng = lng;
    _lastTimezone = timezone ?? DateTime.now().timeZoneName;
    _lastCity = city;
    _lastMethod = method;

    _prefs.setDouble('last_known_lat', lat);
    _prefs.setDouble('last_known_lng', lng);
    _prefs.setInt('last_known_method', method);
    if (city != null) _prefs.setString('last_known_city', city);
    if (_lastTimezone != null) _prefs.setString('last_known_timezone', _lastTimezone!);

    // If web and user already has notifications enabled, sync location updates to Cloudflare Worker
    if (kIsWeb && _enabledPrayers.isNotEmpty) {
      CloudPushService().syncSubscription(
        lat: lat,
        lng: lng,
        timezone: _lastTimezone!,
        city: city,
        method: method,
        enabledPrayers: _enabledPrayers,
      );
    }
  }

  Future<void> toggleNotification(
    String prayerName, {
    double? lat,
    double? lng,
    String? timezone,
    String? city,
    int? method,
  }) async {
    final activeLat = lat ?? _lastLat ?? 21.4225;
    final activeLng = lng ?? _lastLng ?? 39.8262;
    _lastLat = activeLat;
    _lastLng = activeLng;
    if (timezone != null) _lastTimezone = timezone;
    if (city != null) _lastCity = city;
    if (method != null) _lastMethod = method;

    if (_enabledPrayers.contains(prayerName)) {
      _enabledPrayers.remove(prayerName);
    } else {
      _enabledPrayers.add(prayerName);
      await requestPermissions();
    }
    await _prefs.setStringList('enabledPrayers', _enabledPrayers.toList());

    // Sync with Cloudflare Worker for background Web Push
    if (kIsWeb) {
      await CloudPushService().syncSubscription(
        lat: _lastLat!,
        lng: _lastLng!,
        timezone: _lastTimezone ?? DateTime.now().timeZoneName,
        city: _lastCity,
        method: _lastMethod,
        enabledPrayers: _enabledPrayers,
      );
    }

    // Native mobile notifications scheduling
    if (!kIsWeb && _lastCache != null) {
      await schedulePrayerNotifications(_lastCache!);
    }
  }

  Future<bool> enableAllPrayers({
    double? lat,
    double? lng,
    String? timezone,
    String? city,
    int? method,
  }) async {
    final activeLat = lat ?? _lastLat ?? 21.4225;
    final activeLng = lng ?? _lastLng ?? 39.8262;
    _lastLat = activeLat;
    _lastLng = activeLng;
    if (timezone != null) _lastTimezone = timezone;
    if (city != null) _lastCity = city;
    if (method != null) _lastMethod = method;

    _enabledPrayers.addAll(['Fajr', 'Dhuhr', 'Asr', 'Maghrib', 'Isha']);
    await _prefs.setStringList('enabledPrayers', _enabledPrayers.toList());
    await requestPermissions();

    if (kIsWeb) {
      final synced = await CloudPushService().syncSubscription(
        lat: _lastLat!,
        lng: _lastLng!,
        timezone: _lastTimezone ?? DateTime.now().timeZoneName,
        city: _lastCity,
        method: _lastMethod,
        enabledPrayers: _enabledPrayers,
      );
      if (synced) {
        await CloudPushService().sendTestPush();
      }
      return synced;
    }

    if (!kIsWeb && _lastCache != null) {
      await schedulePrayerNotifications(_lastCache!);
    }
    return true;
  }

  Future<void> requestPermissions() async {
    if (kIsWeb) {
      await requestWebNotificationPermission();
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

  // Triggered manually in foreground for web
  void triggerForegroundNotification(String title, String body) {
    if (kIsWeb) {
      showWebNotification(title, body, 'icons/Icon-192.png');
    }
  }

  Future<void> schedulePrayerNotifications(Map<String, PrayerTimings> cache) async {
    _lastCache = cache;
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
          await _scheduleNotification(
            id++,
            "Time to Pray Isha",
            "Time for Isha! Make sure to pray before Fajr tomorrow.",
            ishaStartTime,
          );
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
          'prayer_channel_id',
          'Prayer Times',
          channelDescription: 'Notifications for daily prayer times',
          importance: Importance.max,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
          playSound: true,
          enableVibration: true,
          visibility: NotificationVisibility.public,
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
          sound: 'default',
          interruptionLevel: InterruptionLevel.timeSensitive,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    );
  }
}
