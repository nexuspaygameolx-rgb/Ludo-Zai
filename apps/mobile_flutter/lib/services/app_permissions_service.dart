import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';

/// Automatically requests all required Android runtime permissions on app startup
/// (Microphone, Nearby Wi-Fi Devices, Bluetooth Scan/Advertise/Connect, Location, Notifications)
/// so the Codemagic-built APK works out-of-the-box for Offline P2P, Voice Chat & Alerts.
class AppPermissionsService {
  static bool _requestedOnLaunch = false;

  static List<Permission> get allRequiredPermissions => const [
        Permission.microphone,
        Permission.nearbyWifiDevices,
        Permission.bluetoothScan,
        Permission.bluetoothAdvertise,
        Permission.bluetoothConnect,
        Permission.locationWhenInUse,
        Permission.notification,
      ];

  /// Called once automatically right after the first Flutter frame renders.
  static Future<Map<Permission, PermissionStatus>> requestAllStartupPermissions() async {
    if (kIsWeb || _requestedOnLaunch) return {};
    _requestedOnLaunch = true;
    try {
      return await allRequiredPermissions.request();
    } catch (e) {
      debugPrint('Permission request skipped/error: $e');
      return {};
    }
  }

  /// Ensures Offline P2P + Mic permissions are granted before hosting/joining a nearby room.
  static Future<bool> ensureOfflineP2PPermissions() async {
    if (kIsWeb) return true;
    try {
      final statuses = await [
        Permission.nearbyWifiDevices,
        Permission.bluetoothScan,
        Permission.bluetoothAdvertise,
        Permission.bluetoothConnect,
        Permission.locationWhenInUse,
        Permission.microphone,
      ].request();

      final anyPermanentlyDenied = statuses.values.any((s) => s.isPermanentlyDenied);
      if (anyPermanentlyDenied) {
        await openAppSettings();
        return false;
      }
      return true;
    } catch (_) {
      return true;
    }
  }
}
