import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';

class PermissionService {
  static final _deviceInfo = DeviceInfoPlugin();

  /// Returns true if all required permissions are granted
  static Future<bool> requestBlePermissions() async {
    if (!Platform.isAndroid) return true;
    final info = await _deviceInfo.androidInfo;
    final sdk = info.version.sdkInt;

    if (sdk >= 31) {
      final statuses = await [
        Permission.bluetoothScan,
        Permission.bluetoothAdvertise,
        Permission.bluetoothConnect,
      ].request();

      return statuses.values.every((s) => s.isGranted);
    } else {
      // older devices require location for scanning
      final status = await Permission.locationWhenInUse.request();
      return status.isGranted;
    }
  }

  /// Helper to open app settings when permissions are permanently denied
  static Future<void> openAppSettingsIfNeeded() async {
    if (await Permission.location.isPermanentlyDenied ||
        await Permission.bluetoothScan.isPermanentlyDenied ||
        await Permission.bluetoothAdvertise.isPermanentlyDenied ||
        await Permission.bluetoothConnect.isPermanentlyDenied) {
      openAppSettings();
    }
  }
}
