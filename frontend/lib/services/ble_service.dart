import 'dart:async';
import 'dart:convert';
import 'package:beacon_broadcast/beacon_broadcast.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:crypto/crypto.dart';

class BleService {
  final BeaconBroadcast _beacon = BeaconBroadcast();

  Future<bool> startBeacon(String sessionId) async {
    // Use sessionId as the UUID for the beacon (iBeacon formatted UUID expected)
    try {
      print('[Becon] starting beacon uuid=$sessionId');
      await _beacon
          .setUUID(sessionId)
          .setMajorId(1)
          .setMinorId(1)
          .setLayout('m:2-3=0215,i:4-19,i:20-21,i:22-23,p:24-24')
          .start();
      print('[Becon] started');
      return true;
    } catch (e) {
      print('[Becon] start failed: $e');
      return false;
    }
  }

  Future<void> stopBeacon() async {
    try {
      await _beacon.stop();
      print('[Becon] stopped');
    } catch (e) {
      print('[Becon] stop failed: $e');
    }
  }

  // Start a short-lived beacon that advertises the device signature (peer beacon)
  Future<bool> startPeerBeacon(String deviceSignature) async {
    final uuid = _uuidFromString(deviceSignature);
    try {
      print('[PeerBeacon] start peer uuid=$uuid');
      await _beacon
          .setUUID(uuid)
          .setMajorId(1)
          .setMinorId(1)
          .setLayout('m:2-3=0215,i:4-19,i:20-21,i:22-23,p:24-24')
          .start();
      print('[PeerBeacon] started');
      return true;
    } catch (e) {
      print('[PeerBeacon] start failed: $e');
      return false;
    }
  }

  Future<void> stopPeerBeacon() async {
    try {
      await _beacon.stop();
      print('[PeerBeacon] stopped');
    } catch (e) {
      print('[PeerBeacon] stop failed: $e');
    }
  }

  String _uuidFromString(String s) {
    // Deterministically derive a UUID-like string from the input using MD5
    final bytes = md5.convert(utf8.encode(s)).bytes;
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    // format 8-4-4-4-12
    return '${hex.substring(0,8)}-${hex.substring(8,12)}-${hex.substring(12,16)}-${hex.substring(16,20)}-${hex.substring(20,32)}';
  }
  /// Returns whether device supports BLE advertising (transmission)
  Future<bool> checkTransmissionSupport() async {
    try {
      final s = await _beacon.checkTransmissionSupported();
      // s is an enum like BeaconStatus.SUPPORTED — check by name
      return s.toString().toUpperCase().contains('SUPPORTED');
    } catch (_) {
      return false;
    }
  }

  StreamSubscription<List<ScanResult>>? _scanResultsSub;

  String? _parseIBeaconUuid(List<int> bytes) {
    // Search for iBeacon prefix 0x02 0x15 and extract the 16-byte UUID that follows
    try {
      for (var i = 0; i <= bytes.length - 18; i++) {
        if (bytes[i] == 0x02 && bytes[i + 1] == 0x15) {
          final uuidBytes = bytes.sublist(i + 2, i + 18);
          final hex = uuidBytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
          final uuid = '${hex.substring(0,8)}-${hex.substring(8,12)}-${hex.substring(12,16)}-${hex.substring(16,20)}-${hex.substring(20,32)}';
          return uuid;
        }
      }
    } catch (_) {}
    return null;
  }

  void startScan(void Function(String sessionId) onFound) {
    // Start platform scan and listen to aggregated scan results
    print('[Scan] startScan requested');
    FlutterBluePlus.startScan(timeout: const Duration(seconds: 20));

    _scanResultsSub = FlutterBluePlus.scanResults.listen((results) {
      for (var r in results) {
        final adv = r.advertisementData;
        final advName = adv.advName;
        final name = advName.isNotEmpty ? advName : r.device.platformName;
        print('[Scan] device=${r.device.id} rssi=${r.rssi} name=$name advName=$advName');

        // Prefer manufacturer data if available (iBeacon detection)
        try {
          final m = adv.manufacturerData;
          if (m.isNotEmpty) {
            for (var entry in m.entries) {
              final id = entry.key;
              final bytes = entry.value;
              final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
              final sigRaw = '${id.toRadixString(16)}:$hex';
              print('[Scan] found manufacturer raw=$sigRaw from ${r.device.id}');

              final parsed = _parseIBeaconUuid(bytes);
              if (parsed != null) {
                print('[Scan] parsed iBeacon UUID=$parsed');
                onFound(parsed);
              } else {
                // fallback to raw manufacturer string if parsing didn't find iBeacon
                onFound(sigRaw);
              }
            }
            continue;
          }
        } catch (e) {
          print('[Scan] manufacturer parse error: $e');
        }

        // service UUIDs (prefer full UUIDs)
        try {
          if (adv.serviceUuids.isNotEmpty) {
            for (var su in adv.serviceUuids) {
              final s = su.toString();
              print('[Scan] found service uuid=$s from ${r.device.id}');
              if (s.length >= 36) {
                // likely a full UUID
                onFound(s);
                continue;
              }
            }
          }
        } catch (e) {
          print('[Scan] serviceUuids parse error: $e');
        }

        // fallback to name (if looks like UUID)
        final uuidRegex = RegExp(r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$');
        if (advName.isNotEmpty && uuidRegex.hasMatch(advName)) {
          print('[Scan] advName looks like UUID: $advName');
          onFound(advName);
          continue;
        }

        // final fallback to name
        if (name.isNotEmpty) {
          print('[Scan] fallback name found: $name');
          onFound(name);
        }
      }
    });
  }

  void stopScan() {
    FlutterBluePlus.stopScan();
    _scanResultsSub?.cancel();
    _scanResultsSub = null;
  }
}
