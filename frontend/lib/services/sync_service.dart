import 'package:flutter/foundation.dart';
import 'api_service.dart';
import 'local_store.dart';

class SyncService {
  static final _api = ApiService();

  /// Run automatic syncing for pending devices and attendance snapshots.
  /// This is intended to be run at app startup (after login) and should
  /// be quiet: only minimal user-facing messages (logs / single snack) are used.
  static Future<void> runAutoSync() async {
    try {
      // 1) Sync approved pending devices
      final pending = await LocalStore.loadPending();
      final toApprove = pending.where((d) => d['approved'] == true && d['synced'] != true).toList();
      for (var item in toApprove) {
        try {
          await _api.markAttendanceByTeacher(item['session_id'], item['device_signature']);
          item['synced'] = true;
        } catch (e) {
          debugPrint('[SyncService] failed to sync pending device: $e');
        }
      }
      if (toApprove.isNotEmpty) {
        // Persist any updated sync statuses (this will leave unsynced items present)
        await LocalStore.updatePending(pending);
      }

      // 2) Sync attendance snapshots (remove snapshots when successfully uploaded)
      final snapshots = await LocalStore.loadAttendanceSnapshots();
      final remaining = <Map<String, dynamic>>[];

      for (var snap in snapshots) {
        if (snap['synced'] == true) continue; // already synced
        final sessionId = snap['session_id'];
        final students = (snap['students'] as List<dynamic>?) ?? [];
        try {
          for (var st in students) {
            if (st['present'] == true) {
              await _api.approveStudentById(sessionId, st['student_id']);
            }
          }
          // upload succeeded, do not keep snapshot
          debugPrint('[SyncService] snapshot uploaded for session=$sessionId');
        } catch (e) {
          // If server reports session expired or session not found, treat as non-retriable
          try {
            if (e is ApiException) {
              if (e.statusCode == 410 || e.statusCode == 404) {
                debugPrint('[SyncService] snapshot discarded for session=$sessionId due to server response: $e');
                // do not add to remaining -> drop snapshot
                continue;
              }
            }
          } catch (_) {}

          debugPrint('[SyncService] snapshot upload failed for session=$sessionId: $e');
          remaining.add(snap);
        }
      }

      if (remaining.length != snapshots.length) {
        // Some snapshots were removed (synced), persist remaining
        await LocalStore.updateAttendanceSnapshots(remaining);
      }
    } catch (e) {
      debugPrint('[SyncService] runAutoSync fatal error: $e');
    }
  }
}
