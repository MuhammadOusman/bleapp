import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/device_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _api = ApiService();
  bool _loading = false;

  void _showMessage(String s) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s)));

  Future<void> _doAuth(bool register, {String? fullName}) async {
    setState(() => _loading = true);
    final device = await DeviceService.getDeviceSignature();
    try {
      if (register) {
        await _api.register(_emailCtrl.text.trim(), _passCtrl.text.trim(), device, fullName: fullName);
        _showMessage('Registered. Now login.');
      } else {
        final res = await _api.login(_emailCtrl.text.trim(), _passCtrl.text.trim(), device);
        // Debug: log response
        print('[Login] response: $res');
        if (res.containsKey('token')) {
          final role = res['profile']?['role'] ?? 'student';
          final token = res['token'];
          print('[Login] token: ${token.toString().substring(0, token.toString().length > 8 ? 8 : token.toString().length)}... role: $role');
          if (!mounted) return;
          // Show a small dialog confirming role for debugging
          showDialog(context: context, builder: (_) => AlertDialog(
            title: const Text('Login Success'),
            content: Text('Role: $role'),
            actions: [TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('OK'))],
          ));
          Navigator.of(context).pushReplacementNamed('/courses');
        } else {
          if (!mounted) return;
          _showMessage('Login failed');
        }
      }
    } on Exception catch (e) {
      // ApiException will be shown with friendly text in student flows; here, show message directly
      _showMessage(e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('DSU BLE - Login')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(controller: _emailCtrl, decoration: const InputDecoration(labelText: 'Email')),
            TextField(controller: _passCtrl, decoration: const InputDecoration(labelText: 'Password'), obscureText: true),
            const SizedBox(height: 20),
            if (_loading) const CircularProgressIndicator(),
            if (!_loading)
              Row(
                children: [
                  Expanded(child: ElevatedButton(onPressed: () => _doAuth(false), child: const Text('Login'))),
                  const SizedBox(width: 12),
                  Expanded(child: OutlinedButton(onPressed: () async {
                    final TextEditingController nameCtrl = TextEditingController();
                    final full = await showDialog<String>(context: context, builder: (_) => AlertDialog(
                      title: const Text('Full name (students only)'),
                      content: TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Full name')),
                      actions: [
                        TextButton(onPressed: () => Navigator.of(context).pop(null), child: const Text('Skip')),
                        ElevatedButton(onPressed: () => Navigator.of(context).pop(nameCtrl.text), child: const Text('OK')),
                      ],
                    ));
                    await _doAuth(true, fullName: full?.trim());
                  }, child: const Text('Register'))),
                ],
              )
          ],
        ),
      ),
    );
  }
}
