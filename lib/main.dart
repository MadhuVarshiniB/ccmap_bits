import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'screens/auth/auth_gate.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
Future main() async {
  WidgetsFlutterBinding.ensureInitialized(); // Required for async main
  await dotenv.load();
  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL'] ?? '',
    anonKey: dotenv.env['SUPABASE_KEY'] ?? '',
    // Adding PKCE flow is best practice for Web redirects
    authOptions: const FlutterAuthClientOptions(
      authFlowType: AuthFlowType.pkce,
    ),
  );
  
  runApp(const BikeShareApp());
}

class BikeShareApp extends StatelessWidget {
  const BikeShareApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BikeShare MVP',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.green),
        useMaterial3: true,
      ),
      // AUTH GATE: Automatically listens to stream auth state changes
      home: const AuthGate(),
      debugShowCheckedModeBanner: false,
    );
  }
}