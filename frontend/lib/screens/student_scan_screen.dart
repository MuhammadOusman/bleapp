import 'dart:async';
import 'package:flutter/material.dart';
import '../services/ble_service.dart';
import '../services/api_service.dart';
import '../services/device_service.dart';
import '../services/permission_service.dart';

class StudentScanScreen extends StatefulWidget {
  final Map course;
  const StudentScanScreen({super.key, required this.course});

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

    _ble.startScan((sessionId) async {
      // Try to extract a UUID from possible manufacturer/service data
      final uuidRegex = RegExp(r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$');
      String? candidate = sessionId;

      if (!uuidRegex.hasMatch(sessionId)) {
        // remove any non-hex chars and try to build a UUID from first 32 hex chars
        final hexOnly = sessionId.replaceAll(RegExp(r'[^0-9a-fA-F]'), '');
        if (hexOnly.length >= 32) {
          final hexCandidate = hexOnly.substring(0, 32);
          final parsed = '${hexCandidate.substring(0,8)}-${hexCandidate.substring(8,12)}-${hexCandidate.substring(12,16)}-${hexCandidate.substring(16,20)}-${hexCandidate.substring(20,32)}';
          if (uuidRegex.hasMatch(parsed)) candidate = parsed;
        }
      }

      if (_found.isEmpty) {
        setState(() => _found = candidate ?? sessionId);
        if (candidate != null && uuidRegex.hasMatch(candidate)) {
          try {
            await _api.markAttendance(candidate, device);
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
        } else {
          // couldn't parse a UUID; show a warning so user knows parsing failed
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No valid session UUID found in advertisement')));
        }
      }
    });
    // stop after 20s by design
    Timer(const Duration(seconds: 20), () async {
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
      appBar: AppBar(title: Text('Scan (${widget.course['name'] ?? ''})')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Text('Found: $_found'),
            const SizedBox(height: 20),
            ElevatedButton(onPressed: _scanning ? null : _startScan, child: const Text('Scan for Session'))
          ],
        ),
      ),
    );
  }
}
