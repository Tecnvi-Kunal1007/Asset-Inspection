import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:pump_management_system/screens/call_screen.dart';
// import 'package:pump_management_system/screens/call_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'screens/contractor_dashboard_screen.dart';
import 'package:google_fonts/google_fonts.dart';
import 'services/auth_service.dart';
import 'screens/login_page.dart';
import 'package:app_links/app_links.dart';
import 'dart:async';
import 'test_freelancer.dart'; // Import the test screen
import 'services/deep_link_service.dart';


void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await dotenv.load(fileName: ".env");
    print("🔑 Loaded API Key: ${dotenv.env['OPENAI_API_KEY']?.substring(0, 10)}...");
    print("📋 Available env keys: ${dotenv.env.keys.toList()}");
  } catch (e) {
    print("❌ Error loading .env file: $e");
    if (kIsWeb) {
      print("⚠️ Web platform detected - .env loading may not work as expected");
    }
  }
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
  const MyApp({Key? key}) : super(key: key);

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final _supabase = Supabase.instance.client;
  late AppLinks _appLinks;
  StreamSubscription<Uri>? _linkSubscription;
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();
  String? _initialChannel;
  String? _initialToken;

  @override
  void initState() {
    super.initState();
    _appLinks = AppLinks();
    _checkInitialUrl();
  }

  Future<void> _checkInitialUrl() async {
    if (kIsWeb) {
      final uri = Uri.base;
      if (uri.path == '/join' && uri.queryParameters.containsKey('channel')) {
        print('Deep link detected - Channel: ${uri.queryParameters['channel']}, Token: ${uri.queryParameters['token']}');
        setState(() {
          _initialChannel = uri.queryParameters['channel'];
          _initialToken = uri.queryParameters['token'];
        });
      } else {
        print('No deep link detected on web');
      }
    } else {
      final initialUri = await _appLinks.getInitialLink();
      if (initialUri != null) {
        _handleLink(initialUri);
      }
      _linkSubscription = _appLinks.uriLinkStream.listen(_handleLink);
    }
  }

  void _handleLink(Uri uri) {
    if (uri.scheme == 'assetmanagement' && uri.host == 'join' && uri.queryParameters.containsKey('channel')) {
      print('Mobile deep link detected - Channel: ${uri.queryParameters['channel']}, Token: ${uri.queryParameters['token']}');
      setState(() {
        _initialChannel = uri.queryParameters['channel'];
        _initialToken = uri.queryParameters['token'];
      });
    }
  }

  @override
  void dispose() {
    _linkSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Building Management System',
      navigatorKey: _navigatorKey,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        textTheme: GoogleFonts.poppinsTextTheme(),
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      initialRoute: '/',
      onGenerateRoute: (settings) {
        final uri = Uri.parse(settings.name ?? '/');
        if (uri.path == '/join' && uri.queryParameters.containsKey('channel')) {
          print('Navigating via onGenerateRoute - Channel: ${uri.queryParameters['channel']}');
          return MaterialPageRoute(
            builder: (context) => CallScreen.withJoinConfirmation(
              channelName: uri.queryParameters['channel']!,
              token: uri.queryParameters['token'],
            ),
          );
        }
        print('Default route to LoginPage');
        return MaterialPageRoute(builder: (context) => const LoginPage());
      },
      home: _initialChannel != null
          ? CallScreen.withJoinConfirmation(
        channelName: _initialChannel!,
        token: _initialToken,
      )
          : const LoginPage(),
    );
  }
}