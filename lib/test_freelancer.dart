// import 'package:flutter/material.dart';
// import 'package:supabase_flutter/supabase_flutter.dart';
// import 'services/freelancer_service.dart';
// import 'models/freelancer.dart';
//
// class TestFreelancerScreen extends StatefulWidget {
//   const TestFreelancerScreen({Key? key}) : super(key: key);
//
//   @override
//   State<TestFreelancerScreen> createState() => _TestFreelancerScreenState();
// }
//
// class _TestFreelancerScreenState extends State<TestFreelancerScreen> {
//   final FreelancerService _freelancerService = FreelancerService();
//   bool _isLoading = false;
//   String _result = '';
//
//   Future<void> _testAddFreelancer() async {
//     setState(() {
//       _isLoading = true;
//       _result = 'Testing add freelancer...';
//     });
//
//     try {
//       // Check current user
//       final user = Supabase.instance.client.auth.currentUser;
//       if (user == null) {
//         setState(() {
//           _result = 'Error: No authenticated user found';
//           _isLoading = false;
//         });
//         return;
//       }
//
//       _result += '\nCurrent user: ${user.id}, ${user.email}';
//
//       // Prepare test data
//       final freelancerData = {
//         'name': 'Test Freelancer ${DateTime.now().millisecondsSinceEpoch}',
//         'email': 'test${DateTime.now().millisecondsSinceEpoch}@example.com',
//         'phone': '1234567890',
//         'address': 'Test Address',
//         'skill': 'Test Skill',
//         'specialization': 'Test Specialization',
//         'experience_years': 5,
//         'notes': 'Test Notes',
//         'role': 'freelancer',
//         'status': 'active',
//         'created_at': DateTime.now().toIso8601String(),
//         'updated_at': DateTime.now().toIso8601String(),
//       };
//
//       _result += '\nFreelancer data prepared: $freelancerData';
//
//       // Try to add freelancer
//       final freelancer = await _freelancerService.addFreelancer(freelancerData);
//
//       if (freelancer == null) {
//         _result += '\nError: Failed to add freelancer';
//       } else {
//         _result += '\nFreelancer added successfully: ${freelancer.id}, ${freelancer.name}';
//       }
//     } catch (e) {
//       _result += '\nError: $e';
//     } finally {
//       setState(() {
//         _isLoading = false;
//       });
//     }
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: const Text('Test Freelancer Service'),
//       ),
//       body: Padding(
//         padding: const EdgeInsets.all(16.0),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.stretch,
//           children: [
//             ElevatedButton(
//               onPressed: _isLoading ? null : _testAddFreelancer,
//               child: _isLoading
//                 ? const CircularProgressIndicator()
//                 : const Text('Test Add Freelancer'),
//             ),
//             const SizedBox(height: 20),
//             Expanded(
//               child: SingleChildScrollView(
//                 child: Text(
//                   _result,
//                   style: const TextStyle(fontSize: 16),
//                 ),
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }