import 'package:flutter/material.dart';
import 'package:frontend/screens/auth/login_page.dart';
import 'package:frontend/screens/landing_page.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: Supabase.instance.client.auth.onAuthStateChange,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
           return const Scaffold(
             body: Center(child: CircularProgressIndicator(color: Colors.green)),
           );
        }
        
        final session = snapshot.data?.session;
        if (session != null) {
          return const LandingPage();
        } else {
          return const LoginPage();
        }
      },
    );
  }
}