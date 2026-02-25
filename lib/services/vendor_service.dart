import 'dart:io';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../models/inventory_model.dart';

class VendorService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Get current user ID safely
  String? get currentUserId => _auth.currentUser?.uid;

  /// Uploads an image file by converting to Base64 to bypass Firebase Storage for MVP
  Future<String> uploadImage(File imageFile, String folder) async {
    try {
      final bytes = await imageFile.readAsBytes();
      final base64String = base64Encode(bytes);
      // Return as data URI
      return 'data:image/jpeg;base64,$base64String';
    } catch (e) {
      if (kDebugMode) print('Error encoding image: $e');
      rethrow;
    }
  }

  /// Adds a new product to the `inventory` collection
  Future<void> addProduct({
    required String title,
    required String description,
    required double price,
    required List<String> allergens,
    required List<String> tags,
    required DateTime expiry,
    required List<File> imageFiles,
  }) async {
    final vendorId = currentUserId;
    if (vendorId == null) throw Exception('Vendor not authenticated');

    try {
      // 0. Fetch Store Name
      String storeName = 'Store';
      final vendorDoc = await _firestore.collection('users').doc(vendorId).get();
      if (vendorDoc.exists) {
        final data = vendorDoc.data()!;
        storeName = data['storeName'] ?? data['name'] ?? 'Store';
      }

      // 1. Upload images
      List<String> imageUrls = [];
      for (final imageFile in imageFiles) {
         final url = await uploadImage(imageFile, 'inventory_images');
         imageUrls.add(url);
      }
      
      final mainImageUrl = imageUrls.isNotEmpty ? imageUrls.first : '';

      // 2. Create the data model
      final id = _firestore.collection('inventory').doc().id;
      final product = InventoryModel(
        id: id,
        vendorId: vendorId,
        title: title,
        description: description,
        price: price,
        allergens: allergens,
        tags: tags,
        expiry: expiry,
        imageUrl: mainImageUrl, // For backward compatibility
        imageUrls: imageUrls,
        storeName: storeName,
      );

      // 3. Save to Firestore
      await _firestore.collection('inventory').doc(id).set(product.toMap());
    } catch (e) {
      if (kDebugMode) print('Error adding product: $e');
      rethrow;
    }
  }

  /// Update Vendor's DuitNow Payment QR Code
  Future<void> updatePaymentQr(File qrFile) async {
    final vendorId = currentUserId;
    if (vendorId == null) throw Exception('Vendor not authenticated');

    try {
      final qrUrl = await uploadImage(qrFile, 'vendor_qrs');
      await _firestore.collection('users').doc(vendorId).update({
        'paymentQrUrl': qrUrl,
      });
    } catch (e) {
        if (kDebugMode) print('Error updating QR: $e');
        rethrow;
    }
  }
}
