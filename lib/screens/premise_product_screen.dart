import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pump_management_system/screens/premise_product_details_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import '../models/premise.dart';
import '../models/premise_product.dart';
import '../models/subsection_product.dart'; // For Product class
import 'package:uuid/uuid.dart';
import 'package:image_picker/image_picker.dart';
import '../services/file_upload_service.dart';

class CreatePremiseProductScreen extends StatefulWidget {
  final String premiseId;
  final String premiseName;
  final Premise? premise; // Optional premise object
  final bool isViewMode;
  final PremiseProduct? productToEdit;

  const CreatePremiseProductScreen({
    super.key,
    required this.premiseId,
    required this.premiseName,
    this.premise,
    this.isViewMode = false,
    this.productToEdit,
  });

  @override
  State<CreatePremiseProductScreen> createState() =>
      _CreatePremiseProductScreenState();
}

class ProductForm {
  final TextEditingController nameController = TextEditingController();
  final TextEditingController quantityController = TextEditingController(text: '1');
  final TextEditingController detailsController = TextEditingController();
  final List<Map<String, TextEditingController>> keyValueControllers = [
    {
      'key': TextEditingController(),
      'value': TextEditingController(),
    }
  ];
  final GlobalKey<FormState> formKey = GlobalKey<FormState>();
  final String id = const Uuid().v4();
  File? photoFile;
  String? photoUrl;

  void dispose() {
    nameController.dispose();
    quantityController.dispose();
    detailsController.dispose();
    for (var pair in keyValueControllers) {
      pair['key']?.dispose();
      pair['value']?.dispose();
    }
  }

  void addKeyValuePair() {
    keyValueControllers.add({
      'key': TextEditingController(),
      'value': TextEditingController(),
    });
  }

  void removeKeyValuePair(int index) {
    if (keyValueControllers.length > 1) {
      keyValueControllers[index]['key']?.dispose();
      keyValueControllers[index]['value']?.dispose();
      keyValueControllers.removeAt(index);
    }
  }

  bool isValid() {
    return formKey.currentState?.validate() ?? false;
  }

  Future<void> submitForm(String premiseId) async {
    if (!isValid()) return;

    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;
    if (user == null) throw Exception('User not authenticated');

    // Prepare details object with additional properties
    final detailsMap = <String, dynamic>{
      'info': detailsController.text.trim(),
    };

    // Add key-value pairs to details
    for (var pair in keyValueControllers) {
      final key = pair['key']?.text.trim();
      final value = pair['value']?.text.trim();
      if (key?.isNotEmpty == true && value?.isNotEmpty == true) {
        detailsMap[key!] = value;
      }
    }
    
    // Upload photo if available
    String? uploadedPhotoUrl;
    if (photoFile != null) {
      final fileUploadService = FileUploadService();
      uploadedPhotoUrl = await fileUploadService.uploadProductPhoto(
        photoFile!,
        'premise',
        id,
      );
    }

    await supabase.from('premise_products').insert({
      'contractor_id': user.id,
      'premise_id': premiseId,
      'name': nameController.text.trim(),
      'quantity': int.tryParse(quantityController.text.trim()) ?? 1,
      'details': detailsMap,
      'photo_url': uploadedPhotoUrl,
    });
  }

  Future<void> pickImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);
    
    if (image != null) {
      photoFile = File(image.path);
    }
  }
  
  Widget buildForm(BuildContext context, {
    required int index,
    Function()? onRemove,
    required Function() onUpdate,
  }) {
    final primaryBlue = const Color(0xFF1B365D);
    final accentOrange = const Color(0xFFFF6B35);
    final darkGray = const Color(0xFF2C3E50);

    return Container(
      margin: const EdgeInsets.only(bottom: 24),
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
      child: Form(
        key: formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Form Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: accentOrange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.inventory_2, color: accentOrange),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Product ${index + 1}',
                    style: GoogleFonts.roboto(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: darkGray,
                    ),
                  ),
                ),
                if (onRemove != null)
                  IconButton(
                    onPressed: onRemove,
                    icon: Icon(Icons.delete, color: Colors.red.shade400),
                    tooltip: 'Remove this product',
                  ),
              ],
            ),
            const SizedBox(height: 20),

            // Product Name
            TextFormField(
              controller: nameController,
              decoration: InputDecoration(
                labelText: 'Product Name',
                hintText: 'Enter product name',
                prefixIcon: Icon(Icons.label, color: primaryBlue),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                filled: true,
                fillColor: Colors.grey.shade50,
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter a product name';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Quantity
            TextFormField(
              controller: quantityController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Quantity',
                hintText: 'Enter quantity',
                prefixIcon: Icon(Icons.numbers, color: primaryBlue),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                filled: true,
                fillColor: Colors.grey.shade50,
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter a quantity';
                }
                if (int.tryParse(value) == null) {
                  return 'Please enter a valid number';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Details
            TextFormField(
              controller: detailsController,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: 'Details',
                hintText: 'Enter product details',
                prefixIcon: Icon(Icons.description, color: primaryBlue),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                filled: true,
                fillColor: Colors.grey.shade50,
              ),
            ),
            const SizedBox(height: 24),

            // Key-Value Pairs
            Text(
              'Additional Properties',
              style: GoogleFonts.roboto(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: darkGray,
              ),
            ),
            const SizedBox(height: 12),

            ...List.generate(
              keyValueControllers.length,
              (i) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: keyValueControllers[i]['key'],
                        decoration: InputDecoration(
                          labelText: 'Property',
                          hintText: 'e.g., Location',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          filled: true,
                          fillColor: Colors.grey.shade50,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: keyValueControllers[i]['value'],
                        decoration: InputDecoration(
                          labelText: 'Value',
                          hintText: 'e.g., Building A',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          filled: true,
                          fillColor: Colors.grey.shade50,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                        ),
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        keyValueControllers.length > 1 ? Icons.remove_circle : Icons.add_circle,
                        color: keyValueControllers.length > 1 ? Colors.red.shade400 : primaryBlue,
                      ),
                      onPressed: () {
                        if (keyValueControllers.length > 1) {
                          removeKeyValuePair(i);
                        } else {
                          addKeyValuePair();
                        }
                        onUpdate();
                      },
                    ),
                  ],
                ),
              ),
            ),

            // Add Property Button
            if (keyValueControllers.isNotEmpty)
              TextButton.icon(
                onPressed: () {
                  addKeyValuePair();
                  onUpdate();
                },
                icon: Icon(Icons.add, size: 18, color: primaryBlue),
                label: Text(
                  'Add Property',
                  style: GoogleFonts.roboto(color: primaryBlue, fontWeight: FontWeight.w600),
                ),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  backgroundColor: primaryBlue.withOpacity(0.1),
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
                    color: darkGray,
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
                        onUpdate();
                      },
                      icon: const Icon(Icons.upload_file),
                      label: const Text('Upload Photo'),
                      style: ElevatedButton.styleFrom(
                        foregroundColor: Colors.white,
                        backgroundColor: primaryBlue,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CreatePremiseProductScreenState
    extends State<CreatePremiseProductScreen> with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _quantityController = TextEditingController();
  final TextEditingController _detailsController = TextEditingController();
  final TextEditingController _numberOfProductsController = TextEditingController(text: '1');
  final List<Map<String, String>> _keyValuePairs = [{}];

  final SupabaseClient _supabase = Supabase.instance.client;
  bool _isLoading = false;
  bool _isCreating = false;
  bool _isSubmitting = false;
  bool _isNumberInput = true;
  bool _isEditing = false;
  
  List<PremiseProduct> _products = [];
  List<ProductForm> _productForms = [];
  String _searchQuery = '';

  // Construction company color scheme
  static const Color primaryBlue = Color(0xFF1B365D);
  static const Color accentOrange = Color(0xFFFF6B35);
  static const Color lightGray = Color(0xFFF5F6FA);
  static const Color darkGray = Color(0xFF2C3E50);
  static const Color successGreen = Color(0xFF27AE60);

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
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

    _animationController.forward();
    
    // Always load products first when screen opens
    _loadProducts();
    
    // If editing a product, initialize the edit form
    if (widget.productToEdit != null) {
      _isEditing = true;
      _initializeEditForm();
    }
  }
  
  void _initializeEditForm() {
    if (widget.productToEdit == null) return;
    
    final product = widget.productToEdit!;
    _nameController.text = product.name;
    _quantityController.text = product.quantity.toString();
    
    if (product.details.containsKey('info')) {
      _detailsController.text = product.details['info'].toString();
    }
    
    // Clear default key-value pair
    _keyValuePairs.clear();
    
    // Add key-value pairs from product details
    product.details.forEach((key, value) {
      if (key != 'info') {
        _keyValuePairs.add({
          'key': key,
          'value': value.toString(),
        });
      }
    });
    
    // Add an empty pair if none were added
    if (_keyValuePairs.isEmpty) {
      _keyValuePairs.add({});
    }
    
    // Set photo URL if available
    if (product.photoUrl != null) {
      _productForms.first.photoUrl = product.photoUrl;
    }
  }
  
  Future<void> _loadProducts() async {
    setState(() => _isLoading = true);
    
    try {
      final response = await _supabase
          .from('premise_products')
          .select()
          .eq('premise_id', widget.premiseId)
          .order('created_at', ascending: false);
      
      final List<PremiseProduct> loadedProducts = [];
      
      for (final item in response) {
        loadedProducts.add(PremiseProduct.fromJson(item));
      }
      
      setState(() {
        _products = loadedProducts;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      _showSnackBar('Error loading products: ${e.toString()}');
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    _nameController.dispose();
    _quantityController.dispose();
    _detailsController.dispose();
    super.dispose();
  }

  Future<void> _createProduct() async {
    if (!_formKey.currentState!.validate()) return;

    // Show confirmation dialog
    bool? confirmed = await _showConfirmationDialog();
    if (confirmed != true) return;

    _showLoadingDialog();

    try {
      // Get current user ID for RLS policy
      final user = _supabase.auth.currentUser;
      if (user == null) throw Exception('User not authenticated');

      // Prepare details object with additional properties
      final detailsMap = <String, dynamic>{
        'info': _detailsController.text.trim(),
      };

      // Add key-value pairs to details
      for (var pair in _keyValuePairs) {
        if (pair['key']?.isNotEmpty == true && pair['value']?.isNotEmpty == true) {
          detailsMap[pair['key']!] = pair['value'];
        }
      }
      
      // Create data map for both create and update operations
      final data = {
        'name': _nameController.text.trim(),
        'quantity': int.tryParse(_quantityController.text.trim()) ?? 1,
        'details': detailsMap,
      };
      
      // Check if we're updating or creating
      if (_isEditing && widget.productToEdit != null) {
        // Update existing product
        await _supabase.from('premise_products')
          .update(data)
          .eq('id', widget.productToEdit!.id);
          
        Navigator.of(context).pop(); // Close loading dialog
        _showSnackBar('Product updated successfully!', isSuccess: true);
        _loadProducts(); // Refresh the products list
        return;
      }
      
      // If not updating, create new product
      final response = await _supabase.from('premise_products').insert({
        'contractor_id': user.id,
        'premise_id': widget.premiseId,
        ...data,
      }).select().single();

      final productId = response['id'] as String;

      Navigator.of(context).pop(); // Close loading dialog

      _showSnackBar('Product created successfully!', isSuccess: true);

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
          contractorName: premiseData['contractor_name'] ?? 'Unknown', createdAt: DateTime.parse(premiseData['created_at']),
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
      Navigator.of(context).pop(); // Close loading dialog
      _showSnackBar('Error creating product: ${e.toString()}');
    }
  }

  Future<bool?> _showConfirmationDialog() {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: accentOrange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(_isEditing ? Icons.edit : Icons.confirmation_num, color: accentOrange),
            ),
            const SizedBox(width: 12),
            Text(
              _isEditing ? 'Confirm Product Update' : 'Confirm Product Creation',
              style: GoogleFonts.roboto(fontWeight: FontWeight.bold, color: darkGray),
            ),
          ],
        ),
        content: Text(
          _isEditing 
              ? 'Are you sure you want to update this product?' 
              : 'Are you sure you want to create this product?',
          style: GoogleFonts.roboto(fontSize: 16, color: darkGray),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: Text('Cancel', style: GoogleFonts.roboto(color: Colors.grey.shade600)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: accentOrange,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: Text(_isEditing ? 'Update' : 'Confirm', style: GoogleFonts.roboto(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  void _showLoadingDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Container(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(accentOrange),
                  strokeWidth: 3,
                ),
                const SizedBox(height: 24),
                Text(
                  _isEditing ? 'Updating Product...' : 'Creating Product...',
                  style: GoogleFonts.roboto(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: darkGray,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Please wait while we process your request',
                  style: GoogleFonts.roboto(
                    fontSize: 14,
                    color: Colors.grey.shade600,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showSnackBar(String message, {bool isSuccess = false, bool isError = true}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isSuccess ? Icons.check_circle : Icons.error,
              color: Colors.white,
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(message, style: GoogleFonts.roboto())),
          ],
        ),
        backgroundColor: isSuccess || !isError ? successGreen : Colors.red.shade600,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }
  
  Widget _buildSingleProductForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: SlideTransition(
        position: _slideAnimation,
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Product form container
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.shade200,
                        blurRadius: 10,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Edit Product',
                        style: GoogleFonts.poppins(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey.shade800,
                        ),
                      ),
                      const SizedBox(height: 24),
                      _buildFormField(
                        controller: _nameController,
                        label: 'Product Name',
                        icon: Icons.inventory_2_outlined,
                        isRequired: true,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter a product name';
                          }
                          return null;
                        },
                      ),
                      _buildFormField(
                        controller: _quantityController,
                        label: 'Quantity',
                        icon: Icons.numbers_outlined,
                        keyboardType: TextInputType.number,
                        isRequired: true,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter a quantity';
                          }
                          if (int.tryParse(value) == null) {
                            return 'Please enter a valid number';
                          }
                          return null;
                        },
                      ),
                      _buildFormField(
                        controller: _detailsController,
                        label: 'Description',
                        icon: Icons.description_outlined,
                        maxLines: 3,
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'Additional Properties',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade800,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
  'Additional Properties',
  style: GoogleFonts.poppins(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: Colors.grey.shade800,
  ),
),
const SizedBox(height: 16),
..._keyValuePairs.asMap().entries.map((entry) {
  int pairIndex = entry.key;
  var pair = entry.value;
  return Container(
    margin: const EdgeInsets.only(bottom: 12),
    child: Row(
      children: [
        Expanded(
          child: TextFormField(
            initialValue: pair['key'] ?? '',
            decoration: InputDecoration(
              labelText: 'Property',
              hintText: 'e.g., Material, Color',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              filled: true,
              fillColor: Colors.grey.shade50,
            ),
            onChanged: (value) {
              setState(() {
                pair['key'] = value;
              });
            },
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: TextFormField(
            initialValue: pair['value'] ?? '',
            decoration: InputDecoration(
              labelText: 'Value',
              hintText: 'e.g., Steel, Blue',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              filled: true,
              fillColor: Colors.grey.shade50,
            ),
            onChanged: (value) {
              setState(() {
                pair['value'] = value;
              });
            },
          ),
        ),
        const SizedBox(width: 8),
        IconButton(
          onPressed: () {
            setState(() {
              if (_keyValuePairs.length > 1) {
                _keyValuePairs.removeAt(pairIndex);
              }
            });
          },
          icon: Icon(
            _keyValuePairs.length > 1 ? Icons.remove_circle : Icons.add_circle,
            color: _keyValuePairs.length > 1 ? Colors.red.shade400 : primaryBlue,
          ),
        ),
      ],
    ),
  );
}).toList(),
const SizedBox(height: 16),
OutlinedButton.icon(
  onPressed: () {
    setState(() {
      _keyValuePairs.add({});
    });
  },
  icon: Icon(Icons.add, size: 18, color: primaryBlue),
  label: Text(
    'Add Property',
    style: GoogleFonts.roboto(
      fontSize: 14,
      fontWeight: FontWeight.w500,
      color: primaryBlue,
    ),
  ),
  style: OutlinedButton.styleFrom(
    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
    side: BorderSide(color: primaryBlue.withOpacity(0.5)),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
  ),
),
                      const SizedBox(height: 16),
                      OutlinedButton.icon(
                        onPressed: () {
                          // Add property functionality
                        },
                        icon: Icon(Icons.add, size: 18, color: primaryBlue),
                        label: Text(
                          'Add Property',
                          style: GoogleFonts.roboto(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: primaryBlue,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                          side: BorderSide(color: primaryBlue.withOpacity(0.5)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          side: BorderSide(color: Colors.grey.shade300),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: Text(
                          'Cancel',
                          style: GoogleFonts.roboto(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey.shade700,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _isSubmitting ? null : _updateProduct,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _isSubmitting ? Colors.grey.shade400 : successGreen,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          elevation: _isSubmitting ? 0 : 4,
                          shadowColor: successGreen.withOpacity(0.4),
                        ),
                        child: _isSubmitting
                            ? Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    'Updating...',
                                    style: GoogleFonts.roboto(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              )
                            : Text(
                                'Update Product',
                                style: GoogleFonts.roboto(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
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
    );
  }

  Future<void> _updateProduct() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;

      if (user == null) {
        throw Exception('User not authenticated');
      }

      // Prepare details object with additional properties
      final detailsMap = <String, dynamic>{
        'info': _detailsController.text.trim(),
      };

      // Add key-value pairs to details
      for (var pair in _keyValuePairs) {
        if (pair['key']?.isNotEmpty == true && pair['value']?.isNotEmpty == true) {
          detailsMap[pair['key']!] = pair['value'];
        }
      }

      // Prepare product data
      final Map<String, dynamic> productData = {
        'name': _nameController.text.trim(),
        'quantity': int.parse(_quantityController.text.trim()),
        'details': detailsMap,
        'updated_at': DateTime.now().toIso8601String(),
      };

      // Update product in Supabase
      await supabase
          .from('premise_products')
          .update(productData)
          .eq('id', widget.productToEdit!.id);

      _showSnackBar('Product updated successfully!', isSuccess: true, isError: false);
      Navigator.pop(context, true); // Pass true to indicate refresh needed
    } catch (e) {
      _showSnackBar('Error updating product: ${e.toString()}');
    } finally {
      setState(() {
        _isSubmitting = false;
      });
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
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.arrow_back, color: Colors.white, size: 24),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.isViewMode ? 'Products' : widget.productToEdit != null ? 'Edit Product' : 'Create Product',
                          style: GoogleFonts.roboto(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          widget.premiseName,
                          style: GoogleFonts.roboto(
                            fontSize: 16,
                            color: Colors.white.withOpacity(0.9),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (widget.isViewMode) 
                    Container(
                      decoration: BoxDecoration(
                        color: accentOrange,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: accentOrange.withOpacity(0.3),
                            blurRadius: 12,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.add, color: Colors.white, size: 24),
                        onPressed: () {
                          setState(() {
                            _isCreating = true;
                            _productForms.add(ProductForm());
                          });
                        },
                        tooltip: 'Add New Product',
                      ),
                    )
                  else
                    Container(
                      decoration: BoxDecoration(
                        color: successGreen,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: successGreen.withOpacity(0.3),
                            blurRadius: 12,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.save, color: Colors.white, size: 24),
                        onPressed: widget.productToEdit != null ? _updateProduct : _createProduct,
                        tooltip: widget.productToEdit != null ? 'Update Product' : 'Create Product',
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white.withOpacity(0.2)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(Icons.inventory_2, color: Colors.white, size: 20),
                    ),
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
    bool isRequired = false,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: accentOrange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(icon, color: accentOrange, size: 16),
              ),
              const SizedBox(width: 8),
              Text(
                label + (isRequired ? ' *' : ''),
                style: GoogleFonts.roboto(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: darkGray,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: controller,
            validator: validator,
            keyboardType: keyboardType,
            maxLines: maxLines,
            style: GoogleFonts.roboto(fontSize: 16, color: darkGray),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: GoogleFonts.roboto(color: Colors.grey.shade500, fontSize: 14),
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

  Widget _buildProductsList() {
    return Column(
      children: [
        // Search and Add Button Row
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Row(
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.shade200,
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: TextField(
                    onChanged: (value) {
                      setState(() {
                        _searchQuery = value.toLowerCase();
                      });
                    },
                    decoration: InputDecoration(
                      hintText: 'Search products...',
                      prefixIcon: Icon(Icons.search, color: Colors.grey.shade600),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                onPressed: () {
                  setState(() {
                    _isCreating = true;
                    _isNumberInput = true;
                  });
                },
                icon: const Icon(Icons.add, size: 20),
                label: const Text('Add'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryBlue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
        ),

        // Products List
        Expanded(
          child: _products.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.inventory_2_outlined, size: 64, color: Colors.grey.shade400),
                      const SizedBox(height: 16),
                      Text(
                        'No products found',
                        style: GoogleFonts.poppins(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Add your first product by clicking the Add button',
                        style: GoogleFonts.roboto(
                          fontSize: 14,
                          color: Colors.grey.shade600,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _products.length,
                  itemBuilder: (context, index) {
                    final product = _products[index];
                    // Skip if doesn't match search query
                    if (_searchQuery.isNotEmpty &&
                        !product.name.toLowerCase().contains(_searchQuery) &&
                        !(product.details['info'] != null && product.details['info'].toString().toLowerCase().contains(_searchQuery))) {
                      return const SizedBox.shrink();
                    }
                    return _buildProductCard(product);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildProductCard(PremiseProduct product) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: () {
          // Navigate to product details or edit
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => CreatePremiseProductScreen(
                premiseId: widget.premiseId,
                premiseName: widget.premiseName,
                premise: widget.premise,
                isViewMode: true,
                productToEdit: product,
              ),
            ),
          ).then((_) => _loadProducts());
        },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
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
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: primaryBlue.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(Icons.inventory_2_outlined, color: primaryBlue, size: 24),
                      ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          product.name,
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey.shade800,
                          ),
                        ),
                        Text(
                          'Quantity: ${product.quantity}',
                          style: GoogleFonts.roboto(
                            fontSize: 14,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.edit_outlined, color: accentOrange),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => CreatePremiseProductScreen(
                            premiseId: widget.premiseId,
                            premiseName: widget.premiseName,
                            premise: widget.premise,
                            isViewMode: false,
                            productToEdit: product,
                          ),
                        ),
                      ).then((_) => _loadProducts());
                    },
                  ),
                ],
              ),
              if (product.details.containsKey('info') && product.details['info'].toString().isNotEmpty) ...[  
                const SizedBox(height: 12),
                Text(
                  product.details['info'].toString(),
                  style: GoogleFonts.roboto(
                    fontSize: 14,
                    color: Colors.grey.shade700,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              if (product.details.isNotEmpty) ...[  
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (var entry in product.details.entries)
                        if (entry.key != 'name' && entry.key != 'quantity' && entry.key != 'info')
                          Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: RichText(
                              text: TextSpan(
                                children: [
                                  TextSpan(
                                    text: '${entry.key}: ',
                                    style: GoogleFonts.roboto(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13,
                                      color: Colors.grey.shade800,
                                    ),
                                  ),
                                  TextSpan(
                                    text: '${entry.value}',
                                    style: GoogleFonts.roboto(
                                      fontSize: 13,
                                      color: Colors.grey.shade700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 8),
              Text(
                'Created: ${_formatDate(product.createdAt)}',
                style: GoogleFonts.roboto(
                  fontSize: 12,
                  color: Colors.grey.shade500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return DateFormat('MMM d, yyyy').format(date);
  }

  Widget _buildCreateProductsForm() {
    if (_isNumberInput) {
      return Center(
        child: Container(
          width: double.infinity,
          margin: const EdgeInsets.all(24),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.shade200,
                blurRadius: 10,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'How many products do you want to create?',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade800,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              TextField(
                controller: _numberOfProductsController,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: primaryBlue,
                ),
                decoration: InputDecoration(
                  hintText: '1-10',
                  hintStyle: GoogleFonts.poppins(color: Colors.grey.shade400),
                  filled: true,
                  fillColor: Colors.grey.shade50,
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
                    borderSide: BorderSide(color: primaryBlue, width: 2),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(2),
                ],
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        setState(() {
                          _isCreating = false;
                          _isNumberInput = false;
                        });
                      },
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        side: BorderSide(color: Colors.grey.shade300),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text(
                        'Cancel',
                        style: GoogleFonts.roboto(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade700,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        final numStr = _numberOfProductsController.text.trim();
                        if (numStr.isEmpty) {
                          _showSnackBar('Please enter a number');
                          return;
                        }
                        
                        final num = int.tryParse(numStr);
                        if (num == null || num < 1 || num > 10) {
                          _showSnackBar('Please enter a number between 1 and 10');
                          return;
                        }
                        
                        setState(() {
                          _isNumberInput = false;
                          _productForms.clear();
                          for (int i = 0; i < num; i++) {
                            _productForms.add(ProductForm());
                          }
                        });
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryBlue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 4,
                        shadowColor: primaryBlue.withOpacity(0.4),
                      ),
                      child: Text(
                        'Continue',
                        style: GoogleFonts.roboto(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Product Forms
            ...List.generate(_productForms.length, (index) {
              return SlideTransition(
                position: AlwaysStoppedAnimation<Offset>(Offset.zero),
                child: FadeTransition(
                  opacity: AlwaysStoppedAnimation<double>(1.0),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.shade200,
                          blurRadius: 10,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Form Header
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade50,
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(16),
                              topRight: Radius.circular(16),
                            ),
                            border: Border(
                              bottom: BorderSide(color: Colors.grey.shade200),
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: primaryBlue.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(Icons.inventory_2_outlined, color: primaryBlue),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'Product ${index + 1}',
                                  style: GoogleFonts.poppins(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.grey.shade800,
                                  ),
                                ),
                              ),
                              if (_productForms.length > 1)
                                IconButton(
                                  onPressed: () => _removeProductForm(index),
                                  icon: Icon(Icons.close, color: Colors.grey.shade600),
                                  tooltip: 'Remove form',
                                ),
                            ],
                          ),
                        ),
                        // Form Content
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: _productForms[index].buildForm(context, index: index, onRemove: () => _removeProductForm(index), onUpdate: () => setState(() {})),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),

            // Action Buttons
            const SizedBox(height: 16),
            Row(
              children: [
                // Add Form Button
                if (_productForms.length < 10)
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        setState(() {
                          _productForms.add(ProductForm());
                        });
                      },
                      icon: Icon(Icons.add, size: 18, color: primaryBlue),
                      label: Text(
                        'Add Form',
                        style: GoogleFonts.roboto(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: primaryBlue,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        side: BorderSide(color: primaryBlue.withOpacity(0.5)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                if (_productForms.length < 10) const SizedBox(width: 16),
                // Save All Button
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isSubmitting ? null : _submitAllForms,
                    icon: _isSubmitting
                        ? SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : Icon(Icons.save, size: 18),
                    label: Text(
                      _isSubmitting ? 'Saving...' : 'Save All',
                      style: GoogleFonts.roboto(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _isSubmitting ? Colors.grey.shade400 : successGreen,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: _isSubmitting ? 0 : 4,
                      shadowColor: successGreen.withOpacity(0.4),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Cancel Button
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _isSubmitting
                    ? null
                    : () {
                        setState(() {
                          _isCreating = false;
                          _productForms.clear();
                        });
                      },
                icon: Icon(Icons.cancel_outlined, size: 18, color: Colors.grey.shade700),
                label: Text(
                  'Cancel',
                  style: GoogleFonts.roboto(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade700,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  side: BorderSide(color: Colors.grey.shade300),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _removeProductForm(int index) {
    setState(() {
      _productForms.removeAt(index);
      if (_productForms.isEmpty) {
        _isCreating = false;
      }
    });
  }

  Future<void> _submitAllForms() async {
    // Validate all forms
    bool allValid = true;
    for (int i = 0; i < _productForms.length; i++) {
      if (!_productForms[i].isValid()) {
        allValid = false;
        _showSnackBar('Please fix the errors in Product ${i + 1}');
        break;
      }
    }

    if (!allValid) return;

    setState(() {
      _isSubmitting = true;
    });

    try {
      for (var form in _productForms) {
        await form.submitForm(widget.premiseId);
      }

      _showSnackBar('All products created successfully!', isError: false);
      setState(() {
        _isCreating = false;
        _isSubmitting = false;
        _productForms.clear();
      });
      _loadProducts();
    } catch (e) {
      _showSnackBar('Error creating products: ${e.toString()}');
      setState(() {
        _isSubmitting = false;
      });
    }
  }

  // Removed duplicate _showSnackBar method

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: lightGray,
      body: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: _isCreating 
              ? _buildCreateProductsForm()
              : widget.productToEdit != null
                ? _buildSingleProductForm()
                : _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _buildProductsList(),
          ),
        ],
      ),
    );
  }
}
    