import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'screens/contractor_dashboard_screen.dart';
import 'package:google_fonts/google_fonts.dart';
import 'services/auth_service.dart';
import 'screens/splash_screen.dart';
import 'screens/login_page.dart';
import 'screens/reset_password_callback.dart';
import 'package:app_links/app_links.dart';
import 'dart:async';
import 'test_freelancer.dart'; // Import the test screen

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await dotenv.load(fileName: ".env");
  if (kIsWeb) {
    print("Running on Web");

    await Supabase.initialize(
      url: 'https://crvztrqgmqfixzatlkgz.supabase.co',
      anonKey:
          'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImNydnp0cnFnbXFmaXh6YXRsa2d6Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTIzMjA0MzcsImV4cCI6MjA2Nzg5NjQzN30.9gT5CRf7UuS7MaOHEP41mvOjRdteF5FpC5e_GZelEss',
    );
  } else {
    print("Running on Mobile");

    // ✅ You must load dotenv before using it
    // await dotenv.load(fileName: "assets/.env");

    await Supabase.initialize(
      url: 'https://crvztrqgmqfixzatlkgz.supabase.co',
      anonKey:
          'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImNydnp0cnFnbXFmaXh6YXRsa2d6Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTIzMjA0MzcsImV4cCI6MjA2Nzg5NjQzN30.9gT5CRf7UuS7MaOHEP41mvOjRdteF5FpC5e_GZelEss',
    );
  }

  runApp(MyApp());
}

class MyApp extends StatefulWidget {
  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final _supabase = Supabase.instance.client;
  late AppLinks _appLinks;
  StreamSubscription? _linkSubscription;
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();
    _initDeepLinks();
  }

  @override
  void dispose() {
    _linkSubscription?.cancel();
    super.dispose();
  }

  Future<void> _initDeepLinks() async {
    _appLinks = AppLinks();

    // Handle links when app is already running
    _linkSubscription = _appLinks.uriLinkStream.listen(
      (uri) {
        _handleDeepLink(uri);
      },
      onError: (err) {
        print('Error handling deep links: $err');
      },
    );

    // Handle links when app is opened from terminated state
    try {
      final uri = await _appLinks.getInitialLink();
      if (uri != null) {
        _handleDeepLink(uri);
      }
    } catch (e) {
      print('Error getting initial link: $e');
    }
  }

  void _handleDeepLink(Uri uri) {
    if (uri.toString().contains('reset-callback')) {
      // Navigate to reset password screen
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_navigatorKey.currentContext != null) {
          Navigator.of(_navigatorKey.currentContext!).pushAndRemoveUntil(
            MaterialPageRoute(
              builder: (context) => const ResetPasswordCallback(),
            ),
            (route) => false,
          );
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Building Management System',
      navigatorKey: _navigatorKey,
      theme: ThemeData(textTheme: GoogleFonts.poppinsTextTheme()),
      // Comment out the test screen and uncomment the login page
      // home: const TestFreelancerScreen(), // For testing freelancer service
      home: const LoginPage(), // Regular app flow
    );
  }
}
