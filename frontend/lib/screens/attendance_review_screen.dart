import 'package:flutter/material.dart';
import '../services/local_store.dart';
import '../services/api_service.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

class AttendanceReviewScreen extends StatefulWidget {
  final Map course;
  final String sessionId;
  final int sessionNumber;
  final List<Map<String, dynamic>> students;

  const AttendanceReviewScreen({super.key, required this.course, required this.sessionId, required this.sessionNumber, required this.students});

  @override
  State<AttendanceReviewScreen> createState() => _AttendanceReviewScreenState();
}

class _AttendanceReviewScreenState extends State<AttendanceReviewScreen> {
  late List<Map<String, dynamic>> _students;
  final _api = ApiService();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _students = widget.students.map((s) => Map<String, dynamic>.from(s)).toList();
  }

  Future<void> _saveAttendance() async {
    setState(() => _saving = true);
    final snapshot = {
      'course_id': widget.course['id'],
      'course_name': widget.course['course_name'] ?? widget.course['name'],
      'course_code': widget.course['course_code'],
      'session_id': widget.sessionId,
      'session_number': widget.sessionNumber,
      'created_at': DateTime.now().toIso8601String(),
      'students': _students.map((s) => {
        'student_id': s['student_id'],
        'name': s['name'],
        'present': s['present'] == true,
      }).toList(),
      'synced': false,
    };

    await LocalStore.addAttendanceSnapshot(snapshot);

    // Try to sync right away if online
    final conn = await Connectivity().checkConnectivity();
    if (conn != ConnectivityResult.none) {
      try {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Syncing attendance, don't close app")));
        for (var s in snapshot['students']) {
          if (s['present'] == true) {
            await _api.approveStudentById(snapshot['session_id'], s['student_id']);
          }
        }
        snapshot['synced'] = true;
        final snaps = await LocalStore.loadAttendanceSnapshots();
        // replace the snapshot we just added (mark synced)
        final idx = snaps.indexWhere((sn) => sn['created_at'] == snapshot['created_at'] && sn['session_id'] == snapshot['session_id']);
        if (idx >= 0) {
          snaps[idx] = snapshot;
          await LocalStore.updateAttendanceSnapshots(snaps);
        }
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Attendance saved and synced')));
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Saved locally; sync failed: $e')));
      }
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Offline: sync not available, connect to sync.')));
    }

    setState(() => _saving = false);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final courseTitle = '${widget.course['course_name'] ?? widget.course['name'] ?? ''}${widget.course['course_code'] != null ? ' (${widget.course['course_code']})' : ''}';
    return Scaffold(
      appBar: AppBar(title: Text('$courseTitle — Session ${widget.sessionNumber}')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Expanded(child: ListView.builder(
              itemCount: _students.length,
              itemBuilder: (_, i) {
                final s = _students[i];
                return CheckboxListTile(
                  title: Text(s['name'] ?? 'Student'),
                  value: s['present'] == true,
                  onChanged: (v) => setState(() => s['present'] = v == true),
                );
              },
            )),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: ElevatedButton(
                onPressed: _saving ? null : _saveAttendance,
                child: _saving ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Save Attendance'),
              ),
            )
          ],
        ),
      ),
    );
  }
}
