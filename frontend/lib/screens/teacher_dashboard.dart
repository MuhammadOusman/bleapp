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
              : ListView.builder(
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
      final sessions = await _api.getCourseSessions(widget.course['id']);
      setState(() => _sessions = sessions);
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
