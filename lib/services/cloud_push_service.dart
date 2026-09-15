import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/push_config.dart';
import 'web_permission.dart';

class CloudPushService {
  static final CloudPushService _instance = CloudPushService._internal();
  factory CloudPushService() => _instance;
  CloudPushService._internal();

  /// Sync user preferences and location with Cloudflare Worker
  Future<bool> syncSubscription({
    required double lat,
    required double lng,
    required String timezone,
    String? city,
    int method = 3,
    required Set<String> enabledPrayers,
  }) async {
    if (!kIsWeb) return true;

    try {
      // 1. Get or generate Web Push subscription
      String? rawSubscription = await getWebPushSubscription();
      rawSubscription ??= await subscribeWebPush(PushConfig.vapidPublicKey);

      if (rawSubscription == null) {
        debugPrint('[CloudPushService] No web push subscription available (permission denied or unsupported)');
        return false;
      }

      final Map<String, dynamic> subData = json.decode(rawSubscription);
      final String? endpoint = subData['endpoint'];
      final dynamic keys = subData['keys'];

      if (endpoint == null || keys == null) {
        debugPrint('[CloudPushService] Invalid subscription data format');
        return false;
      }

      // If all prayers are disabled, unsubscribe from backend
      if (enabledPrayers.isEmpty) {
        await unsubscribe();
        return true;
      }

      // 2. Build payload for Cloudflare Worker
      final Map<String, dynamic> payload = {
        'endpoint': endpoint,
        'keys': keys,
        'lat': lat,
        'lng': lng,
        'timezone': timezone,
        'city': city ?? '',
        'method': method,
        'fajr': enabledPrayers.contains('Fajr') ? 1 : 0,
        'dhuhr': enabledPrayers.contains('Dhuhr') ? 1 : 0,
        'asr': enabledPrayers.contains('Asr') ? 1 : 0,
        'maghrib': enabledPrayers.contains('Maghrib') ? 1 : 0,
        'isha': enabledPrayers.contains('Isha') ? 1 : 0,
      };

      final response = await http.post(
        Uri.parse('${PushConfig.workerApiUrl}/api/subscribe'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(payload),
      );

      if (response.statusCode == 200) {
        debugPrint('[CloudPushService] Successfully synced push subscription with Cloudflare Worker');
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('last_push_endpoint', endpoint);
        return true;
      } else {
        debugPrint('[CloudPushService] Error syncing subscription: ${response.statusCode} ${response.body}');
        return false;
      }
    } catch (e) {
      debugPrint('[CloudPushService] Exception while syncing push subscription: $e');
      return false;
    }
  }

  /// Send an immediate test notification to verify push delivery to this device
  Future<bool> sendTestPush() async {
    if (!kIsWeb) return false;
    try {
      String? rawSubscription = await getWebPushSubscription();
      rawSubscription ??= await subscribeWebPush(PushConfig.vapidPublicKey);
      if (rawSubscription == null) return false;

      final Map<String, dynamic> subData = json.decode(rawSubscription);
      final String? endpoint = subData['endpoint'];
      final dynamic keys = subData['keys'];

      if (endpoint == null || keys == null) return false;

      final response = await http.post(
        Uri.parse('${PushConfig.workerApiUrl}/api/test-push'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'endpoint': endpoint,
          'keys': keys,
          'title': 'سِرّ • اختبار الإشعارات',
          'body': 'Push notifications are successfully active for Sirr Prayer Times!',
        }),
      );

      return response.statusCode == 200;
    } catch (e) {
      debugPrint('[CloudPushService] Test push error: $e');
      return false;
    }
  }

  /// Unsubscribe from Cloudflare backend and browser push manager
  Future<void> unsubscribe() async {
    if (!kIsWeb) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final endpoint = prefs.getString('last_push_endpoint');

      if (endpoint != null) {
        await http.post(
          Uri.parse('${PushConfig.workerApiUrl}/api/unsubscribe'),
          headers: {'Content-Type': 'application/json'},
          body: json.encode({'endpoint': endpoint}),
        );
        await prefs.remove('last_push_endpoint');
      }

      await unsubscribeWebPush();
      debugPrint('[CloudPushService] Unsubscribed from Web Push');
    } catch (e) {
      debugPrint('[CloudPushService] Error during unsubscribe: $e');
    }
  }
}
