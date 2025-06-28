import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pump_management_system/screens/premise_product_details_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/premise.dart';
import '../models/subsection_product.dart'; // For Product class

class CreatePremiseProductScreen extends StatefulWidget {
  final String premiseId;
  final String premiseName;
  final Premise? premise; // Optional premise object

  const CreatePremiseProductScreen({
    super.key,
    required this.premiseId,
    required this.premiseName,
    this.premise,
  });

  @override
  State<CreatePremiseProductScreen> createState() =>
      _CreatePremiseProductScreenState();
}

class _CreatePremiseProductScreenState
    extends State<CreatePremiseProductScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _quantityController = TextEditingController();
  final TextEditingController _detailsController = TextEditingController();

  final SupabaseClient _supabase = Supabase.instance.client;
  bool _isLoading = false;

  // Construction company color scheme
  static const Color primaryBlue = Color(0xFF1B365D);
  static const Color accentOrange = Color(0xFFFF6B35);
  static const Color lightGray = Color(0xFFF5F6FA);
  static const Color darkGray = Color(0xFF2C3E50);
  static const Color successGreen = Color(0xFF27AE60);

  Future<void> _createProduct() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      // Get current user ID for RLS policy
      final user = _supabase.auth.currentUser;
      if (user == null) throw Exception('User not authenticated');

      final response = await _supabase.from('premise_products').insert({
        'contractor_id': user.id, // Add contractor_id for RLS policy
        'premise_id': widget.premiseId,
        'name': _nameController.text.trim(),
        'quantity': int.tryParse(_quantityController.text.trim()) ?? 1,
        'details': {'info': _detailsController.text.trim()},
      }).select().single();

      final productId = response['id'] as String;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Product added successfully!'),
          backgroundColor: successGreen,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );

      // Fetch the complete product data
      final productData = await _supabase
          .from('premise_products')
          .select()
          .eq('id', productId)
          .single();

      // Create the Product object
      final product = Product(
        id: productData['id'],
        premiseId: productData['premise_id'],
        name: productData['name'],
        quantity: productData['quantity'] ?? 1,
        details: productData['details'] ?? {},
        createdAt: DateTime.parse(productData['created_at']),
      );

      // Use the existing premise object if available, otherwise fetch it
      Premise premise;
      if (widget.premise != null) {
        premise = widget.premise!;
      } else {
        final premiseData = await _supabase
            .from('premises')
            .select()
            .eq('id', widget.premiseId)
            .single();

        premise = Premise(
          id: premiseData['id'],
          contractorId: premiseData['contractor_id'] ?? '',
          name: premiseData['data']['name'] ?? widget.premiseName,
          additionalData: Map<String, dynamic>.from(premiseData['data'] ?? {})..remove('name'),
          contractorName: premiseData['contractor_name'] ?? 'Unknown',
        );
      }

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => ProductDetailsScreen(
            product: product,
            premise: premise,
          ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: Colors.red.shade600,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [primaryBlue, primaryBlue.withOpacity(0.8)],
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.arrow_back, color: Colors.white, size: 28),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Add New Product',
                          style: GoogleFonts.roboto(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'To ${widget.premiseName}',
                          style: GoogleFonts.roboto(
                            fontSize: 16,
                            color: Colors.white.withOpacity(0.9),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.inventory_2, color: Colors.white, size: 24),
                    const SizedBox(width: 12),
                    Text(
                      'Product Management System',
                      style: GoogleFonts.roboto(
                        fontSize: 16,
                        color: Colors.white,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFormField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? Function(String?)? validator,
    TextInputType? keyboardType,
    int maxLines = 1,
    String? hint,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.roboto(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: darkGray,
            ),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: controller,
            validator: validator,
            keyboardType: keyboardType,
            maxLines: maxLines,
            style: GoogleFonts.roboto(
              fontSize: 16,
              color: darkGray,
            ),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: GoogleFonts.roboto(
                color: Colors.grey.shade500,
                fontSize: 14,
              ),
              prefixIcon: Container(
                margin: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: accentOrange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: accentOrange, size: 20),
              ),
              filled: true,
              fillColor: Colors.white,
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
                borderSide: const BorderSide(color: accentOrange, width: 2),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.red.shade400),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: lightGray,
      body: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Progress indicator
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 10,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: primaryBlue.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(Icons.info_outline, color: primaryBlue, size: 20),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Fill in the product details below to add it to your premise inventory.',
                                style: GoogleFonts.roboto(
                                  fontSize: 14,
                                  color: darkGray,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 32),

                      // Form fields container
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.08),
                              blurRadius: 20,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Product Information',
                              style: GoogleFonts.roboto(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: primaryBlue,
                              ),
                            ),
                            const SizedBox(height: 24),

                            _buildFormField(
                              controller: _nameController,
                              label: 'Product Name',
                              icon: Icons.label_outline,
                              hint: 'Enter the product name',
                              validator: (value) =>
                              value == null || value.isEmpty ? 'Please enter a product name' : null,
                            ),

                            _buildFormField(
                              controller: _quantityController,
                              label: 'Quantity',
                              icon: Icons.inventory,
                              hint: 'Enter quantity (e.g., 10)',
                              keyboardType: TextInputType.number,
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please enter quantity';
                                }
                                if (int.tryParse(value) == null || int.parse(value) <= 0) {
                                  return 'Please enter a valid positive number';
                                }
                                return null;
                              },
                            ),

                            _buildFormField(
                              controller: _detailsController,
                              label: 'Product Details',
                              icon: Icons.description_outlined,
                              hint: 'Add any additional details about the product (optional)',
                              maxLines: 4,
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 32),

                      // Create button
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _createProduct,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _isLoading ? Colors.grey.shade400 : accentOrange,
                            foregroundColor: Colors.white,
                            elevation: _isLoading ? 0 : 8,
                            shadowColor: accentOrange.withOpacity(0.3),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: _isLoading
                              ? Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Text(
                                'Creating Product...',
                                style: GoogleFonts.roboto(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          )
                              : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.add_circle_outline, size: 24),
                              const SizedBox(width: 12),
                              Text(
                                'Create Product',
                                style: GoogleFonts.roboto(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _quantityController.dispose();
    _detailsController.dispose();
    super.dispose();
  }
}