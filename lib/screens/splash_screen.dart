import 'dart:developer';


import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'login_page.dart';


class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _navigateToHome();
  }

  // Future<void> _route() async {
  //   final supabase = Supabase.instance.client;
  //   final session = supabase.auth.currentSession;
  //   log("Session: ${session.toString()}");

  //   if(session != null) {
  //     final user = supabase.auth.currentUser;
  //     final email = user?.userMetadata?['email'];

  //     final contractorData = await supabase
  //         .from('contractor')
  //         .select()
  //         .eq('email', email)
  //         .maybeSingle();

  //     if(contractorData != null)
  //       Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const ContractorDashboard()));

  //     // Check if the user is a site manager
  //     final siteManagerData = await supabase
  //         .from('site_manager')
  //         .select()
  //         .eq('email', email)
  //         .maybeSingle();

  //     if(siteManagerData != null)
  //       Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const SiteManagerDashboard()));
  //   }

  //   else
  //     Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const LoginPage()));
  // }

  _navigateToHome() async {
    await Future.delayed(const Duration(seconds: 1), () {});
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const LoginPage()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        height: double.infinity,
        width: double.infinity,
        child: Image.asset(
          'assets/images/Tecnvi_AI_logo.jpeg'
        ),
      ),
      backgroundColor: Colors.white,
    );
  }
}