import 'package:flutter/material.dart';
import '../services/api_service.dart';

class CourseDetailScreen extends StatefulWidget {
  final Map course;
  const CourseDetailScreen({super.key, required this.course});

  @override
  State<CourseDetailScreen> createState() => _CourseDetailScreenState();
}

class _CourseDetailScreenState extends State<CourseDetailScreen> {
  final _api = ApiService();
  bool _loading = true;
  Map<String, dynamic> _details = {};
  List<dynamic> _sessions = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final det = await _api.getCourseDetails(widget.course['id']);
      final sessions = await _api.getCourseSessions(widget.course['id']);
      if (mounted) {
        setState(() {
          _details = det;
          _sessions = sessions;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to load course details: $e')));
      }
    }
    if (mounted) {
      setState(() => _loading = false);
    }
  }

  String _formatDate(String? iso) {
    if (iso == null) {
      return '';
    }
    try {
      final dt = DateTime.parse(iso).toLocal();
      return '${dt.year}-${dt.month.toString().padLeft(2,'0')}-${dt.day.toString().padLeft(2,'0')} ${dt.hour.toString().padLeft(2,'0')}:${dt.minute.toString().padLeft(2,'0')}';
    } catch (_) {
      return iso;
    }
  }

  @override
  Widget build(BuildContext context) {
    final course = widget.course;
    final teacher = (_details['teacher'] as Map<String, dynamic>?) ?? {};
    return Scaffold(
      appBar: AppBar(title: Text(course['course_name'] ?? course['name'] ?? 'Course')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(course['course_code'] ?? '', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  Text('Teacher: ${teacher['full_name'] ?? teacher['email'] ?? 'TBD'}'),
                  const SizedBox(height: 12),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('Total Sessions'), Text('${_details['total_sessions'] ?? 0}')]),
                          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('Your Attendance'), Text('${_details['student_attendance'] ?? 0}')]),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text('Sessions', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Expanded(
                    child: _sessions.isEmpty
                        ? const Center(child: Text('No sessions found'))
                        : ListView.separated(
                            itemCount: _sessions.length,
                            separatorBuilder: (_, index) => const Divider(height: 1),
                            itemBuilder: (_, i) {
                              final s = _sessions[i];
                              final attended = s['student_attended'] == true;
                              return ListTile(
                                title: Text('Session ${s['session_number'] ?? ''}'),
                                subtitle: Text(_formatDate(s['created_at']?.toString())),
                                trailing: attended
                                    ? Row(mainAxisSize: MainAxisSize.min, children: const [Icon(Icons.check_circle, color: Colors.green), SizedBox(width:6), Text('Present')])
                                    : Row(mainAxisSize: MainAxisSize.min, children: const [Icon(Icons.cancel, color: Colors.red), SizedBox(width:6), Text('Absent')]),
                              );
                            },
                          ),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Back')),
                ],
              ),
            ),
    );
  }
}
