import 'dart:async';
import 'dart:convert';
import 'package:beacon_broadcast/beacon_broadcast.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:crypto/crypto.dart';

class BleService {
  final BeaconBroadcast _beacon = BeaconBroadcast();

  // Strict filtering constants
  static const int kAppMajorId = 54529; // 0xD501
  static const int kTeacherMinorId = 1;
  static const int kStudentMinorId = 2;

  Future<bool> startBeacon(String sessionId) async {
    // Teacher beacon: uuid = sessionId, major = kAppMajorId, minor = kTeacherMinorId
    try {
      print('[Beacon] starting teacher beacon uuid=$sessionId major=$kAppMajorId minor=$kTeacherMinorId');
      await _beacon
          .setUUID(sessionId)
          .setMajorId(kAppMajorId)
          .setMinorId(kTeacherMinorId)
          .setLayout('m:2-3=0215,i:4-19,i:20-21,i:22-23,p:24-24')
          .start();
      print('[Beacon] started');
      return true;
    } catch (e) {
      print('[Beacon] start failed: $e');
      return false;
    }
  }

  Future<void> stopBeacon() async {
    try {
      await _beacon.stop();
      print('[Beacon] stopped');
    } catch (e) {
      print('[Beacon] stop failed: $e');
    }
  }

  // Start a short-lived beacon that advertises the device signature (peer beacon)
  Future<bool> startPeerBeacon(String deviceSignature) async {
    // Student beacon: uuid = deviceSignature, major = kAppMajorId, minor = kStudentMinorId
    try {
      print('[PeerBeacon] start student uuid=$deviceSignature major=$kAppMajorId minor=$kStudentMinorId');
      await _beacon
          .setUUID(deviceSignature)
          .setMajorId(kAppMajorId)
          .setMinorId(kStudentMinorId)
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

  Map<String, dynamic>? _parseIBeacon(List<int> bytes) {
    // Search for iBeacon prefix 0x02 0x15 and extract 16-byte UUID, 2-byte Major, 2-byte Minor
    try {
      for (var i = 0; i <= bytes.length - 23; i++) {
        if (bytes[i] == 0x02 && bytes[i + 1] == 0x15) {
          final uuidBytes = bytes.sublist(i + 2, i + 18);
          final majorBytes = bytes.sublist(i + 18, i + 20);
          final minorBytes = bytes.sublist(i + 20, i + 22);

          final hex = uuidBytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
          final uuid = '${hex.substring(0,8)}-${hex.substring(8,12)}-${hex.substring(12,16)}-${hex.substring(16,20)}-${hex.substring(20,32)}';

          final major = (majorBytes[0] << 8) | majorBytes[1];
          final minor = (minorBytes[0] << 8) | minorBytes[1];

          return {'uuid': uuid, 'major': major, 'minor': minor};
        }
      }
    } catch (_) {}
    return null;
  }

  void startScan(void Function(String uuid, int minor) onFound) {
    // Start platform scan and listen to aggregated scan results
    print('[Scan] startScan requested');
    FlutterBluePlus.startScan(timeout: const Duration(seconds: 20));

    _scanResultsSub = FlutterBluePlus.scanResults.listen((results) {
      for (var r in results) {
        final adv = r.advertisementData;

        // Strict filtering: Only process iBeacon data that matches our App Major ID
        try {
          final m = adv.manufacturerData;
          if (m.isNotEmpty) {
            for (var entry in m.entries) {
              final bytes = entry.value;
              final parsed = _parseIBeacon(bytes);

              if (parsed != null && parsed['major'] == kAppMajorId) {
                print('[Scan] MATCH! uuid=${parsed['uuid']} minor=${parsed['minor']} rssi=${r.rssi}');
                onFound(parsed['uuid'], parsed['minor']);
              }
            }
          }
        } catch (e) {
          print('[Scan] parse error: $e');
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
