// ignore_for_file: uri_does_not_exist, avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:js' as js;
import 'dart:js_util' as js_util;

Future<bool> requestWebOrientationPermission() async {
  try {
    final hasRequestPermission = js.context.hasProperty('requestDeviceOrientation');
    if (hasRequestPermission) {
      final dynamic resultPromise = js.context.callMethod('requestDeviceOrientation');
      final bool isGranted = await js_util.promiseToFuture(resultPromise);
      return isGranted;
    }
  } catch (e) {
    // Suppress error
  }
  return true;
}

Future<bool> requestWebNotificationPermission() async {
  try {
    final hasRequest = js.context.hasProperty('requestWebNotificationPermission');
    if (hasRequest) {
      final dynamic resultPromise = js.context.callMethod('requestWebNotificationPermission');
      final bool isGranted = await js_util.promiseToFuture(resultPromise);
      return isGranted;
    }
  } catch (e) {
    // Suppress error
  }
  return false;
}

Future<bool> showWebNotification(String title, String body, [String? icon]) async {
  try {
    final hasShow = js.context.hasProperty('showWebNotification');
    if (hasShow) {
      final dynamic resultPromise = js.context.callMethod('showWebNotification', [title, body, icon ?? 'icons/Icon-192.png']);
      final bool result = await js_util.promiseToFuture(resultPromise);
      return result;
    }
  } catch (e) {
    // Suppress error
  }
  return false;
}

double? getWebCompassHeading() {
  try {
    final hasFn = js.context.hasProperty('getDeviceCompassHeading');
    if (hasFn) {
      final dynamic val = js.context.callMethod('getDeviceCompassHeading');
      if (val != null) {
        return (val as num).toDouble();
      }
    }
  } catch (e) {
    // Suppress error
  }
  return null;
}
