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
