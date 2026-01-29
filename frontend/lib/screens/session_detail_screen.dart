import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'attendance_review_screen.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../services/local_store.dart';
import '../services/permission_service.dart';

class SessionDetailScreen extends StatefulWidget {
  final Map session;
  const SessionDetailScreen({super.key, required this.session});

  @override
  State<SessionDetailScreen> createState() => _SessionDetailScreenState();
}

class _SessionDetailScreenState extends State<SessionDetailScreen> {
  final _api = ApiService();
  List _attendees = [];
  bool _loading = true;
  bool _ending = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final rows = await _api.getSessionAttendance(widget.session['id']);
      setState(() => _attendees = rows);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to load attendees: $e')));
    }
    setState(() => _loading = false);
  }

  /// End session on server, build a students snapshot and open AttendanceReviewScreen
  Future<void> _endAndReview({bool autoSave = false}) async {
    final sid = widget.session['id'];
    if (sid == null) return;

    setState(() => _ending = true);
    try {
      await _api.endSession(sid);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Session ended on server')));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to end session: $e')));
      setState(() => _ending = false);
      return;
    }

    // Fetch course details to load enrolled students
    Map<String, dynamic>? course;
    try {
      final s = await _api.getSession(sid);
      course = s['course'] as Map<String, dynamic>?;
    } catch (_) {
      course = null;
    }

    // Build students list for review
    List<Map<String, dynamic>> students = [];
    try {
      if (course != null) {
        final enrolled = await _api.getCourseStudents(course['id']);
        final presentIds = _attendees.map((a) => a['student_id']).toSet();
        students = enrolled.map<Map<String, dynamic>>((s) => {
          'student_id': s['id'],
          'name': (s['full_name'] ?? s['email'] ?? 'Student') as String,
          'present': presentIds.contains(s['id']),
        }).toList();
      } else {
        // No course info, create a best-effort list from attendees only
        students = _attendees.map<Map<String, dynamic>>((a) => {
          'student_id': a['student_id'],
          'name': (a['profile']?['full_name'] ?? a['profile']?['email'] ?? a['student_id'] ?? 'Student').toString(),
          'present': true,
        }).toList();
      }
    } catch (e) {
      debugPrint('Failed to build students list: $e');
    }

    setState(() => _ending = false);

    // Open review screen; autoSave will trigger confirmation then save
    if (!mounted) return;
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => AttendanceReviewScreen(
      course: course ?? {'course_name': 'Course'},
      sessionId: sid,
      sessionNumber: widget.session['session_number'] ?? 1,
      students: students,
      autoSave: autoSave,
    )));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Session ${widget.session['session_number'] ?? ''}')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _attendees.isEmpty
              ? const Center(child: Text('No attendees yet'))
              : ListView.builder(
                  itemCount: _attendees.length,
                  itemBuilder: (_, i) {
                    final a = _attendees[i] as Map;
                    final prof = a['profile'] as Map?;
                    final name = prof == null ? (a['student_id'] ?? 'Unknown') : (prof['full_name'] ?? prof['email'] ?? 'Student');
                    return ListTile(
                      title: Text(name.toString()),
                      subtitle: Text('Marked at: ${a['marked_at'] ?? ''}'),
                    );
                  },
                ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _ending ? null : () async { await _endAndReview(autoSave: false); },
                  child: _ending ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('End Attendance'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                  onPressed: _saving ? null : () async { setState(() => _saving = true); await _endAndReview(autoSave: true); setState(() => _saving = false); },
                  child: _saving ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('Save Attendance'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
