import 'package:supabase_flutter/supabase_flutter.dart';

class AuthService{
  final SupabaseClient _supabase = Supabase.instance.client;

  Future<AuthResponse> signInWithEmailPassword(
    String email, String password) async{
      return await _supabase.auth.signInWithPassword(
        email: email,
        password: password
      );
    }

// Inside your AuthService class
  Future<void> signUpWithEmailPassword(
    String email, 
    String password, 
    String fullName, 
    String phoneNumber,
    String gender
  ) async {
    await Supabase.instance.client.auth.signUp(
      email: email,
      password: password,
      data: {
        'full_name': fullName,
        'phone_number': phoneNumber,
        'gender': gender,
        'role': 'user',
        'wallet_balance': 0,
      },
    );
  }

    Future<void> signOut() async{
      await _supabase.auth.signOut();
    }

    String? getCurrentUserEmail(){
      final session = _supabase.auth.currentSession;
      final user = session?.user;
      return user?.email;
    }

    
}