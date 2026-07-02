import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'screens/auth/auth_gate.dart';
import 'theme/wabway_theme.dart';

// Injected at build time via --dart-define-from-file=.env
// See .env.example for required keys.
const _supabaseUrl = String.fromEnvironment('SUPABASE_URL');
const _supabasePublishableKey = String.fromEnvironment('SUPABASE_ANON_KEY');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  assert(
    _supabaseUrl.isNotEmpty && _supabasePublishableKey.isNotEmpty,
    'SUPABASE_URL and SUPABASE_ANON_KEY must be set.\n'
    'Run with: flutter run --dart-define-from-file=.env',
  );

  await Supabase.initialize(
    url: _supabaseUrl,
    publishableKey: _supabasePublishableKey,
    debug: kDebugMode,
  );

  if (kDebugMode) {
    debugPrint('[Supabase] initialized → $_supabaseUrl');
  }

  runApp(const WabwayApp());
}

class WabwayApp extends StatelessWidget {
  const WabwayApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Wabway',
      debugShowCheckedModeBanner: false,
      theme: buildWabwayTheme(),
      home: const AuthGate(),
    );
  }
}
