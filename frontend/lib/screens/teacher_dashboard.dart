import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../services/api_service.dart';
import 'session_detail_screen.dart';

class TeacherDashboardScreen extends StatefulWidget {
  const TeacherDashboardScreen({super.key});

  @override
  State<TeacherDashboardScreen> createState() => _TeacherDashboardScreenState();
}

class _TeacherDashboardScreenState extends State<TeacherDashboardScreen> {
  final _api = ApiService();
  final _storage = const FlutterSecureStorage();
  List _courses = [];
  bool _loading = true;
  int _totalSessions = 0;
  int _totalAttendance = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final token = await _storage.read(key: 'token');
    try {
      final courses = await _api.getCourses(token ?? '');
      setState(() => _courses = courses);

      // Fetch per-course details to compute metrics (functional, may be optimized later)
      int sessions = 0;
      int attendance = 0;
      for (var c in courses) {
        try {
          final details = await _api.getCourseDetails(c['id']);
          sessions += (details['total_sessions'] as int?) ?? 0;
          attendance += (details['total_attendance'] as int?) ?? 0;
        } catch (_) {}
      }
      if (mounted) setState(() {
        _totalSessions = sessions;
        _totalAttendance = attendance;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to load courses: $e')));
    }
    setState(() => _loading = false);
  }

  void _openCourseSessions(Map course) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => CourseSessionsScreen(course: course)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Teacher Dashboard')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _courses.isEmpty
              ? Center(child: Text('No courses found.'))
              : Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          Column(children: [Text('Courses', style: TextStyle(fontWeight: FontWeight.bold)), Text('${_courses.length}')]),
                          Column(children: [Text('Sessions', style: TextStyle(fontWeight: FontWeight.bold)), Text('$_totalSessions')]),
                          Column(children: [Text('Attendance', style: TextStyle(fontWeight: FontWeight.bold)), Text('$_totalAttendance')]),
                        ],
                      ),
                    ),
                    const Divider(),
                    Expanded(
                      child: ListView.builder(
                        itemCount: _courses.length,
                        itemBuilder: (_, i) {
                          final c = _courses[i] as Map;
                          return ListTile(
                            title: Text(c['course_name'] ?? c['name'] ?? 'Course'),
                            subtitle: Text(c['course_code'] ?? ''),
                            onTap: () => _openCourseSessions(c),
                          );
                        },
                      ),
                    ),
                  ],
                ),
    );
  }
}

class CourseSessionsScreen extends StatefulWidget {
  final Map course;
  const CourseSessionsScreen({super.key, required this.course});

  @override
  State<CourseSessionsScreen> createState() => _CourseSessionsScreenState();
}

class _CourseSessionsScreenState extends State<CourseSessionsScreen> {
  final _api = ApiService();
  List _sessions = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final details = await _api.getCourseDetails(widget.course['id']);
      final sessions = await _api.getCourseSessions(widget.course['id']);
      setState(() {
        _sessions = sessions;
        // attach details to course for header display
        widget.course['teacher_profile'] = details['teacher'];
        widget.course['total_sessions'] = details['total_sessions'];
        widget.course['total_attendance'] = details['total_attendance'];
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to load sessions: $e')));
    }
    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.course['course_name'] ?? 'Course')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _sessions.isEmpty
              ? const Center(child: Text('No sessions yet'))
              : ListView.builder(
                  itemCount: _sessions.length,
                  itemBuilder: (_, i) {
                    final s = _sessions[i] as Map;
                    final cnt = s['attendance_count'] ?? 0;
                    return ListTile(
                      title: Text('Session ${s['session_number'] ?? ''} • ${s['is_active'] == false ? 'Ended' : 'Active'}'),
                      subtitle: Text('$cnt attendees'),
                      trailing: ElevatedButton(
                        onPressed: () {
                          Navigator.of(context).push(MaterialPageRoute(builder: (_) => SessionDetailScreen(session: s)));
                        },
                        child: const Text('Open'),
                      ),
                    );
                  },
                ),
    );
  }
}
