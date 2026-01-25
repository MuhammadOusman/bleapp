import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'screens/login_screen.dart';
import 'screens/courses_screen.dart';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter/services.dart' show rootBundle;

// Values are sourced from .env (preferred). Fallbacks provided for convenience.
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await dotenv.load(fileName: '.env');
  } catch (e) {
    // Some environments (device assets) may not expose the file system path; try to load .env from assets
    try {
      final raw = await rootBundle.loadString('.env');
      final lines = raw.split(RegExp(r'\r?\n'));
      for (var line in lines) {
        line = line.trim();
        if (line.isEmpty || line.startsWith('#')) continue;
        final idx = line.indexOf('=');
        if (idx <= 0) continue;
        final k = line.substring(0, idx).trim();
        var v = line.substring(idx + 1).trim();
        // remove optional surrounding quotes
        if (v.startsWith('"') && v.endsWith('"')) v = v.substring(1, v.length - 1);
        if (v.startsWith("'") && v.endsWith("'")) v = v.substring(1, v.length - 1);
        dotenv.env[k] = v;
      }
      // quick info to help debugging in logs
      // ignore: avoid_print
      print('Loaded .env from assets fallback');
    } catch (e2) {
      // Rethrow the original exception to preserve the error
      rethrow;
    }
  }

  // Read Supabase config exclusively from environment. No fallbacks or hard-coded secrets.
  final supabaseUrl = dotenv.env['SUPABASE_URL'];
  final supabaseAnonKey = dotenv.env['SUPABASE_ANON_KEY'];

  if (supabaseUrl == null || supabaseUrl.isEmpty || supabaseAnonKey == null || supabaseAnonKey.isEmpty) {
    // Fail fast - secrets must be provided via `.env` (do not commit `.env`)
    throw Exception('Missing SUPABASE_URL and/or SUPABASE_ANON_KEY in .env. Copy .env.example → .env and fill values.');
  }

  await Supabase.initialize(
    url: supabaseUrl,
    anonKey: supabaseAnonKey,
  );

  runApp(const MyApp());
} 

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DSU BLE Attendance',
      theme: ThemeData(primarySwatch: Colors.indigo),
      initialRoute: '/',
      routes: {
        '/': (context) => const LoginScreen(),
        '/courses': (context) => const CoursesScreen(),
      },
    );
  }
}

