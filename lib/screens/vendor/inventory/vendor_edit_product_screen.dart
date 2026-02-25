import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class VendorEditProductScreen extends StatefulWidget {
  final String itemId;
  final Map<String, dynamic> itemData;

  const VendorEditProductScreen({
    super.key,
    required this.itemId,
    required this.itemData,
  });

  @override
  State<VendorEditProductScreen> createState() => _VendorEditProductScreenState();
}

class _VendorEditProductScreenState extends State<VendorEditProductScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _titleController;
  late TextEditingController _descriptionController;
  late TextEditingController _priceController;
  late TextEditingController _allergensController;
  final _customTagController = TextEditingController();
  bool _isLoading = false;

  final List<String> _availableTags = ['Halal', 'Non-Halal', 'Vegetarian', 'Vegan', 'Spicy', 'Sweet'];
  late List<String> _selectedTags;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.itemData['title'] ?? '');
    _descriptionController = TextEditingController(text: widget.itemData['description'] ?? '');
    _priceController = TextEditingController(text: ((widget.itemData['price'] as num?)?.toDouble() ?? 0.0).toStringAsFixed(2));
    
    final allergens = widget.itemData['allergens'] as List<dynamic>? ?? [];
    _allergensController = TextEditingController(text: allergens.join(', '));

    final tags = widget.itemData['tags'] as List<dynamic>? ?? [];
    _selectedTags = List<String>.from(tags);
    
    for (String tag in _selectedTags) {
      if (!_availableTags.contains(tag)) {
        _availableTags.add(tag);
      }
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    _allergensController.dispose();
    _customTagController.dispose();
    super.dispose();
  }

  Future<void> _updateProduct() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);

      try {
        final allergensList = _allergensController.text
            .split(',')
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty)
            .toList();

        await FirebaseFirestore.instance.collection('inventory').doc(widget.itemId).update({
          'title': _titleController.text.trim(),
          'description': _descriptionController.text.trim(),
          'price': double.parse(_priceController.text),
          'allergens': allergensList,
          'tags': _selectedTags,
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Product updated successfully!')),
          );
          Navigator.pop(context); // Go back to inventory list
        }
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update product: $e')),
        );
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _deleteProduct() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Product'),
        content: const Text('Are you sure you want to delete this product? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => _isLoading = true);
      try {
        await FirebaseFirestore.instance.collection('inventory').doc(widget.itemId).delete();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Product deleted.')),
          );
          Navigator.pop(context);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to delete: $e')),
          );
        }
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final imageUrl = widget.itemData['imageUrl'] as String?;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Product'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete, color: Colors.red),
            onPressed: _isLoading ? null : _deleteProduct,
            tooltip: 'Delete Product',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Show existing image (read-only for simple edit logic)
              if (imageUrl != null && imageUrl.isNotEmpty)
                Center(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: imageUrl.startsWith('data:image')
                        ? Image.memory(base64Decode(imageUrl.split(',').last), height: 150, fit: BoxFit.cover)
                        : Image.network(imageUrl, height: 150, fit: BoxFit.cover),
                  ),
                )
              else
                Container(
                  height: 150,
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Center(child: Icon(Icons.fastfood, size: 40, color: Colors.grey)),
                ),
              const SizedBox(height: 16),
              const Text('Note: Image and expiry date cannot be edited currently.', style: TextStyle(color: Colors.grey, fontSize: 12), textAlign: TextAlign.center,),
              const SizedBox(height: 24),

              TextFormField(
                controller: _titleController,
                decoration: InputDecoration(
                  labelText: 'Product Title',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                validator: (value) => value!.isEmpty ? 'Please enter a title' : null,
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _descriptionController,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: 'Description',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                validator: (value) => value!.isEmpty ? 'Please enter a description' : null,
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _priceController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: 'Discounted Price (RM)',
                  prefixIcon: const Icon(Icons.attach_money),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                validator: (value) => value!.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _allergensController,
                decoration: InputDecoration(
                  labelText: 'Allergens (e.g. Nuts, Dairy) - Optional',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 24),
              const Text('Tags:', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8.0,
                runSpacing: 4.0,
                children: _availableTags.map((tag) {
                  return FilterChip(
                    label: Text(tag),
                    selected: _selectedTags.contains(tag),
                    onSelected: (bool selected) {
                      setState(() {
                        if (selected) {
                          _selectedTags.add(tag);
                        } else {
                          _selectedTags.remove(tag);
                        }
                      });
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _customTagController,
                      decoration: InputDecoration(
                        labelText: 'Add Custom Tag',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.add_circle, size: 32),
                    color: Theme.of(context).colorScheme.primary,
                    onPressed: () {
                      final newTag = _customTagController.text.trim();
                      if (newTag.isNotEmpty && !_availableTags.contains(newTag)) {
                        setState(() {
                          _availableTags.add(newTag);
                          _selectedTags.add(newTag);
                          _customTagController.clear();
                        });
                      } else if (newTag.isNotEmpty && !_selectedTags.contains(newTag)) {
                        setState(() {
                          _selectedTags.add(newTag);
                          _customTagController.clear();
                        });
                      }
                    },
                  ),
                ],
              ),
              const SizedBox(height: 32),

              ElevatedButton(
                onPressed: _isLoading ? null : _updateProduct,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Theme.of(context).colorScheme.onPrimary,
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 24,
                        width: 24,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : const Text('Save Changes', style: TextStyle(fontSize: 16)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
