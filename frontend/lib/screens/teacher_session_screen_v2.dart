import 'dart:async';
import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/api_service.dart';
import '../services/ble_service.dart';
import '../services/permission_service.dart';
import '../services/local_store.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

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
  int _remaining = 0;
  Timer? _timer;

  bool _scanning = false;
  List<Map<String, dynamic>> _detected = []; // { device_signature, discovered_at, approved, synced }

  StreamSubscription<dynamic>? _connSub;
  bool _syncing = false;

  // Poll timer for realtime fallback
  Timer? _realtimeTimer;

  @override
  void initState() {
    super.initState();
    _loadPending();
    _connSub = Connectivity().onConnectivityChanged.listen((dynamic result) {
      // On some platforms the stream emits a List<ConnectivityResult>, on others a single ConnectivityResult
      if (result is List) {
        final anyOnline = result.any((r) => r != ConnectivityResult.none);
        if (anyOnline) _autoSync();
      } else if (result is ConnectivityResult) {
        if (result != ConnectivityResult.none) _autoSync();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _ble.stopBeacon();
    _ble.stopScan();
    _connSub?.cancel();
    try {
      _realtimeTimer?.cancel();
      _realtimeTimer = null;
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
      _remaining = 15;
    });

    // Poll attendance table every 2s for this session (simple realtime fallback)
    _realtimeTimer = Timer.periodic(const Duration(seconds: 2), (t) async {
      try {
        final resp = await Supabase.instance.client.from('attendance').select('id,student_id,created_at,device_signature').eq('session_id', sid);
        final rows = (resp as List<dynamic>?) ?? [];
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
                'discovered_at': r['created_at'] ?? DateTime.now().toIso8601String(),
                'approved': true,
                'synced': true,
                'name': name,
              });
            });
          }
        }
      } catch (_) {}
    });
    final status = await _ble.checkTransmissionSupport();
    if (!status) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Device does not support BLE advertising')));
      return;
    }

    await _ble.startBeacon(sid);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      setState(() {
        _remaining -= 1;
        if (_remaining <= 0) {
          _ble.stopBeacon();
          // Stop polling when session ends
          try {
            _realtimeTimer?.cancel();
            _realtimeTimer = null;
          } catch (_) {}
          t.cancel();
        }
      });
    });
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
    _ble.startScan((s) async {
      final sig = s;
      final now = DateTime.now().toIso8601String();
      final exists = _detected.any((d) => d['device_signature'] == sig);
      if (!exists) {
        final item = {
          'session_id': _sessionId,
          'device_signature': sig,
          'discovered_at': now,
          'approved': false,
          'synced': false,
        };
        setState(() => _detected.add(item));
        await LocalStore.addPending(item);
      }
    });

    Timer(const Duration(seconds: 20), () async {
      _ble.stopScan();
      setState(() { _scanning = false; });
    });
  }

  Future<void> _loadPending() async {
    final items = await LocalStore.loadPending();
    setState(() => _detected = items);
  }

  Future<void> _toggleApprove(int idx) async {
    setState(() => _detected[idx]['approved'] = !_detected[idx]['approved']);
    await LocalStore.updatePending(_detected);
  }

  Future<void> _syncApproved() async {
    final approved = _detected.where((d) => d['approved'] == true && d['synced'] != true).toList();
    if (approved.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No approved items to sync')));
      return;
    }

    for (var item in approved) {
      try {
        await _api.markAttendance(item['session_id'], item['device_signature']);
        item['synced'] = true;
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Sync failed: $e')));
      }
    }
    await LocalStore.updatePending(_detected);
    setState(() {});
  }

  Future<void> _autoSync() async {
    if (_syncing) return;
    final pending = await LocalStore.loadPending();
    final need = pending.where((d) => d['approved'] == true && d['synced'] != true).toList();
    if (need.isEmpty) return;
    _syncing = true;
    await _syncApproved();
    _syncing = false;
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
        await _api.markAttendance(item['session_id'], item['device_signature']);
        item['synced'] = true;
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Sync failed: $e')));
      }
    }
    await LocalStore.updatePending(_detected);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Start Session (${widget.course['name'] ?? ''})')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            if (_sessionId != null) ...[
              Text('Session: $_sessionId'),
              const SizedBox(height: 8),
              Text('Remaining: $_remaining s', style: const TextStyle(fontSize: 20)),
            ],
            const SizedBox(height: 12),
            Row(children: [
              ElevatedButton(onPressed: _startSession, child: const Text('Start 15s Attendance')),
              const SizedBox(width: 12),
              ElevatedButton(onPressed: _scanning ? null : _startScanForStudents, child: Text(_scanning ? 'Scanning...' : 'Scan for Students')),
            ]),
            const SizedBox(height: 12),
            Expanded(
              child: ListView.builder(
                itemCount: _detected.length,
                itemBuilder: (_, i) {
                  final d = _detected[i];
                  return ListTile(
                    title: Text(d['name'] ?? d['device_signature']),
                    subtitle: Text('${d['discovered_at']} - ${d['synced'] ? 'Synced' : d['approved'] ? 'Approved' : 'Pending'}'),
                    trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                      IconButton(icon: Icon(d['approved'] ? Icons.check_box : Icons.check_box_outline_blank), onPressed: () => _toggleApprove(i)),
                      IconButton(icon: Icon(Icons.sync), onPressed: _syncApproved),
                    ]),
                  );
                },
              ),
            ),
            Row(children: [
              ElevatedButton(onPressed: _syncApproved, child: const Text('Sync Approved')),
              const SizedBox(width: 12),
              ElevatedButton(onPressed: _syncAll, child: const Text('Retry All')),
            ]),
          ],
        ),
      ),
    );
  }
}
