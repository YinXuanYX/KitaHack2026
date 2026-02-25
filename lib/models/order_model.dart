import 'package:cloud_firestore/cloud_firestore.dart';

class OrderModel {
  final String id;
  final String consumerId;
  final String vendorId;
  final String inventoryId;
  final String status; // 'pending', 'reserved', 'claimed'
  final String receiptUrl;
  final DateTime createdAt;

  OrderModel({
    required this.id,
    required this.consumerId,
    required this.vendorId,
    required this.inventoryId,
    this.status = 'reserved',
    required this.receiptUrl,
    required this.createdAt,
  });

  factory OrderModel.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return OrderModel(
      id: data['id'] ?? doc.id,
      consumerId: data['consumerId'] ?? '',
      vendorId: data['vendorId'] ?? '',
      inventoryId: data['inventoryId'] ?? '',
      status: data['status'] ?? 'reserved',
      receiptUrl: data['receiptUrl'] ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'consumerId': consumerId,
      'vendorId': vendorId,
      'inventoryId': inventoryId,
      'status': status,
      'receiptUrl': receiptUrl,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}
