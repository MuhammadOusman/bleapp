import 'package:flutter/material.dart';
// ignore_for_file: curly_braces_in_flow_control_structures, use_build_context_synchronously

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../services/api_service.dart';
import '../services/sync_service.dart';
import '../services/device_service.dart';
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
            final id = r['id'] as String;
            final cnt = int.tryParse(r['count']?.toString() ?? '') ?? 0;
            counts[id] = cnt;
            detailsMap[id] = Map<String, dynamic>.from(r['details'] as Map);
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

            // Fetch sessions for each course to compute per-student attendance reliably
            try {
              final sessionFutures = enrolled.map((c) => _api.getCourseSessions(c['id']));
              final sessionsResults = await Future.wait(sessionFutures);

              for (var i = 0; i < enrolled.length; i++) {
                final c = enrolled[i];
                final det = detailsMap[c['id']] ?? {};

                sessionsTotal += (det['total_sessions'] as int?) ?? (counts[c['id']] ?? 0);

                final sessForCourseList = (sessionsResults[i] as List<dynamic>?) ?? <dynamic>[];
                final studentAtt = sessForCourseList.where((s) => s['student_attended'] == true).length;

                // Store student_attendance into detailsMap so UI can prefer it
                detailsMap[c['id']] = {...det, 'student_attendance': studentAtt};

                attendanceTotal += studentAtt;
              }
            } catch (e) {
              // If fetching sessions fails, fall back to previous logic
              for (var c in enrolled) {
                final det = detailsMap[c['id']] ?? {};
                sessionsTotal += (det['total_sessions'] as int?) ?? (counts[c['id']] ?? 0);
                if (det.containsKey('student_attendance')) {
                  final val = det['student_attendance'];
                  if (val is int) attendanceTotal += val;
                  else if (val is num) attendanceTotal += val.toInt();
                  else if (val is String) attendanceTotal += int.tryParse(val) ?? 0;
                } else {
                  final val = det['total_attendance'];
                  if (val is int) attendanceTotal += val;
                  else if (val is num) attendanceTotal += val.toInt();
                  else if (val is String) attendanceTotal += int.tryParse(val) ?? 0;
                }
              }
            }

            if (mounted) setState(() {
              _enrolledCourses = List.from(enrolled);
              _enrolledSessionsTotal = sessionsTotal;
              _enrolledAttendanceTotal = attendanceTotal;
              _courseDetails = detailsMap; // persist updated student_attendance entries
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

  void _onCourseTap(Map<String, dynamic> course) {
    if (_role == 'teacher') {
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => CourseSessionsScreen(course: course)));
    } else {
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => CourseDetailScreen(course: course)));
    }
  }

  // ignore: unused_element
  Future<void> _markAttendanceForCourse(Map<String, dynamic> course) async {
    final courseId = course['id'] as String;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();

    try {
      final sessions = await _api.getCourseSessions(courseId);
      if (sessions.isEmpty) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No sessions found for this course')));
        return;
      }

      Map<String, dynamic>? active;
      for (var s in sessions) {
        if (s is Map && s['is_active'] == true) {
          active = Map<String, dynamic>.from(s);
          break;
        }
      }
      active ??= Map<String, dynamic>.from(sessions.first as Map);

      final sessionId = active['id'];
      final already = active['student_attended'] == true;
      if (already) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('You already marked attendance for this session')));
        return;
      }

      final sig = await DeviceService.getDeviceSignature();
      try {
        await _api.markAttendance(sessionId, sig);
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Attendance marked ✅')));
        await _refreshCourseAfterMark(courseId);
      } catch (e) {
        final msg = e.toString();
        if (msg.contains('410') || msg.toLowerCase().contains('expired')) {
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Session expired or inactive')));
        } else if (msg.toLowerCase().contains('already marked')) {
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('You already marked attendance')));
        } else {
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to mark attendance: $e')));
        }
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error marking attendance: $e')));
    }
  }

  Future<void> _refreshCourseAfterMark(String courseId) async {
    try {
      final details = await _api.getCourseDetails(courseId);
      final sessions = await _api.getCourseSessions(courseId);
      final studentAtt = sessions.where((s) => s['student_attended'] == true).length;
      final merged = {...details, 'student_attendance': studentAtt};

      if (mounted) setState(() {
        _courseDetails[courseId] = Map<String, dynamic>.from(merged);
        _sessionCounts[courseId] = merged['total_sessions'] as int? ?? _sessionCounts[courseId] ?? 0;
      });

      if (_role == 'student') await _computeStudentTotals();
    } catch (e) {
      debugPrint('[Courses] refreshCourseAfterMark failed: $e');
    }
  }

  Future<void> _computeStudentTotals() async {
    final enrolled = _courses;
    int sessionsTotal = 0;
    int attendanceTotal = 0;

    try {
      final sessionFutures = enrolled.map((c) => _api.getCourseSessions(c['id'])).toList();
      final sessionsResults = await Future.wait(sessionFutures);

      for (var i = 0; i < enrolled.length; i++) {
        final c = enrolled[i];
        final det = _courseDetails[c['id']] ?? {};
        sessionsTotal += (det['total_sessions'] as int?) ?? (_sessionCounts[c['id']] ?? 0);

        final sessForCourseList = (sessionsResults[i] as List<dynamic>?) ?? <dynamic>[];
        final studentAtt = sessForCourseList.where((s) => s['student_attended'] == true).length;
        attendanceTotal += studentAtt;

        _courseDetails[c['id']] = {...det, 'student_attendance': studentAtt};
      }
    } catch (e) {
      for (var c in enrolled) {
        final det = _courseDetails[c['id']] ?? {};
        sessionsTotal += (det['total_sessions'] as int?) ?? (_sessionCounts[c['id']] ?? 0);
        final val = det['student_attendance'] ?? det['total_attendance'] ?? 0;
        if (val is int) attendanceTotal += val;
        else if (val is num) attendanceTotal += val.toInt();
        else if (val is String) attendanceTotal += int.tryParse(val) ?? 0;
      }
    }

    if (mounted) setState(() {
      _enrolledCourses = List.from(enrolled);
      _enrolledSessionsTotal = sessionsTotal;
      _enrolledAttendanceTotal = attendanceTotal;
    });
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
