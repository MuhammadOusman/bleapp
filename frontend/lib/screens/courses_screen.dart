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
  Map<String, int> _sessionCounts = {}; // course_id -> count

  // Search state for courses list
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    try {
      _searchController.dispose();
    } catch (_) {}
    super.dispose();
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

        // Load session counts for the courses (parallel)
        try {
          final futures = courses.map((c) async {
            final cnt = await _api.getSessionCount(c['id']);
            return {'id': c['id'], 'count': cnt};
          }).toList();
          final results = await Future.wait(futures);
          final counts = <String, int>{};
          for (var r in results) counts[r['id'] as String] = r['count'] as int;
          if (mounted) setState(() => _sessionCounts = counts);
        } catch (e) {
          print('[Courses] failed to fetch session counts: $e');
        }
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
              : Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          hintText: 'Search courses by name or code',
                          suffixIcon: _searchQuery.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear),
                                  onPressed: () {
                                    _searchController.clear();
                                    setState(() => _searchQuery = '');
                                  },
                                )
                              : null,
                        ),
                        onChanged: (v) => setState(() => _searchQuery = v.trim()),
                      ),
                    ),
                    Expanded(
                      child: Builder(builder: (_) {
                        final q = _searchQuery.toLowerCase();
                        final filtered = _courses.where((c) {
                          if (q.isEmpty) return true;
                          final name = (c['course_name'] ?? c['name'] ?? '').toString().toLowerCase();
                          final code = (c['course_code'] ?? '').toString().toLowerCase();
                          return name.contains(q) || code.contains(q);
                        }).toList();
                        if (filtered.isEmpty) {
                          return Center(child: Text('No courses match "$_searchQuery"'));
                        }
                        return ListView.builder(
                          itemCount: filtered.length,
                          itemBuilder: (_, i) {
                            final c = filtered[i];
                            return ListTile(
                              title: Text(c['course_name'] ?? c['name'] ?? 'Course'),
                              subtitle: Builder(builder: (_) {
                                final raw = _sessionCounts[c['id']] ?? 0;
                                final display = raw == 0 ? 0 : (raw % 16 == 0 ? 16 : raw % 16);
                                return Text('${c['course_code'] ?? ''} • ${display}/16');
                              }),
                              onTap: () => _onCourseTap(c),
                            );
                          },
                        );
                      }),
                    ),
                  ],
                )),

    );
  }
}
