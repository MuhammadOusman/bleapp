import 'dart:async';
import 'package:flutter/material.dart';
import '../services/ble_service.dart';
import 'student_scan_screen.dart';

class StudentSessionScanner extends StatefulWidget {
  const StudentSessionScanner({super.key});

  @override
  State<StudentSessionScanner> createState() => _StudentSessionScannerState();
}

class _StudentSessionScannerState extends State<StudentSessionScanner> {
  final _ble = BleService();
  bool _scanning = false;
  bool _opened = false;
  final Map<String, Map<String, dynamic>> _found = {}; // sessionId -> data
  StreamSubscription? _sub;

  void _startScan() async {
    setState(() {
      _scanning = true;
      _found.clear();
      _opened = false;
    });

    _ble.startScan((uuid, minor) async {
      if (minor != BleService.kTeacherMinorId) return;
      if (_opened) return;
      _opened = true;

      // Stop scanning and open the StudentScanScreen directly with the session id
      _ble.stopScan();
      setState(() => _scanning = false);
      if (!mounted) return;
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => StudentScanScreen(sessionId: uuid)));
    });

    // stop after 30s
    Timer(const Duration(seconds: 30), () {
      _ble.stopScan();
      if (mounted) setState(() => _scanning = false);
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    _ble.stopScan();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Scan for Sessions')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            ElevatedButton(onPressed: _scanning ? null : _startScan, child: Text(_scanning ? 'Scanning...' : 'Scan for Sessions')),
            const SizedBox(height: 12),
            Expanded(
              child: _scanning
                  ? const Center(child: Text('Scanning for sessions...'))
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const SizedBox(height: 20),
                        const Text('No sessions found. Try scanning.'),
                        const SizedBox(height: 12),
                        ElevatedButton(onPressed: _startScan, child: const Text('Retry')),
                      ],
                    ),
            )
          ],
        ),
      ),
    );
  }
}
