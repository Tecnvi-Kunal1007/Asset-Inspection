import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pump_management_system/models/section.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../models/section_product.dart';
import '../services/supabase_service.dart';
import '../utils/responsive_helper.dart';
import '../utils/theme_helper.dart';
import '../models/subsection_product.dart';
import '../models/premise.dart';
import 'package:image_picker/image_picker.dart';
import '../services/file_upload_service.dart';
// import 'PremiseDetailsScreen.dart';

class SectionProductsScreen extends StatefulWidget {
  final Premise premise;
  final String? subsectionId;
  final String? subsectionName;
  final String? sectionId;
  final Section section;
  final bool isViewMode;
  final SectionProduct? productToEdit;

  const SectionProductsScreen({
    super.key,
    required this.premise,
    this.subsectionId,
    this.subsectionName,
    this.sectionId,
    required this.section,
    this.isViewMode = false,
    this.productToEdit,
  });

  @override
  State<SectionProductsScreen> createState() => _SectionProductsScreenState();

}

class ProductForm {  
  final TextEditingController nameController = TextEditingController();
  final TextEditingController locationController = TextEditingController();
  final List<Map<String, TextEditingController>> keyValueControllers = [];
  final GlobalKey<FormState> formKey = GlobalKey<FormState>();
  final SupabaseService _supabaseService = SupabaseService();
  final _supabase = Supabase.instance.client;
  File? photoFile;
  String? photoUrl;
  
  ProductForm() {
    // Initialize with one empty key-value pair
    addKeyValuePair();
  }
  
  void addKeyValuePair() {
    keyValueControllers.add({
      'key': TextEditingController(),
      'value': TextEditingController(),
    });
  }
  
  void removeKeyValuePair(int index) {
    if (keyValueControllers.length > 1) {
      final controllers = keyValueControllers.removeAt(index);
      controllers['key']?.dispose();
      controllers['value']?.dispose();
    }
  }
  
  void dispose() {
    nameController.dispose();
    locationController.dispose();
    for (var controllers in keyValueControllers) {
      controllers['key']?.dispose();
      controllers['value']?.dispose();
    }
  }
  
  bool isValid() {
    if (nameController.text.isEmpty) return false;
    if (!RegExp(r'^[A-Z]').hasMatch(nameController.text)) return false;
    
    // Check if all filled key-value pairs are valid
    for (var controllers in keyValueControllers) {
      final keyText = controllers['key']?.text ?? '';
      final valueText = controllers['value']?.text ?? '';
      
      if (keyText.isNotEmpty && valueText.isEmpty) return false;
      if (keyText.isEmpty && valueText.isNotEmpty) return false;
    }
    
    return true;
  }
  
  Future<void> submitForm(String sectionId) async {
    if (!isValid()) return;
    
    final user = _supabase.auth.currentUser;
    if (user == null) throw Exception('User not authenticated');
    
    // Prepare details map
    final Map<String, dynamic> details = {};
    
    // Add location if available
    if (locationController.text.trim().isNotEmpty) {
      details['location'] = locationController.text.trim();
    }
    
    // Add other key-value pairs
    for (var controllers in keyValueControllers) {
      final keyText = controllers['key']?.text.trim() ?? '';
      final valueText = controllers['value']?.text.trim() ?? '';
      
      if (keyText.isNotEmpty && valueText.isNotEmpty) {
        details[keyText] = valueText;
      }
    }
    
    // Upload photo if available
    String? uploadedPhotoUrl;
    if (photoFile != null) {
      final fileUploadService = FileUploadService();
      final productId = const Uuid().v4();
      uploadedPhotoUrl = await fileUploadService.uploadProductPhoto(
        photoFile!,
        'section',
        productId,
      );
    }
    
    // Create the product
    final product = SectionProduct.fromForm(
      sectionId: sectionId,
      name: nameController.text.trim(),
      quantity: 1, // Default quantity
      details: details,
      photoUrl: uploadedPhotoUrl,
    );
    await _supabaseService.createSectionProduct(product);
  }
  
  Future<void> pickImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);
    
    if (image != null) {
      photoFile = File(image.path);
    }
  }
  
  Widget buildForm(BuildContext context, {required int index, Function? onRemove, Function? onUpdate}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Form(
        key: formKey,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Form Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Product ${index + 1}',
                    style: GoogleFonts.roboto(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF1B365D),
                    ),
                  ),
                  if (onRemove != null)
                    IconButton(
                      onPressed: () => onRemove(),
                      icon: const Icon(Icons.delete_outline, color: Colors.red),
                      tooltip: 'Remove this product',
                    ),
                ],
              ),
              const Divider(height: 24),
              
              // Product Name
              TextFormField(
                controller: nameController,
                decoration: InputDecoration(
                  labelText: 'Product Name*',
                  labelStyle: GoogleFonts.roboto(color: Colors.grey.shade700),
                  hintText: 'Enter product name',
                  hintStyle: GoogleFonts.roboto(color: Colors.grey.shade400),
                  filled: true,
                  fillColor: Colors.grey.shade50,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  prefixIcon: const Icon(Icons.inventory, color: Color(0xFF1B365D)),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a product name';
                  }
                  if (!RegExp(r'^[A-Z]').hasMatch(value)) {
                    return 'Name must start with a capital letter';
                  }
                  return null;
                },
                onChanged: (_) => onUpdate?.call(),
              ),
              const SizedBox(height: 16),
              
              // Location
              TextFormField(
                controller: locationController,
                decoration: InputDecoration(
                  labelText: 'Location',
                  labelStyle: GoogleFonts.roboto(color: Colors.grey.shade700),
                  hintText: 'Enter product location',
                  hintStyle: GoogleFonts.roboto(color: Colors.grey.shade400),
                  filled: true,
                  fillColor: Colors.grey.shade50,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  prefixIcon: const Icon(Icons.location_on, color: Color(0xFF1B365D)),
                ),
              ),
              
              const SizedBox(height: 24),
              
              // Photo Upload Section
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Product Photo',
                    style: GoogleFonts.roboto(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF2C3E50),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      // Photo Preview
                      Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: photoFile != null
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Image.file(
                                  photoFile!,
                                  fit: BoxFit.cover,
                                ),
                              )
                            : photoUrl != null
                                ? ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: Image.network(
                                      photoUrl!,
                                      fit: BoxFit.cover,
                                      loadingBuilder: (context, child, loadingProgress) {
                                        if (loadingProgress == null) return child;
                                        return Center(
                                          child: CircularProgressIndicator(
                                            value: loadingProgress.expectedTotalBytes != null
                                                ? loadingProgress.cumulativeBytesLoaded /
                                                    loadingProgress.expectedTotalBytes!
                                                : null,
                                          ),
                                        );
                                      },
                                    ),
                                  )
                                : Icon(
                                    Icons.photo_outlined,
                                    size: 40,
                                    color: Colors.grey.shade400,
                                  ),
                      ),
                      const SizedBox(width: 16),
                      // Upload Button
                      ElevatedButton.icon(
                        onPressed: () async {
                          await pickImage();
                          onUpdate?.call();
                        },
                        icon: const Icon(Icons.upload_file),
                        label: const Text('Upload Photo'),
                        style: ElevatedButton.styleFrom(
                          foregroundColor: Colors.white,
                          backgroundColor: const Color(0xFF1B365D),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),
              
              // Location
              TextFormField(
                controller: locationController,
                decoration: InputDecoration(
                  labelText: 'Location',
                  labelStyle: GoogleFonts.roboto(color: Colors.grey.shade700),
                  hintText: 'Enter location (optional)',
                  hintStyle: GoogleFonts.roboto(color: Colors.grey.shade400),
                  filled: true,
                  fillColor: Colors.grey.shade50,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  prefixIcon: const Icon(Icons.location_on, color: Color(0xFF1B365D)),
                ),
                onChanged: (_) => onUpdate?.call(),
              ),
              const SizedBox(height: 24),
              
              // Properties Section
              Text(
                'Properties',
                style: GoogleFonts.roboto(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade800,
                ),
              ),
              const SizedBox(height: 16),
              
              // Key-Value Pairs
              Column(
                children: List.generate(keyValueControllers.length, (i) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: keyValueControllers[i]['key'],
                          decoration: InputDecoration(
                            labelText: 'Property',
                            hintText: 'e.g. Color',
                            filled: true,
                            fillColor: Colors.grey.shade50,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                          ),
                          onChanged: (_) => onUpdate?.call(),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: keyValueControllers[i]['value'],
                          decoration: InputDecoration(
                            labelText: 'Value',
                            hintText: 'e.g. Blue',
                            filled: true,
                            fillColor: Colors.grey.shade50,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                          ),
                          onChanged: (_) => onUpdate?.call(),
                        ),
                      ),
                      IconButton(
                        icon: Icon(
                          i == keyValueControllers.length - 1 ? Icons.add_circle : Icons.remove_circle,
                          color: i == keyValueControllers.length - 1 ? Colors.green : Colors.red,
                        ),
                        onPressed: () {
                          if (i == keyValueControllers.length - 1) {
                            addKeyValuePair();
                          } else {
                            removeKeyValuePair(i);
                          }
                          onUpdate?.call();
                        },
                      ),
                    ],
                  ),
                );
              }),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionProductsScreenState extends State<SectionProductsScreen> with TickerProviderStateMixin {
  final _supabaseService = SupabaseService();
  final _supabase = Supabase.instance.client;
  final _formKey = GlobalKey<FormState>();

  // Form controllers
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _numberOfProductsController = TextEditingController();

  // State variables
  bool _isLoading = true;
  bool _isCreating = false;
  bool _isSubmitting = false;
  bool _isNumberInput = false;
  bool _isEditing = false;
  List<SectionProduct> _products = [];
  List<ProductForm> _productForms = [];

  String _searchQuery = '';

  final List<Map<String, String>> _keyValuePairs = [{}];
  
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

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
    
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animationController, curve: Curves.easeOutCubic));
    
    if (widget.isViewMode) {
      _isCreating = false;
    } else if (widget.productToEdit != null) {
      _isEditing = true;
      _isCreating = true;
      _initializeEditForm();
    }
    
    if (_isCreating) {
      _animationController.forward();
    }
  }
  
  @override
  void dispose() {
    _animationController.dispose();
    _nameController.dispose();
    _locationController.dispose();
    _searchController.dispose();
    _numberOfProductsController.dispose();
    for (var form in _productForms) {
      form.dispose();
    }
    super.dispose();
  }
  
  void _initializeEditForm() {
    if (widget.productToEdit != null) {
      final product = widget.productToEdit!;
      _nameController.text = product.name;
      if (product.details.containsKey('location')) {
        _locationController.text = product.details['location'];
      }
      
      // Initialize key-value pairs from product details
      _keyValuePairs.clear();
      product.details.forEach((key, value) {
        if (key != 'location') {
          _keyValuePairs.add({'key': key, 'value': value.toString()});
        }
      });
      if (_keyValuePairs.isEmpty) {
        _keyValuePairs.add({});
      }
    }
  }


  Future<void> _loadProducts() async {
    try {
      setState(() => _isLoading = true);

      final user = _supabase.auth.currentUser;
      if (user != null) {
        // Make sure this ID matches what your getSectionProducts expects
        final List<SectionProduct> products = await _supabaseService.getSectionProducts(widget.section.id);

        if (!mounted) return;
        setState(() {
          _products = products;
          _isLoading = false;
        });
      } else {
        if (!mounted) return;
        setState(() => _isLoading = false);
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


  Future<void>createSectionProduct() async {
    if (!_formKey.currentState!.validate()) return;

    if (!RegExp(r'^[A-Z]').hasMatch(_nameController.text)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Product name must start with a capital letter.')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final user = _supabase.auth.currentUser;
      if (user == null) throw Exception('User not authenticated');

      // Prepare the key-value details map
      final Map<String, dynamic> details = {};
      for (var pair in _keyValuePairs) {
        if (pair['key']?.isNotEmpty == true && pair['value']?.isNotEmpty == true) {
          details[pair['key']!] = pair['value'];
        }
      }

      // Add location if available
      if (_locationController.text.trim().isNotEmpty) {
        details['location'] = _locationController.text.trim();
      }

      // Create a SectionProduct instance
      final product = SectionProduct(
        id: const Uuid().v4(), // Or your method to generate UUID
        sectionId:widget.section.id, // Make sure `sectionId` is passed via widget
        name: _nameController.text.trim(),
        quantity: 1, // You can customize this or add a quantity input
        details: details,
        createdAt: DateTime.now(),
      );

      // Call your Supabase service
      await _supabaseService.createSectionProduct(product);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Product created successfully!'),
          backgroundColor: successGreen,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );

      // Reset form
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

  List<SectionProduct> get _filteredProducts {
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
                          widget.section.name,
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

  Widget _buildCreateProductsForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_productForms.isEmpty) ...[  
            SlideTransition(
              position: _slideAnimation,
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.white, Colors.grey.shade50],
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.08),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: accentOrange.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.inventory_2, color: accentOrange, size: 40),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'Create Multiple Products',
                        style: GoogleFonts.roboto(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: darkGray,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'How many products would you like to create?',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.roboto(
                          fontSize: 16,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      const SizedBox(height: 32),
                      TextField(
                        controller: _numberOfProductsController,
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.roboto(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: darkGray,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Enter number',
                          hintStyle: GoogleFonts.roboto(color: Colors.grey.shade400),
                          filled: true,
                          fillColor: Colors.grey.shade100,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                      ),
                      const SizedBox(height: 32),
                      ElevatedButton.icon(
                        onPressed: () {
                          final count = int.tryParse(_numberOfProductsController.text);
                          if (count != null && count > 0 && count <= 10) {
                            setState(() {
                              _productForms = List.generate(count, (_) => ProductForm());
                            });
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Please enter a valid number between 1 and 10'),
                                backgroundColor: Colors.red.shade600,
                              ),
                            );
                          }
                        },
                        icon: Icon(Icons.check_circle, color: Colors.white),
                        label: Text(
                          'Continue',
                          style: GoogleFonts.roboto(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: accentOrange,
                          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          elevation: 8,
                          shadowColor: accentOrange.withOpacity(0.3),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],

          // Product Forms
          if (_productForms.isNotEmpty)
            ...List.generate(_productForms.length, (index) {
              return SlideTransition(
                position: _slideAnimation,
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: _productForms[index].buildForm(
                    context,
                    index: index,
                    onRemove: _productForms.length > 1 ? () => _removeProductForm(index) : null,
                    onUpdate: () => setState(() {}),
                  ),
                ),
              );
            }),

          // Action Buttons
          if (_productForms.isNotEmpty) ...[  
            SlideTransition(
              position: _slideAnimation,
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 15,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Text(
                        'Quick Actions',
                        style: GoogleFonts.roboto(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: darkGray,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () => setState(() => _productForms.add(ProductForm())),
                              icon: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Icon(Icons.add, size: 16, color: Colors.white),
                              ),
                              label: Text(
                                'Add Form',
                                style: GoogleFonts.roboto(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: primaryBlue,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: _submitAllForms,
                              icon: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Icon(Icons.save, size: 16, color: Colors.white),
                              ),
                              label: Text(
                                'Save All',
                                style: GoogleFonts.roboto(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: successGreen,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () {
                                setState(() {
                                  _isCreating = false;
                                  _productForms.clear();
                                  _animationController.reverse();
                                });
                              },
                              icon: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Icon(Icons.close, size: 16, color: Colors.white),
                              ),
                              label: Text(
                                'Cancel',
                                style: GoogleFonts.roboto(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.grey.shade600,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
  
  void _removeProductForm(int index) {
    if (_productForms.length > 1) {
      setState(() {
        _productForms[index].dispose();
        _productForms.removeAt(index);
      });
    } else {
      setState(() {
        _productForms.clear();
        _isCreating = false;
        _animationController.reverse();
      });
    }
  }
  
  Future<void> _submitAllForms() async {
    bool hasErrors = false;
    for (var form in _productForms) {
      if (!form.isValid()) {
        hasErrors = true;
        break;
      }
    }
    
    if (hasErrors) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please fix the errors in the forms'),
          backgroundColor: Colors.red.shade600,
        ),
      );
      return;
    }
    
    setState(() => _isSubmitting = true);
    
    try {
      for (var form in _productForms) {
        await form.submitForm(widget.section.id);
      }
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('All products created successfully!'),
          backgroundColor: successGreen,
        ),
      );
      
      setState(() {
        _isCreating = false;
        _productForms.clear();
        _animationController.reverse();
      });
      
      await _loadProducts();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error creating products: $e'),
          backgroundColor: Colors.red.shade600,
        ),
      );
    } finally {
      setState(() => _isSubmitting = false);
    }
  }
  
  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
  
  Widget _buildProductCard(SectionProduct product) {
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

                          // Location if available
                          if (product.details['location'] != null) ...[
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
                                    product.details['location'].toString(),
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
                if (product.details.isNotEmpty) ...[
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
                        ...product.details.entries
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
                      'Added ${_formatDate(product.createdAt)}', // Using original _formatDate method
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
                onPressed: _isSubmitting ? null :createSectionProduct,
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

  // Using the existing _formatDate method defined earlier
  String _formatDateRelative(DateTime date) {
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
                )

            ),
          ],
        ],
      ),
    );
  }

  // Removed duplicate dispose method
}

