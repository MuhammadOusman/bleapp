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

  Future<void> _doAuth(bool register) async {
    setState(() => _loading = true);
    final device = await DeviceService.getDeviceSignature();
    try {
      if (register) {
        await _api.register(_emailCtrl.text.trim(), _passCtrl.text.trim(), device);
        _showMessage('Registered. Now login.');
      } else {
        final res = await _api.login(_emailCtrl.text.trim(), _passCtrl.text.trim(), device);
        if (res.containsKey('token')) {
          if (!mounted) return;
          Navigator.of(context).pushReplacementNamed('/courses');
        } else {
          if (!mounted) return;
          _showMessage('Login failed');
        }
      }
    } catch (e) {
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
                  Expanded(child: OutlinedButton(onPressed: () => _doAuth(true), child: const Text('Register'))),
                ],
              )
          ],
        ),
      ),
    );
  }
}
