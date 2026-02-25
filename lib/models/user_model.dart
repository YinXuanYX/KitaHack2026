import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String uid;
  final String role; // 'consumer' or 'vendor'
  final String name;
  final String email;
  final DateTime createdAt;
  
  // Vendor-specific fields
  final String? storeName;
  final double? lat;
  final double? lng;
  final String? paymentQrUrl;

  UserModel({
    required this.uid,
    required this.role,
    required this.name,
    required this.email,
    required this.createdAt,
    this.storeName,
    this.lat,
    this.lng,
    this.paymentQrUrl,
  });

  factory UserModel.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return UserModel(
      uid: data['uid'] ?? '',
      role: data['role'] ?? 'consumer',
      name: data['name'] ?? '',
      email: data['email'] ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      storeName: data['storeName'],
      lat: (data['lat'] as num?)?.toDouble(),
      lng: (data['lng'] as num?)?.toDouble(),
      paymentQrUrl: data['paymentQrUrl'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'role': role,
      'name': name,
      'email': email,
      'createdAt': Timestamp.fromDate(createdAt),
      if (storeName != null) 'storeName': storeName,
      if (lat != null) 'lat': lat,
      if (lng != null) 'lng': lng,
      if (paymentQrUrl != null) 'paymentQrUrl': paymentQrUrl,
    };
  }
}
