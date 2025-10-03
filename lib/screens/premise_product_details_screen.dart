import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pump_management_system/models/subsection_product.dart';
import 'package:pump_management_system/screens/premise_product_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/premise.dart';
import '../models/premise_product.dart'; // Use PremiseProduct instead of Product

class ProductDetailsScreen extends StatefulWidget {
  final Premise premise;

  const ProductDetailsScreen({
    super.key,
    required this.premise, required Product product,
  });

  @override
  State<ProductDetailsScreen> createState() => _ProductDetailsScreenState();
}

class _ProductDetailsScreenState extends State<ProductDetailsScreen> {
  final SupabaseClient _supabase = Supabase.instance.client;
  List<PremiseProduct> _products = []; // Changed to PremiseProduct
  bool _isLoading = true;
  String _searchQuery = '';

  // Construction company color scheme
  static const Color primaryBlue = Color(0xFF1B365D);
  static const Color accentOrange = Color(0xFFFF6B35);
  static const Color lightGray = Color(0xFFF5F6FA);
  static const Color darkGray = Color(0xFF2C3E50);
  static const Color successGreen = Color(0xFF27AE60);
  static const Color cardWhite = Color(0xFFFFFFF);

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  Future<void> _loadProducts() async {
    try {
      setState(() => _isLoading = true);

      final response = await _supabase
          .from('premise_products')
          .select()
          .eq('premise_id', widget.premise.id)
          .order('created_at', ascending: false);

      final products = response.map<PremiseProduct>((data) => PremiseProduct.fromJson(data)).toList();

      setState(() {
        _products = products;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error loading products: ${e.toString()}'),
          backgroundColor: Colors.red.shade600,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }

  List<PremiseProduct> get _filteredProducts {
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
                          widget.premise.name,
                          style: GoogleFonts.roboto(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Product Inventory',
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
                      onPressed: () => _navigateToCreateProduct(),
                      icon: const Icon(Icons.add, color: Colors.white, size: 28),
                      tooltip: 'Add New Product',
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
                      '${_products.length} Products',
                      style: GoogleFonts.roboto(
                        fontSize: 16,
                        color: Colors.white,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const Spacer(),
                    Icon(Icons.engineering, color: Colors.white, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Total Qty: ${_products.fold(0, (sum, product) => sum + product.quantity)}',
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

  Widget _buildProductCard(PremiseProduct product) {
    final detailsText = product.details['info']?.toString() ?? '';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Card(
        elevation: 8,
        shadowColor: Colors.black.withOpacity(0.1),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: InkWell(
          onTap: () => _navigateToProductDetails(product),
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
                    // Product Icon or Photo
                    product.photoUrl != null && product.photoUrl!.isNotEmpty
                        ? Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        image: DecorationImage(
                          image: NetworkImage(product.photoUrl!),
                          fit: BoxFit.cover,
                        ),
                      ),
                    )
                        : Container(
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

                          // Quantity Badge
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: primaryBlue.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.format_list_numbered, size: 16, color: primaryBlue),
                                const SizedBox(width: 4),
                                Text(
                                  'Qty: ${product.quantity}',
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

                // Product Details
                if (detailsText.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.description, size: 16, color: Colors.grey.shade600),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            detailsText,
                            style: GoogleFonts.roboto(
                              fontSize: 14,
                              color: Colors.grey.shade700,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
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
            'Add your first product to this premise\nto get started with inventory management.',
            textAlign: TextAlign.center,
            style: GoogleFonts.roboto(
              fontSize: 16,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: _navigateToCreateProduct,
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

  void _navigateToCreateProduct() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CreatePremiseProductScreen(
          premiseId: widget.premise.id,
          premiseName: widget.premise.name,
          premise: widget.premise,
        ),
      ),
    ).then((_) => _loadProducts()); // Refresh products when returning
  }

  void _navigateToProductDetails(PremiseProduct product) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => IndividualProductDetailsScreen(
          product: product,
          premise: widget.premise,
        ),
      ),
    ).then((_) => _loadProducts()); // Refresh products when returning from edit
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: lightGray,
      body: Column(
        children: [
          _buildHeader(),
          if (!_isLoading && _products.isNotEmpty) _buildSearchBar(),
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
                itemCount: _filteredProducts.length,
                itemBuilder: (context, index) => _buildProductCard(_filteredProducts[index]),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Updated Individual Product Details Screen
class IndividualProductDetailsScreen extends StatelessWidget {
  final PremiseProduct product; // Changed to PremiseProduct
  final Premise premise;

  // Construction company color scheme
  static const Color primaryBlue = Color(0xFF1B365D);
  static const Color accentOrange = Color(0xFFFF6B35);
  static const Color lightGray = Color(0xFFF5F6FA);
  static const Color darkGray = Color(0xFF2C3E50);

  const IndividualProductDetailsScreen({
    super.key,
    required this.product,
    required this.premise,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: lightGray,
      appBar: AppBar(
        title: Text(
          product.name,
          style: GoogleFonts.roboto(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        backgroundColor: primaryBlue,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined, color: Colors.white),
            onPressed: () {
              // Navigate to edit screen
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => CreatePremiseProductScreen(
                    premiseId: premise.id,
                    premiseName: premise.name,
                    premise: premise,
                    isViewMode: false,
                    productToEdit: product,
                  ),
                ),
              ).then((result) {
                // Close this screen and go back to the product list
                if (result == true) {
                  Navigator.pop(context, true); // Pass true to indicate refresh needed
                }
              });
            },
            tooltip: 'Edit Product',
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Main Product Card
            Container(
              width: double.infinity,
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
                  Row(
                    children: [
                      product.photoUrl != null && product.photoUrl!.isNotEmpty
                          ? Container(
                        width: 70,
                        height: 70,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          image: DecorationImage(
                            image: NetworkImage(product.photoUrl!),
                            fit: BoxFit.cover,
                          ),
                        ),
                      )
                          : Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: accentOrange.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Icon(
                          Icons.inventory,
                          color: accentOrange,
                          size: 32,
                        ),
                      ),
                      const SizedBox(width: 20),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              product.name,
                              style: GoogleFonts.roboto(
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                                color: darkGray,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Icon(Icons.location_on, size: 16, color: Colors.grey.shade600),
                                const SizedBox(width: 4),
                                Text(
                                  premise.name,
                                  style: GoogleFonts.roboto(
                                    fontSize: 16,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // Quantity Display
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: primaryBlue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.format_list_numbered, color: primaryBlue, size: 24),
                        const SizedBox(width: 12),
                        Text(
                          'Quantity: ${product.quantity}',
                          style: GoogleFonts.roboto(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: primaryBlue,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Details Section
                  if (product.details['info']?.toString().isNotEmpty ?? false) ...[
                    const SizedBox(height: 24),
                    Text(
                      'Product Details',
                      style: GoogleFonts.roboto(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: darkGray,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        product.details['info'].toString(),
                        style: GoogleFonts.roboto(
                          fontSize: 16,
                          color: darkGray,
                          height: 1.5,
                        ),
                      ),
                    ),
                  ],

                  // Additional Properties
                  if (product.details.length > 1) ...[
                    const SizedBox(height: 24),
                    Text(
                      'Additional Properties',
                      style: GoogleFonts.roboto(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: darkGray,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          for (var entry in product.details.entries)
                            if (entry.key != 'info')
                              Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    SizedBox(
                                      width: 100,
                                      child: Text(
                                        '${entry.key}:',
                                        style: GoogleFonts.roboto(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 14,
                                          color: darkGray,
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      child: Text(
                                        entry.value.toString(),
                                        style: GoogleFonts.roboto(
                                          fontSize: 14,
                                          color: Colors.grey.shade700,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 24),

                  // Created Date
                  Row(
                    children: [
                      Icon(Icons.access_time, size: 20, color: Colors.grey.shade600),
                      const SizedBox(width: 8),
                      Text(
                        'Created: ${product.createdAt.day}/${product.createdAt.month}/${product.createdAt.year}',
                        style: GoogleFonts.roboto(
                          fontSize: 14,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Edit Button (Bottom)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => CreatePremiseProductScreen(
                        premiseId: premise.id,
                        premiseName: premise.name,
                        premise: premise,
                        isViewMode: false,
                        productToEdit: product,
                      ),
                    ),
                  ).then((result) {
                    if (result == true) {
                      Navigator.pop(context, true);
                    }
                  });
                },
                icon: const Icon(Icons.edit, size: 20),
                label: Text(
                  'Edit Product',
                  style: GoogleFonts.roboto(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: accentOrange,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 4,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}