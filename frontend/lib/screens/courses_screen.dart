import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../services/api_service.dart';
import '../services/sync_service.dart';
import 'student_session_scanner.dart';
import 'teacher_dashboard.dart';
import 'course_detail_screen.dart';

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

  // Student-specific state
  List _enrolledCourses = [];
  int _enrolledSessionsTotal = 0;
  int _enrolledAttendanceTotal = 0;
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
          final fetchedName = profile['full_name'] ?? profile['email'] ?? 'Student';
          // store for faster subsequent loads and to ensure the UI shows a name even if network fails later
          try { await _storage.write(key: 'profile_full_name', value: fetchedName); } catch (_) {}
          if (mounted) setState(() => _profileName = fetchedName);
        } catch (e) {
          // If fetching failed, try using a cached name so the UI isn't stuck as 'Student'
          try {
            final cached = await _storage.read(key: 'profile_full_name');
            if (cached != null && mounted) setState(() => _profileName = cached);
          } catch (_) {}
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

          // Compute student-specific dashboard totals when the current user is a student
          if (role == 'student') {
            final enrolled = courses;
            int sessionsTotal = 0;
            int attendanceTotal = 0;
            for (var c in enrolled) {
              final det = detailsMap[c['id']] ?? {};
              sessionsTotal += (det['total_sessions'] as int?) ?? (counts[c['id']] ?? 0);
              // Use per-student attendance when the key is present (even if it's 0). Fall back to total_attendance otherwise.
              if (det.containsKey('student_attendance')) {
                final val = det['student_attendance'];
                if (val is int) attendanceTotal += val;
                else if (val is num) attendanceTotal += val.toInt();
                else if (val is String) attendanceTotal += int.tryParse(val) ?? 0;
                else attendanceTotal += 0;
              } else {
                final val = det['total_attendance'];
                if (val is int) attendanceTotal += val;
                else if (val is num) attendanceTotal += val.toInt();
                else if (val is String) attendanceTotal += int.tryParse(val) ?? 0;
                else attendanceTotal += 0;
              }
            }
            if (mounted) setState(() {
              _enrolledCourses = List.from(enrolled);
              _enrolledSessionsTotal = sessionsTotal;
              _enrolledAttendanceTotal = attendanceTotal;
            });
          }
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
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => CourseSessionsScreen(course: course)));
    } else {
      // Students should see course details instead of opening the course list
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => CourseDetailScreen(course: course)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_role == 'student' ? 'Dashboard' : 'Courses'),
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
                      Text('Welcome, $_profileName', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Card(
                        margin: const EdgeInsets.symmetric(horizontal: 24),
                        child: Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              Column(children: [const Text('Courses'), const SizedBox(height:4), Text('${_enrolledCourses.length}')]),
                              Column(children: [const Text('Sessions'), const SizedBox(height:4), Text('$_enrolledSessionsTotal')]),
                              Column(children: [const Text('Attendance'), const SizedBox(height:4), Text('$_enrolledAttendanceTotal')]),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (_enrolledCourses.isNotEmpty)
                        SizedBox(
                          height: 120,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            itemCount: _enrolledCourses.length,
                            itemBuilder: (_, i) {
                              final c = _enrolledCourses[i];
                              final details = _courseDetails[c['id']] ?? {};
                              return Padding(
                                padding: const EdgeInsets.symmetric(horizontal:8.0),
                                child: InkWell(
                                  onTap: () => _onCourseTap(c),
                                  child: Card(
                                    child: Container(
                                      width: 220,
                                      padding: const EdgeInsets.all(12),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(c['course_name'] ?? c['name'] ?? 'Course', style: const TextStyle(fontWeight: FontWeight.bold)),
                                          const SizedBox(height:6),
                                          Text(c['course_code'] ?? ''),
                                          const Spacer(),
                                          Text('Sessions: ${details['total_sessions'] ?? _sessionCounts[c['id']] ?? 0} • Attendance: ${details.containsKey('student_attendance') ? (details['student_attendance'] is num ? (details['student_attendance'] as num).toInt() : (int.tryParse(details['student_attendance']?.toString() ?? '') ?? details['total_attendance'] ?? 0)) : (details['total_attendance'] ?? 0)}')
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      const SizedBox(height: 12),
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
