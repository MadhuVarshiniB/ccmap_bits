import 'package:supabase_flutter/supabase_flutter.dart';

class AuthService{
  final SupabaseClient _supabase = Supabase.instance.client;

  Future<void> signInWithEmailOTP(String email) async {
    await _supabase.auth.signInWithOtp(
      email: email,
    );
  }

  Future<AuthResponse> signInWithEmailPassword(String email, String password) async {
    return await _supabase.auth.signInWithPassword(
      email: email,
      password: password,
    );
  }

  Future<AuthResponse> verifyEmailOTP(String email, String token, {bool isSignUp = false}) async {
    return await _supabase.auth.verifyOTP(
      email: email,
      token: token,
      type: isSignUp ? OtpType.signup : OtpType.magiclink,
    );
  }

Future<void> signUpWithEmail(
  String email, 
  String fullName, 
  String phoneNumber,
  String gender
) async {
  await _supabase.auth.signUp(
    email: email,
    password: "tempPassword123!", // Required for signUp method
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
