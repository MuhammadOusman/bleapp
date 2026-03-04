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
  String? _error;
  Map<String, dynamic> _details = {};
  List<dynamic> _sessions = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        _api.getCourseDetails(widget.course['id']),
        _api.getCourseSessions(widget.course['id']),
      ]);
      final det = results[0] as Map<String, dynamic>;
      final sessions = results[1] as List<dynamic>;
      if (mounted) {
        setState(() {
          _details = det;
          _sessions = sessions;
        });
      }
    } catch (e) {
      if (mounted) {
        _error = 'Failed to load course details: $e';
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_error!)));
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
      body: RefreshIndicator(
        onRefresh: _load,
        child: _loading
            ? ListView(
                padding: const EdgeInsets.symmetric(vertical: 48),
                children: const [Center(child: CircularProgressIndicator())],
              )
            : ListView(
                padding: const EdgeInsets.all(12.0),
                children: [
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8.0),
                      child: Text(_error!, style: const TextStyle(color: Colors.red)),
                    ),
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
                  if (_sessions.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24.0),
                      child: Center(child: Text('No sessions found')),
                    )
                  else
                    ..._sessions.map((s) {
                      final attended = s['student_attended'] == true;
                      return Column(
                        children: [
                          ListTile(
                            title: Text('Session ${s['session_number'] ?? ''}'),
                            subtitle: Text(_formatDate(s['created_at']?.toString())),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(attended ? Icons.check_circle : Icons.cancel, color: attended ? Colors.green : Colors.red),
                                const SizedBox(width: 6),
                                Text(attended ? 'Present' : 'Absent'),
                              ],
                            ),
                          ),
                          const Divider(height: 1),
                        ],
                      );
                    }),
                  const SizedBox(height: 12),
                  ElevatedButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Back')),
                ],
              ),
      ),
    );
  }
}
