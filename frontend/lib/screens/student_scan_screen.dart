import 'dart:async';
import 'package:flutter/material.dart';
import '../services/ble_service.dart';
import '../services/api_service.dart';
import '../services/device_service.dart';
import '../services/permission_service.dart';

class StudentScanScreen extends StatefulWidget {
  final String sessionId;
  const StudentScanScreen({super.key, required this.sessionId});

  @override
  State<StudentScanScreen> createState() => _StudentScanScreenState();
}

class _StudentScanScreenState extends State<StudentScanScreen> {
  final _ble = BleService();
  final _api = ApiService();
  String _found = '';
  bool _scanning = false;

  void _startScan() async {
    setState(() {
      _scanning = true;
      _found = '';
    });

    final allowed = await PermissionService.requestBlePermissions();
    if (!allowed) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Bluetooth/Location permissions are required')));
      await PermissionService.openAppSettingsIfNeeded();
      setState(() => _scanning = false);
      return;
    }

    // Start advertising the student's own signature briefly so teachers can detect it
    final device = await DeviceService.getDeviceSignature();
    try {
      await _ble.startPeerBeacon(device);
    } catch (_) {}

    _ble.startScan((uuid, minor) async {
      // Filter for Teacher broadcasts only
      if (minor != BleService.kTeacherMinorId) return;

      if (_found.isEmpty) {
        setState(() => _found = uuid);
        try {
          // Use the provided session id directly (no backend resolution)
          await _api.markAttendance(widget.sessionId, device);
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Marked present')));
        } on ApiException catch (e) {
          final msg = e.statusCode == 410
              ? 'Too late! Session expired.'
              : e.statusCode == 403
                  ? 'Account locked to another device.'
                  : e.toString();
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
        } catch (e) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e')));
        }
      }
    });
    // stop after 30s by design
    Timer(const Duration(seconds: 30), () async {
      _ble.stopScan();
      try {
        await _ble.stopPeerBeacon();
      } catch (_) {}
      setState(() => _scanning = false);
    });
  }

  @override
  void dispose() {
    _ble.stopScan();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Scan Session ${widget.sessionId.substring(0, 8)}'),
        automaticallyImplyLeading: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Text(_found.isEmpty ? 'Not yet scanned' : 'Found: $_found'),
            const SizedBox(height: 20),
            ElevatedButton(onPressed: _scanning ? null : _startScan, child: Text(_scanning ? 'Scanning...' : 'Scan for Session'))
          ],
        ),
      ),
    );
  }
}