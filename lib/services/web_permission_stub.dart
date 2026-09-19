Future<bool> requestWebOrientationPermission() async {
  return true;
}

Future<bool> requestWebNotificationPermission() async {
  return true;
}

Future<String> getWebNotificationPermissionState() async {
  return 'granted';
}

Future<bool> showWebNotification(String title, String body, [String? icon]) async {
  return true;
}

double? getWebCompassHeading() {
  return null;
}

String getDeviceIanaTimezone() {
  return 'UTC';
}

Future<String?> subscribeWebPush(String vapidPublicKey) async {
  return null;
}

Future<String?> getWebPushSubscription() async {
  return null;
}

Future<bool> unsubscribeWebPush() async {
  return true;
}
