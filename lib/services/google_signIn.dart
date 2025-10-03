import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../screens/contractor_dashboard_screen.dart';
import '../screens/site_manager_dashboard.dart';

class GoogleSignInWithRole extends StatefulWidget {
  const GoogleSignInWithRole({Key? key}) : super(key: key);

  @override
  State<GoogleSignInWithRole> createState() => _GoogleSignInWithRoleState();
}

class _GoogleSignInWithRoleState extends State<GoogleSignInWithRole> {
  String? selectedRole;
  bool isLoading = false;

  final supabase = Supabase.instance.client;

  Future<void> signInWithGoogle() async {
    if (selectedRole == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select a role before signing in")),
      );
      return;
    }

    setState(() => isLoading = true);

    try {
      // Initiate Google OAuth sign-in
      await Supabase.instance.client.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: 'https://assetmanagementsystem-tecnvi.web.app',
      );

      // Listen for auth state changes
      supabase.auth.onAuthStateChange.listen((data) async {
        final session = data.session;
        if (session != null && mounted) {
          final userId = session.user.id;
          final email = session.user.email;
          final name = session.user.userMetadata?['full_name'] ?? '';

          try {
            // Check if user already exists in any table
            final contractorRes = await supabase
                .from('contractor')
                .select()
                .eq('id', userId)
                .maybeSingle();

            final freelancerRes = await supabase
                .from('freelancer_employee')
                .select()
                .eq('id', userId)
                .maybeSingle();

            if (contractorRes != null) {
              // Existing contractor user
              if (mounted) {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (_) => const ContractorDashboardScreen()),
                );
              }
            } else if (freelancerRes != null) {
              // Existing freelancer user
              if (mounted) {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (_) => const SiteManagerDashboard()),
                );
              }
            } else {
              // New user - insert into selected role table
              if (selectedRole == 'Contractor') {
                await supabase.from('contractor').insert({
                  'id': userId,
                  'email': email ?? '',
                  'name': name,
                  'login_provider': 'google',
                  'created_at': DateTime.now().toIso8601String(),
                });
                if (mounted) {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (_) => const ContractorDashboardScreen()),
                  );
                }
              } else if (selectedRole == 'Freelancer') {
                await supabase.from('freelancer_employee').insert({
                  'id': userId,
                  'email': email ?? '',
                  'name': name,
                  'login_provider': 'google',
                  'created_at': DateTime.now().toIso8601String(),
                });
                if (mounted) {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (_) => const SiteManagerDashboard()),
                  );
                }
              }
            }
          } catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text("Database error: $e")),
              );
            }
          }
        }
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Sign-in error: $e")),
        );
      }
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Google Sign-In"),
        backgroundColor: Colors.blue.shade600,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.account_circle,
              size: 100,
              color: Colors.blue,
            ),
            const SizedBox(height: 30),
            const Text(
              "Select your role:",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 20),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(8),
              ),
              child: DropdownButton<String>(
                value: selectedRole,
                hint: const Text("Select Role"),
                isExpanded: true,
                underline: const SizedBox(),
                items: const [
                  DropdownMenuItem(
                    value: "Contractor",
                    child: Text("Contractor"),
                  ),
                  DropdownMenuItem(
                    value: "freelancer_employee",
                    child: Text("Freelancer Employee"),
                  ),
                ],
                onChanged: (value) => setState(() => selectedRole = value),
              ),
            ),
            const SizedBox(height: 30),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: isLoading ? null : signInWithGoogle,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue.shade600,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                icon: isLoading
                    ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                )
                    : const Icon(Icons.login),
                label: Text(
                  isLoading ? "Signing in..." : "Sign in with Google",
                  style: const TextStyle(fontSize: 16),
                ),
              ),
            ),
            const SizedBox(height: 20),
            if (selectedRole != null)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info, color: Colors.blue.shade600),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        "You'll be registered as: $selectedRole",
                        style: TextStyle(
                          color: Colors.blue.shade800,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}