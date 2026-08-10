import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'screens/auth/auth_gate.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'services/app_settings.dart';

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

  // Pre-load app settings (NFC dev mode flag, etc.)
  await AppSettings.instance.load();
  
  runApp(const BikeShareApp());
}

final ValueNotifier<ThemeMode> themeNotifier = ValueNotifier(ThemeMode.light);

class BikeShareApp extends StatelessWidget {
  const BikeShareApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (_, ThemeMode currentMode, __) {
        return MaterialApp(
          title: 'CCMAP - E-Bike Sharing',
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(seedColor: Colors.green, brightness: Brightness.light),
            useMaterial3: true,
            textTheme: GoogleFonts.poppinsTextTheme(
              ThemeData.light().textTheme,
            ),
          ),
          darkTheme: ThemeData(
            colorScheme: ColorScheme.fromSeed(seedColor: Colors.green, brightness: Brightness.dark),
            useMaterial3: true,
            textTheme: GoogleFonts.poppinsTextTheme(
              ThemeData.dark().textTheme,
            ),
          ),
          themeMode: currentMode,
          // AUTH GATE: Automatically listens to stream auth state changes
          home: const AuthGate(),
          debugShowCheckedModeBanner: false,
        );
      },
    );
  }
}