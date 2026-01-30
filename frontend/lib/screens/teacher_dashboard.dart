// ignore_for_file: use_build_context_synchronously

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../services/api_service.dart';
import '../services/permission_service.dart';
import '../state/theme_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/app_scaffold.dart';
import '../widgets/app_snackbar.dart';
import 'session_detail_screen.dart';
import 'teacher_session_screen_v2.dart';

class TeacherDashboardScreen extends ConsumerStatefulWidget {
  const TeacherDashboardScreen({super.key});

  @override
  ConsumerState<TeacherDashboardScreen> createState() => _TeacherDashboardScreenState();
}

class _TeacherDashboardScreenState extends ConsumerState<TeacherDashboardScreen> {
  final _api = ApiService();
  final _storage = const FlutterSecureStorage();
  final _searchController = TextEditingController();

  List<Map<String, dynamic>> _courses = [];
  bool _loading = true;
  int _totalSessions = 0;
  int _totalAttendance = 0;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _toast(String message, {SnackType type = SnackType.info}) {
    if (!mounted) return;
    showAppSnackBar(context, message, type: type);
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final token = await _storage.read(key: 'token');
      if (token == null) throw 'Session expired. Please log in again.';

      final courses = await _api.getCourses(token);
      int sessions = 0;
      int attendance = 0;
      final normalized = courses.map((c) => Map<String, dynamic>.from(c as Map)).toList();
      for (final c in normalized) {
        sessions += (c['total_sessions'] as int?) ?? 0;
        attendance += (c['total_attendance'] as int?) ?? 0;
      }

      if (!mounted) return;
      setState(() {
        _courses = normalized;
        _totalSessions = sessions;
        _totalAttendance = attendance;
      });
    } catch (e) {
      _toast('Failed to load dashboard: $e', type: SnackType.error);
      if (!mounted) return;
      setState(() {
        _courses = [];
        _totalAttendance = 0;
        _totalSessions = 0;
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openCourseSessions(Map<String, dynamic> course) async {
    final result = await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => CourseSessionsScreen(course: Map<String, dynamic>.from(course))),
    );
    if (result == true) await _load();
  }

  @override
  Widget build(BuildContext context) {
    final mode = ref.watch(themeProvider);
    final controller = ref.read(themeProvider.notifier);
    final theme = Theme.of(context);

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
        title: Text('Teacher • atDSU', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
        actions: [
          IconButton(
            icon: Icon(mode == ThemeMode.dark ? Icons.wb_sunny_rounded : Icons.nights_stay_rounded),
            onPressed: controller.toggle,
          ),
        ],
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _TeacherHeader(
                      courses: _courses.length,
                      sessions: _totalSessions,
                      attendance: _totalAttendance,
                    ),
                    const SizedBox(height: 18),
                    _SearchField(
                      controller: _searchController,
                      query: _searchQuery,
                      onChanged: (v) => setState(() => _searchQuery = v.trim()),
                      onClear: () {
                        _searchController.clear();
                        setState(() => _searchQuery = '');
                      },
                    ),
                    const SizedBox(height: 12),
                    if (filtered.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 32.0),
                        child: Center(child: Text('No courses match your search', style: theme.textTheme.bodyMedium)),
                      )
                    else
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: filtered.length,
                        itemBuilder: (_, i) {
                          final c = filtered[i];
                          return _TeacherCourseTile(
                            course: c,
                            onTap: () => _openCourseSessions(c),
                          );
                        },
                      ),
                  ],
                ),
              ),
            ),
    );
  }
}

class _TeacherHeader extends StatelessWidget {
  final int courses;
  final int sessions;
  final int attendance;
  const _TeacherHeader({required this.courses, required this.sessions, required this.attendance});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        gradient: AppTheme.gradient,
        borderRadius: BorderRadius.circular(22),
        boxShadow: AppTheme.glow,
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Insights', style: theme.textTheme.labelLarge?.copyWith(color: Colors.white70)),
          const SizedBox(height: 6),
          Text('Classroom pulse', style: theme.textTheme.headlineSmall?.copyWith(color: Colors.white, fontWeight: FontWeight.w800)),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(child: _StatPill(label: 'Courses', value: courses.toString())),
              const SizedBox(width: 8),
              Expanded(child: _StatPill(label: 'Sessions', value: sessions.toString())),
              const SizedBox(width: 8),
              Expanded(child: _StatPill(label: 'Attendance', value: attendance.toString())),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 120,
            child: BarChart(
              BarChartData(
                barTouchData: BarTouchData(enabled: false),
                gridData: FlGridData(show: false),
                titlesData: FlTitlesData(show: false),
                borderData: FlBorderData(show: false),
                barGroups: [
                  BarChartGroupData(x: 0, barRods: [BarChartRodData(toY: courses.toDouble(), color: Colors.white, width: 16, borderRadius: BorderRadius.circular(6))]),
                  BarChartGroupData(x: 1, barRods: [BarChartRodData(toY: sessions.toDouble().clamp(0, 30), color: Colors.white.withAlpha((255 * 0.9).round()), width: 16, borderRadius: BorderRadius.circular(6))]),
                  BarChartGroupData(x: 2, barRods: [BarChartRodData(toY: attendance.toDouble().clamp(0, 60), color: Colors.white70, width: 16, borderRadius: BorderRadius.circular(6))]),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;
  final String query;

  const _SearchField({required this.controller, required this.query, required this.onChanged, required this.onClear});

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
          prefixIcon: const Icon(Icons.search_rounded),
          suffixIcon: query.isNotEmpty
              ? IconButton(icon: const Icon(Icons.close_rounded), onPressed: onClear)
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

class _TeacherCourseTile extends StatelessWidget {
  final Map<String, dynamic> course;
  final VoidCallback onTap;
  const _TeacherCourseTile({required this.course, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final code = course['course_code']?.toString() ?? '';
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
                  width: 50,
                  height: 50,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: AppTheme.accentGradient,
                  ),
                  child: Center(child: Text(code.isNotEmpty ? code[0] : '?', style: theme.textTheme.titleLarge?.copyWith(color: Colors.white, fontWeight: FontWeight.bold))),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name.toString(), style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 6),
                      Text(code, style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey)),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded),
              ],
            ),
          ),
        ),
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

class CourseSessionsScreen extends StatefulWidget {
  final Map<String, dynamic> course;
  const CourseSessionsScreen({super.key, required this.course});

  @override
  State<CourseSessionsScreen> createState() => _CourseSessionsScreenState();
}

class _CourseSessionsScreenState extends State<CourseSessionsScreen> {
  final _api = ApiService();
  List<Map<String, dynamic>> _sessions = [];
  bool _loading = true;

  void _toast(String message, {SnackType type = SnackType.info}) {
    if (!mounted) return;
    showAppSnackBar(context, message, type: type);
  }

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
      int studentCount = 0;
      try {
        final students = await _api.getCourseStudents(widget.course['id']);
        studentCount = students.length;
      } catch (_) {}
      if (!mounted) return;
      setState(() {
        _sessions = sessions.map((s) => Map<String, dynamic>.from(s as Map)).toList();
        widget.course['teacher_profile'] = details['teacher'];
        widget.course['total_sessions'] = details['total_sessions'];
        widget.course['total_attendance'] = details['total_attendance'];
        widget.course['student_count'] = studentCount;
      });
    } catch (e) {
      _toast('Failed to load sessions: $e', type: SnackType.error);
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _startSessionFromCourse() async {
    try {
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

      try {
        final sessions = await _api.getCourseSessions(widget.course['id']);
        final active = sessions.firstWhere((s) => s['is_active'] == true, orElse: () => null);
        if (active != null) {
          if (!mounted) return;
          _toast('Active session exists: Session ${active['session_number'] ?? ''}', type: SnackType.info);
          return;
        }
      } catch (_) {}

      final sid = await _api.startSession(token, widget.course['id'], (widget.course['total_sessions'] as int? ?? 0) + 1);
      if (!mounted) return;
      final res = await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => TeacherSessionScreenV2(course: widget.course, initialSessionId: sid)),
      );
      if (res == true) {
        await _load();
      }
    } catch (e) {
      if (!mounted) return;
      _toast('Failed to start session: $e', type: SnackType.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final teacher = widget.course['teacher_profile'] as Map<String, dynamic>?;
    final totalSessions = widget.course['total_sessions'] ?? 0;
    final totalAttendance = widget.course['total_attendance'] ?? 0;

    final theme = Theme.of(context);

    return AppScaffold(
      padded: false,
      appBar: AppBar(
        title: Text(widget.course['course_name'] ?? 'Course', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Stack(
              children: [
                SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          gradient: AppTheme.gradient,
                          borderRadius: BorderRadius.circular(22),
                          boxShadow: AppTheme.glow,
                        ),
                        padding: const EdgeInsets.all(18),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(widget.course['course_code'] ?? '',
                                          style: theme.textTheme.labelLarge?.copyWith(color: Colors.white70)),
                                      const SizedBox(height: 6),
                                      Text(widget.course['course_name'] ?? 'Course',
                                          style: theme.textTheme.headlineSmall?.copyWith(color: Colors.white, fontWeight: FontWeight.w800)),
                                      const SizedBox(height: 4),
                                      Text('Teacher: ${teacher != null ? (teacher['full_name'] ?? teacher['email']) : 'Unknown'}',
                                          style: theme.textTheme.bodyMedium?.copyWith(color: Colors.white70)),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            Row(
                              children: [
                                _StatPill(label: 'Students', value: '${widget.course['student_count'] ?? 0}'),
                                const SizedBox(width: 8),
                                _StatPill(label: 'Sessions', value: '$totalSessions'),
                                const SizedBox(width: 8),
                                _StatPill(label: 'Attendance', value: '$totalAttendance'),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text('Sessions', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 8),
                      _sessions.isEmpty
                          ? Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(color: theme.cardColor, borderRadius: BorderRadius.circular(16)),
                              child: Row(
                                children: [
                                  Icon(Icons.event_busy_rounded, color: theme.colorScheme.primary),
                                  const SizedBox(width: 12),
                                  Text('No sessions yet. Start one to begin attendance.', style: theme.textTheme.bodyMedium),
                                ],
                              ),
                            )
                          : ListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: _sessions.length,
                              itemBuilder: (_, i) {
                                final s = _sessions[i];
                                final cnt = s['attendance_count'] ?? 0;
                                final isActive = s['is_active'] == true;
                                return Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 6.0),
                                  child: Material(
                                    color: theme.cardColor,
                                    borderRadius: BorderRadius.circular(16),
                                    child: InkWell(
                                      borderRadius: BorderRadius.circular(16),
                                      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => SessionDetailScreen(session: s))),
                                      child: Padding(
                                        padding: const EdgeInsets.all(14.0),
                                        child: Row(
                                          children: [
                                            Container(
                                              width: 44,
                                              height: 44,
                                              decoration: BoxDecoration(
                                                shape: BoxShape.circle,
                                                color: isActive
                                                    ? theme.colorScheme.primary.withAlpha((255 * 0.15).round())
                                                    : Colors.grey.withAlpha((255 * 0.15).round()),
                                              ),
                                              child: Icon(
                                                isActive ? Icons.wifi_tethering_rounded : Icons.flag_rounded,
                                                color: isActive ? theme.colorScheme.primary : Colors.grey,
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text('Session ${s['session_number'] ?? ''}',
                                                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                                                  const SizedBox(height: 4),
                                                  Text(isActive ? 'Active now' : 'Ended',
                                                      style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey)),
                                                  const SizedBox(height: 6),
                                                  Text('$cnt attendees', style: theme.textTheme.bodyMedium),
                                                ],
                                              ),
                                            ),
                                            const Icon(Icons.chevron_right_rounded),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                      const SizedBox(height: 96),
                    ],
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 20,
                  child: Center(
                    child: SizedBox(
                      width: 240,
                      child: ElevatedButton.icon(
                        onPressed: _loading ? null : _startSessionFromCourse,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                          elevation: 8,
                          shadowColor: theme.colorScheme.primary.withAlpha(120),
                        ),
                        icon: const Icon(Icons.play_arrow_rounded),
                        label: const Text('Start attendance'),
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
