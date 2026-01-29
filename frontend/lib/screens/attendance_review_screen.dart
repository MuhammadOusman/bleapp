import 'package:flutter/material.dart';
import '../services/local_store.dart';
import '../services/api_service.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'teacher_dashboard.dart';

class AttendanceReviewScreen extends StatefulWidget {
  final Map course;
  final String sessionId;
  final int sessionNumber;
  final List<Map<String, dynamic>> students;
  final bool autoSave;

  const AttendanceReviewScreen({super.key, required this.course, required this.sessionId, required this.sessionNumber, required this.students, this.autoSave = false});

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

    // If caller requested auto-save, trigger save after first frame so
    // UI is fully built and SnackBars/dialogs work correctly.
    if (widget.autoSave == true) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        // Ask for confirmation before auto-saving
        final choice = await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Confirm Save'),
            content: const Text('Save attendance now? This will upload attendance and finalize the session.'),
            actions: [
              TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
              ElevatedButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Confirm')),
            ],
          ),
        );
        if (choice == true) {
          await _saveAttendance();
        }
      });
    }
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

    // Check connectivity first
    final conn = await Connectivity().checkConnectivity();
    if (conn == ConnectivityResult.none) {
      // Offline: save locally only
      await LocalStore.addAttendanceSnapshot(snapshot);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Offline: saved locally. Will sync when online.')));
      setState(() => _saving = false);
      // After saving, return to Dashboard for teacher flows
      Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const TeacherDashboardScreen()));
      return;
    }

    // Online: Try to upload directly. On failure, offer to Save Locally or Discard.
    try {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Syncing attendance, don't close app")));
      for (var s in snapshot['students']) {
        if (s['present'] == true) {
          await _api.approveStudentById(snapshot['session_id'], s['student_id']);
        }
      }

      // On success, ensure any local snapshot for this session is removed
      try {
        await LocalStore.removeAttendanceSnapshotsForSession(snapshot['session_id']);
      } catch (_) {}

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Attendance saved and synced')));
      setState(() => _saving = false);
      // After successful save, navigate back to the teacher dashboard
      Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const TeacherDashboardScreen()));
      return;
    } catch (e) {
      // Upload failed. Ask the user whether to save locally or discard.
      if (!mounted) return;
      final choice = await showDialog<String>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Sync failed'),
          content: Text('Could not upload attendance: $e. Save locally and retry later, or discard?'),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop('discard'), child: const Text('Discard')),
            TextButton(onPressed: () => Navigator.of(context).pop('save'), child: const Text('Save Locally')),
            ElevatedButton(onPressed: () => Navigator.of(context).pop('retry'), child: const Text('Retry')),
          ],
        ),
      );

      if (choice == 'save') {
        await LocalStore.addAttendanceSnapshot(snapshot);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Saved locally; will retry when online.')));
        setState(() => _saving = false);
        // After saving locally, return to Dashboard for teacher flows
        Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const TeacherDashboardScreen()));
        return;
      } else if (choice == 'retry') {
        // try again recursively (but avoid infinite loops)
        setState(() => _saving = false);
        await _saveAttendance();
        return;
      } else {
        // discard
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Attendance discarded')));
        setState(() => _saving = false);
        Navigator.of(context).pop();
        return;
      }
    }
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
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _saving ? null : () { Navigator.of(context).pop(); },
                      child: const Text('Discard'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _saving ? null : _saveAttendance,
                      child: _saving ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Save Attendance'),
                    ),
                  ),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }
}
