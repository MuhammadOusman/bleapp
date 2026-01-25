import 'dart:async';
import 'package:beacon_broadcast/beacon_broadcast.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

class BleService {
  final BeaconBroadcast _beacon = BeaconBroadcast();

  Future<void> startBeacon(String sessionId) async {
    // Use sessionId as the UUID for the beacon (iBeacon formatted UUID expected)
    await _beacon
        .setUUID(sessionId)
        .setMajorId(1)
        .setMinorId(1)
        .setLayout('m:2-3=0215,i:4-19,i:20-21,i:22-23,p:24-24')
        .start();
  }

  Future<void> stopBeacon() async {
    await _beacon.stop();
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

  void startScan(void Function(String sessionId) onFound) {
    // Start platform scan and listen to aggregated scan results
    FlutterBluePlus.startScan(timeout: const Duration(seconds: 20));

    _scanResultsSub = FlutterBluePlus.scanResults.listen((results) {
      for (var r in results) {
        final adv = r.advertisementData;
        final advName = adv.advName;
        final name = advName.isNotEmpty ? advName : r.device.platformName;

        // Prefer manufacturer data if available
        try {
          final m = adv.manufacturerData;
          if (m.isNotEmpty) {
            for (var entry in m.entries) {
              final id = entry.key;
              final bytes = entry.value;
              final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
              final sig = '${id.toRadixString(16)}:$hex';
              onFound(sig);
            }
            continue;
          }
        } catch (_) {}

        // service UUIDs
        try {
          if (adv.serviceUuids.isNotEmpty) {
            for (var su in adv.serviceUuids) {
              final s = su.toString();
              if (s.isNotEmpty) onFound(s);
            }
            continue;
          }
        } catch (_) {}

        // fallback to name
        if (name.isNotEmpty) onFound(name);
      }
    });
  }

  void stopScan() {
    FlutterBluePlus.stopScan();
    _scanResultsSub?.cancel();
    _scanResultsSub = null;
  }
}
