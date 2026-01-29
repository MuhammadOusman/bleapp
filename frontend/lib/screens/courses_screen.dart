import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter/foundation.dart';
import '../services/api_service.dart';
import '../services/sync_service.dart';
import 'teacher_session_screen_v2.dart';
import 'student_session_scanner.dart';
import 'teacher_dashboard.dart';

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
  String _profileName = 'Student';
  bool _loading = true;
  Map<String, int> _sessionCounts = {}; // course_id -> count
  Map<String, Map<String, dynamic>> _courseDetails = {}; // course_id -> details (teacher, totals)

  // Search state for courses list
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  // Student scanner entry
  void _openStudentScanner() {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const StudentSessionScanner()));
  }

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
    final rawRole = await _storage.read(key: 'role');
    final role = (rawRole ?? 'student').toString().toLowerCase();
    if (token != null) {
      // Set role immediately so teacher view appears even if network call fails
      setState(() => _role = role);

      // Run background auto-sync now (do not await blocking the UI)
      // This ensures pending snapshots & devices are processed once on app open.
      // We run silently and log results.
      try {
        SyncService.runAutoSync();
      } catch (e) {
        debugPrint('[Courses] runAutoSync scheduling failed: $e');
      }

      try {
        final courses = await _api.getCourses(token);
        // Get profile (to show student's name when role=student)
        try {
          final profile = await _api.getProfile();
          if (mounted) setState(() => _profileName = profile['full_name'] ?? profile['email'] ?? 'Student');
        } catch (e) {
          // ignore
        }

        setState(() {
          _courses = courses;
        });

        // Load course details (teacher, totals) and session counts in parallel
        try {
          final futures = courses.map((c) async {
            final details = await _api.getCourseDetails(c['id']);
            final count = details['total_sessions'] as int? ?? 0;
            return {'id': c['id'], 'details': details, 'count': count};
          }).toList();
          final results = await Future.wait(futures);

          final counts = <String, int>{};
          final detailsMap = <String, Map<String, dynamic>>{};
          for (var r in results) {
            counts[r['id'] as String] = r['count'] as int;
            detailsMap[r['id'] as String] = r['details'] as Map<String, dynamic>;
          }
          if (mounted) setState(() {
            _sessionCounts = counts;
            _courseDetails = detailsMap;
          });
        } catch (e) {
          debugPrint('[Courses] failed to fetch course details/counts: $e');
        }
      } catch (e) {
        // Log and show user-friendly message with details for debugging
        debugPrint('[Courses] getCourses error: $e');
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to load courses: $e')));
      }
    }
    setState(() => _loading = false);
  }

  void _onCourseTap(Map course) {
    if (_role == 'teacher') {
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => TeacherSessionScreenV2(course: course)));
    } else {
      // Students should use the scanner entrypoint instead of opening a course
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => const StudentSessionScanner()));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_role == 'student' ? _profileName : 'Courses'),
        automaticallyImplyLeading: _role == 'student' ? false : true,
        actions: [
          if (_role == 'teacher') IconButton(onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const TeacherDashboardScreen())), icon: const Icon(Icons.dashboard), tooltip: 'Dashboard'),
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
          : (_role == 'student'
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('Scan for Sessions', style: TextStyle(fontSize: 18)),
                      const SizedBox(height: 12),
                      ElevatedButton(onPressed: _openStudentScanner, child: const Text('Scan for Sessions')),
                      const SizedBox(height: 8),
                      TextButton(onPressed: _load, child: const Text('Reload')),
                    ],
                  ),
                )
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
                                final details = _courseDetails[c['id']] ?? {};
                                final teacher = details['teacher'] as Map<String, dynamic>?;
                                final raw = _sessionCounts[c['id']] ?? 0;
                                return ListTile(
                                  title: Text(c['course_name'] ?? c['name'] ?? 'Course'),
                                  subtitle: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('${c['course_code'] ?? ''} • Sessions: $raw'),
                                      Text('Teacher: ${teacher != null ? (teacher['full_name'] ?? teacher['email']) : 'TBD'} • Attendance: ${details['total_attendance'] ?? 0}'),
                                    ],
                                  ),
                                  onTap: () => _onCourseTap(c),
                                );
                              },
                            );
                          }),
                        ),
                      ],
                    ))),
      bottomNavigationBar: _role == 'student'
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ElevatedButton.icon(onPressed: _openStudentScanner, icon: const Icon(Icons.nfc), label: const Text('Scan')),
                  ],
                ),
              ),
            )
          : null,
    );
  }
}
