import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

final backendBase = dotenv.env['BACKEND_BASE'] ?? 'https://dsu-ble-attendance.vercel.app/api';

class ApiService {
  final storage = const FlutterSecureStorage();

  Future<Map<String, dynamic>> register(String email, String password, String deviceSignature) async {
    final res = await http.post(
      Uri.parse('$backendBase/register'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'email': email,
        'password': password,
        'device_signature': deviceSignature,
      }),
    );
    return _handle(res);
  }

  Future<Map<String, dynamic>> login(String email, String password, String deviceSignature) async {
    final res = await http.post(
      Uri.parse('$backendBase/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'email': email,
        'password': password,
        'device_signature': deviceSignature,
      }),
    );
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
    final res = await http.get(
      Uri.parse('$backendBase/courses'),
      headers: {'Authorization': 'Bearer $token'},
    );
    final data = _handle(res);
    return data as List<dynamic>;
  }

  Future<String> startSession(String token, String courseId, int sessionNumber) async {
    final res = await http.post(
      Uri.parse('$backendBase/sessions/start'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token'
      },
      body: jsonEncode({'course_id': courseId, 'session_number': sessionNumber}),
    );
    final data = _handle(res);
    return data['session_id'] as String;
  }

  Future<Map<String, dynamic>> markAttendance(String sessionId, String deviceSignature) async {
    final res = await http.post(
      Uri.parse('$backendBase/attendance/mark'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'session_id': sessionId, 'device_signature': deviceSignature}),
    );
    return _handle(res);
  }

  Map<String, dynamic> _handle(http.Response res) {
    if (res.statusCode >= 200 && res.statusCode < 300) {
      return jsonDecode(res.body) as Map<String, dynamic>;
    }
    throw Exception('HTTP ${res.statusCode}: ${res.body}');
  }
}
