// ignore_for_file: curly_braces_in_flow_control_structures, use_build_context_synchronously

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter/cupertino.dart';

import '../services/api_service.dart';
import '../services/device_service.dart';
import '../services/sync_service.dart';
import '../state/theme_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/app_scaffold.dart';
import '../widgets/app_snackbar.dart';
import 'course_detail_screen.dart';
import 'student_session_scanner.dart';
import 'teacher_dashboard.dart';


class CoursesScreen extends ConsumerStatefulWidget {
  const CoursesScreen({super.key});

  @override
  ConsumerState<CoursesScreen> createState() => _CoursesScreenState();
}

class _CoursesScreenState extends ConsumerState<CoursesScreen> {
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

  String _deriveDisplayName(Map<String, dynamic> profile) {
    final full = profile['full_name']?.toString().trim();
    if (full != null && full.isNotEmpty) return full;

    final email = profile['email']?.toString().trim() ?? '';
    if (email.isEmpty) return 'Student';

    const domain = '@dsu.edu.pk';
    final lower = email.toLowerCase();
    if (lower.endsWith(domain)) {
      return email.substring(0, email.length - domain.length);
    }

    final atIdx = email.indexOf('@');
    return atIdx > 0 ? email.substring(0, atIdx) : email;
  }

  String _sanitizeCachedName(String? cached) {
    if (cached == null || cached.trim().isEmpty) return 'Student';
    final name = cached.trim();
    const domain = '@dsu.edu.pk';
    final lower = name.toLowerCase();
    if (lower.endsWith(domain)) {
      return name.substring(0, name.length - domain.length);
    }
    return name;
  }

  void _toast(String message, {SnackType type = SnackType.info}) {
    if (!mounted) return;
    showAppSnackBar(context, message, type: type);
  }

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
      // Show a cached profile name immediately so the header isn't "Student" while loading
      try {
        final cachedName = await _storage.read(key: 'profile_full_name');
        final sanitized = _sanitizeCachedName(cachedName);
        if (sanitized.isNotEmpty && mounted) setState(() => _profileName = sanitized);
      } catch (_) {}

      // Set role immediately so teacher view appears even if network call fails
      setState(() => _role = role);

      // Run background auto-sync now (do not await blocking the UI)
      // This ensures pending snapshots & devices are processed once on app open.
      // We run silently and log results.
      try {
        SyncService.runAutoSync();
      } catch (_) {}

      // Fetch the latest profile to display the student's name (or email) as soon as possible
      try {
        final profile = await _api.getProfile();
        final fetchedName = _deriveDisplayName(profile);
        try {
          await _storage.write(key: 'profile_full_name', value: fetchedName);
        } catch (_) {}
        if (mounted) setState(() => _profileName = fetchedName);
      } catch (_) {}

      try {
        final courses = await _api.getCourses(token);

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
          _toast('Failed to load course details: $e', type: SnackType.error);
        }
      } catch (e) {
        if (!mounted) return;
        _toast('Failed to load courses: $e', type: SnackType.error);
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
      _toast('Refresh failed: $e', type: SnackType.error);
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
    final mode = ref.watch(themeProvider);
    final themeController = ref.read(themeProvider.notifier);
    final theme = Theme.of(context);
    final isStudent = _role == 'student';
    final completion = _enrolledSessionsTotal == 0
        ? 0.0
        : (_enrolledAttendanceTotal / _enrolledSessionsTotal).clamp(0.0, 1.0);

    final q = _searchQuery.toLowerCase();
    final filtered = _courses.where((c) {
      if (q.isEmpty) return true;
      final name = (c['course_name'] ?? c['name'] ?? '').toString().toLowerCase();
      final code = (c['course_code'] ?? '').toString().toLowerCase();
      return name.contains(q) || code.contains(q);
    }).toList();

    return AppScaffold(
      padded: false,
      appBar: AppBar(
        title: Text(isStudent ? 'atDSU' : 'Courses', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
        actions: [
          IconButton(
            icon: Icon(mode == ThemeMode.dark ? CupertinoIcons.sun_max_fill : CupertinoIcons.moon_fill),
            onPressed: themeController.toggle,
            tooltip: 'Toggle theme',
          ),
          if (!isStudent)
            IconButton(
              icon: const Icon(Icons.dashboard_customize_rounded),
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const TeacherDashboardScreen())),
              tooltip: 'Teacher dashboard',
            ),
        ],
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _GlassHeader(
                    name: _profileName,
                    isStudent: isStudent,
                    courses: isStudent ? _enrolledCourses.length : _courses.length,
                    sessions: isStudent ? _enrolledSessionsTotal : _sessionCounts.values.fold<int>(0, (a, b) => a + b),
                    attendance: isStudent ? _enrolledAttendanceTotal : _courseDetails.values.fold<int>(0, (a, b) => a + ((b['total_attendance'] ?? 0) as int)),
                    completion: completion,
                    onScan: isStudent ? _openStudentScanner : null,
                  ),
                  const SizedBox(height: 18),
                  _SearchField(
                    controller: _searchController,
                    onChanged: (v) => setState(() => _searchQuery = v.trim()),
                    onClear: () => setState(() => _searchQuery = ''),
                  ),
                  const SizedBox(height: 12),
                  if (filtered.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24.0),
                      child: Center(
                        child: Column(
                          children: [
                            Icon(CupertinoIcons.search, size: 48, color: Colors.grey.shade500),
                            const SizedBox(height: 10),
                            Text('No courses match that search', style: theme.textTheme.bodyMedium),
                            const SizedBox(height: 12),
                            OutlinedButton(onPressed: _load, child: const Text('Refresh')),
                          ],
                        ),
                      ),
                    )
                  else
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: filtered.length,
                      itemBuilder: (_, i) {
                        final c = filtered[i];
                        final details = _courseDetails[c['id']] ?? {};
                        final teacher = details['teacher'] as Map<String, dynamic>?;
                        final totalSessions = _sessionCounts[c['id']] ?? (details['total_sessions'] ?? 0);
                        final attendance = details['student_attendance'] ?? details['total_attendance'] ?? 0;
                        return _CourseCard(
                          course: c,
                          teacher: teacher,
                          sessions: totalSessions,
                          attendance: attendance is num ? attendance.toInt() : int.tryParse(attendance.toString()) ?? 0,
                          onTap: () => _onCourseTap(c),
                        );
                      },
                    ),
                ],
              ),
            ),
      bottomBar: isStudent
          ? SafeArea(
              minimum: const EdgeInsets.fromLTRB(18, 0, 18, 18),
              child: ElevatedButton.icon(
                onPressed: _openStudentScanner,
                icon: const Icon(Icons.radar_rounded),
                label: const Text('Scan for Sessions'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Colors.white,
                ),
              ),
            )
          : null,
    );
  }
}

class _GlassHeader extends StatelessWidget {
  final String name;
  final bool isStudent;
  final int courses;
  final int sessions;
  final int attendance;
  final double completion;
  final VoidCallback? onScan;

  const _GlassHeader({
    required this.name,
    required this.isStudent,
    required this.courses,
    required this.sessions,
    required this.attendance,
    required this.completion,
    this.onScan,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        gradient: AppTheme.gradient,
        borderRadius: BorderRadius.circular(24),
        boxShadow: AppTheme.glow,
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(isStudent ? 'Welcome,' : 'Overview', style: theme.textTheme.labelLarge?.copyWith(color: Colors.white70)),
                  Text(name, style: theme.textTheme.headlineSmall?.copyWith(color: Colors.white, fontWeight: FontWeight.w800)),
                ],
              ),
              if (onScan != null)
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: onScan,
                  icon: const Icon(Icons.radar_rounded),
                  label: const Text('Scan'),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _StatPill(label: 'Courses', value: courses.toString()),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _StatPill(label: 'Sessions', value: sessions.toString()),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _StatPill(label: 'Attendance', value: attendance.toString()),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 140,
            child: Row(
              children: [
                Expanded(
                  child: PieChart(
                    PieChartData(
                      sectionsSpace: 0,
                      centerSpaceRadius: 34,
                      startDegreeOffset: -90,
                      sections: [
                        PieChartSectionData(
                          value: completion * 100,
                          color: Colors.white,
                          radius: 18,
                          title: '',
                        ),
                        PieChartSectionData(
                          value: (1 - completion) * 100,
                          color: Colors.white.withAlpha((255 * 0.18).round()),
                          radius: 14,
                          title: '',
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('Presence health', style: theme.textTheme.titleMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 6),
                      Text('${(completion * 100).toStringAsFixed(0)}% attendance logged', style: theme.textTheme.bodyMedium?.copyWith(color: Colors.white70)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatPill extends StatelessWidget {
  final String label;
  final String value;
  const _StatPill({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha((255 * 0.18).round()),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: theme.textTheme.labelSmall?.copyWith(color: Colors.white70)),
          const SizedBox(height: 6),
          Text(value, style: theme.textTheme.titleLarge?.copyWith(color: Colors.white, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  const _SearchField({required this.controller, required this.onChanged, required this.onClear});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [BoxShadow(color: Color(0x14000000), blurRadius: 12, offset: Offset(0, 8))],
      ),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        decoration: InputDecoration(
          hintText: 'Search courses by name or code',
            prefixIcon: const Icon(CupertinoIcons.search),
            suffixIcon: controller.text.isNotEmpty
              ? IconButton(icon: const Icon(Icons.clear_rounded), onPressed: onClear)
              : null,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          filled: true,
          fillColor: Colors.transparent,
        ),
      ),
    );
  }
}

class _CourseCard extends StatelessWidget {
  final Map course;
  final Map<String, dynamic>? teacher;
  final int sessions;
  final int attendance;
  final VoidCallback onTap;

  const _CourseCard({required this.course, required this.teacher, required this.sessions, required this.attendance, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final code = course['course_code'] ?? '';
    final name = course['course_name'] ?? course['name'] ?? 'Course';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Material(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: AppTheme.accentGradient,
                  ),
                  child: Center(child: Text(code.isNotEmpty ? code[0] : '?', style: theme.textTheme.titleLarge?.copyWith(color: Colors.white, fontWeight: FontWeight.bold))),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 4),
                      Text(code, style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey)),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          _Badge(icon: Icons.schedule_rounded, label: '$sessions sessions'),
                          const SizedBox(width: 8),
                          _Badge(icon: Icons.check_circle_rounded, label: '$attendance attendance'),
                        ],
                      ),
                      if (teacher != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Text('Teacher: ${teacher?['full_name'] ?? teacher?['email'] ?? 'TBD'}', style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey.shade600)),
                        ),
                    ],
                  ),
                ),
                const Icon(Icons.arrow_forward_ios_rounded, size: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final IconData icon;
  final String label;
  const _Badge({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withAlpha((255 * 0.08).round()),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: theme.colorScheme.primary),
          const SizedBox(width: 6),
          Text(label, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.primary, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
