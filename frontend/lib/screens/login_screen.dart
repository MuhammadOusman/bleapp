import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../services/device_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_scaffold.dart';
import '../widgets/app_snackbar.dart';

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

  void _showMessage(String s, {SnackType type = SnackType.info}) => showAppSnackBar(context, s, type: type);

  String _deriveDisplayName(Map<String, dynamic>? profile, String emailInput) {
    final full = profile?['full_name']?.toString().trim();
    if (full != null && full.isNotEmpty) return full;

    final email = (profile?['email'] ?? emailInput).toString().trim();
    if (email.isEmpty) return 'Student';

    const domain = '@dsu.edu.pk';
    final lower = email.toLowerCase();
    if (lower.endsWith(domain)) {
      return email.substring(0, email.length - domain.length);
    }

    final atIdx = email.indexOf('@');
    return atIdx > 0 ? email.substring(0, atIdx) : email;
  }

  Future<void> _doAuth(bool register, {String? fullName}) async {
    if (_emailCtrl.text.trim().isEmpty || _passCtrl.text.isEmpty) {
      _showMessage('Email and password required', type: SnackType.error);
      return;
    }

    setState(() => _loading = true);
    final device = await DeviceService.getDeviceSignature();
    try {
      if (register) {
        await _api.register(_emailCtrl.text.trim(), _passCtrl.text.trim(), device, fullName: fullName);
        _showMessage('Registered. Sign in to continue.', type: SnackType.success);
      } else {
        final res = await _api.login(_emailCtrl.text.trim(), _passCtrl.text.trim(), device);
        if (!mounted) return;
        final role = res['profile']?['role']?.toString().toLowerCase() ?? 'student';
        final target = role == 'teacher' ? '/dashboard' : '/courses';
        final displayName = _deriveDisplayName(res['profile'] as Map<String, dynamic>?, _emailCtrl.text.trim());
        _showMessage('Welcome back, $displayName', type: SnackType.success);
        Navigator.of(context).pushReplacementNamed(target);
      }
    } on Exception catch (e) {
      _showMessage(e.toString(), type: SnackType.error);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return AppScaffold(
      padded: false,
      appBar: AppBar(
        title: const Text('atDSU'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 120,
                height: 120,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: AppTheme.accentGradient,
                  boxShadow: AppTheme.glow,
                ),
                child: const Icon(Icons.verified_user_rounded, color: Colors.white, size: 64),
              ),
              const SizedBox(height: 18),
              Text('Welcome to atDSU',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : theme.textTheme.headlineSmall?.color,
                  )),
              const SizedBox(height: 8),
              Text(
                'Presence made effortless. Sign in to continue.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(color: isDark ? Colors.white70 : Colors.black54),
              ),
              const SizedBox(height: 28),
              _FancyField(controller: _emailCtrl, label: 'Email', icon: Icons.mail_outline_rounded),
              const SizedBox(height: 14),
              _FancyField(controller: _passCtrl, label: 'Password', icon: Icons.lock_outline_rounded, obscure: true),
              const SizedBox(height: 18),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: _loading
                    ? const Padding(
                        padding: EdgeInsets.all(8.0),
                        child: CircularProgressIndicator(strokeWidth: 2.5),
                      )
                    : Column(
                        children: [
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              icon: const Icon(Icons.arrow_forward_rounded),
                              onPressed: () => _doAuth(false),
                              label: const Text('Sign In'),
                            ),
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              icon: const Icon(Icons.person_add_alt_1_rounded),
                              onPressed: () async {
                                final nameCtrl = TextEditingController();
                                final full = await showDialog<String>(
                                  context: context,
                                  builder: (_) => AlertDialog(
                                    title: const Text('Full name (optional)'),
                                    content: TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Full name')),
                                    actions: [
                                      TextButton(onPressed: () => Navigator.of(context).pop(null), child: const Text('Skip')),
                                      ElevatedButton(onPressed: () => Navigator.of(context).pop(nameCtrl.text), child: const Text('Continue')),
                                    ],
                                  ),
                                );
                                await _doAuth(true, fullName: full?.trim());
                              },
                              label: const Text('Create Account'),
                            ),
                          ),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FancyField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final bool obscure;

  const _FancyField({required this.controller, required this.label, required this.icon, this.obscure = false});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [BoxShadow(color: Color(0x1A000000), blurRadius: 12, offset: Offset(0, 8))],
      ),
      child: TextField(
        controller: controller,
        obscureText: obscure,
        style: theme.textTheme.bodyMedium?.copyWith(color: isDark ? Colors.black : theme.textTheme.bodyMedium?.color),
        cursorColor: isDark ? Colors.black : theme.colorScheme.primary,
        decoration: InputDecoration(
          border: InputBorder.none,
          labelText: label,
          labelStyle: theme.textTheme.bodyMedium?.copyWith(color: isDark ? Colors.black : Colors.grey.shade600),
          prefixIcon: Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: Icon(icon, color: isDark ? Colors.black : Colors.grey.shade700),
          ),
          prefixIconConstraints: const BoxConstraints(minWidth: 32, minHeight: 32),
        ),
      ),
    );
  }
}
