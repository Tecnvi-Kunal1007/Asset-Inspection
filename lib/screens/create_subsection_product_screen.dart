import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/supabase_service.dart';
import '../utils/responsive_helper.dart';
import '../utils/theme_helper.dart';
import '../models/subsection_product.dart';
import '../models/premise.dart';
// import 'PremiseDetailsScreen.dart';

class SubsectionProductsScreen extends StatefulWidget {
  final Premise premise;
  final String subsectionId;
  final String subsectionName;

  const SubsectionProductsScreen({
    super.key,
    required this.premise,
    required this.subsectionId,
    required this.subsectionName,
  });

  @override
  State<SubsectionProductsScreen> createState() => _SubsectionProductsScreenState();
}

class _SubsectionProductsScreenState extends State<SubsectionProductsScreen> {
  final _supabaseService = SupabaseService();
  final _supabase = Supabase.instance.client;
  final _formKey = GlobalKey<FormState>();

  // Form controllers
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();

  // State variables
  bool _isLoading = true;
  bool _isCreating = false;
  bool _isSubmitting = false;
  List<Product> _products = [];
  String _searchQuery = '';
  final List<Map<String, String>> _keyValuePairs = [{}];

  // Construction company color scheme
  static const Color primaryBlue = Color(0xFF1B365D);
  static const Color accentOrange = Color(0xFFFF6B35);
  static const Color lightGray = Color(0xFFF5F6FA);
  static const Color darkGray = Color(0xFF2C3E50);
  static const Color successGreen = Color(0xFF27AE60);
  static const Color cardWhite = Color(0xFFFFFFFF);

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  Future<void> _loadProducts() async {
    try {
      setState(() => _isLoading = true);

      final user = _supabase.auth.currentUser;
      if (user != null) {
        final products = await _supabaseService.getProducts(widget.subsectionId);
        setState(() {
          _products = products;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error loading products: $e'),
          backgroundColor: Colors.red.shade600,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }

  Future<void> _createProduct() async {
    if (!_formKey.currentState!.validate()) return;

    if (!RegExp(r'^[A-Z]').hasMatch(_nameController.text)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Product name must start with a capital letter.')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    final data = {
      'name': _nameController.text.trim(),
      'location': _locationController.text.isNotEmpty ? _locationController.text.trim() : null,
    };

    // Add key-value pairs
    for (var pair in _keyValuePairs) {
      if (pair['key']?.isNotEmpty == true && pair['value']?.isNotEmpty == true) {
        data[pair['key']!] = pair['value'];
      }
    }

    try {
      final user = _supabase.auth.currentUser;
      if (user == null) throw Exception('User not authenticated');

      await _supabaseService.createProduct(widget.subsectionId, data);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Product created successfully!'),
          backgroundColor: successGreen,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );

      // Reset form and reload products
      _nameController.clear();
      _locationController.clear();
      _keyValuePairs.clear();
      _keyValuePairs.add({});
      setState(() => _isCreating = false);

      await _loadProducts();

    } on PostgrestException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.code == '23514'
              ? 'Invalid product name. Please ensure it starts with a capital letter.'
              : 'Error creating product: ${e.message}'),
          backgroundColor: Colors.red.shade600,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error creating product: $e'),
          backgroundColor: Colors.red.shade600,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    } finally {
      setState(() => _isSubmitting = false);
    }
  }

  void _addKeyValuePair() {
    setState(() {
      _keyValuePairs.add({});
    });
  }

  void _removeKeyValuePair(int index) {
    if (_keyValuePairs.length > 1) {
      setState(() {
        _keyValuePairs.removeAt(index);
      });
    }
  }

  List<Product> get _filteredProducts {
    if (_searchQuery.isEmpty) return _products;
    return _products.where((product) =>
        product.name.toLowerCase().contains(_searchQuery.toLowerCase())).toList();
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
                          widget.subsectionName,
                          style: GoogleFonts.roboto(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Product Management',
                          style: GoogleFonts.roboto(
                            fontSize: 16,
                            color: Colors.white.withOpacity(0.9),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Add Product Button
                  Container(
                    decoration: BoxDecoration(
                      color: accentOrange,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: accentOrange.withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: IconButton(
                      onPressed: () => setState(() => _isCreating = !_isCreating),
                      icon: Icon(
                        _isCreating ? Icons.close : Icons.add,
                        color: Colors.white,
                        size: 28,
                      ),
                      tooltip: _isCreating ? 'Cancel' : 'Add New Product',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Stats Container
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
                      '${_products.length} ${_products.length == 1 ? 'Product' : 'Products'}',
                      style: GoogleFonts.roboto(
                        fontSize: 16,
                        color: Colors.white,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const Spacer(),
                    Icon(Icons.location_on, color: Colors.white, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      widget.premise.name,
                      style: GoogleFonts.roboto(
                        fontSize: 14,
                        color: Colors.white.withOpacity(0.9),
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

  Widget _buildSearchBar() {
    return Container(
      margin: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 15,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: TextField(
        controller: _searchController,
        onChanged: (value) => setState(() => _searchQuery = value),
        style: GoogleFonts.roboto(fontSize: 16, color: darkGray),
        decoration: InputDecoration(
          hintText: 'Search products...',
          hintStyle: GoogleFonts.roboto(color: Colors.grey.shade500),
          prefixIcon: Container(
            margin: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: primaryBlue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Icons.search, color: primaryBlue, size: 20),
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
      ),
    );
  }

  Widget _buildProductCard(Product product) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Card(
        elevation: 8,
        shadowColor: Colors.black.withOpacity(0.1),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: InkWell(
          onTap: () {
            // Navigate to individual product details if needed
            // You can implement this based on your requirements
          },
          borderRadius: BorderRadius.circular(16),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Colors.white, Colors.grey.shade50],
              ),
            ),
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Product Icon
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: accentOrange.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.inventory,
                        color: accentOrange,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 16),

                    // Product Info
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            product.name,
                            style: GoogleFonts.roboto(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: darkGray,
                            ),
                          ),
                          const SizedBox(height: 4),

                          // Location if available
                          if (product.data['location'] != null) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: primaryBlue.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.location_on, size: 16, color: primaryBlue),
                                  const SizedBox(width: 4),
                                  Text(
                                    product.data['location'].toString(),
                                    style: GoogleFonts.roboto(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: primaryBlue,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),

                    // Arrow Icon
                    Icon(
                      Icons.arrow_forward_ios,
                      color: Colors.grey.shade400,
                      size: 16,
                    ),
                  ],
                ),

                // Additional product data
                if (product.data.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.info_outline, size: 16, color: Colors.grey.shade600),
                            const SizedBox(width: 8),
                            Text(
                              'Additional Details',
                              style: GoogleFonts.roboto(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey.shade700,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ...product.data.entries
                            .where((entry) => entry.key != 'location' && entry.key != 'name')
                            .map((entry) => Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${entry.key}: ',
                                style: GoogleFonts.roboto(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                              Expanded(
                                child: Text(
                                  entry.value.toString(),
                                  style: GoogleFonts.roboto(
                                    fontSize: 13,
                                    color: Colors.grey.shade700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ))
                            .toList(),
                      ],
                    ),
                  ),
                ],

                // Created Date
                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(Icons.access_time, size: 14, color: Colors.grey.shade500),
                    const SizedBox(width: 4),
                    Text(
                      'Added ${_formatDate(product.createdAt)}',
                      style: GoogleFonts.roboto(
                        fontSize: 12,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCreateProductForm() {
    return Container(
      margin: const EdgeInsets.all(20),
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
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Create New Product',
              style: GoogleFonts.roboto(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: primaryBlue,
              ),
            ),
            const SizedBox(height: 24),

            // Product Name Field
            _buildFormField(
              controller: _nameController,
              label: 'Product Name',
              icon: Icons.label_outline,
              hint: 'Enter product name (must start with capital letter)',
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter a product name';
                }
                if (!RegExp(r'^[A-Z]').hasMatch(value)) {
                  return 'Product name must start with a capital letter';
                }
                return null;
              },
            ),

            // Location Field
            _buildFormField(
              controller: _locationController,
              label: 'Location (Optional)',
              icon: Icons.location_on_outlined,
              hint: 'Enter product location',
            ),

            // Dynamic Key-Value Pairs
            const SizedBox(height: 16),
            Text(
              'Additional Details',
              style: GoogleFonts.roboto(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: darkGray,
              ),
            ),
            const SizedBox(height: 12),

            ..._keyValuePairs.asMap().entries.map((entry) {
              int index = entry.key;
              var pair = entry.value;
              return Container(
                margin: const EdgeInsets.only(bottom: 16),
                child: Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        decoration: InputDecoration(
                          labelText: 'Key ${index + 1}',
                          hintText: 'e.g., Brand, Model, etc.',
                          hintStyle: GoogleFonts.roboto(color: Colors.grey.shade500, fontSize: 14),
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
                        ),
                        onChanged: (value) => setState(() => pair['key'] = value),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        decoration: InputDecoration(
                          labelText: 'Value ${index + 1}',
                          hintText: 'Enter value',
                          hintStyle: GoogleFonts.roboto(color: Colors.grey.shade500, fontSize: 14),
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
                        ),
                        onChanged: (value) => setState(() => pair['value'] = value),
                      ),
                    ),
                    if (_keyValuePairs.length > 1)
                      IconButton(
                        onPressed: () => _removeKeyValuePair(index),
                        icon: Icon(Icons.remove_circle_outline, color: Colors.red.shade400),
                      ),
                  ],
                ),
              );
            }).toList(),

            // Add Key-Value Pair Button
            TextButton.icon(
              onPressed: _addKeyValuePair,
              icon: const Icon(Icons.add, color: primaryBlue),
              label: Text(
                'Add Detail Field',
                style: GoogleFonts.roboto(color: primaryBlue, fontWeight: FontWeight.w600),
              ),
            ),

            const SizedBox(height: 24),

            // Create Button
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _createProduct,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _isSubmitting ? Colors.grey.shade400 : accentOrange,
                  foregroundColor: Colors.white,
                  elevation: _isSubmitting ? 0 : 8,
                  shadowColor: accentOrange.withOpacity(0.3),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: _isSubmitting
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
          ],
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

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.inventory_2_outlined,
              size: 64,
              color: Colors.grey.shade400,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'No Products Yet',
            style: GoogleFonts.roboto(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: darkGray,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Add your first product to ${widget.subsectionName}\nto get started with inventory management.',
            textAlign: TextAlign.center,
            style: GoogleFonts.roboto(
              fontSize: 16,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: () => setState(() => _isCreating = true),
            icon: const Icon(Icons.add, size: 20),
            label: Text(
              'Add First Product',
              style: GoogleFonts.roboto(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: accentOrange,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 4,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      return 'today';
    } else if (difference.inDays == 1) {
      return 'yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: lightGray,
      body: Column(
        children: [
          _buildHeader(),

          // Create Product Form (shown when _isCreating is true)
          if (_isCreating)
            Expanded(
              child: SingleChildScrollView(
                child: _buildCreateProductForm(),
              ),
            )
          else ...[
            // Search Bar (only show when not creating and there are products)
            if (!_isLoading && _products.isNotEmpty) _buildSearchBar(),

            // Products List
            Expanded(
              child: _isLoading
                  ? const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(primaryBlue),
                ),
              )
                  : _filteredProducts.isEmpty
                  ? _searchQuery.isNotEmpty
                  ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.search_off, size: 64, color: Colors.grey.shade400),
                    const SizedBox(height: 16),
                    Text(
                      'No products found',
                      style: GoogleFonts.roboto(
                        fontSize: 18,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    Text(
                      'Try searching with different keywords',
                      style: GoogleFonts.roboto(
                        fontSize: 14,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ],
                ),
              )
                  : _buildEmptyState()
                  : RefreshIndicator(
                onRefresh: _loadProducts,
                color: accentOrange,
                child: ListView.builder(
                  padding: const EdgeInsets.only(bottom: 20),
                  itemCount: _filteredProducts.length,
                  itemBuilder: (context, index) => _buildProductCard(_filteredProducts[index]),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _locationController.dispose();
    _searchController.dispose();
    super.dispose();
  }
}