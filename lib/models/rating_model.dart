import 'package:cloud_firestore/cloud_firestore.dart';

class RatingModel {
  final String id;
  final String orderId;
  final String vendorId;
  final String consumerId;
  final double rating; // 1.0 - 5.0
  final String comment;
  final DateTime createdAt;
  final DateTime updatedAt;

  RatingModel({
    required this.id,
    required this.orderId,
    required this.vendorId,
    required this.consumerId,
    required this.rating,
    this.comment = '',
    required this.createdAt,
    required this.updatedAt,
  });

  factory RatingModel.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return RatingModel(
      id: doc.id,
      orderId: data['orderId'] ?? '',
      vendorId: data['vendorId'] ?? '',
      consumerId: data['consumerId'] ?? '',
      rating: (data['rating'] as num?)?.toDouble() ?? 0.0,
      comment: data['comment'] ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'orderId': orderId,
      'vendorId': vendorId,
      'consumerId': consumerId,
      'rating': rating,
      'comment': comment,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }
}
