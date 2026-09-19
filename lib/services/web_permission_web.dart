// ignore_for_file: uri_does_not_exist, avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:js_util' as js_util;
import 'package:flutter/foundation.dart';

Future<bool> requestWebOrientationPermission() async {
  try {
    if (js_util.hasProperty(js_util.globalThis, 'requestDeviceOrientation')) {
      final dynamic resultPromise = js_util.callMethod(js_util.globalThis, 'requestDeviceOrientation', []);
      final bool isGranted = await js_util.promiseToFuture(resultPromise);
      return isGranted;
    }
  } catch (e) {
    debugPrint('[web_permission] requestWebOrientationPermission error: $e');
  }
  return true;
}

Future<bool> requestWebNotificationPermission() async {
  try {
    if (js_util.hasProperty(js_util.globalThis, 'requestWebNotificationPermission')) {
      final dynamic resultPromise = js_util.callMethod(js_util.globalThis, 'requestWebNotificationPermission', []);
      final bool isGranted = await js_util.promiseToFuture(resultPromise);
      return isGranted;
    }
  } catch (e) {
    debugPrint('[web_permission] requestWebNotificationPermission error: $e');
  }
  return false;
}

Future<String> getWebNotificationPermissionState() async {
  try {
    if (js_util.hasProperty(js_util.globalThis, 'getNotificationPermissionState')) {
      final dynamic result = js_util.callMethod(js_util.globalThis, 'getNotificationPermissionState', []);
      if (result != null) {
        return result.toString();
      }
    }
  } catch (e) {
    debugPrint('[web_permission] getWebNotificationPermissionState error: $e');
  }
  return 'default';
}

Future<bool> showWebNotification(String title, String body, [String? icon]) async {
  try {
    if (js_util.hasProperty(js_util.globalThis, 'showWebNotification')) {
      final dynamic resultPromise = js_util.callMethod(
        js_util.globalThis,
        'showWebNotification',
        [title, body, icon ?? 'icons/Icon-192.png'],
      );
      final bool result = await js_util.promiseToFuture(resultPromise);
      return result;
    }
  } catch (e) {
    debugPrint('[web_permission] showWebNotification error: $e');
  }
  return false;
}

double? getWebCompassHeading() {
  try {
    if (js_util.hasProperty(js_util.globalThis, 'getDeviceCompassHeading')) {
      final dynamic val = js_util.callMethod(js_util.globalThis, 'getDeviceCompassHeading', []);
      if (val != null) {
        return (val as num).toDouble();
      }
    }
  } catch (e) {
    debugPrint('[web_permission] getWebCompassHeading error: $e');
  }
  return null;
}

/// Request Web Push subscription with VAPID Public Key
Future<String?> subscribeWebPush(String vapidPublicKey) async {
  try {
    if (js_util.hasProperty(js_util.globalThis, 'subscribeWebPush')) {
      final dynamic resultPromise = js_util.callMethod(js_util.globalThis, 'subscribeWebPush', [vapidPublicKey]);
      final dynamic result = await js_util.promiseToFuture(resultPromise);
      if (result != null) {
        debugPrint('[web_permission] subscribeWebPush: success');
        return result.toString();
      }
    }
  } catch (e, stack) {
    debugPrint('[web_permission] Error in subscribeWebPush: $e\n$stack');
  }
  return null;
}

/// Retrieve existing Web Push subscription JSON
Future<String?> getWebPushSubscription() async {
  try {
    if (js_util.hasProperty(js_util.globalThis, 'getWebPushSubscription')) {
      final dynamic resultPromise = js_util.callMethod(js_util.globalThis, 'getWebPushSubscription', []);
      final dynamic result = await js_util.promiseToFuture(resultPromise);
      if (result != null) {
        return result.toString();
      }
    }
  } catch (e, stack) {
    debugPrint('[web_permission] Error in getWebPushSubscription: $e\n$stack');
  }
  return null;
}

/// Unsubscribe from Web Push
Future<bool> unsubscribeWebPush() async {
  try {
    if (js_util.hasProperty(js_util.globalThis, 'unsubscribeWebPush')) {
      final dynamic resultPromise = js_util.callMethod(js_util.globalThis, 'unsubscribeWebPush', []);
      final bool result = await js_util.promiseToFuture(resultPromise);
      return result;
    }
  } catch (e) {
    debugPrint('[web_permission] Error in unsubscribeWebPush: $e');
  }
  return true;
}
