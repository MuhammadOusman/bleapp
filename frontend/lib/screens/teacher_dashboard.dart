import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../services/api_service.dart';
import '../services/permission_service.dart';
import 'session_detail_screen.dart';
import 'teacher_session_screen_v2.dart';

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

  // Search state for courses
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

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
                    // Search bar
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
                      child: TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          hintText: 'Search courses by name or code',
                          prefixIcon: const Icon(Icons.search),
                          suffixIcon: _searchQuery.isNotEmpty
                              ? IconButton(icon: const Icon(Icons.clear), onPressed: () { _searchController.clear(); setState(() => _searchQuery = ''); })
                              : null,
                          border: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(8.0))),
                        ),
                        onChanged: (v) => setState(() => _searchQuery = v.trim()),
                      ),
                    ),
                    const Divider(),
                    Expanded(
                      child: Builder(builder: (_) {
                        final q = _searchQuery.toLowerCase();
                        final filtered = _courses.where((c) {
                          if (q.isEmpty) return true;
                          final name = (c['course_name'] ?? c['name'] ?? '').toString().toLowerCase();
                          final code = (c['course_code'] ?? '').toString().toLowerCase();
                          return name.contains(q) || code.contains(q);
                        }).toList();

                        if (filtered.isEmpty) return Center(child: Text('No courses match "$_searchQuery"'));

                        return ListView.builder(
                          itemCount: filtered.length,
                          itemBuilder: (_, i) {
                            final c = filtered[i] as Map;
                            return ListTile(
                              title: Text(c['course_name'] ?? c['name'] ?? 'Course'),
                              subtitle: Text(c['course_code'] ?? ''),
                              onTap: () => _openCourseSessions(c),
                            );
                          },
                        );
                      }),
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
      // Get student count
      int studentCount = 0;
      try {
        final students = await _api.getCourseStudents(widget.course['id']);
        studentCount = students.length;
      } catch (_) {}
      setState(() {
        _sessions = sessions;
        // attach details to course for header display
        widget.course['teacher_profile'] = details['teacher'];
        widget.course['total_sessions'] = details['total_sessions'];
        widget.course['total_attendance'] = details['total_attendance'];
        widget.course['student_count'] = studentCount;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to load sessions: $e')));
    }
    setState(() => _loading = false);
  }

  // Start a session from the course screen (permission checks + navigation)
  Future<void> _startSessionFromCourse() async {
    try {
      // Permission check
      final allowed = await PermissionService.requestBlePermissions();
      if (!allowed) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Bluetooth permissions are required')));
        await PermissionService.openAppSettingsIfNeeded();
        return;
      }

      final storage = const FlutterSecureStorage();
      final token = await storage.read(key: 'token');
      if (token == null) return;

      // Before starting ensure no active session exists
      try {
        final sessions = await _api.getCourseSessions(widget.course['id']);
        final active = sessions.firstWhere((s) => s['is_active'] == true, orElse: () => null);
        if (active != null) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Active session exists: Session ${active['session_number'] ?? ''}')));
          return;
        }
      } catch (_) {}

      final sid = await _api.startSession(token, widget.course['id'], (widget.course['total_sessions'] as int? ?? 0) + 1);
      if (!mounted) return;
      final res = await Navigator.of(context).push(MaterialPageRoute(builder: (_) => TeacherSessionScreenV2(course: widget.course, initialSessionId: sid)));
      // if child popped with true it indicates session state changed and we should reload
      if (res == true) {
        await _load();
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to start session: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final teacher = widget.course['teacher_profile'] as Map<String, dynamic>?;
    final totalSessions = widget.course['total_sessions'] ?? 0;
    final totalAttendance = widget.course['total_attendance'] ?? 0;

    return Scaffold(
      appBar: AppBar(title: Text(widget.course['course_name'] ?? 'Course')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(widget.course['course_code'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 6),
                        Text('Teacher: ${teacher != null ? (teacher['full_name'] ?? teacher['email']) : 'Unknown'}'),
                      ]),
                      Column(children: [Text('Students', style: TextStyle(fontWeight: FontWeight.bold)), Text('${widget.course['student_count'] ?? 0}')]),
                      Column(children: [Text('Sessions', style: TextStyle(fontWeight: FontWeight.bold)), Text('$totalSessions')]),
                      Column(children: [Text('Attendance', style: TextStyle(fontWeight: FontWeight.bold)), Text('$totalAttendance')]),
                    ],
                  ),
                ),

                const Divider(),
                Expanded(
                  child: _sessions.isEmpty
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
                ),
              ],
            ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: ElevatedButton(
            onPressed: _loading ? null : _startSessionFromCourse,
            child: const Text('Start Session'),
          ),
        ),
      ),
    );
  }
}
