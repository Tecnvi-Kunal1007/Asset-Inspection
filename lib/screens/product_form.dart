import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/scanner_page.dart';


class ProductFormPage extends StatefulWidget {
  const ProductFormPage({super.key});

  @override
  State<ProductFormPage> createState() => _ProductFormPageState();
}

class _ProductFormPageState extends State<ProductFormPage> {
  final _formKey = GlobalKey<FormState>();
  String _name = "";
  int _quantity = 0;
  double _price = 0;
  String _tagUid = "";

  final supabase = Supabase.instance.client;

  Future<void> _submitForm() async {
    if (_formKey.currentState!.validate()) {
      if (_tagUid.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("⚠ Please scan tag first!")),
        );
        return;
      }
      _formKey.currentState!.save();

      try {
        // Save tag & product
        await supabase.from('tags').insert({'uid': _tagUid});
        await supabase.from('products').insert({
          'name': _name,
          'quantity': _quantity,
          'price': _price,
          'tag_uid': _tagUid,
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("✅ Product saved with Tag $_tagUid")),
        );

        _formKey.currentState!.reset();
        setState(() => _tagUid = "");
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("❌ Error: $e")),
        );
      }
    }
  }

  void _scanTag() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CameraScanner(
          onScanned: (uid) {
            setState(() => _tagUid = uid);
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Add Product")),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                decoration: const InputDecoration(labelText: "Product Name"),
                validator: (v) => v!.isEmpty ? "Enter product name" : null,
                onSaved: (v) => _name = v!,
              ),
              TextFormField(
                decoration: const InputDecoration(labelText: "Quantity"),
                keyboardType: TextInputType.number,
                validator: (v) => v!.isEmpty ? "Enter quantity" : null,
                onSaved: (v) => _quantity = int.parse(v!),
              ),
              TextFormField(
                decoration: const InputDecoration(labelText: "Price"),
                keyboardType: TextInputType.number,
                validator: (v) => v!.isEmpty ? "Enter price" : null,
                onSaved: (v) => _price = double.parse(v!),
              ),
              const SizedBox(height: 20),

              ElevatedButton.icon(
                onPressed: _scanTag,
                icon: const Icon(Icons.qr_code_scanner),
                label: Text(_tagUid.isEmpty ? "Scan Tag" : "Tag: $_tagUid"),
              ),

              const SizedBox(height: 20),

              ElevatedButton(
                onPressed: _submitForm,
                child: const Text("Submit Product"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}