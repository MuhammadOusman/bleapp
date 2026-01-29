import 'dart:async';
import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/api_service.dart';
import '../services/ble_service.dart';
import '../services/permission_service.dart';
import '../services/local_store.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'attendance_review_screen.dart';

class TeacherSessionScreenV2 extends StatefulWidget {
  final Map course;
  const TeacherSessionScreenV2({super.key, required this.course});

  @override
  State<TeacherSessionScreenV2> createState() => _TeacherSessionScreenV2State();
}

class _TeacherSessionScreenV2State extends State<TeacherSessionScreenV2> {
  final _api = ApiService();
  final _ble = BleService();
  final _storage = const FlutterSecureStorage();

  String? _sessionId;

  int _sessionsCount = 0;
  static const int kMaxSessions = 16;

  // Search state for enrolled students list
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  bool _scanning = false;

  // Elapsed seconds counter for open attendance
  int _elapsedSeconds = 0;
  Timer? _elapsedTimer;
  // _students: list of enrolled students (populated when session starts)
  List<Map<String, dynamic>> _students = []; // { student_id, name, present, discovered_at, synced }

  // Detected devices that could not be resolved to an enrolled student
  List<Map<String, dynamic>> _detected = []; // { device_signature, discovered_at, approved, synced }

  StreamSubscription<dynamic>? _connSub;
  bool _syncing = false;

  // Poll timer for realtime fallback
  Timer? _realtimeTimer;

  @override
  void initState() {
    super.initState();
    _loadPending();
    // Ensure session count is loaded immediately when opening this screen
    _loadSessionCount();

    _connSub = Connectivity().onConnectivityChanged.listen((dynamic result) {
      // On some platforms the stream emits a List<ConnectivityResult>, on others a single ConnectivityResult
      if (result is List) {
        final anyOnline = result.any((r) => r != ConnectivityResult.none);
        if (anyOnline) _autoSync();
      } else if (result is ConnectivityResult) {
        if (result != ConnectivityResult.none) _autoSync();
      }
    });

    // On startup check for unsynced snapshots and trigger sync check
    _checkUnsyncedSnapshots();
  }

  @override
  void dispose() {
    _ble.stopBeacon();
    _ble.stopScan();
    _connSub?.cancel();
    try {
      _realtimeTimer?.cancel();
      _realtimeTimer = null;
    } catch (_) {}
    // Dispose controllers
    try {
      _searchController.dispose();
    } catch (_) {}
    super.dispose();
  }

  Future<void> _startSession() async {
    final token = await _storage.read(key: 'token');
    if (token == null) return;

    final allowed = await PermissionService.requestBlePermissions();
    if (!allowed) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Bluetooth permissions are required')));
      await PermissionService.openAppSettingsIfNeeded();
      return;
    }

    final sid = await _api.startSession(token, widget.course['id'], 1);
    setState(() {
      _sessionId = sid;
    });
    // Refresh the session count since a session was just started
    _loadSessionCount();

    // Load enrolled students for the course and initialize as absent
    try {
      final students = await _api.getCourseStudents(widget.course['id']);
      setState(() {
        _students = students.map<Map<String, dynamic>>((s) => {
          'student_id': s['id'],
          'name': (s['full_name'] ?? s['email'] ?? 'Student') as String,
          'present': false,
          'discovered_at': null,
          'synced': false,
        }).toList();
      });
    } catch (e) {
      print('[Start] failed to load students: $e');
    }

    // Poll attendance table every 2s for this session (simple realtime fallback)
    _realtimeTimer = Timer.periodic(const Duration(seconds: 2), (t) async {
      try {
        final resp = await Supabase.instance.client.from('attendance').select('id,student_id,marked_at,device_signature').eq('session_id', sid);
        // Debugging: log raw response and type
        try {
          print('[Poll] rawResp type=${resp.runtimeType} value=$resp');
        } catch (_) {}

        final rows = (resp as List<dynamic>?) ?? [];
        print('[Poll] fetched ${rows.length} rows for session=$sid');
        for (var r in rows) {
          final studentId = r['student_id'];
          final exists = _detected.any((d) => d['student_id'] == studentId);
          if (!exists) {
            // best-effort fetch profile name
            final profileRes = await Supabase.instance.client.from('profiles').select('id,full_name').eq('id', studentId).limit(1);
            final profiles = (profileRes as List<dynamic>?) ?? [];
            final name = profiles.isNotEmpty ? (profiles[0]['full_name'] as String? ?? 'Student') : 'Student';
            setState(() {
              _detected.add({
                'session_id': sid,
                'student_id': studentId,
                'device_signature': r['device_signature'] ?? 'unknown',
                'discovered_at': r['marked_at'] ?? DateTime.now().toIso8601String(),
                'approved': true,
                'synced': true,
                'name': name,
              });
            });
          }
        }
      } catch (e) {
        print('[Poll] error: $e');
      }
    });
    final status = await _ble.checkTransmissionSupport();
    if (!status) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Device does not support BLE advertising')));
      return;
    }

    await _ble.startBeacon(sid);

    // Start elapsed seconds timer (counts up until End Attendance)
    _elapsedSeconds = 0;
    _elapsedTimer?.cancel();
    _elapsedTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      setState(() => _elapsedSeconds += 1);
    });

    // Ensure we are scanning continuously for students while session is active
    if (!_scanning) await _startScanForStudents();
  }

  Future<void> _startScanForStudents() async {
    if (_sessionId == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Start a session first')));
      return;
    }

    final allowed = await PermissionService.requestBlePermissions();
    if (!allowed) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Bluetooth/Location permissions are required')));
      await PermissionService.openAppSettingsIfNeeded();
      return;
    }

    setState(() { _scanning = true; });
    try {
      _ble.startScan((uuid, minor) async {
        // Filter for Student broadcasts only
        if (minor != BleService.kStudentMinorId) return;

        final sig = uuid;
        final now = DateTime.now().toIso8601String();

        // Try resolving to a student profile
        try {
          final profile = await _api.resolveAdvertised(sig);
          if (profile != null) {
            // If the profile matches an enrolled student, mark them present
            final idx = _students.indexWhere((s) => s['student_id'] == profile['id']);
            if (idx >= 0) {
              if (!_students[idx]['present']) {
                _students[idx]['present'] = true;
                _students[idx]['discovered_at'] = now;
                _students[idx]['synced'] = false;
                await LocalStore.updatePending(_students);
                if (mounted) setState(() {});
              }
              return;
            }

            // Not enrolled in this course, add to unknown detected list
            final exists = _detected.any((d) => d['device_signature'] == sig);
            if (!exists) {
              final item = {
                'session_id': _sessionId,
                'device_signature': sig,
                'discovered_at': now,
                'approved': false,
                'synced': false,
                'name': profile['full_name'] ?? profile['email'] ?? 'Student',
                'resolved': true,
              };
              setState(() => _detected.add(item));
              await LocalStore.addPending(item);
            }
            return;
          }
        } catch (e) {
          print('[Scan] resolve error: $e');
        }

        // Fallback: add raw signature to unknown list
        final exists2 = _detected.any((d) => d['device_signature'] == sig);
        if (!exists2) {
          final item = {
            'session_id': _sessionId,
            'device_signature': sig,
            'discovered_at': now,
            'approved': false,
            'synced': false,
            'name': null,
            'resolved': false,
          };
          setState(() => _detected.add(item));
          await LocalStore.addPending(item);
        }
      });
    } catch (e) {
      // Friendly message when Bluetooth is off
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Bluetooth must be turned on to scan.')));
    }

    // Keep scanning until explicitly stopped by End Attendance
    setState(() { _scanning = true; });
  }

  Future<void> _stopScanForStudents() async {
    try {
      _ble.stopScan();
    } catch (_) {}
    setState(() { _scanning = false; });
  }

  Future<void> _loadPending() async {
    final items = await LocalStore.loadPending();
    setState(() => _detected = items);
    _loadSessionCount();
  }

  Future<void> _refreshAttendance() async {
    if (_sessionId == null) return;
    final sid = _sessionId!;
    try {
      final resp = await Supabase.instance.client.from('attendance').select('id,student_id,created_at').eq('session_id', sid);
      print('[Refresh] rawResp type=${resp.runtimeType} value=$resp');
      final rows = (resp as List<dynamic>?) ?? [];
      print('[Refresh] fetched ${rows.length} rows');
      for (var r in rows) {
        final studentId = r['student_id'];
        final exists = _detected.any((d) => d['student_id'] == studentId);
        if (!exists) {
          final profileRes = await Supabase.instance.client.from('profiles').select('id,full_name').eq('id', studentId).limit(1);
          final profiles = (profileRes as List<dynamic>?) ?? [];
          final name = profiles.isNotEmpty ? (profiles[0]['full_name'] as String? ?? 'Student') : 'Student';
          setState(() {
            _detected.add({
              'session_id': _sessionId ?? '',
              'student_id': studentId,
                'device_signature': 'unknown', // device_signature column not present in DB
              'discovered_at': r['created_at'] ?? DateTime.now().toIso8601String(),
              'approved': true,
              'synced': true,
              'name': name,
            });
          });
        }
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Refreshed: ${rows.length} rows found')));
    } catch (e) {
      print('[Refresh] error: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Refresh failed: $e')));
    }
  }

  Future<void> _loadSessionCount() async {
    try {
      final cnt = await _api.getSessionCount(widget.course['id']);
      if (mounted) setState(() => _sessionsCount = cnt);
    } catch (e) {
      print('[SessionCount] failed to load for course ${widget.course['id']}: $e');
    }
  }

  // Convert raw session rows into a user-friendly count within 0..kMaxSessions
  int _sessionsDisplayCount() {
    final raw = _sessionsCount;
    if (raw == 0) return 0;
    final rem = raw % kMaxSessions;
    return rem == 0 ? kMaxSessions : rem;
  }

  Future<void> _toggleApprove(int idx) async {
    setState(() => _detected[idx]['approved'] = !_detected[idx]['approved']);
    await LocalStore.updatePending(_detected);
  }

  Future<void> _syncApproved() async {
    // Legacy: sync unknown detected devices approved by teacher
    final approved = _detected.where((d) => d['approved'] == true && d['synced'] != true).toList();
    if (approved.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No approved items to sync')));
      return;
    }

    for (var item in approved) {
      try {
        await _api.markAttendanceByTeacher(item['session_id'], item['device_signature']);
        item['synced'] = true;
      } on Exception catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Sync failed: $e')));
      }
    }
    await LocalStore.updatePending(_detected);
    setState(() {});
  }

  Future<void> _syncPresent() async {
    if (_sessionId == null) return;
    final toSync = _students.where((s) => s['present'] == true && s['synced'] != true).toList();
    if (toSync.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No present students to sync')));
      return;
    }

    for (var s in toSync) {
      try {
        await _api.approveStudentById(_sessionId!, s['student_id']);
        s['synced'] = true;
      } on Exception catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Sync failed: $e')));
      }
    }

    await LocalStore.updatePending(_students);
    setState(() {});
  }

  Future<void> _autoSync() async {
    if (_syncing) return;
    // 1) Sync legacy pending approved devices
    final pending = await LocalStore.loadPending();
    final need = pending.where((d) => d['approved'] == true && d['synced'] != true).toList();
    if (need.isNotEmpty) {
      _syncing = true;
      await _syncApproved();
      _syncing = false;
    }

    // 2) Sync attendance snapshots
    final snapshots = await LocalStore.loadAttendanceSnapshots();
    final needSnap = snapshots.where((s) => s['synced'] != true).toList();
    if (needSnap.isEmpty) return;

    // Inform user and begin syncing
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Syncing attendance, don't close app")));

    _syncing = true;
    for (var snap in needSnap) {
      try {
        final sessionId = snap['session_id'];
        final students = (snap['students'] as List<dynamic>?) ?? [];
        for (var st in students) {
          if (st['present'] == true) {
            await _api.approveStudentById(sessionId, st['student_id']);
          }
        }
        // mark snapshot as synced
        snap['synced'] = true;
      } catch (e) {
        print('[AutoSync] failed snapshot sync: $e');
      }
    }
    await LocalStore.updateAttendanceSnapshots(snapshots);
    _syncing = false;
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Attendance sync complete')));
  }

  Future<void> _syncAll() async {
    final pending = await LocalStore.loadPending();
    final toSync = pending.where((d) => d['synced'] != true).toList();
    if (toSync.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No items to sync')));
      return;
    }
    for (var item in toSync) {
      try {
        await _api.markAttendanceByTeacher(item['session_id'], item['device_signature']);
        item['synced'] = true;
      } on Exception catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Sync failed: $e')));
      }
    }
    await LocalStore.updatePending(_detected);
    setState(() {});
  }

  Future<void> _checkUnsyncedSnapshots() async {
    try {
      final snaps = await LocalStore.loadAttendanceSnapshots();
      final need = snaps.where((s) => s['synced'] != true).toList();
      if (need.isNotEmpty) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Device restart (not synced): syncing previous attendance pls wait.')));
        _autoSync();
      }
    } catch (e) {
      // ignore
    }
  }

  Future<void> _checkAdvertise() async {
    // Quick roundtrip test: start beacon and scan locally
    final token = await _storage.read(key: 'token');
    if (_sessionId == null) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Start a session first')));
      return;
    }
    final sid = _sessionId!;
    final canAdvertise = await _ble.checkTransmissionSupport();
    if (!canAdvertise) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Device does not support advertising')));
      return;
    }

    final started = await _ble.startBeacon(sid);
    if (!started) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Beacon start failed')));
      return;
    }

    // scan for 5 seconds to detect our own adv
    bool found = false;
    final completer = Completer<bool>();
    _ble.startScan((uuid, minor) async {
      print('[Check] scan callback saw: $uuid minor: $minor');
      if (uuid.toLowerCase() == sid.toLowerCase() && minor == BleService.kTeacherMinorId) {
        found = true;
        if (!completer.isCompleted) completer.complete(true);
      }
    });

    Future.delayed(const Duration(seconds: 5), () async {
      _ble.stopScan();
      await _ble.stopBeacon();
      if (!completer.isCompleted) completer.complete(found);
    });

    final res = await completer.future;
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res ? 'Advertising detected locally' : 'No local advertisement detected')));
  }

  @override
  Widget build(BuildContext context) {
    final courseTitle = '${widget.course['course_name'] ?? widget.course['name'] ?? ''}${widget.course['course_code'] != null ? ' (${widget.course['course_code']})' : ''}';
    return Scaffold(
      appBar: AppBar(title: Text(courseTitle)),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Show sessions count (normalized) even before starting attendance
            Text('Sessions: ${_sessionsDisplayCount()}/$kMaxSessions', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            const SizedBox(height: 12),
            // Note: Start/End buttons are in bottomNavigationBar
            const SizedBox(height: 8),
            Text('Seconds: $_elapsedSeconds s', style: const TextStyle(fontSize: 18)),
            const SizedBox(height: 8),
            const SizedBox(height: 12),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    // Unknown detected devices
                    ..._detected.map((d) => ListTile(
                          title: Text(d['name'] ?? d['device_signature']),
                          subtitle: Text('${d['discovered_at']} - ${d['synced'] ? 'Synced' : d['approved'] ? 'Approved' : 'Pending'}'),
                          trailing: IconButton(icon: Icon(d['approved'] ? Icons.check_box : Icons.check_box_outline_blank), onPressed: () => _toggleApprove(_detected.indexOf(d))),
                        )).toList(),
                    const Divider(),
                    const SizedBox(height: 8),
                    Text('Enrolled Students', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    // Search bar for enrolled students
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8.0),
                      child: TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          hintText: 'Search students by name or email',
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
                    const SizedBox(height: 8),
                    // Enrolled students list (filtered by search)
                    ..._students.where((s) {
                      final q = _searchQuery.toLowerCase();
                      if (q.isEmpty) return true;
                      final name = (s['name'] ?? '').toString().toLowerCase();
                      final email = (s['email'] ?? '').toString().toLowerCase();
                      return name.contains(q) || email.contains(q);
                    }).map((s) => ListTile(
                          title: Text(s['name'] ?? 'Student'),
                          subtitle: Text(s['discovered_at'] ?? ''),
                          leading: Checkbox(value: s['present'] == true, onChanged: (_) {
                            setState(() => s['present'] = !(s['present'] == true));
                          }),
                        )).toList(),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 36), // space so bottom buttons don't overlap

          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: _sessionId == null ? _startSession : null,
                  child: const Text('Start Attendance'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: _sessionId != null ? () async {
                    // End attendance: stop beacon and scanning, call endSession API and open review page
                    try { await _ble.stopBeacon(); } catch (_) {}
                    await _stopScanForStudents();
                    _elapsedTimer?.cancel();

                    final sessId = _sessionId;

                    // Call backend to end session (best-effort; show status)
                    if (sessId != null) {
                      try {
                        final resp = await _api.endSession(sessId);
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Session ended on server')));
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to end session on server: $e')));
                      }
                    }

                    setState(() { _sessionId = null; /* preserve students for review navigation */ });

                    if (sessId != null) {
                      Navigator.of(context).push(MaterialPageRoute(builder: (_) => AttendanceReviewScreen(
                        course: widget.course,
                        sessionId: sessId,
                        sessionNumber: _sessionsDisplayCount(),
                        students: _students,
                      )));
                      // Reset elapsed and students only after returning from review if needed
                      _elapsedSeconds = 0;
                    }
                  } : null,
                  child: const Text('End Attendance'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
