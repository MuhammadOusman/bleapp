import 'dart:async';
import 'package:flutter/material.dart';
import '../services/ble_service.dart';
import '../services/api_service.dart';
import 'student_scan_screen.dart';

class StudentSessionScanner extends StatefulWidget {
  const StudentSessionScanner({super.key});

  @override
  State<StudentSessionScanner> createState() => _StudentSessionScannerState();
}

class _StudentSessionScannerState extends State<StudentSessionScanner> {
  final _ble = BleService();
  bool _scanning = false;
  final Map<String, Map<String, dynamic>> _found = {}; // sessionId -> { discovered_at, checking, course?, marked }
  StreamSubscription? _sub;
  final _api = ApiService();
  Map<String, dynamic>? _profile;

  void _startScan() async {
    setState(() {
      _scanning = true;
      _found.clear();
    });

    // Load profile once for attendance checks
    try {
      _profile = await _api.getProfile();
    } catch (_) {
      _profile = null;
    }

    _ble.startScan((uuid, minor) async {
      if (minor != BleService.kTeacherMinorId) return;
      if (_found.containsKey(uuid)) return; // already discovered

      final discoveredAt = DateTime.now().toIso8601String();
      setState(() {
        _found[uuid] = {'discovered_at': discoveredAt, 'checking': true, 'course': null, 'marked': false};
      });

      // Fetch session details and whether current student is already marked
      try {
        final session = await _api.getSession(uuid);
        final course = session['course'] as Map<String, dynamic>?;
        bool marked = false;
        try {
          final attendees = await _api.getSessionAttendance(uuid);
          final sid = _profile?['id'];
          if (sid != null) marked = attendees.any((a) => a['student_id'] == sid);
        } catch (_) {
          // ignore attendance check failure
        }

        if (mounted) setState(() {
          _found[uuid] = {'discovered_at': discoveredAt, 'checking': false, 'course': course, 'marked': marked};
        });
      } catch (e) {
        // Could not resolve session details; leave it as unknown
        if (mounted) setState(() {
          _found[uuid] = {'discovered_at': discoveredAt, 'checking': false, 'course': null, 'marked': false};
        });
      }
    });

    // stop after 30s
    Timer(const Duration(seconds: 30), () async {
      _ble.stopScan();
      setState(() => _scanning = false);
    });
  }

  /// Restart the current scan (stop and immediately start again)
  void _restartScan() async {
    try {
      _ble.stopScan();
    } catch (_) {}
    if (mounted) setState(() => _scanning = false);
    // brief pause so plugin cleans up
    await Future.delayed(const Duration(milliseconds: 200));
    _startScan();
  }

  @override
  void initState() {
    super.initState();
    // Auto-start scanning when screen opens
    _startScan();
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
            const SizedBox(height: 8),

            // Progress indicator + Restart button while scanning, or Retry when idle
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (_scanning) ...[
                  SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                  const SizedBox(width: 12),
                  TextButton(onPressed: _restartScan, child: const Text('Restart')),
                ] else ...[
                  TextButton(onPressed: _startScan, child: const Text('Retry')),
                ]
              ],
            ),

            const SizedBox(height: 12),
            Expanded(
              child: _found.isEmpty
                  ? (_scanning ? const Center(child: Text('Scanning for sessions...')) : Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const SizedBox(height: 20),
                        const Text('No sessions found. Try scanning.'),
                        const SizedBox(height: 12),
                        ElevatedButton(onPressed: _startScan, child: const Text('Retry')),
                      ],
                    ))
                  : ListView(
                      children: _found.entries.map((e) {
                        final id = e.key;
                        final val = e.value;
                        final course = val['course'] as Map<String, dynamic>?;
                        final title = course != null ? '${course['course_name'] ?? 'Course'} (${course['course_code'] ?? ''})' : 'Session ${id.substring(0,8)}';
                        final subtitle = '${val['discovered_at']} • ${val['checking'] == true ? 'Checking...' : (val['marked'] == true ? 'Marked' : 'Not marked') }';
                        return ListTile(
                          title: Text(title),
                          subtitle: Text(subtitle),
                          trailing: val['marked'] == true ? const Icon(Icons.check_circle, color: Colors.green) : null,
                          onTap: () async {
                            // Stop scanning and open detailed scan/mark screen
                            _ble.stopScan();
                            if (mounted) setState(() => _scanning = false);
                            await Navigator.of(context).push(MaterialPageRoute(builder: (_) => StudentScanScreen(sessionId: id)));
                            // After returning, refresh status for this session
                            try {
                              final attendees = await _api.getSessionAttendance(id);
                              final sid = _profile?['id'];
                              final marked = sid != null && attendees.any((a) => a['student_id'] == sid);
                              if (mounted) setState(() => _found[id]?['marked'] = marked);
                            } catch (_) {}
                          },
                        );
                      }).toList(),
                    ),
            )
          ],
        ),
      ),
    );
  }
}
