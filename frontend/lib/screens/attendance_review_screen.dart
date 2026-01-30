// ignore_for_file: use_build_context_synchronously

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../services/local_store.dart';

class AttendanceReviewScreen extends StatefulWidget {
  final Map course;
  final String sessionId;
  final int sessionNumber;
  final List<Map<String, dynamic>> students;
  final bool sessionSynced;
  final bool autoSave;

  const AttendanceReviewScreen({
    super.key,
    required this.course,
    required this.sessionId,
    required this.sessionNumber,
    required this.students,
    this.sessionSynced = false,
    this.autoSave = false,
  });

  @override
  State<AttendanceReviewScreen> createState() => _AttendanceReviewScreenState();
}

class _AttendanceReviewScreenState extends State<AttendanceReviewScreen> {
  final _api = ApiService();
  late List<Map<String, dynamic>> _students;
  bool _saving = false;
  late bool _sessionSynced;

  @override
  void initState() {
    super.initState();
    _students = widget.students.map((s) => Map<String, dynamic>.from(s)).toList();
    _sessionSynced = widget.sessionSynced;

    if (widget.autoSave == true) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        final confirm = await showDialog<bool>(
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
        if (confirm == true) {
          await _saveAttendance();
        }
      });
    }
  }

  Future<void> _saveAttendance() async {
    if (_sessionSynced || _saving) return;
    setState(() => _saving = true);

    final snapshot = {
      'course_id': widget.course['id'],
      'course_name': widget.course['course_name'] ?? widget.course['name'],
      'course_code': widget.course['course_code'],
      'session_id': widget.sessionId,
      'session_number': widget.sessionNumber,
      'created_at': DateTime.now().toIso8601String(),
      'students': _students
          .map((s) => {
                'student_id': s['student_id'],
                'name': s['name'],
                'present': s['present'] == true,
              })
          .toList(),
      'synced': false,
    };

    final conn = await Connectivity().checkConnectivity();
    final isOffline = conn.isEmpty || conn.every((r) => r == ConnectivityResult.none);
    if (isOffline) {
      await LocalStore.addAttendanceSnapshot(snapshot);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Offline: saved locally. Will sync when online.')));
      setState(() => _saving = false);
      Navigator.of(context).pop('saved');
      return;
    }

    try {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Syncing attendance, don't close app")));
      }

      for (var s in snapshot['students']) {
        if (s['present'] == true) {
          await _api.approveStudentById(snapshot['session_id'], s['student_id']);
        }
      }

      try {
        await LocalStore.removeAttendanceSnapshotsForSession(snapshot['session_id']);
      } catch (_) {}

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Attendance saved and synced')));
      setState(() => _saving = false);
      Navigator.of(context).pop('saved');
    } catch (e) {
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
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Saved locally; will retry when online.')));
        setState(() => _saving = false);
        Navigator.of(context).pop('saved');
      } else if (choice == 'retry') {
        setState(() => _saving = false);
        await _saveAttendance();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Attendance discarded')));
        setState(() => _saving = false);
        Navigator.of(context).pop('discard');
      }
    }
  }

  Future<void> _discardAttendance() async {
    if (_sessionSynced || _saving) return;
    setState(() => _saving = true);

    try {
      await LocalStore.removeAttendanceSnapshotsForSession(widget.sessionId);
    } catch (_) {}

    final conn = await Connectivity().checkConnectivity();
    final isOffline = conn.isEmpty || conn.every((r) => r == ConnectivityResult.none);
    if (isOffline) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Offline: cannot discard. Connect to internet to delete session.')));
      }
      setState(() => _saving = false);
      return;
    }

    try {
      await _api.deleteSession(widget.sessionId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Session discarded and removed')));
      Navigator.of(context).pop('discard');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to discard session: $e')));
        setState(() => _saving = false);
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
            Expanded(
              child: ListView.builder(
                itemCount: _students.length,
                itemBuilder: (_, i) {
                  final s = _students[i];
                  return CheckboxListTile(
                    title: Text(s['name'] ?? 'Student'),
                    value: s['present'] == true,
                    onChanged: _sessionSynced || _saving ? null : (v) => setState(() => s['present'] = v == true),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _saving || _sessionSynced ? null : _discardAttendance,
                      child: const Text('Discard'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _saving || _sessionSynced ? null : _saveAttendance,
                      child: _saving
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Text('Save Attendance'),
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
