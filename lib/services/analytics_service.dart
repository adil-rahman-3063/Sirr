import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sirr/config/app_info.dart';
import 'package:sirr/services/analytics_web.dart';

/// Centralized cross-platform Analytics Service supporting Google Analytics 4 (GA4).
/// Works on both Web (via gtag.js) and Mobile (via GA4 Measurement Protocol).
class AnalyticsService {
  static final AnalyticsService _instance = AnalyticsService._internal();
  factory AnalyticsService() => _instance;
  AnalyticsService._internal();

  String? _clientId;

  /// Initializes analytics client ID from local preferences.
  Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _clientId = prefs.getString('analytics_client_id');
      if (_clientId == null) {
        _clientId = 'sirr_${DateTime.now().millisecondsSinceEpoch}_${(1000 + (DateTime.now().microsecond % 9000))}';
        await prefs.setString('analytics_client_id', _clientId!);
      }
    } catch (e) {
      _clientId = 'anonymous_user';
    }
  }

  /// Logs a custom event to Google Analytics.
  Future<void> logEvent(String name, [Map<String, dynamic>? parameters]) async {
    final params = parameters != null ? Map<String, dynamic>.from(parameters) : <String, dynamic>{};
    params['platform'] = kIsWeb ? 'web' : defaultTargetPlatform.name;
    params['app_version'] = AppInfo.version;

    if (kDebugMode) {
      debugPrint('[Analytics] Event: $name, Params: $params');
    }

    // 1. Web Tracking via gtag.js
    if (kIsWeb) {
      logWebAnalyticsEvent(name, params);
      return;
    }

    // 2. Mobile Tracking via Google Analytics 4 Measurement Protocol
    final measurementId = AppInfo.googleAnalyticsMeasurementId;
    if (measurementId.isEmpty || measurementId.startsWith('G-XXXXX')) {
      // Measurement ID not yet provided - skip network call
      return;
    }

    try {
      if (_clientId == null) await init();

      final url = Uri.parse('https://www.google-analytics.com/mp/collect?measurement_id=$measurementId&api_secret=');
      final body = json.encode({
        'client_id': _clientId,
        'events': [
          {
            'name': name,
            'params': params,
          }
        ]
      });

      await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: body,
      ).timeout(const Duration(seconds: 4));
    } catch (e) {
      debugPrint('[Analytics] Dispatch failed: $e');
    }
  }

  /// Helper methods for key user journeys
  Future<void> logAppOpen() => logEvent('app_open');
  
  Future<void> logDateChanged(String date, int dayOffset) => logEvent('date_changed', {
    'target_date': date,
    'day_offset': dayOffset,
  });

  Future<void> logBackToToday() => logEvent('back_to_today_clicked');

  Future<void> logQiblaOpened() => logEvent('qibla_compass_opened');

  Future<void> logNotificationToggled(String prayerName, bool enabled) => logEvent('notification_toggle', {
    'prayer_name': prayerName,
    'enabled': enabled,
  });
}
