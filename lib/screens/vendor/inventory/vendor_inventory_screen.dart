import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import '../../../services/vendor_service.dart';
import 'vendor_edit_product_screen.dart';

class VendorInventoryScreen extends StatefulWidget {
  const VendorInventoryScreen({super.key});

  @override
  State<VendorInventoryScreen> createState() => _VendorInventoryScreenState();
}

class _VendorInventoryScreenState extends State<VendorInventoryScreen> {
  @override
  Widget build(BuildContext context) {
    final vendorId = VendorService().currentUserId;
    if (vendorId == null) {
      return const Center(child: Text('Not authenticated'));
    }

    return StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('inventory')
            .where('vendorId', isEqualTo: vendorId)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Text(
                'No products listed yet.\nTap "Add Product" to start!',
                textAlign: TextAlign.center,
              ),
            );
          }

          final items = snapshot.data!.docs.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            return data['status'] != 'claimed';
          }).toList();

          if (items.isEmpty) {
            return const Center(
              child: Text(
                'No active products listed.\nTap "Add Product" to start!',
                textAlign: TextAlign.center,
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.only(bottom: 80, top: 16),
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index].data() as Map<String, dynamic>;
              final imageUrl = item['imageUrl'] as String?;
              final status = item['status'] ?? 'available';

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ListTile(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => VendorEditProductScreen(
                          itemId: items[index].id,
                          itemData: item,
                        ),
                      ),
                    );
                  },
                  contentPadding: const EdgeInsets.all(12),
                  leading: imageUrl != null && imageUrl.isNotEmpty
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: imageUrl.startsWith('data:image')
                              ? Image.memory(
                                  base64Decode(imageUrl.split(',').last),
                                  width: 60,
                                  height: 60,
                                  fit: BoxFit.cover,
                                )
                              : Image.network(
                                  imageUrl,
                                  width: 60,
                                  height: 60,
                                  fit: BoxFit.cover,
                                ),
                        )
                      : Container(
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(
                            color: Colors.grey[200],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.fastfood, color: Colors.grey),
                        ),
                  title: Text(
                    item['title'] ?? '',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    'RM ${(item['price'] as num?)?.toDouble().toStringAsFixed(2) ?? "0.00"} • ${status.toString().toUpperCase()}',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () {
                      FirebaseFirestore.instance
                          .collection('inventory')
                          .doc(items[index].id)
                          .delete();
                    },
                  ),
                ),
              );
            },
          );
        },
      );
  }
}

class AddProductScreen extends StatefulWidget {
  const AddProductScreen({super.key});

  @override
  State<AddProductScreen> createState() => _AddProductScreenState();
}

class _AddProductScreenState extends State<AddProductScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _priceController = TextEditingController();
  final _allergensController = TextEditingController();
  final _customTagController = TextEditingController();
  DateTime? _expiryDate;
  final List<File> _imageFiles = [];
  bool _isLoading = false;
  bool _isSnappingWithAI = false;

  final List<String> _availableTags = [
    'Halal',
    'Non-Halal',
    'Vegetarian',
    'Vegan',
    'Spicy',
    'Sweet',
  ];
  final List<String> _selectedTags = [];

  Future<void> _snapWithAI() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.camera, imageQuality: 50, maxWidth: 800);
    
    if (image == null) return;

    setState(() => _isSnappingWithAI = true);

    try {
      final bytes = await image.readAsBytes();
      
      final model = GenerativeModel(
        model: 'gemini-2.5-flash',
        apiKey: 'AIzaSyBD24BGbR8W66gsiFEXvnMNyYqrziEcsL4',
      );

      final prompt = '''
You are an AI assistant for a surplus food business. The vendor just uploaded a picture of an item to sell. 
Look at the item and return a JSON object with strictly these keys:
- "title": (string) A catchy title.
- "description": (string) Short catchy description, mentioning it's surplus or needs to be sold soon.
- "price": (double) Suggested markdown price in RM. Make it cheap.
- "allergens": (string) Comma separated allergens if visible/likely, else empty string.
Do not wrap in markdown tags like ```json. Return ONLY valid JSON.
''';

      final response = await model.generateContent([
        Content.multi([
          TextPart(prompt),
          DataPart('image/jpeg', bytes),
        ])
      ]);

      if (response.text != null && response.text!.isNotEmpty) {
        String rspText = response.text!.trim();
        if (rspText.startsWith('```json')) {
           rspText = rspText.substring(7);
        }
        if (rspText.startsWith('```')) {
           rspText = rspText.substring(3);
        }
        if (rspText.endsWith('```')) {
           rspText = rspText.substring(0, rspText.length - 3);
        }
        
        final data = jsonDecode(rspText.trim());
        setState(() {
          _titleController.text = data['title']?.toString() ?? '';
          _descriptionController.text = data['description']?.toString() ?? '';
          if (data['price'] != null) {
            _priceController.text = data['price'].toString();
          }
          _allergensController.text = data['allergens']?.toString() ?? '';
          _imageFiles.add(File(image.path));
        });
        
        if (mounted) {
           ScaffoldMessenger.of(context).showSnackBar(
             const SnackBar(content: Text('Auto-filled fields successfully!')),
           );
        }
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('AI Vision failed: \$e')),
      );
    } finally {
      if (mounted) setState(() => _isSnappingWithAI = false);
    }
  }

  Future<void> _selectExpiryDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null && picked != _expiryDate) {
      setState(() {
        _expiryDate = picked;
      });
    }
  }

  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();
    final List<XFile> images = await picker.pickMultiImage(
      imageQuality: 20,
      maxWidth: 600,
    );
    if (images.isNotEmpty) {
      setState(() {
        _imageFiles.addAll(images.map((x) => File(x.path)));
      });
    }
  }

  Future<void> _saveProduct() async {
    if (_formKey.currentState!.validate()) {
      if (_expiryDate == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select an expiry date')),
        );
        return;
      }
      if (_imageFiles.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please provide at least one image of the food'),
          ),
        );
        return;
      }

      setState(() => _isLoading = true);

      try {
        final allergensList = _allergensController.text
            .split(',')
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty)
            .toList();

        await VendorService().addProduct(
          title: _titleController.text.trim(),
          description: _descriptionController.text.trim(),
          price: double.parse(_priceController.text),
          allergens: allergensList,
          tags: _selectedTags,
          expiry: _expiryDate!,
          imageFiles: _imageFiles,
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Product listed successfully!')),
          );
          Navigator.pop(context); // Go back to inventory list
        }
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to list product: $e')));
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('List New Product')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Placeholder "Snap with AI" Button
              Card(
                color: Theme.of(context).colorScheme.primaryContainer,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      Icon(
                        Icons.auto_awesome,
                        color: Theme.of(context).colorScheme.primary,
                        size: 32,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Magic Auto-Fill (Coming Soon)',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              color: Theme.of(context).colorScheme.primary,
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Take a photo of the food and our AI will automatically fill in the title, description, and allergens!',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: _isSnappingWithAI ? null : _snapWithAI,
                        icon: _isSnappingWithAI 
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.camera_alt),
                        label: const Text('Snap with AI'),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Or Enter Manually:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),

              // Image Picker
              if (_imageFiles.isNotEmpty) ...[
                SizedBox(
                  height: 100,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: _imageFiles.length + 1,
                    itemBuilder: (context, index) {
                      if (index == _imageFiles.length) {
                        return GestureDetector(
                          onTap: _pickImage,
                          child: Container(
                            width: 100,
                            margin: const EdgeInsets.only(right: 8),
                            decoration: BoxDecoration(
                              color: Colors.grey[200],
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.grey[400]!),
                            ),
                            child: const Icon(
                              Icons.add_a_photo,
                              color: Colors.grey,
                            ),
                          ),
                        );
                      }
                      return Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Container(
                            width: 100,
                            margin: const EdgeInsets.only(right: 8),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              image: DecorationImage(
                                image: FileImage(_imageFiles[index]),
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                          Positioned(
                            top: -8,
                            right: 0,
                            child: GestureDetector(
                              onTap: () {
                                setState(() {
                                  _imageFiles.removeAt(index);
                                });
                              },
                              child: const CircleAvatar(
                                radius: 12,
                                backgroundColor: Colors.red,
                                child: Icon(
                                  Icons.close,
                                  size: 16,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ] else ...[
                GestureDetector(
                  onTap: _pickImage,
                  child: Container(
                    height: 150,
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey[400]!),
                    ),
                    child: const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add_a_photo, size: 40, color: Colors.grey),
                          SizedBox(height: 8),
                          Text(
                            'Tap to add photo',
                            style: TextStyle(color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 16),

              TextFormField(
                controller: _titleController,
                decoration: InputDecoration(
                  labelText: 'Product Title',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                validator: (value) =>
                    value!.isEmpty ? 'Please enter a title' : null,
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _descriptionController,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: 'Description (Is it near expiry? Surplus?)',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                validator: (value) =>
                    value!.isEmpty ? 'Please enter a description' : null,
              ),
              const SizedBox(height: 16),

              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _priceController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: InputDecoration(
                        labelText: 'Discounted Price (RM)',
                        prefixIcon: const Icon(Icons.attach_money),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      validator: (value) => value!.isEmpty ? 'Required' : null,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: InkWell(
                      onTap: () => _selectExpiryDate(context),
                      child: InputDecorator(
                        decoration: InputDecoration(
                          labelText: 'Expiry Date',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          _expiryDate == null
                              ? 'Select Date'
                              : '${_expiryDate!.day}/${_expiryDate!.month}/${_expiryDate!.year}',
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _allergensController,
                decoration: InputDecoration(
                  labelText: 'Allergens (e.g. Nuts, Dairy) - Optional',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Tags:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
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
                          _selectedTags.removeWhere((String name) {
                            return name == tag;
                          });
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
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.add_circle, size: 32),
                    color: Theme.of(context).colorScheme.primary,
                    onPressed: () {
                      final newTag = _customTagController.text.trim();
                      if (newTag.isNotEmpty &&
                          !_availableTags.contains(newTag)) {
                        setState(() {
                          _availableTags.add(newTag);
                          _selectedTags.add(newTag);
                          _customTagController.clear();
                        });
                      } else if (newTag.isNotEmpty &&
                          !_selectedTags.contains(newTag)) {
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
                onPressed: _isLoading ? null : _saveProduct,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Theme.of(context).colorScheme.onPrimary,
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 24,
                        width: 24,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Text(
                        'List Product',
                        style: TextStyle(fontSize: 16),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
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
}
