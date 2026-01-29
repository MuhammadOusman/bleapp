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
  final _api = ApiService();
  bool _scanning = false;
  final Map<String, Map<String, dynamic>> _found = {}; // sessionId -> data
  StreamSubscription? _sub;

  void _startScan() async {
    setState(() {
      _scanning = true;
      _found.clear();
    });

    _ble.startScan((uuid, minor) async {
      if (minor != BleService.kTeacherMinorId) return;
      if (_found.containsKey(uuid)) return;

      // Try to resolve session info from backend
      try {
        final data = await _api.getSession(uuid);
        // Expect { session: {...}, course: {...} }
        final session = data['session'] as Map<String, dynamic>?;
        final course = data['course'] as Map<String, dynamic>?;
        if (session != null && course != null) {
          setState(() {
            _found[uuid] = {'session': session, 'course': course};
          });
        }
      } catch (e) {
        // ignore errors - session might be unknown to backend
      }
    });

    // stop after 20s
    Timer(const Duration(seconds: 20), () {
      _ble.stopScan();
      setState(() => _scanning = false);
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
                child: _found.isEmpty
                    ? const Center(child: Text('No sessions found. Try scanning.'))
                    : ListView(
                        children: _found.entries.map((e) {
                          final uuid = e.key;
                          final course = e.value['course'] as Map<String, dynamic>;
                          final session = e.value['session'] as Map<String, dynamic>;
                          final title = course['course_name'] ?? course['name'] ?? 'Course';
                          final subtitle = session['is_active'] == false ? 'Ended' : 'Active';
                          return Card(
                            child: ListTile(
                              title: Text('$title'),
                              subtitle: Text('Session: $subtitle • id ${uuid.substring(0, 8)}'),
                              trailing: ElevatedButton(
                                onPressed: () {
                                  Navigator.of(context).push(MaterialPageRoute(builder: (_) => StudentScanScreen(course: course)));
                                },
                                child: const Text('Open'),
                              ),
                            ),
                          );
                        }).toList(),
                      ))
          ],
        ),
      ),
    );
  }
}
