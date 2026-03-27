import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'screens/auth/auth_gate.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized(); // Required for async main

  await Supabase.initialize(
    url: "https://ypsnbqcssryflpurgzzy.supabase.co",
    anonKey: "sb_publishable_Lcppv0mvsfIiNFmwiexEPA_AqDNzQcL",
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