import 'package:flutter/material.dart';
import 'package:frontend/screens/auth/auth_service.dart';
import '../landing_page.dart';

class OtpVerificationPage extends StatefulWidget {
  final String email;
  final bool isSignUp;

  const OtpVerificationPage({super.key, required this.email, required this.isSignUp});

  @override
  State<OtpVerificationPage> createState() => _OtpVerificationPageState();
}

class _OtpVerificationPageState extends State<OtpVerificationPage> {
  final TextEditingController _otpController = TextEditingController();
  bool _isLoading = false;

 void _verifyOtp() async {
    final token = _otpController.text.trim();
    if (token.length < 6) return;

    setState(() => _isLoading = true);
    try {
      await AuthService().verifyEmailOTP(
        widget.email, 
        token, 
        isSignUp: widget.isSignUp
      );

      if (!mounted) return;

      // IMPORTANT: Don't push LandingPage. 
      // Just pop back to the root. AuthGate will see the session 
      // and swap LoginPage for LandingPage automatically.
      Navigator.of(context).popUntil((route) => route.isFirst);
      
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Verification Failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
  @override
  void dispose() {
    _otpController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Verify Email',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Enter the 6-digit code sent to ${widget.email}',
                style: const TextStyle(
                  fontSize: 16,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 48),
              // Using a simple TextField for a 6-digit OTP
              TextField(
                controller: _otpController,
                keyboardType: TextInputType.number,
                maxLength: 6,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 24, letterSpacing: 8.0, fontWeight: FontWeight.bold),
                decoration: InputDecoration(
                  counterText: "",
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 48),
              ElevatedButton(
                onPressed: _isLoading ? null : _verifyOtp,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                ),
                child: _isLoading 
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text('Verify and Proceed', style: TextStyle(fontSize: 16)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
