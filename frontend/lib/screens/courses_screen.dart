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
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
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
      appBar: AppBar(title: const Text('Courses')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
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
            ),
    );
  }
}
