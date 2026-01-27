import 'dart:io';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:device_info_plus/device_info_plus.dart';

class DeviceService {
  static final _plugin = DeviceInfoPlugin();

  static Future<String> getDeviceSignature() async {
    String rawId = 'unknown-device';
    try {
      if (Platform.isAndroid) {
        final info = await _plugin.androidInfo;
        rawId = info.id;
      } else if (Platform.isIOS) {
        final info = await _plugin.iosInfo;
        rawId = info.identifierForVendor ?? info.utsname.machine;
      }
    } catch (_) {}

    return _uuidFromString(rawId);
  }

  static String _uuidFromString(String s) {
    // Deterministically derive a UUID-like string from the input using MD5
    final bytes = md5.convert(utf8.encode(s)).bytes;
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    // format 8-4-4-4-12
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20, 32)}';
  }
}
