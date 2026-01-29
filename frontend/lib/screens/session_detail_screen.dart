import 'package:flutter/material.dart';
import '../services/api_service.dart';

class SessionDetailScreen extends StatefulWidget {
  final Map session;
  const SessionDetailScreen({super.key, required this.session});

  @override
  State<SessionDetailScreen> createState() => _SessionDetailScreenState();
}

class _SessionDetailScreenState extends State<SessionDetailScreen> {
  final _api = ApiService();
  List _attendees = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final rows = await _api.getSessionAttendance(widget.session['id']);
      setState(() => _attendees = rows);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to load attendees: $e')));
    }
    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Session ${widget.session['session_number'] ?? ''}')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _attendees.isEmpty
              ? const Center(child: Text('No attendees yet'))
              : ListView.builder(
                  itemCount: _attendees.length,
                  itemBuilder: (_, i) {
                    final a = _attendees[i] as Map;
                    final prof = a['profile'] as Map?;
                    final name = prof == null ? (a['student_id'] ?? 'Unknown') : (prof['full_name'] ?? prof['email'] ?? 'Student');
                    return ListTile(
                      title: Text(name.toString()),
                      subtitle: Text('Marked at: ${a['marked_at'] ?? ''}'),
                    );
                  },
                ),
    );
  }
}
