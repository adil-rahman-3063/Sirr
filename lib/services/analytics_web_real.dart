// ignore_for_file: uri_does_not_exist, avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:js_util' as js_util;
import 'package:flutter/foundation.dart';

void logWebAnalyticsEvent(String name, Map<String, dynamic> params) {
  try {
    if (js_util.hasProperty(js_util.globalThis, 'logAnalyticsEvent')) {
      js_util.callMethod(js_util.globalThis, 'logAnalyticsEvent', [name, js_util.jsify(params)]);
    }
  } catch (e) {
    debugPrint('[Analytics] Web dispatch error: $e');
  }
}
