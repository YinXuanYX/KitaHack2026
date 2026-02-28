import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'checkout/consumer_checkout_screen.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import '../chat/chat_screen.dart';

class ConsumerItemDetailScreen extends StatefulWidget {
  final Map<String, dynamic> inventoryItem;

  const ConsumerItemDetailScreen({
    super.key,
    required this.inventoryItem,
  });

  @override
  State<ConsumerItemDetailScreen> createState() => _ConsumerItemDetailScreenState();
}

class _ConsumerItemDetailScreenState extends State<ConsumerItemDetailScreen> {
  int _currentImageIndex = 0;
  bool _isGeneratingRecipe = false;

  Future<void> _generateRecipe(BuildContext context, String itemTitle, String description) async {
    setState(() {
      _isGeneratingRecipe = true;
    });

    try {
      final model = GenerativeModel(
        model: 'gemini-2.5-flash',
        apiKey: 'AIzaSyBD24BGbR8W66gsiFEXvnMNyYqrziEcsL4',
      );

      final prompt = 'I have this surplus food item: \$itemTitle. Description: \$description. Give me a creative, quick recipe I can make using this ingredient, in a short response.';
      final response = await model.generateContent([Content.text(prompt)]);

      if (!mounted) return;
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.restaurant_menu, color: Colors.orange),
              SizedBox(width: 8),
              Text('AI Recipe Idea'),
            ],
          ),
          content: SingleChildScrollView(
            child: Text(response.text ?? 'Could not generate recipe.'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cool!'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to generate recipe: \$e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isGeneratingRecipe = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.inventoryItem;
    final title = item['title'] ?? 'Item Details';
    final description = item['description'] ?? 'No description provided.';
    final price = (item['price'] as num?)?.toDouble() ?? 0.0;
    final storeName = item['storeName'] ?? 'Store';
    
    // Backwards compatibility for single image vs multiple images
    final String legacyImageUrl = item['imageUrl'] ?? '';
    final List<String> imageUrls = List<String>.from(item['imageUrls'] ?? []);
    
    final List<String> displayImages = imageUrls.isNotEmpty 
        ? imageUrls 
        : (legacyImageUrl.isNotEmpty ? [legacyImageUrl] : []);

    final allergens = List<String>.from(item['allergens'] ?? []);
    final tags = List<String>.from(item['tags'] ?? []);

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Image Carousel with PageView for left/right swipe
            if (displayImages.isNotEmpty) ...[
              SizedBox(
                height: 300,
                child: Stack(
                  children: [
                    PageView.builder(
                      itemCount: displayImages.length,
                      onPageChanged: (index) {
                        setState(() {
                          _currentImageIndex = index;
                        });
                      },
                      itemBuilder: (context, index) {
                        final img = displayImages[index];
                        return SizedBox(
                          width: double.infinity,
                          child: img.startsWith('data:image')
                              ? Image.memory(base64Decode(img.split(',').last), fit: BoxFit.cover)
                              : Image.network(img, fit: BoxFit.cover),
                        );
                      },
                    ),
                    if (displayImages.length > 1)
                      Positioned(
                        bottom: 16,
                        left: 0,
                        right: 0,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(
                            displayImages.length,
                            (index) => Container(
                              margin: const EdgeInsets.symmetric(horizontal: 4),
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: _currentImageIndex == index
                                    ? Theme.of(context).colorScheme.primary
                                    : Colors.white.withOpacity(0.9),
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ] else ...[
              Container(
                height: 250,
                color: Colors.grey[200],
                child: const Center(
                  child: Icon(Icons.fastfood, size: 80, color: Colors.grey),
                ),
              ),
            ],

            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.storefront, size: 20, color: Colors.grey[700]),
                      const SizedBox(width: 8),
                      Text(
                        storeName,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: Colors.grey[700],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'RM ${price.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  
                  // Description
                  Text(
                    'About this item',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    description,
                    style: const TextStyle(fontSize: 16, height: 1.5),
                  ),
                  const SizedBox(height: 24),

                  // Tags
                  if (tags.isNotEmpty) ...[
                    Text(
                      'Dietary Tags',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: tags.map((tag) => Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.tertiaryContainer,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(
                          tag,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onTertiaryContainer,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      )).toList(),
                    ),
                    const SizedBox(height: 24),
                  ],

                  // Allergens
                  if (allergens.isNotEmpty) ...[
                    Text(
                      'Allergens',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: allergens.map((allergen) => Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.errorContainer,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(
                          allergen,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onErrorContainer,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      )).toList(),
                    ),
                    const SizedBox(height: 24),
                  ],
                  
                  // AI Recipe Button
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 24),
                    child: ElevatedButton.icon(
                      onPressed: _isGeneratingRecipe ? null : () => _generateRecipe(context, title, description),
                      icon: _isGeneratingRecipe 
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.auto_awesome),
                      label: const Text('What can I make? (AI Idea)'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange.shade100,
                        foregroundColor: Colors.orange.shade900,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        elevation: 0,
                      ),
                    ),
                  ),

                  const SizedBox(height: 100), // padding for bottom bar
                ],
              ),
            ),
          ],
        ),
      ),
      bottomSheet: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              offset: const Offset(0, -4),
              blurRadius: 10,
            ),
          ],
        ),
        child: SafeArea(
          child: Row(
            children: [
              Expanded(
                flex: 1,
                child: OutlinedButton(
                  onPressed: () {
                    final vendorId = item['vendorId'];
                    if (vendorId != null) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ChatScreen(
                            receiverId: vendorId,
                            receiverName: storeName,
                          ),
                        ),
                      );
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Cannot find seller info')),
                      );
                    }
                  },
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Icon(Icons.chat),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ConsumerCheckoutScreen(inventoryItem: item),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Theme.of(context).colorScheme.onPrimary,
                  ),
                  child: const Text('Reserve Item', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
