import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

final backendBase = dotenv.env['BACKEND_BASE'] ?? 'https://dsu-ble-attendance.vercel.app/api';

class ApiException implements Exception {
  final int statusCode;
  final Map<String, dynamic>? body;
  ApiException(this.statusCode, this.body);
  @override
  String toString() => 'HTTP $statusCode: ${body?['error'] ?? body?['message'] ?? body?.toString() ?? ''}';
}

class ApiService {
  final storage = const FlutterSecureStorage();

  void _log(String msg) {
    try {
      // Keep logs helpful but concise
      print('[API] $msg');
    } catch (_) {}
  }

  Future<Map<String, dynamic>> register(String email, String password, String deviceSignature, {String? fullName}) async {
    final url = Uri.parse('$backendBase/register');
    final body = jsonEncode({
      'email': email,
      'password': password,
      'device_signature': deviceSignature,
      if (fullName != null) 'full_name': fullName,
    });
    _log('POST $url body=${body.length} bytes');
    final res = await http.post(url, headers: {'Content-Type': 'application/json'}, body: body);
    _log('RESPONSE ${res.statusCode} ${res.body?.length ?? 0} bytes');
    return _handle(res);
  }

  Future<Map<String, dynamic>> login(String email, String password, String deviceSignature) async {
    final url = Uri.parse('$backendBase/login');
    final body = jsonEncode({'email': email, 'password': password, 'device_signature': deviceSignature});
    _log('POST $url body=${body.length} bytes');
    final res = await http.post(url, headers: {'Content-Type': 'application/json'}, body: body);
    _log('RESPONSE ${res.statusCode} ${res.body?.length ?? 0} bytes');
    final data = _handle(res);
    if (data.containsKey('token')) {
      await storage.write(key: 'token', value: data['token']);
      if (data.containsKey('profile')) {
        await storage.write(key: 'role', value: data['profile']['role']?.toString() ?? 'student');
      }
    }
    return data;
  }

  Future<List<dynamic>> getCourses(String token) async {
    final url = Uri.parse('$backendBase/courses');
    _log('GET $url');
    final res = await http.get(url, headers: {'Authorization': 'Bearer $token'});
    _log('RESPONSE ${res.statusCode} ${res.body?.length ?? 0} bytes body=${res.body}');
    final data = _handle(res);
    return (data ?? []) as List<dynamic>;
  }

  /// Get number of sessions started for a course
  Future<int> getSessionCount(String courseId) async {
    final token = await storage.read(key: 'token');
    final headers = <String, String>{'Content-Type': 'application/json'};
    if (token != null) headers['Authorization'] = 'Bearer $token';
    final url = Uri.parse('$backendBase/courses/$courseId/sessions_count');
    _log('GET $url');
    final res = await http.get(url, headers: headers);
    final data = _handle(res);
    return (data['count'] as int?) ?? 0;
  }

  Future<String> startSession(String token, String courseId, int sessionNumber) async {
    final url = Uri.parse('$backendBase/sessions/start');
    final body = jsonEncode({'course_id': courseId, 'session_number': sessionNumber});
    _log('POST $url body=${body.length} bytes');
    final res = await http.post(url, headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'}, body: body);
    _log('RESPONSE ${res.statusCode} ${res.body?.length ?? 0} bytes');
    final data = _handle(res);
    return data['session_id'] as String;
  }

  Future<Map<String, dynamic>> endSession(String sessionId) async {
    final token = await storage.read(key: 'token');
    final headers = <String, String>{'Content-Type': 'application/json'};
    if (token != null) headers['Authorization'] = 'Bearer $token';
    final url = Uri.parse('$backendBase/sessions/$sessionId/end');
    _log('POST $url');
    final res = await http.post(url, headers: headers);
    _log('RESPONSE ${res.statusCode} ${res.body?.length ?? 0} bytes');
    return _handle(res) as Map<String, dynamic>;
  }

  /// Get list of students enrolled in the course (backend will return all students until
  /// enrollment mapping is added). Returns a list of maps with keys: id, full_name, email, lms_id
  Future<List<dynamic>> getCourseStudents(String courseId) async {
    final token = await storage.read(key: 'token');
    final headers = <String, String>{'Content-Type': 'application/json'};
    if (token != null) headers['Authorization'] = 'Bearer $token';
    final url = Uri.parse('$backendBase/courses/$courseId/students');
    _log('GET $url');
    final res = await http.get(url, headers: headers);
    _log('RESPONSE ${res.statusCode} ${res.body?.length ?? 0} bytes');
    final data = _handle(res);
    return (data['students'] as List<dynamic>?) ?? [];
  }

  /// Get a session by id with course info
  Future<Map<String, dynamic>> getSession(String sessionId) async {
    final token = await storage.read(key: 'token');
    final headers = <String, String>{'Content-Type': 'application/json'};
    if (token != null) headers['Authorization'] = 'Bearer $token';
    final url = Uri.parse('$backendBase/sessions/$sessionId');
    _log('GET $url');
    final res = await http.get(url, headers: headers);
    _log('RESPONSE ${res.statusCode} ${res.body?.length ?? 0} bytes');
    final data = _handle(res);
    return (data as Map<String, dynamic>);
  }

  /// Get sessions for a course (teacher dashboard)
  Future<List<dynamic>> getCourseSessions(String courseId) async {
    final token = await storage.read(key: 'token');
    final headers = <String, String>{'Content-Type': 'application/json'};
    if (token != null) headers['Authorization'] = 'Bearer $token';
    final url = Uri.parse('$backendBase/courses/$courseId/sessions');
    _log('GET $url');
    final res = await http.get(url, headers: headers);
    _log('RESPONSE ${res.statusCode} ${res.body?.length ?? 0} bytes');
    final data = _handle(res);
    return (data['sessions'] as List<dynamic>?) ?? [];
  }

  /// Get attendance rows for a session
  Future<List<dynamic>> getSessionAttendance(String sessionId) async {
    final token = await storage.read(key: 'token');
    final headers = <String, String>{'Content-Type': 'application/json'};
    if (token != null) headers['Authorization'] = 'Bearer $token';
    final url = Uri.parse('$backendBase/sessions/$sessionId/attendance');
    _log('GET $url');
    final res = await http.get(url, headers: headers);
    _log('RESPONSE ${res.statusCode} ${res.body?.length ?? 0} bytes');
    final data = _handle(res);
    return (data['attendees'] as List<dynamic>?) ?? [];
  }

  /// Teacher: approve attendance for a student by id (manual or sync)
  Future<Map<String, dynamic>> approveStudentById(String sessionId, String studentId) async {
    final token = await storage.read(key: 'token');
    final headers = <String, String>{'Content-Type': 'application/json'};
    if (token != null) headers['Authorization'] = 'Bearer $token';

    final url = Uri.parse('$backendBase/attendance/approve_by_student');
    final body = jsonEncode({'session_id': sessionId, 'student_id': studentId});
    _log('POST $url headers=${headers.keys.toList()} body=${body.length} bytes');
    final res = await http.post(url, headers: headers, body: body);
    _log('RESPONSE ${res.statusCode} ${res.body?.length ?? 0} bytes');
    return _handle(res);
  }

  Future<Map<String, dynamic>> markAttendance(String sessionId, String deviceSignature) async {
    final token = await storage.read(key: 'token');
    final headers = <String, String>{'Content-Type': 'application/json'};
    if (token != null) headers['Authorization'] = 'Bearer $token';

    final url = Uri.parse('$backendBase/attendance/mark');
    final body = jsonEncode({'session_id': sessionId, 'device_signature': deviceSignature});
    _log('POST $url headers=${headers.keys.toList()} body=${body.length} bytes');
    final res = await http.post(url, headers: headers, body: body);
    _log('RESPONSE ${res.statusCode} ${res.body?.length ?? 0} bytes');
    return _handle(res);
  }

  // Teacher API: approve attendance by device_signature (teacher-only)
  Future<Map<String, dynamic>> markAttendanceByTeacher(String sessionId, String deviceSignature) async {
    final token = await storage.read(key: 'token');
    final headers = <String, String>{'Content-Type': 'application/json'};
    if (token != null) headers['Authorization'] = 'Bearer $token';

    final url = Uri.parse('$backendBase/attendance/approve');
    final body = jsonEncode({'session_id': sessionId, 'device_signature': deviceSignature});
    _log('POST $url headers=${headers.keys.toList()} body=${body.length} bytes');
    final res = await http.post(url, headers: headers, body: body);
    _log('RESPONSE ${res.statusCode} ${res.body?.length ?? 0} bytes');
    return _handle(res);
  }

  // Resolve an advertised string to a profile (teacher helper)
  Future<Map<String, dynamic>?> resolveAdvertised(String advertised) async {
    final token = await storage.read(key: 'token');
    final headers = <String, String>{'Content-Type': 'application/json'};
    if (token != null) headers['Authorization'] = 'Bearer $token';

    try {
      final res = await http.post(
        Uri.parse('$backendBase/profiles/resolve'),
        headers: headers,
        body: jsonEncode({'advertised': advertised}),
      );
      final data = _handle(res);
      return data['profile'] as Map<String, dynamic>?;
    } catch (e) {
      return null;
    }
  }

  dynamic _handle(http.Response res) {
    final body = res.body.isNotEmpty ? jsonDecode(res.body) : null;
    if (res.statusCode >= 200 && res.statusCode < 300) {
      return body;
    }
    // Normalize body for error reporting
    final errBody = (body is Map<String, dynamic>) ? body : {'error': body?.toString()};
    throw ApiException(res.statusCode, errBody);
  }
}
