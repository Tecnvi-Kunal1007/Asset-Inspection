import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../models/area.dart';
import '../services/supabase_service.dart';

class CreateAreaScreen extends StatefulWidget {
  const CreateAreaScreen({super.key});

  @override
  State<CreateAreaScreen> createState() => _CreateAreaScreenState();
}

class _CreateAreaScreenState extends State<CreateAreaScreen> {
  final _formKey = GlobalKey<FormState>();
  final _supabaseService = SupabaseService();
  final _uuid = const Uuid();

  // Form controllers
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _siteOwnerController = TextEditingController();
  final _siteOwnerEmailController = TextEditingController();
  final _siteOwnerPhoneController = TextEditingController();
  final _siteManagerController = TextEditingController();
  final _siteManagerEmailController = TextEditingController();
  final _siteManagerPhoneController = TextEditingController();
  final _siteLocationController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _siteOwnerController.dispose();
    _siteOwnerEmailController.dispose();
    _siteOwnerPhoneController.dispose();
    _siteManagerController.dispose();
    _siteManagerEmailController.dispose();
    _siteManagerPhoneController.dispose();
    _siteLocationController.dispose();
    super.dispose();
  }

  Future<void> _createArea() async {
    if (!_formKey.currentState!.validate()) return;

    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      final contractorData =
          await Supabase.instance.client
              .from('contractor')
              .select()
              .eq('id', user.id)
              .maybeSingle();

      final area = Area(
        id: _uuid.v4(),
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim(),
        contractorId: user.id,
        siteOwner: _siteOwnerController.text.trim(),
        siteOwnerEmail: _siteOwnerEmailController.text.trim(),
        siteOwnerPhone: _siteOwnerPhoneController.text.trim(),
        siteManager: _siteManagerController.text.trim(),
        siteManagerEmail: _siteManagerEmailController.text.trim(),
        siteManagerPhone: _siteManagerPhoneController.text.trim(),
        siteLocation: _siteLocationController.text.trim(),
        contractorEmail: contractorData?['email'] ?? '',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await _supabaseService.createArea(area);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Area created successfully!',
            style: GoogleFonts.poppins(),
          ),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );

      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString()),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    }
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: TextFormField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: GoogleFonts.poppins(color: Colors.grey.shade600),
          prefixIcon: Icon(icon, color: Colors.blue.shade700),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.blue.shade700, width: 2),
          ),
          filled: true,
          fillColor: Colors.white,
        ),
        keyboardType: keyboardType,
        validator:
            validator ??
            (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter $label';
              }
              return null;
            },
        style: GoogleFonts.poppins(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Create Area', style: GoogleFonts.poppins()),
        elevation: 0,
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        foregroundColor: Colors.blue.shade700,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Card(
                margin: EdgeInsets.zero,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Area Information',
                        style: GoogleFonts.poppins(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue.shade700,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildTextField(
                        controller: _nameController,
                        label: 'Area Name',
                        icon: Icons.business,
                      ),
                      _buildTextField(
                        controller: _descriptionController,
                        label: 'Description',
                        icon: Icons.description,
                      ),
                      _buildTextField(
                        controller: _siteLocationController,
                        label: 'Location',
                        icon: Icons.location_on,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Card(
                margin: EdgeInsets.zero,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Owner Information',
                        style: GoogleFonts.poppins(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue.shade700,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildTextField(
                        controller: _siteOwnerController,
                        label: 'Owner Name',
                        icon: Icons.person,
                      ),
                      _buildTextField(
                        controller: _siteOwnerEmailController,
                        label: 'Owner Email',
                        icon: Icons.email,
                        keyboardType: TextInputType.emailAddress,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter owner email';
                          }
                          if (!value.contains('@')) {
                            return 'Please enter a valid email';
                          }
                          return null;
                        },
                      ),
                      _buildTextField(
                        controller: _siteOwnerPhoneController,
                        label: 'Owner Phone',
                        icon: Icons.phone,
                        keyboardType: TextInputType.phone,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Card(
                margin: EdgeInsets.zero,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Manager Information',
                        style: GoogleFonts.poppins(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue.shade700,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildTextField(
                        controller: _siteManagerController,
                        label: 'Manager Name',
                        icon: Icons.manage_accounts,
                      ),
                      _buildTextField(
                        controller: _siteManagerEmailController,
                        label: 'Manager Email',
                        icon: Icons.email,
                        keyboardType: TextInputType.emailAddress,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter manager email';
                          }
                          if (!value.contains('@')) {
                            return 'Please enter a valid email';
                          }
                          return null;
                        },
                      ),
                      _buildTextField(
                        controller: _siteManagerPhoneController,
                        label: 'Manager Phone',
                        icon: Icons.phone,
                        keyboardType: TextInputType.phone,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _createArea,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue.shade700,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: Text(
                  'Create Area',
                  style: GoogleFonts.poppins(fontSize: 16, color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
