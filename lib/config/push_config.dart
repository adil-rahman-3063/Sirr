/// Configuration for Cloudflare Worker Anonymous Push Notifications
class PushConfig {
  /// Base URL of your deployed Cloudflare Worker
  static const String workerApiUrl = 'https://sirr-notifications.adilrahman3063.workers.dev';

  /// VAPID Public Key generated for Web Push notifications
  static const String vapidPublicKey =
      'BJBckAgVOJ0kC2ri3PdbHqhzRfc2DFMBoqJRG_oEji7RYElJaU5r4y7TK2d64_SHTTBmXVMftw3w-xIMsSGYgTM';
}
