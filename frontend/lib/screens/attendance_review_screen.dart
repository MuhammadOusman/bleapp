// ignore_for_file: use_build_context_synchronously

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../services/local_store.dart';
import '../theme/app_theme.dart';
import '../widgets/app_scaffold.dart';
import '../widgets/app_snackbar.dart';

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

  void _toast(String message, {SnackType type = SnackType.info}) {
    if (!mounted) return;
    showAppSnackBar(context, message, type: type);
  }

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
      _toast('Offline: saved locally. Will sync when online.', type: SnackType.info);
      setState(() => _saving = false);
      Navigator.of(context).pop('saved');
      return;
    }

    try {
      if (mounted) {
        _toast("Syncing attendance, don't close app", type: SnackType.info);
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
      _toast('Attendance saved and synced', type: SnackType.success);
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
        _toast('Saved locally; will retry when online.', type: SnackType.info);
        setState(() => _saving = false);
        Navigator.of(context).pop('saved');
      } else if (choice == 'retry') {
        setState(() => _saving = false);
        await _saveAttendance();
      } else {
        _toast('Attendance discarded', type: SnackType.info);
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
        _toast('Offline: cannot discard. Connect to internet to delete session.', type: SnackType.error);
      }
      setState(() => _saving = false);
      return;
    }

    try {
      await _api.deleteSession(widget.sessionId);
      if (!mounted) return;
      _toast('Session discarded and removed', type: SnackType.success);
      Navigator.of(context).pop('discard');
    } on FormatException catch (e) {
      if (mounted) {
        _toast('Discard failed: invalid session format (${e.message})', type: SnackType.error);
        setState(() => _saving = false);
      }
    } catch (e) {
      if (mounted) {
        _toast('Failed to discard session: $e', type: SnackType.error);
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final courseTitle = '${widget.course['course_name'] ?? widget.course['name'] ?? ''}${widget.course['course_code'] != null ? ' (${widget.course['course_code']})' : ''}';

    return AppScaffold(
      padded: false,
      appBar: AppBar(
        title: Text('$courseTitle — Session ${widget.sessionNumber}'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 8),
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: AppTheme.gradient,
                borderRadius: BorderRadius.circular(20),
                boxShadow: AppTheme.glow,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Review & Finalize', style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.white70)),
                  const SizedBox(height: 6),
                  Text(courseTitle, style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: Colors.white, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _headerBadge(Icons.people_alt_rounded, '${_students.length} students'),
                      const SizedBox(width: 8),
                      _headerBadge(Icons.check_circle, '${_students.where((s) => s['present'] == true).length} marked'),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: const [BoxShadow(color: Color(0x14000000), blurRadius: 12, offset: Offset(0, 8))],
                ),
                child: ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: _students.length,
                  itemBuilder: (_, i) {
                    final s = _students[i];
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6.0),
                      child: ListTile(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        tileColor: Theme.of(context).colorScheme.surface,
                        leading: CircleAvatar(
                          backgroundColor: Theme.of(context).colorScheme.primary.withAlpha((255 * 0.12).round()),
                          child: Icon(
                            Icons.person_rounded,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                        title: Text(s['name'] ?? 'Student', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                        trailing: Switch(
                          value: s['present'] == true,
                          onChanged: _sessionSynced || _saving ? null : (v) => setState(() => s['present'] = v == true),
                          thumbColor: WidgetStateProperty.all(Theme.of(context).colorScheme.primary),
                          trackColor: WidgetStateProperty.resolveWith(
                            (states) => states.contains(WidgetState.selected)
                                ? Theme.of(context).colorScheme.primary.withAlpha(90)
                                : null,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _saving || _sessionSynced ? null : _discardAttendance,
                    icon: const Icon(Icons.delete_outline_rounded),
                    label: const Text('Discard'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _saving || _sessionSynced ? null : _saveAttendance,
                    icon: _saving
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.check_circle_rounded),
                    label: Text(_saving ? 'Saving...' : 'Save'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _headerBadge(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha((255 * 0.18).round()),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 18),
          const SizedBox(width: 6),
          Text(text, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
