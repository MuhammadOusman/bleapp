import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class LocalStore {
  static const _pendingKey = 'pending_attendance';

  static Future<List<Map<String, dynamic>>> loadPending() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_pendingKey);
    if (raw == null) return [];
    final arr = jsonDecode(raw) as List;
    return arr.map((e) => Map<String, dynamic>.from(e)).toList();
  }

  static Future<void> savePending(List<Map<String, dynamic>> items) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_pendingKey, jsonEncode(items));
  }

  static Future<void> addPending(Map<String, dynamic> item) async {
    final list = await loadPending();
    list.add(item);
    await savePending(list);
  }

  static Future<void> updatePending(List<Map<String, dynamic>> items) async {
    await savePending(items);
  }

  static Future<void> clearPending() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_pendingKey);
  }

  // Attendance snapshots (for review & offline sync)
  static const _snapshotsKey = 'attendance_snapshots';

  static Future<List<Map<String, dynamic>>> loadAttendanceSnapshots() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_snapshotsKey);
    if (raw == null) return [];
    final arr = jsonDecode(raw) as List;
    return arr.map((e) => Map<String, dynamic>.from(e)).toList();
  }

  static Future<void> saveAttendanceSnapshots(List<Map<String, dynamic>> items) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_snapshotsKey, jsonEncode(items));
  }

  static Future<void> addAttendanceSnapshot(Map<String, dynamic> item) async {
    final list = await loadAttendanceSnapshots();
    list.add(item);
    await saveAttendanceSnapshots(list);
  }

  static Future<void> updateAttendanceSnapshots(List<Map<String, dynamic>> items) async {
    await saveAttendanceSnapshots(items);
  }

  /// Remove any saved attendance snapshots that match the given session id
  static Future<void> removeAttendanceSnapshotsForSession(String sessionId) async {
    final list = await loadAttendanceSnapshots();
    final filtered = list.where((s) => (s['session_id'] as String?) != sessionId).toList();
    await saveAttendanceSnapshots(filtered);
  }
}
