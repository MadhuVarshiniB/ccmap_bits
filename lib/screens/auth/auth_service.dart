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
    final response = await Supabase.instance.client.auth.signUp(
      email: email,
      password: password,
    );

    final user = response.user;

    if (user != null) {
      // This updates your 'profiles' table from the image
      await Supabase.instance.client.from('profiles').insert({
        'id': user.id, // Links to auth.users.id
        'full_name': fullName,
        'phone_number': phoneNumber,
        'gender': gender,
        'role': 'user', // Default role
        'wallet_balance': 0, // Initial balance
      });
    }
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