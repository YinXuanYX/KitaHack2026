import 'package:cloud_firestore/cloud_firestore.dart';

class InventoryModel {
  final String id;
  final String vendorId;
  final String title;
  final String description;
  final double price;
  final List<String> allergens;
  final List<String> tags; // Vegetarian, Halal, etc.
  final DateTime expiry;
  final String imageUrl; // Kept for backwards compatibility
  final List<String> imageUrls; // Array of item images
  final String status; // 'available', 'reserved', 'claimed'
  final String storeName; // Denormalized for display

  InventoryModel({
    required this.id,
    required this.vendorId,
    required this.title,
    required this.description,
    required this.price,
    required this.allergens,
    this.tags = const [],
    required this.expiry,
    required this.imageUrl,
    this.imageUrls = const [],
    this.status = 'available',
    this.storeName = 'Store',
  });

  factory InventoryModel.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return InventoryModel(
      id: data['id'] ?? doc.id,
      vendorId: data['vendorId'] ?? '',
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      price: (data['price'] as num?)?.toDouble() ?? 0.0,
      allergens: List<String>.from(data['allergens'] ?? []),
      tags: List<String>.from(data['tags'] ?? []),
      expiry: (data['expiry'] as Timestamp?)?.toDate() ?? DateTime.now(),
      imageUrl: data['imageUrl'] ?? '',
      imageUrls: List<String>.from(data['imageUrls'] ?? []),
      status: data['status'] ?? 'available',
      storeName: data['storeName'] ?? 'Store',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'vendorId': vendorId,
      'title': title,
      'description': description,
      'price': price,
      'allergens': allergens,
      'tags': tags,
      'expiry': Timestamp.fromDate(expiry),
      'imageUrl': imageUrl,
      'imageUrls': imageUrls,
      'status': status,
      'storeName': storeName,
    };
  }
}
