import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/premise.dart';
import '../models/subsection.dart';
import '../models/subsection_product.dart';
import '../utils/responsive_helper.dart';
import '../utils/theme_helper.dart';
import '../services/supabase_service.dart';
import 'package:image_picker/image_picker.dart';
import '../services/file_upload_service.dart';
import 'package:uuid/uuid.dart';

class ProductForm {
  final TextEditingController nameController = TextEditingController();
  final TextEditingController locationController = TextEditingController();
  final List<Map<String, String>> keyValuePairs = [{}];
  File? photoFile;
  String? photoUrl;

  ProductForm({String? name, String? location, List<Map<String, String>>? keyValuePairs, this.photoUrl}) {
    if (name != null) nameController.text = name;
    if (location != null) locationController.text = location;
    if (keyValuePairs != null && keyValuePairs.isNotEmpty) {
      this.keyValuePairs.clear();
      this.keyValuePairs.addAll(keyValuePairs.map((pair) => Map<String, String>.from(pair)));
    }
  }

  void dispose() {
    nameController.dispose();
    locationController.dispose();
  }

  bool isValid() {
    return nameController.text.isNotEmpty && RegExp(r'^[A-Z]').hasMatch(nameController.text);
  }

  Map<String, dynamic> getData() {
    final dataMap = <String, dynamic>{};
    dataMap['name'] = nameController.text.trim();

    if (locationController.text.isNotEmpty) {
      dataMap['location'] = locationController.text.trim();
    }
    
    if (photoUrl != null) {
      dataMap['photo_url'] = photoUrl;
    }

    for (var pair in keyValuePairs) {
      if (pair['key']?.isNotEmpty == true && pair['value']?.isNotEmpty == true) {
        dataMap[pair['key']!] = pair['value'];
      }
    }

    return dataMap;
  }

  Future<void> pickImage() async {
  try {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1920,
      maxHeight: 1080,
      imageQuality: 85,
    );
    
    if (image != null) {
      photoFile = File(image.path);
      print('DEBUG: Photo selected: ${image.path}');
    } else {
      print('DEBUG: No photo selected');
    }
  } catch (e) {
    print('DEBUG: Error picking image: $e');
    // You might want to show an error message to the user here
  }
}
  
  Widget buildForm(BuildContext context, {required int index, VoidCallback? onRemove, required VoidCallback onUpdate}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
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
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with product number and remove button
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [const Color(0xFFFF6B35), const Color(0xFFFF8C42)],
                    ),
                    borderRadius: BorderRadius.circular(25),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFFF6B35).withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.inventory, color: Colors.white, size: 18),
                      const SizedBox(width: 8),
                      Text(
                        'Product ${index + 1}',
                        style: GoogleFonts.roboto(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                if (onRemove != null)
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: IconButton(
                      onPressed: onRemove,
                      icon: Icon(Icons.delete_outline, color: Colors.red.shade400, size: 22),
                      tooltip: 'Remove Product',
                    ),
                  ),
              ],
            ),

            const SizedBox(height: 24),

            // Product Name Field
            _buildFormField(
              controller: nameController,
              label: 'Product Name',
              icon: Icons.label_important,
              hint: 'Enter product name (must start with capital letter)',
              isRequired: true,
              onChanged: (value) => onUpdate(),
            ),

            // Location Field
            _buildFormField(
              controller: locationController,
              label: 'Location',
              icon: Icons.location_on,
              hint: 'Enter product location (optional)',
              onChanged: (value) => onUpdate(),
            ),
            
            // Photo Upload Section
            const SizedBox(height: 8),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF6B35).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Icon(Icons.photo_camera, color: const Color(0xFFFF6B35), size: 16),
                ),
                const SizedBox(width: 8),
                Text(
                  'Product Photo',
                  style: GoogleFonts.roboto(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF2C3E50),
                  ),
                ),
              ],
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
                    backgroundColor: const Color(0xFFFF6B35),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Additional Properties Section
            const SizedBox(height: 8),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1B365D).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.settings, color: const Color(0xFF1B365D), size: 20),
                ),
                const SizedBox(width: 12),
                Text(
                  'Additional Properties',
                  style: GoogleFonts.roboto(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF1B365D),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Key-Value Pairs
            ...keyValuePairs.asMap().entries.map((entry) {
              int pairIndex = entry.key;
              var pair = entry.value;
              return Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        decoration: InputDecoration(
                          labelText: 'Property Name',
                          hintText: 'e.g., Brand, Model',
                          hintStyle: GoogleFonts.roboto(color: Colors.grey.shade500),
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(color: Color(0xFFFF6B35), width: 2),
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        ),
                        onChanged: (value) {
                          pair['key'] = value;
                          onUpdate();
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        decoration: InputDecoration(
                          labelText: 'Value',
                          hintText: 'e.g., ABC, XYZ-123',
                          hintStyle: GoogleFonts.roboto(color: Colors.grey.shade500),
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(color: Color(0xFFFF6B35), width: 2),
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        ),
                        onChanged: (value) {
                          pair['value'] = value;
                          onUpdate();
                        },
                      ),
                    ),
                    if (keyValuePairs.length > 1) ...[
                      const SizedBox(width: 8),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: IconButton(
                          onPressed: () {
                            keyValuePairs.removeAt(pairIndex);
                            onUpdate();
                          },
                          icon: Icon(Icons.remove_circle_outline, color: Colors.red.shade400, size: 20),
                        ),
                      ),
                    ],
                  ],
                ),
              );
            }).toList(),

            // Add Property Button
            Container(
              width: double.infinity,
              child: TextButton.icon(
                onPressed: () {
                  keyValuePairs.add({});
                  onUpdate();
                },
                icon: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1B365D).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Icon(Icons.add, size: 16, color: const Color(0xFF1B365D)),
                ),
                label: Text(
                  'Add Property',
                  style: GoogleFonts.roboto(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF1B365D),
                  ),
                ),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                    side: BorderSide(color: const Color(0xFF1B365D).withOpacity(0.2)),
                  ),
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
    String? hint,
    bool isRequired = false,
    void Function(String)? onChanged,
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
                  color: const Color(0xFFFF6B35).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(icon, color: const Color(0xFFFF6B35), size: 16),
              ),
              const SizedBox(width: 8),
              Text(
                label + (isRequired ? ' *' : ''),
                style: GoogleFonts.roboto(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF2C3E50),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: controller,
            onChanged: onChanged,
            style: GoogleFonts.roboto(fontSize: 16, color: const Color(0xFF2C3E50)),
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
                borderSide: const BorderSide(color: Color(0xFFFF6B35), width: 2),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            ),
          ),
        ],
      ),
    );
  }
}

class CreateMultipleSubsectionProductsScreen extends StatefulWidget {
  final Premise premise;
  final String subsectionId;
  final Subsection subsection;
  final String subsectionName;
  final Product? productToEdit; // Add product parameter for editing
  final bool isViewMode; // Flag to indicate if we're in view/edit mode

  const CreateMultipleSubsectionProductsScreen({
    super.key,
    required this.premise,
    required this.subsectionId,
    required this.subsection,
    required this.subsectionName,
    this.productToEdit, // Optional parameter for editing
    this.isViewMode = false, // Default to creation mode
  });

  @override
  State<CreateMultipleSubsectionProductsScreen> createState() => _CreateMultipleSubsectionProductsScreenState();
}

class _CreateMultipleSubsectionProductsScreenState extends State<CreateMultipleSubsectionProductsScreen> with TickerProviderStateMixin {
  final _supabaseService = SupabaseService();
  final _searchController = TextEditingController();
  final _numberOfProductsController = TextEditingController();
  List<ProductForm> _productForms = [];
  bool _isCreating = false;
  bool _isNumberInput = false;
  bool _isLoading = true;
  bool _isUpdating = false; // Flag to track if we're updating an existing product
  List<Product> _products = [];

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

    print('initState - isViewMode: ${widget.isViewMode}, productToEdit: ${widget.productToEdit?.name}');

    // Force edit mode if productToEdit is provided, regardless of isViewMode
    if (widget.productToEdit != null) {
      print('Setting up edit mode for product: ${widget.productToEdit!.name}');
      _isUpdating = true;
      _isCreating = true; // Show the form

      // Start the animation to show the form
      _animationController.forward();

      // Create a form with the product data
      final product = widget.productToEdit!;
      final keyValuePairs = <Map<String, String>>[];

      print('Product details: ${product.details}');

      // Extract key-value pairs from product data
      product.details.forEach((key, value) {
        if (key != 'name' && key != 'location') {
          print('Adding key-value pair: $key = $value');
          keyValuePairs.add({'key': key, 'value': value.toString()});
        }
      });

      // If no key-value pairs were found, add an empty one
      if (keyValuePairs.isEmpty) {
        print('No key-value pairs found, adding empty one');
        keyValuePairs.add({});
      }

      // Create the form with the product data
      print('Creating form with name: ${product.name}, location: ${product.details["location"]}');
      _productForms.add(ProductForm(
        name: product.name,
        location: product.details['location'],
        keyValuePairs: keyValuePairs,
      ));

      print('Product form added, total forms: ${_productForms.length}');
    }
    // Check if we're in view mode
    else if (widget.isViewMode) {
      _isCreating = false; // Start in list view mode
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadProducts();
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    _searchController.dispose();
    _numberOfProductsController.dispose();
    for (var form in _productForms) {
      form.dispose();
    }
    super.dispose();
  }

  Future<void> _loadProducts() async {
    setState(() => _isLoading = true);
    try {
      final response = await _supabaseService.getProducts(widget.subsectionId);
      setState(() {
        _products = response;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      _showSnackBar('Error loading products: Please try again later');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _createProducts() async {
  List<ProductForm> validForms = _productForms.where((form) => form.isValid()).toList();

  if (validForms.isEmpty) {
    _showSnackBar('Please fill at least one product form correctly');
    return;
  }

  // Different confirmation message based on whether we're updating or creating
  String confirmationMessage = _isUpdating
      ? 'Are you sure you want to update this product?'
      : 'You have filled ${validForms.length} valid product(s). Do you want to create them?';

  bool? confirmed = await _showConfirmationDialog(validForms.length, message: confirmationMessage);
  if (confirmed != true) return;

  try {
    _showLoadingDialog();
    final fileUploadService = FileUploadService();

    if (_isUpdating && widget.productToEdit != null) {
      // Update existing product
      final form = validForms.first;
      
      // Handle photo upload if there's a new photo
      if (form.photoFile != null) {
        // Delete old photo if exists
        if (form.photoUrl != null && form.photoUrl!.isNotEmpty) {
          try {
            await fileUploadService.deleteProductPhoto(form.photoUrl!, 'subsection');
          } catch (e) {
            print('DEBUG: Error deleting old photo: $e');
            // Continue even if deletion fails
          }
        }
        
        // Upload new photo
        try {
          form.photoUrl = await fileUploadService.uploadProductPhoto(
            form.photoFile!,
            'subsection',
            widget.productToEdit!.id
          );
          print('DEBUG: New photo uploaded: ${form.photoUrl}');
        } catch (e) {
          print('DEBUG: Error uploading new photo: $e');
          Navigator.of(context).pop(); // Close loading dialog
          _showSnackBar('Error uploading photo: $e');
          return;
        }
      }
      
      final data = form.getData();
      final result = await _supabaseService.updateProduct(widget.productToEdit!.id, data);

      if (result == null) {
        Navigator.of(context).pop(); // Close loading dialog
        _showSnackBar('Failed to update product. Please try again.');
        return;
      }
    } else {
      // Create new products
      for (var form in validForms) {
        // Handle photo upload if there's a photo
        if (form.photoFile != null) {
          try {
            final productId = const Uuid().v4();
            final uploadedPhotoUrl = await fileUploadService.uploadProductPhoto(
              form.photoFile!,
              'subsection',
              productId
            );
            
            // Set the photo URL in the form
            form.photoUrl = uploadedPhotoUrl;
            print('DEBUG: Photo uploaded successfully: $uploadedPhotoUrl');
          } catch (e) {
            print('DEBUG: Error uploading photo: $e');
            Navigator.of(context).pop(); // Close loading dialog
            _showSnackBar('Error uploading photo for ${form.nameController.text}: $e');
            return;
          }
        }
        
        final data = form.getData();
        print('DEBUG: Creating product with data: $data');
        await _supabaseService.createProduct(widget.subsectionId, data);
      }
    }

    Navigator.of(context).pop(); // Close loading dialog

    // Show success message
    _showSnackBar(
      _isUpdating ? 'Product updated successfully!' : 'Products created successfully!',
      isSuccess: true
    );

    setState(() {
      _productForms.clear();
      _isCreating = false;
      _isNumberInput = false;
      _numberOfProductsController.clear();
    });

    _animationController.reverse();
    await _loadProducts();

  } on PostgrestException catch (e) {
    Navigator.of(context).pop();
    _showSnackBar(e.code == '23505'
        ? 'A product with this name already exists.'
        : e.code == '23514'
        ? 'Invalid product name. Please ensure it starts with a capital letter.'
        : 'Error creating products: ${e.message}');
  } catch (e) {
    Navigator.of(context).pop();
    print('DEBUG: General error in _createProducts: $e');
    _showSnackBar('Error creating products: Please try again later');
  }
}

  Future<bool?> _showConfirmationDialog(int count, {String? message}) {
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
              child: Icon(_isUpdating ? Icons.edit : Icons.confirmation_num, color: accentOrange),
            ),
            const SizedBox(width: 12),
            Text(
              _isUpdating ? 'Update Product' : 'Confirm Products',
              style: GoogleFonts.roboto(fontWeight: FontWeight.bold, color: darkGray),
            ),
          ],
        ),
        content: Text(
          message ?? 'You have filled $count valid product(s). Do you want to create them?',
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
            child: Text(_isUpdating ? 'Update' : 'Confirm', style: GoogleFonts.roboto(fontWeight: FontWeight.w600)),
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
                  'Creating Products...',
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

  void _showSnackBar(String message, {bool isSuccess = false}) {
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
        backgroundColor: isSuccess ? successGreen : Colors.red.shade600,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  void _generateProductForms() {
    if (_productForms.isEmpty || !_productForms[0].isValid()) {
      _showSnackBar('Please fill the first product form correctly');
      return;
    }

    final numberText = _numberOfProductsController.text;
    final number = int.tryParse(numberText) ?? 0;
    if (number < 0) {
      _showSnackBar('Please enter a valid number of additional products');
      return;
    }

    final templateForm = _productForms[0];
    setState(() {
      _productForms = [
        templateForm,
        ...List.generate(
          number,
              (_) => ProductForm(
            name: templateForm.nameController.text,
            location: templateForm.locationController.text,
            keyValuePairs: templateForm.keyValuePairs,
          ),
        ),
      ];
      _isNumberInput = false;
      _isCreating = true;
      _animationController.forward();
    });
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
        _isNumberInput = false;
        _numberOfProductsController.clear();
        _animationController.reverse();
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
                          _isUpdating ? 'Update Product' : 'Create Products',
                          style: GoogleFonts.roboto(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          widget.subsection.name,
                          style: GoogleFonts.roboto(
                            fontSize: 16,
                            color: Colors.white.withOpacity(0.9),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_isCreating)
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
                        onPressed: _createProducts,
                        tooltip: _isUpdating ? 'Update Product' : 'Create Products',
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
                      '${_products.length} existing products',
                      style: GoogleFonts.roboto(
                        fontSize: 16,
                        color: Colors.white,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const Spacer(),
                    Icon(Icons.location_on, color: Colors.white, size: 18),
                    const SizedBox(width: 6),
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
      margin: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: TextField(
        controller: _searchController,
        onChanged: (value) => setState(() {}),
        style: GoogleFonts.roboto(fontSize: 16, color: darkGray),
        decoration: InputDecoration(
          hintText: 'Search existing products...',
          hintStyle: GoogleFonts.roboto(color: Colors.grey.shade500),
          prefixIcon: Container(
            margin: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: primaryBlue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.search, color: primaryBlue, size: 20),
          ),
          suffixIcon: Container(
            margin: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _isCreating ? Colors.red.shade50 : accentOrange.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: IconButton(
              onPressed: () {
                setState(() {
                  if (_isCreating) {
                    _isCreating = false;
                    _isNumberInput = false;
                    _productForms.clear();
                    _numberOfProductsController.clear();
                    _animationController.reverse();
                  } else {
                    _isCreating = true;
                    _productForms = [ProductForm()];
                    _animationController.forward();
                  }
                });
              },
              icon: Icon(
                _isCreating ? Icons.close : Icons.add,
                color: _isCreating ? Colors.red.shade400 : accentOrange,
                size: 20,
              ),
              tooltip: _isCreating ? 'Cancel' : 'Add Products',
            ),
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
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
                        child: Icon(Icons.add_box, size: 48, color: accentOrange),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'Start Creating Products',
                        style: GoogleFonts.roboto(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: darkGray,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Add your first product to get started with bulk creation',
                        style: GoogleFonts.roboto(
                          fontSize: 16,
                          color: Colors.grey.shade600,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton.icon(
                        onPressed: () => setState(() => _productForms.add(ProductForm())),
                        icon: const Icon(Icons.add, size: 20),
                        label: Text(
                          'Add First Product',
                          style: GoogleFonts.roboto(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: accentOrange,
                          foregroundColor: Colors.white,
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
          if (_productForms.isNotEmpty && !_isNumberInput)
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
          if (_productForms.isNotEmpty && !_isNumberInput) ...[
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
                                'Add Another',
                                style: GoogleFonts.roboto(fontWeight: FontWeight.w600),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: primaryBlue,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                elevation: 4,
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () => setState(() => _isNumberInput = true),
                              icon: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Icon(Icons.copy, size: 16, color: Colors.white),
                              ),
                              label: Text(
                                'Bulk Duplicate',
                                style: GoogleFonts.roboto(fontWeight: FontWeight.w600),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: accentOrange,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                elevation: 4,
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
            const SizedBox(height: 20),
          ],

          // Bulk Duplicate Section
          if (_isNumberInput)
            SlideTransition(
              position: _slideAnimation,
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: Container(
                  width: double.infinity,
                  margin: const EdgeInsets.symmetric(vertical: 16),
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [accentOrange.withOpacity(0.1), accentOrange.withOpacity(0.05)],
                    ),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: accentOrange.withOpacity(0.2), width: 2),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: accentOrange,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(Icons.copy_all, color: Colors.white, size: 24),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Bulk Duplicate Products',
                                  style: GoogleFonts.roboto(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: darkGray,
                                  ),
                                ),
                                Text(
                                  'Create multiple copies of the first product',
                                  style: GoogleFonts.roboto(
                                    fontSize: 14,
                                    color: Colors.grey.shade700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      TextField(
                        controller: _numberOfProductsController,
                        keyboardType: TextInputType.number,
                        style: GoogleFonts.roboto(fontSize: 18, fontWeight: FontWeight.w600),
                        decoration: InputDecoration(
                          labelText: 'Number of Additional Products',
                          hintText: 'e.g., 10',
                          hintStyle: GoogleFonts.roboto(color: Colors.grey.shade500),
                          prefixIcon: Container(
                            margin: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: accentOrange.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(Icons.format_list_numbered, color: accentOrange, size: 20),
                          ),
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide.none,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(color: accentOrange, width: 2),
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Expanded(
                            child: TextButton(
                              onPressed: () => setState(() => _isNumberInput = false),
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  side: BorderSide(color: Colors.grey.shade300),
                                ),
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
                            flex: 2,
                            child: ElevatedButton.icon(
                              onPressed: _generateProductForms,
                              icon: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Icon(Icons.auto_fix_high, size: 16, color: Colors.white),
                              ),
                              label: Text(
                                'Generate Products',
                                style: GoogleFonts.roboto(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: accentOrange,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                elevation: 8,
                                shadowColor: accentOrange.withOpacity(0.3),
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

          // Create Products Button
          if (_productForms.isNotEmpty && !_isNumberInput) ...[
            SlideTransition(
              position: _slideAnimation,
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: ElevatedButton.icon(
                    onPressed: _createProducts,
                    icon: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(Icons.rocket_launch, color: Colors.white, size: 20),
                    ),
                    label: Text(
                      'Create ${_productForms.length} Product${_productForms.length > 1 ? 's' : ''}',
                      style: GoogleFonts.roboto(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: successGreen,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 32),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 12,
                      shadowColor: successGreen.withOpacity(0.4),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildProductsList() {
    final filteredProducts = _products
        .where((product) =>
    _searchController.text.isEmpty ||
        product.name.toLowerCase().contains(_searchController.text.toLowerCase()))
        .toList();

    if (filteredProducts.isEmpty) {
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
              _products.isEmpty ? 'No Products Yet' : 'No Results Found',
              style: GoogleFonts.roboto(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: darkGray,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _products.isEmpty
                  ? 'Add products to track assets in this subsection'
                  : 'Try a different search term',
              style: GoogleFonts.roboto(
                fontSize: 16,
                color: Colors.grey.shade600,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: filteredProducts.length,
      padding: const EdgeInsets.all(24),
      itemBuilder: (context, index) {
        final product = filteredProducts[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          child: Card(
            elevation: 8,
            shadowColor: Colors.black.withOpacity(0.1),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
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
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: accentOrange.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(Icons.inventory, color: accentOrange, size: 24),
                          ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              product.name,
                              style: GoogleFonts.roboto(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: darkGray,
                              ),
                            ),
                            if (product.data['location'] != null) ...[                              const SizedBox(height: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                decoration: BoxDecoration(
                                  color: primaryBlue.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.location_on, size: 14, color: primaryBlue),
                                    const SizedBox(width: 4),
                                    Text(
                                      product.data['location'],
                                      style: GoogleFonts.roboto(
                                        fontSize: 12,
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
                      // Edit button
                      if (widget.isViewMode)
                        IconButton(
                          icon: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: primaryBlue.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(Icons.edit, color: primaryBlue, size: 16),
                          ),
                          onPressed: () {
                            // Create a completely new instance for editing
                            final editScreen = CreateMultipleSubsectionProductsScreen(
                              premise: widget.premise,
                              subsectionId: widget.subsectionId,
                              subsection: widget.subsection,
                              subsectionName: widget.subsectionName,
                              productToEdit: product,
                              isViewMode: false, // Set to false to enable edit mode
                            );

                            // Navigate to edit screen with the selected product
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => editScreen),
                            ).then((_) => _loadProducts());
                          },
                          tooltip: 'Edit Product',
                        )
                      else
                        Icon(Icons.chevron_right, color: Colors.grey.shade400),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Icon(Icons.access_time, size: 14, color: Colors.grey.shade500),
                      const SizedBox(width: 6),
                      Text(
                        'Created: ${_formatDate(product.createdAt)}',
                        style: GoogleFonts.roboto(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    print('build - isCreating: $_isCreating, isUpdating: $_isUpdating, productToEdit: ${widget.productToEdit?.name}');
    return Scaffold(
      backgroundColor: lightGray,
      body: Column(
        children: [
          _buildHeader(),

          Expanded(
            child: _isCreating
                ? _buildCreateProductsForm()
                : Column(
              children: [
                _buildSearchBar(),
                Expanded(
                  child: _isLoading
                      ? const Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(primaryBlue),
                    ),
                  )
                      : _buildProductsList(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
