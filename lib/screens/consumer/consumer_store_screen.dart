import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/rating_service.dart';
import 'checkout/consumer_checkout_screen.dart';
import 'consumer_item_detail_screen.dart';
import '../chat/chat_screen.dart';
import '../report/report_screen.dart';

class ConsumerStoreScreen extends StatefulWidget {
  final String vendorId;
  final String storeName;

  const ConsumerStoreScreen({
    super.key,
    required this.vendorId,
    required this.storeName,
  });

  @override
  State<ConsumerStoreScreen> createState() => _ConsumerStoreScreenState();
}

class _ConsumerStoreScreenState extends State<ConsumerStoreScreen> {
  final RatingService _ratingService = RatingService();
  
  Map<String, dynamic>? _vendorData;
  double _averageRating = 0.0;
  int _ratingCount = 0;
  List<Map<String, dynamic>> _recentReviews = [];
  bool _isLoadingHeaders = true;

  @override
  void initState() {
    super.initState();
    _loadStoreData();
  }

  Future<void> _loadStoreData() async {
    try {
      print('DEBUG: Loading store data for vendorId: ${widget.vendorId}');
      // Fetch vendor details, average rating, and recent reviews concurrently
      final responses = await Future.wait([
        FirebaseFirestore.instance.collection('users').doc(widget.vendorId).get(),
        _ratingService.getVendorAverageRating(widget.vendorId),
        _ratingService.getRecentReviewsForVendor(widget.vendorId, limit: 2),
      ]);

      print('DEBUG: Data fetched successfully for ${widget.vendorId}');

      final vendorDoc = responses[0] as DocumentSnapshot;
      final ratingData = responses[1] as Map<String, dynamic>;
      final reviews = responses[2] as List<Map<String, dynamic>>;

      print('DEBUG: Vendor Doc exists: ${vendorDoc.exists}');
      print('DEBUG: Rating Data: $ratingData');
      print('DEBUG: Reviews count: ${reviews.length}');

      if (mounted) {
        setState(() {
          _vendorData = vendorDoc.data() as Map<String, dynamic>?;
          _averageRating = ratingData['average'] as double;
          _ratingCount = ratingData['count'] as int;
          _recentReviews = reviews;
          _isLoadingHeaders = false;
        });
      }
    } catch (e, stack) {
      print('DEBUG ERROR in _loadStoreData: $e');
      print(stack);
      if (mounted) setState(() => _isLoadingHeaders = false);
    }
  }

  Widget _buildStoreHeader() {
    if (_isLoadingHeaders) {
      return const SizedBox(
        height: 200,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    final profileImageUrl = _vendorData?['profileImageUrl'] as String?;
    final phone = _vendorData?['phone'] as String? ?? 'No phone number';
    final actualStoreName = _vendorData?['storeName'] ?? _vendorData?['name'] ?? widget.storeName;

    return Container(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Column(
        children: [
          CircleAvatar(
            radius: 50,
            backgroundColor: Colors.grey[200],
            backgroundImage: profileImageUrl != null && profileImageUrl.isNotEmpty
                ? (profileImageUrl.startsWith('data:image')
                    ? MemoryImage(base64Decode(profileImageUrl.split(',').last))
                    : NetworkImage(profileImageUrl) as ImageProvider)
                : null,
            child: profileImageUrl == null || profileImageUrl.isEmpty
                ? const Icon(Icons.storefront, size: 45, color: Colors.grey)
                : null,
          ),
          const SizedBox(height: 16),
          Text(
            actualStoreName,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.phone, size: 16, color: Colors.grey[600]),
              const SizedBox(width: 8),
              Text(
                phone,
                style: TextStyle(fontSize: 15, color: Colors.grey[600]),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ...List.generate(5, (index) {
                return Icon(
                  index < _averageRating.round()
                      ? Icons.star_rounded
                      : Icons.star_border_rounded,
                  color: index < _averageRating.round()
                      ? Colors.amber
                      : Colors.grey[300],
                  size: 24,
                );
              }),
              const SizedBox(width: 8),
              Text(
                _ratingCount > 0
                    ? '${_averageRating.toStringAsFixed(1)} ($_ratingCount reviews)'
                    : 'No reviews yet',
                style: TextStyle(
                  fontSize: 15,
                  color: Colors.grey[700],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ChatScreen(
                      receiverId: widget.vendorId,
                      receiverName: actualStoreName,
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.chat),
              label: const Text('Message Store'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentReviews() {
    if (_recentReviews.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Recent Reviews',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          ..._recentReviews.map((review) {
            final rating = (review['rating'] as num).toDouble();
            final comment = review['comment'] as String? ?? '';
            final consumerName = review['consumerName'] as String;

            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              elevation: 0,
              color: Colors.grey.shade50,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: Colors.grey.shade200),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          consumerName,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                        Row(
                          children: [
                            Text(
                              rating.toStringAsFixed(1),
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.amber[800],
                              ),
                            ),
                            const SizedBox(width: 4),
                            const Icon(Icons.star_rounded, color: Colors.amber, size: 18),
                          ],
                        ),
                      ],
                    ),
                    if (comment.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        '"$comment"',
                        style: TextStyle(
                          fontStyle: FontStyle.italic,
                          color: Colors.grey.shade700,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            title: Text(widget.storeName),
            floating: true,
            pinned: true,
            elevation: 0,
            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
            surfaceTintColor: Colors.transparent,
            actions: [
              IconButton(
                icon: const Icon(Icons.report_gmailerrorred),
                tooltip: 'Report Seller',
                color: Colors.red,
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ReportScreen(
                        reportedUserId: widget.vendorId,
                        reportedUserName: widget.storeName,
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
          SliverToBoxAdapter(
            child: _buildStoreHeader(),
          ),
          if (!_isLoadingHeaders && _recentReviews.isNotEmpty)
            SliverToBoxAdapter(
              child: _buildRecentReviews(),
            ),
          
          // Products Section Title
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(16, 24, 16, 12),
              child: Text(
                'Available Products',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
          ),

          // Products List
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('inventory')
                .where('vendorId', isEqualTo: widget.vendorId)
                .where('status', isEqualTo: 'available')
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(child: CircularProgressIndicator()),
                );
              }

              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.inventory_2_outlined, size: 64, color: Colors.grey[300]),
                          const SizedBox(height: 16),
                          Text(
                            'No items currently available at\n${widget.storeName}',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.grey[600], fontSize: 16),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }

              final items = snapshot.data!.docs;
              return SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final item = items[index].data() as Map<String, dynamic>;
                      return _buildStoreItem(context, item);
                    },
                    childCount: items.length,
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildStoreItem(BuildContext context, Map<String, dynamic> item) {
    final imageUrl = item['imageUrl'] as String?;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 2,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ConsumerItemDetailScreen(inventoryItem: item),
            ),
          );
        },
        child: ListTile(
          contentPadding: const EdgeInsets.all(12),
          leading: imageUrl != null && imageUrl.isNotEmpty
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: imageUrl.startsWith('data:image')
                      ? Image.memory(base64Decode(imageUrl.split(',').last),
                          width: 60, height: 60, fit: BoxFit.cover)
                      : Image.network(imageUrl,
                          width: 60, height: 60, fit: BoxFit.cover),
                )
              : Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(8)),
                  child: const Icon(Icons.fastfood, color: Colors.grey),
                ),
          title: Text(item['title'] ?? '',
              style: const TextStyle(fontWeight: FontWeight.bold)),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 4),
              Text(item['description'] ?? '',
                  maxLines: 2, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 4),
              Text(
                'RM ${(item['price'] as num?)?.toDouble().toStringAsFixed(2) ?? "0.00"}',
                style: TextStyle(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.bold),
              ),
            ],
          ),
          trailing: ElevatedButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      ConsumerCheckoutScreen(inventoryItem: item),
                ),
              );
            },
            child: const Text('Reserve'),
          ),
        ),
      ),
    );
  }
}
