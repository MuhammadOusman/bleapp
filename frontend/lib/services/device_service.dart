import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';

class DeviceService {
  static final _plugin = DeviceInfoPlugin();

  static Future<String> getDeviceSignature() async {
    try {
      if (Platform.isAndroid) {
        final info = await _plugin.androidInfo;
        // Use the device id provided by the plugin
        return info.id;
      } else if (Platform.isIOS) {
        final info = await _plugin.iosInfo;
        return info.identifierForVendor ?? info.utsname.machine;
      }
    } catch (_) {}
    return 'unknown-device';
  }
}
