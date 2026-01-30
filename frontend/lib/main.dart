import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'screens/courses_screen.dart';
import 'screens/login_screen.dart';
import 'screens/teacher_dashboard.dart';
import 'state/theme_provider.dart';
import 'theme/app_theme.dart';
import 'widgets/bluetooth_gate.dart';

// Values are sourced from .env (preferred). Fallbacks provided for convenience.
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await _loadEnv();

  final supabaseUrl = dotenv.env['SUPABASE_URL'];
  final supabaseAnonKey = dotenv.env['SUPABASE_ANON_KEY'];

  if (supabaseUrl == null || supabaseUrl.isEmpty || supabaseAnonKey == null || supabaseAnonKey.isEmpty) {
    throw Exception('Missing SUPABASE_URL and/or SUPABASE_ANON_KEY in .env.');
  }

  await Supabase.initialize(url: supabaseUrl, anonKey: supabaseAnonKey);
  runApp(const ProviderScope(child: AtDsuApp()));
}

Future<void> _loadEnv() async {
  try {
    await dotenv.load(fileName: '.env');
  } catch (_) {
    final raw = await rootBundle.loadString('.env');
    final lines = raw.split(RegExp(r'\r?\n'));
    for (var line in lines) {
      line = line.trim();
      if (line.isEmpty || line.startsWith('#')) continue;
      final idx = line.indexOf('=');
      if (idx <= 0) continue;
      final k = line.substring(0, idx).trim();
      var v = line.substring(idx + 1).trim();
      if (v.startsWith('"') && v.endsWith('"')) v = v.substring(1, v.length - 1);
      if (v.startsWith("'") && v.endsWith("'")) v = v.substring(1, v.length - 1);
      dotenv.env[k] = v;
    }
  }
}

class AtDsuApp extends ConsumerWidget {
  const AtDsuApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(themeProvider);

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'atDSU',
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: mode,
      initialRoute: '/',
      routes: {
        '/': (context) => const LoginScreen(),
        '/courses': (context) => const CoursesScreen(),
        '/dashboard': (context) => const TeacherDashboardScreen(),
      },
      builder: (context, child) => BluetoothGate(child: child ?? const SizedBox.shrink()),
    );
  }
}

