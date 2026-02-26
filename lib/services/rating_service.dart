import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class RatingService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? get currentUserId => _auth.currentUser?.uid;

  /// Submit a new rating for an order
  Future<void> submitRating({
    required String orderId,
    required String vendorId,
    required double rating,
    String comment = '',
  }) async {
    final consumerId = currentUserId;
    if (consumerId == null) throw Exception('User not authenticated');

    final now = DateTime.now();
    await _firestore.collection('ratings').add({
      'orderId': orderId,
      'vendorId': vendorId,
      'consumerId': consumerId,
      'rating': rating,
      'comment': comment,
      'createdAt': Timestamp.fromDate(now),
      'updatedAt': Timestamp.fromDate(now),
    });
  }

  /// Update an existing rating
  Future<void> updateRating({
    required String ratingId,
    required double rating,
    String comment = '',
  }) async {
    await _firestore.collection('ratings').doc(ratingId).update({
      'rating': rating,
      'comment': comment,
      'updatedAt': Timestamp.fromDate(DateTime.now()),
    });
  }

  /// Get the rating for a specific order (returns null if no rating exists)
  Future<Map<String, dynamic>?> getRatingForOrder(String orderId) async {
    final snapshot = await _firestore
        .collection('ratings')
        .where('orderId', isEqualTo: orderId)
        .limit(1)
        .get();

    if (snapshot.docs.isEmpty) return null;

    final doc = snapshot.docs.first;
    final data = doc.data();
    data['id'] = doc.id;
    return data;
  }

  /// Get average rating and count for a vendor
  /// Returns a map with 'average' (double) and 'count' (int)
  Future<Map<String, dynamic>> getVendorAverageRating(String vendorId) async {
    final snapshot = await _firestore
        .collection('ratings')
        .where('vendorId', isEqualTo: vendorId)
        .get();

    if (snapshot.docs.isEmpty) {
      return {'average': 0.0, 'count': 0};
    }

    double total = 0;
    for (var doc in snapshot.docs) {
      final data = doc.data();
      total += (data['rating'] as num?)?.toDouble() ?? 0.0;
    }

    final count = snapshot.docs.length;
    final average = total / count;

    return {'average': average, 'count': count};
  }

  /// Get recent reviews for a vendor (default limit: 2)
  /// Returns a list of maps containing rating details and the consumer's name
  Future<List<Map<String, dynamic>>> getRecentReviewsForVendor(String vendorId, {int limit = 2}) async {
    // Note: Removed orderBy('createdAt', descending: true) to avoid requiring a composite index 
    // since this is a hackathon MVP. We fetch and then sort locally.
    final snapshot = await _firestore
        .collection('ratings')
        .where('vendorId', isEqualTo: vendorId)
        .get();

    if (snapshot.docs.isEmpty) return [];

    // Sort locally by createdAt (descending)
    final docs = snapshot.docs.toList()
      ..sort((a, b) {
        final aTime = (a.data()['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();
        final bTime = (b.data()['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();
        return bTime.compareTo(aTime);
      });

    // Apply limit after sorting
    final limitedDocs = docs.take(limit).toList();

    List<Map<String, dynamic>> reviews = [];
    for (var doc in limitedDocs) {
      final data = doc.data();
      final consumerId = data['consumerId'] as String?;
      
      String consumerName = 'Anonymous';
      if (consumerId != null) {
        try {
          final userDoc = await _firestore.collection('users').doc(consumerId).get();
          if (userDoc.exists) {
            consumerName = userDoc.data()?['name'] ?? 'Anonymous';
          }
        } catch (_) {}
      }
      
      data['id'] = doc.id;
      data['consumerName'] = consumerName;
      reviews.add(data);
    }
    
    return reviews;
  }
}
