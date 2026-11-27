import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Bridges Flutter with Android's native LudoKeepAliveService so that
/// minimizing the app keeps the match, timers, AI Buddy, and P2P/Online links alive
/// until the user explicitly removes the app from Recent Apps.
class BackgroundKeepAliveService {
  static const MethodChannel _channel = MethodChannel('com.ludozai.ludo_zai/keep_alive');
  static bool _isRunning = false;

  static bool get isRunning => _isRunning;

  static Future<void> startKeepAlive({
    String title = 'Ludo-Z! Game Background Mein Chal Raha Hai',
    String body = 'App minimize hai — match jari hai. Wapas aane ke liye tap karein.',
  }) async {
    if (kIsWeb) return;
    try {
      await _channel.invokeMethod('startKeepAlive', {
        'title': title,
        'body': body,
      });
      _isRunning = true;
    } catch (e) {
      debugPrint('startKeepAlive skipped: $e');
    }
  }

  static Future<void> stopKeepAlive() async {
    if (kIsWeb) return;
    try {
      await _channel.invokeMethod('stopKeepAlive');
      _isRunning = false;
    } catch (e) {
      debugPrint('stopKeepAlive skipped: $e');
    }
  }

  /// Minimizes the app to background instead of killing it when Back is pressed on Lobby.
  static Future<void> minimizeToBackground() async {
    if (kIsWeb) return;
    try {
      await startKeepAlive();
      await _channel.invokeMethod('moveToBackground');
    } catch (e) {
      debugPrint('minimizeToBackground skipped: $e');
    }
  }

  /// Asks Android not to kill Ludo-Z! under aggressive battery saver while minimized.
  static Future<void> requestBatteryOptimizationExemption() async {
    if (kIsWeb) return;
    try {
      await _channel.invokeMethod('requestIgnoreBatteryOptimizations');
    } catch (e) {
      debugPrint('Battery exemption skipped: $e');
    }
  }
}
