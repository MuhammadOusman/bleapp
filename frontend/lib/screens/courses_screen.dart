import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../services/api_service.dart';
import 'teacher_session_screen_v2.dart';
import 'student_scan_screen.dart';

class CoursesScreen extends StatefulWidget {
  const CoursesScreen({super.key});

  @override
  State<CoursesScreen> createState() => _CoursesScreenState();
}

class _CoursesScreenState extends State<CoursesScreen> {
  final _api = ApiService();
  final _storage = const FlutterSecureStorage();
  List _courses = [];
  String _role = 'student';
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final token = await _storage.read(key: 'token');
    final role = await _storage.read(key: 'role') ?? 'student';
    if (token != null) {
      try {
        final courses = await _api.getCourses(token);
        setState(() {
          _courses = courses;
          _role = role;
        });
      } catch (e) {
        // Log and show user-friendly message
        print('[Courses] getCourses error: $e');
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to load courses (see logs)')));
      }
    }
    setState(() => _loading = false);
  }

  void _onCourseTap(Map course) {
    if (_role == 'teacher') {
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => TeacherSessionScreenV2(course: course)));
    } else {
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => StudentScanScreen(course: course)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Courses'),
        actions: [
          IconButton(
            icon: const Icon(Icons.bug_report),
            tooltip: 'Show debug info',
            onPressed: () async {
              final token = await _storage.read(key: 'token');
              final role = await _storage.read(key: 'role');
              final masked = token == null ? 'none' : (token.length > 8 ? '${token.substring(0,8)}...' : token);
              if (!mounted) return;
              showDialog(context: context, builder: (_) => AlertDialog(
                title: const Text('Debug Info'),
                content: Text('role: ${role ?? 'none'}\ntoken: $masked'),
                actions: [TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('OK'))],
              ));
            },
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : (_courses.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('No courses found for this account.', textAlign: TextAlign.center),
                      const SizedBox(height: 12),
                      ElevatedButton(onPressed: _load, child: const Text('Retry')),
                      const SizedBox(height: 8),
                      const Text('If you should see courses, ensure your teacher record is set in the backend.'),
                    ],
                  ),
                )
              : ListView.builder(
                  itemCount: _courses.length,
                  itemBuilder: (_, i) {
                    final c = _courses[i];
                    return ListTile(
                      title: Text(c['name'] ?? c['course_name'] ?? 'Course'),
                      subtitle: Text(c['id'] ?? ''),
                      onTap: () => _onCourseTap(c),
                    );
                  },
                )),

    );
  }
}
