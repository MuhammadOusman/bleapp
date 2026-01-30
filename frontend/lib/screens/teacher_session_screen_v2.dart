import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/api_service.dart';
import '../services/ble_service.dart';
import '../services/local_store.dart';
import '../services/permission_service.dart';
import 'attendance_review_screen.dart';
import '../widgets/app_snackbar.dart';

class TeacherSessionScreenV2 extends StatefulWidget {
	final Map course;
	final String? initialSessionId;

	const TeacherSessionScreenV2({super.key, required this.course, this.initialSessionId});

	@override
	State<TeacherSessionScreenV2> createState() => _TeacherSessionScreenV2State();
}

class _TeacherSessionScreenV2State extends State<TeacherSessionScreenV2> {
	static const int kMaxSessions = 16;

	final _api = ApiService();
	final _ble = BleService();
	final _storage = const FlutterSecureStorage();

	String? _sessionId;
	int _sessionsCount = 0;
	bool _scanning = false;
	int _elapsedSeconds = 0;

	final TextEditingController _searchController = TextEditingController();
	String _searchQuery = '';

	List<Map<String, dynamic>> _students = [];

	StreamSubscription<dynamic>? _connSub;
	bool _syncing = false;
	Timer? _realtimeTimer;
	Timer? _elapsedTimer;

	@override
	void initState() {
		super.initState();
		_loadSessionCount();

		_connSub = Connectivity().onConnectivityChanged.listen((dynamic result) {
			if (result is List) {
				final anyOnline = result.any((r) => r != ConnectivityResult.none);
				if (anyOnline) _autoSync();
			} else if (result is ConnectivityResult) {
				if (result != ConnectivityResult.none) _autoSync();
			}
		});

		_checkUnsyncedSnapshots();

		if (widget.initialSessionId != null) {
			WidgetsBinding.instance.addPostFrameCallback((_) {
				_onSessionStarted(widget.initialSessionId!);
			});
		}
	}

	@override
	void dispose() {
		_ble.stopBeacon();
		_ble.stopScan();
		_connSub?.cancel();
		_realtimeTimer?.cancel();
		_elapsedTimer?.cancel();
		_searchController.dispose();
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
		await _onSessionStarted(sid);
	}

	Future<void> _onSessionStarted(String sid) async {
		setState(() => _sessionId = sid);
		_loadSessionCount();

		try {
			final students = await _api.getCourseStudents(widget.course['id']);
			setState(() {
				_students = students
						.map<Map<String, dynamic>>((s) => {
									'student_id': s['id'],
									'name': (s['full_name'] ?? s['email'] ?? 'Student') as String,
									'email': s['email'],
									'present': false,
									'discovered_at': null,
									'synced': false,
								})
						.toList();
			});
		} catch (e) {
			debugPrint('[Start] failed to load students: $e');
		}

		_startPollAttendance(sid);

		final status = await _ble.checkTransmissionSupport();
		if (!status) {
			if (!mounted) return;
			ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Device does not support BLE advertising')));
			return;
		}
		await _ble.startBeacon(sid);

		_elapsedSeconds = 0;
		_elapsedTimer?.cancel();
		_elapsedTimer = Timer.periodic(const Duration(seconds: 1), (_) {
			if (!mounted) return;
			setState(() => _elapsedSeconds += 1);
		});

		if (!_scanning) await _startScanForStudents();
	}

	void _startPollAttendance(String sessionId) {
		_realtimeTimer?.cancel();
		bool attendanceHasDeviceSignature = true;

		_realtimeTimer = Timer.periodic(const Duration(seconds: 2), (t) async {
			try {
				dynamic resp;
				if (attendanceHasDeviceSignature) {
					try {
						resp = await Supabase.instance.client
								.from('attendance')
								.select('id,student_id,marked_at,device_signature')
								.eq('session_id', sessionId);
					} catch (e) {
						final msg = e.toString();
						if (msg.contains('device_signature') || msg.contains('column "device_signature"')) {
							attendanceHasDeviceSignature = false;
							resp = await Supabase.instance.client
									.from('attendance')
									.select('id,student_id,marked_at')
									.eq('session_id', sessionId);
						} else {
							rethrow;
						}
					}
				} else {
					resp = await Supabase.instance.client
							.from('attendance')
							.select('id,student_id,marked_at')
							.eq('session_id', sessionId);
				}

				final rows = (resp as List<dynamic>?) ?? [];
				for (var r in rows) {
					final studentId = r['student_id'];
					final idx = _students.indexWhere((s) => s['student_id'] == studentId);
					if (idx >= 0) {
						final discovered = r['marked_at'] ?? DateTime.now().toIso8601String();
						if (_students[idx]['present'] != true) {
							setState(() {
								_students[idx]['present'] = true;
								_students[idx]['discovered_at'] = discovered;
								_students[idx]['synced'] = true;
							});
						}
					}
				}
			} catch (e) {
				debugPrint('[Poll] error: $e');
			}
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

		setState(() => _scanning = true);
		try {
			_ble.startScan((uuid, minor) async {
				if (minor != BleService.kStudentMinorId) return;

				final sig = uuid;
				final now = DateTime.now().toIso8601String();

				try {
					final profile = await _api.resolveAdvertised(sig);
					if (profile != null) {
						final idx = _students.indexWhere((s) => s['student_id'] == profile['id']);
						if (idx >= 0 && _students[idx]['present'] != true) {
							_students[idx]['present'] = true;
							_students[idx]['discovered_at'] = now;
							_students[idx]['synced'] = false;
							await LocalStore.updatePending(_students);
							if (mounted) setState(() {});
						}
						return; // ignore non-enrolled
					}
				} catch (e) {
					debugPrint('[Scan] resolve error: $e');
				}
			});
		} catch (e) {
			if (!mounted) return;
			ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Bluetooth must be turned on to scan.')));
		}
	}

	Future<void> _stopScanForStudents() async {
		try {
			_ble.stopScan();
		} catch (_) {}
		setState(() => _scanning = false);
	}

	Future<void> _endAttendance() async {
		try {
			await _ble.stopBeacon();
		} catch (_) {}
		await _stopScanForStudents();
		_elapsedTimer?.cancel();
		_realtimeTimer?.cancel();

		final sessId = _sessionId;
		final sessionNumber = _sessionsDisplayCount();
		final reviewStudents = _students.map((e) => Map<String, dynamic>.from(e)).toList();

		if (sessId != null) {
			try {
				await _api.endSession(sessId); 
				if (mounted) showAppSnackBar(context, 'Session ended on server', type: SnackType.success);
			} catch (e) {
				if (mounted) {
					ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to end session on server: $e')));
				}
			}
		}

		if (sessId != null && mounted) {
			final result = await Navigator.of(context).push(MaterialPageRoute(
				builder: (_) => AttendanceReviewScreen(
					course: widget.course,
					sessionId: sessId,
					sessionNumber: sessionNumber,
					students: reviewStudents,
					sessionSynced: false,
				),
			));

			_elapsedSeconds = 0;
			setState(() => _sessionId = null);
			if (result != null && mounted) {
				Navigator.of(context).pop(result == 'saved');
			}
		}
	}

	Future<void> _loadSessionCount() async {
		try {
			final cnt = await _api.getSessionCount(widget.course['id']);
			if (mounted) setState(() => _sessionsCount = cnt);
		} catch (e) {
			debugPrint('[SessionCount] failed to load for course ${widget.course['id']}: $e');
		}
	}

	int _sessionsDisplayCount() {
		if (_sessionsCount == 0) return 0;
		final rem = _sessionsCount % kMaxSessions;
		return rem == 0 ? kMaxSessions : rem;
	}

	Future<void> _autoSync() async {
		if (_syncing) return;

		final pending = await LocalStore.loadPending();
		final need = pending.where((d) => d['approved'] == true && d['synced'] != true).toList();
		if (need.isNotEmpty) {
			_syncing = true;
			// Legacy pending sync removed; kept to avoid concurrent syncs.
			_syncing = false;
		}

		final snapshots = await LocalStore.loadAttendanceSnapshots();
		final needSnap = snapshots.where((s) => s['synced'] != true).toList();
		if (needSnap.isEmpty) return;

		if (mounted) {
			ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Syncing attendance, don't close app")));
		}

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
				snap['synced'] = true;
			} catch (e) {
				debugPrint('[AutoSync] failed snapshot sync: $e');
			}
		}
		await LocalStore.updateAttendanceSnapshots(snapshots);
		_syncing = false;

		if (mounted) {
			ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Attendance sync complete')));
		}
	}

	Future<void> _checkUnsyncedSnapshots() async {
		try {
			final snaps = await LocalStore.loadAttendanceSnapshots();
			final need = snaps.where((s) => s['synced'] != true).toList();
			if (need.isNotEmpty) {
				if (mounted) {
					ScaffoldMessenger.of(context).showSnackBar(
						const SnackBar(content: Text('Device restart (not synced): syncing previous attendance pls wait.')),
					);
				}
				_autoSync();
			}
		} catch (_) {}
	}

	List<Map<String, dynamic>> get _filteredStudents {
		final query = _searchQuery.toLowerCase();
		if (query.isEmpty) return _students;
		return _students.where((s) {
			final name = (s['name'] ?? '').toString().toLowerCase();
			final email = (s['email'] ?? '').toString().toLowerCase();
			return name.contains(query) || email.contains(query);
		}).toList();
	}

	@override
	Widget build(BuildContext context) {
		final courseTitle = '${widget.course['course_name'] ?? widget.course['name'] ?? ''}${widget.course['course_code'] != null ? ' (${widget.course['course_code']})' : ''}';

		return Scaffold(
			appBar: AppBar(
				title: Text(courseTitle),
				actions: [
					if (_sessionId != null)
						Padding(
							padding: const EdgeInsets.only(right: 12.0),
							child: Center(
								child: Row(
									children: [
										if (_scanning) const Icon(Icons.bluetooth_searching, size: 18),
										const SizedBox(width: 6),
										Text('$_elapsedSeconds s'),
									],
								),
							),
						),
				],
			),
			body: Padding(
				padding: const EdgeInsets.all(16.0),
				child: Column(
					crossAxisAlignment: CrossAxisAlignment.start,
					children: [
						Text('Sessions: ${_sessionsDisplayCount()}/$kMaxSessions', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
						const SizedBox(height: 12),
						TextField(
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
						const SizedBox(height: 12),
						Expanded(
							child: ListView.builder(
								itemCount: _filteredStudents.length,
								itemBuilder: (context, index) {
									final s = _filteredStudents[index];
									return ListTile(
										leading: Checkbox(
											value: s['present'] == true,
											onChanged: (_) {
												setState(() => s['present'] = !(s['present'] == true));
											},
										),
										title: Text(s['name'] ?? 'Student'),
										subtitle: s['discovered_at'] != null ? Text('Detected at ${s['discovered_at']}') : null,
									);
								},
							),
						),
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
									onPressed: _sessionId != null ? _endAttendance : null,
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

