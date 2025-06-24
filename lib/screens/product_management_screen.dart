import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:file_picker/file_picker.dart';
import 'package:excel/excel.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

class ProductManagementScreen extends StatefulWidget {
  const ProductManagementScreen({Key? key}) : super(key: key);

  @override
  State<ProductManagementScreen> createState() =>
      _ProductManagementScreenState();
}

class _ProductManagementScreenState extends State<ProductManagementScreen> {
  final _searchController = TextEditingController();
  final _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _products = [];
  List<Map<String, dynamic>> _filteredProducts = [];
  bool _isLoading = false;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadProducts() async {
    setState(() => _isLoading = true);
    try {
      final response = await _supabase.from('products').select().order('name');
      setState(() {
        _products = List<Map<String, dynamic>>.from(response);
        _filterProducts();
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading products: $e')));
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _filterProducts() {
    if (_searchQuery.isEmpty) {
      setState(() => _filteredProducts = _products);
    } else {
      setState(() {
        _filteredProducts =
            _products
                .where(
                  (product) => product['name']
                      .toString()
                      .toLowerCase()
                      .contains(_searchQuery.toLowerCase()),
                )
                .toList();
      });
    }
  }

  Future<void> _pickAndProcessExcel() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx', 'xls'],
        withData: true,
      );

      if (result == null) return;

      setState(() => _isLoading = true);

      // Read the Excel file
      final bytes = result.files.first.bytes;
      if (bytes == null) {
        throw Exception('Could not read file');
      }

      final excel = Excel.decodeBytes(bytes);
      final sheet = excel.tables.keys.first;
      final rows = excel.tables[sheet]!.rows;

      // Skip header row and process data
      for (var i = 1; i < rows.length; i++) {
        final row = rows[i];
        if (row.isEmpty || row[0]?.value == null) continue;

        final name = row[0]?.value.toString() ?? '';
        final price = double.tryParse(row[1]?.value.toString() ?? '0') ?? 0.0;

        if (name.isNotEmpty && price > 0) {
          await _supabase.from('products').insert({
            'name': name,
            'price': price,
          });
        }
      }

      await _loadProducts();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Products imported successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error importing products: $e')));
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _editProduct(Map<String, dynamic> product) async {
    final nameController = TextEditingController(text: product['name']);
    final priceController = TextEditingController(
      text: product['price'].toString(),
    );

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Edit Product'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'Product Name'),
                ),
                TextField(
                  controller: priceController,
                  decoration: const InputDecoration(labelText: 'Price'),
                  keyboardType: TextInputType.number,
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () {
                  final price = double.tryParse(priceController.text) ?? 0.0;
                  if (nameController.text.isNotEmpty && price > 0) {
                    Navigator.pop(context, {
                      'name': nameController.text,
                      'price': price,
                    });
                  }
                },
                child: const Text('Save'),
              ),
            ],
          ),
    );

    if (result != null) {
      try {
        await _supabase.from('products').update(result).eq('id', product['id']);
        await _loadProducts();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Error updating product: $e')));
        }
      }
    }
  }

  Future<void> _deleteProduct(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Delete Product'),
            content: const Text(
              'Are you sure you want to delete this product?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Delete'),
              ),
            ],
          ),
    );

    if (confirm == true) {
      try {
        await _supabase.from('products').delete().eq('id', id);
        await _loadProducts();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Error deleting product: $e')));
        }
      }
    }
  }

  Future<void> _addProduct() async {
    final nameController = TextEditingController();
    final priceController = TextEditingController();

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Add New Product'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Product Name',
                    border: OutlineInputBorder(),
                  ),
                  autofocus: true,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: priceController,
                  decoration: const InputDecoration(
                    labelText: 'Price',
                    border: OutlineInputBorder(),
                    prefixText: '\₹',
                  ),
                  keyboardType: TextInputType.number,
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () {
                  final price = double.tryParse(priceController.text) ?? 0.0;
                  if (nameController.text.isNotEmpty && price > 0) {
                    Navigator.pop(context, {
                      'name': nameController.text,
                      'price': price,
                    });
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Please enter valid product name and price',
                        ),
                      ),
                    );
                  }
                },
                child: const Text('Add'),
              ),
            ],
          ),
    );

    if (result != null) {
      try {
        await _supabase.from('products').insert(result);
        await _loadProducts();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Product added successfully')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Error adding product: $e')));
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Product Management'),
        backgroundColor: Colors.blue,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addProduct,
        backgroundColor: Colors.blue,
        child: const Icon(Icons.add),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: const InputDecoration(
                      labelText: 'Search Products',
                      prefixIcon: Icon(Icons.search),
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (value) {
                      setState(() {
                        _searchQuery = value;
                        _filterProducts();
                      });
                    },
                  ),
                ),
                const SizedBox(width: 16),
                ElevatedButton.icon(
                  onPressed: _pickAndProcessExcel,
                  icon: const Icon(Icons.upload_file),
                  label: const Text('Import Excel'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 16,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child:
                _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : ListView.builder(
                      itemCount: _filteredProducts.length,
                      itemBuilder: (context, index) {
                        final product = _filteredProducts[index];
                        return Card(
                          margin: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          child: ListTile(
                            title: Text(
                              product['name'],
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            subtitle: Text(
                              '\$${product['price'].toStringAsFixed(2)}',
                              style: const TextStyle(
                                color: Colors.green,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.edit),
                                  onPressed: () => _editProduct(product),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete),
                                  onPressed:
                                      () => _deleteProduct(product['id']),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
          ),
        ],
      ),
    );
  }
}
