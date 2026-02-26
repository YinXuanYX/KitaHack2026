import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../../services/rating_service.dart';

class VendorOrderDetailScreen extends StatefulWidget {
  final Map<String, dynamic> orderData;
  final String orderId;

  const VendorOrderDetailScreen({
    super.key,
    required this.orderId,
    required this.orderData,
  });

  @override
  State<VendorOrderDetailScreen> createState() => _VendorOrderDetailScreenState();
}

class _VendorOrderDetailScreenState extends State<VendorOrderDetailScreen> {
  final RatingService _ratingService = RatingService();
  Map<String, dynamic>? _ratingData;
  bool _isLoadingRating = true;

  @override
  void initState() {
    super.initState();
    if (widget.orderData['status'] == 'claimed') {
      _loadRating();
    } else {
      _isLoadingRating = false;
    }
  }

  Future<void> _loadRating() async {
    try {
      final rating = await _ratingService.getRatingForOrder(widget.orderId);
      if (mounted) {
        setState(() {
          _ratingData = rating;
          _isLoadingRating = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingRating = false);
    }
  }

  Color _getStatusColor(String? status) {
    switch (status) {
      case 'pending':
        return Colors.orange;
      case 'confirmed':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      case 'claimed':
        return Colors.grey;
      default:
        return Colors.black;
    }
  }

  void _showReceiptDialog(BuildContext context, String receiptUrl) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
               receiptUrl.startsWith('data:image')
                  ? Image.memory(base64Decode(receiptUrl.split(',').last), fit: BoxFit.contain)
                  : Image.network(receiptUrl, fit: BoxFit.contain),
               const SizedBox(height: 16),
               TextButton(
                 onPressed: () => Navigator.pop(context),
                 child: const Text('Close'),
               ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRatingSection() {
    if (_isLoadingRating) {
      return const Padding(
        padding: EdgeInsets.all(16.0),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_ratingData == null) {
      return Card(
        elevation: 1,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Icon(Icons.star_border_rounded, color: Colors.grey[400], size: 28),
              const SizedBox(width: 12),
              Text(
                'No rating submitted yet',
                style: TextStyle(color: Colors.grey[500], fontSize: 15),
              ),
            ],
          ),
        ),
      );
    }

    final rating = (_ratingData!['rating'] as num).toDouble();
    final comment = _ratingData!['comment'] as String? ?? '';

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(5, (index) {
                return Icon(
                  index < rating.round()
                      ? Icons.star_rounded
                      : Icons.star_border_rounded,
                  color: index < rating.round()
                      ? Colors.amber
                      : Colors.grey[300],
                  size: 32,
                );
              }),
            ),
            const SizedBox(height: 8),
            Text(
              '${rating.toStringAsFixed(1)} / 5.0',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.amber[800],
              ),
            ),
            if (comment.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Divider(),
              const SizedBox(height: 8),
              Text(
                '"$comment"',
                style: const TextStyle(
                  fontStyle: FontStyle.italic,
                  fontSize: 15,
                  color: Colors.black87,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.orderData['itemTitle'] ?? 'Unknown Item';
    final price = (widget.orderData['itemPrice'] as num?)?.toDouble() ?? 0.0;
    final status = widget.orderData['status'] as String?;
    final receiptUrl = widget.orderData['receiptUrl'] as String?;
    final imageUrl = widget.orderData['itemImageUrl'] as String?;
    
    DateTime? orderDate;
    if (widget.orderData['createdAt'] != null) {
      orderDate = (widget.orderData['createdAt'] as Timestamp).toDate();
    }

    DateTime? claimedDate;
    if (widget.orderData['claimedAt'] != null) {
      claimedDate = (widget.orderData['claimedAt'] as Timestamp).toDate();
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Order Details'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Image Card
            if (imageUrl != null && imageUrl.isNotEmpty)
              Card(
                elevation: 2,
                clipBehavior: Clip.antiAlias,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: SizedBox(
                   height: 200,
                   width: double.infinity,
                   child: imageUrl.startsWith('data:image')
                      ? Image.memory(base64Decode(imageUrl.split(',').last), fit: BoxFit.cover)
                      : Image.network(imageUrl, fit: BoxFit.cover),
                ),
              ),
            if (imageUrl != null && imageUrl.isNotEmpty) const SizedBox(height: 24),

            // Header Card
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'RM ${price.toStringAsFixed(2)}',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: _getStatusColor(status).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: _getStatusColor(status)),
                      ),
                      child: Text(
                        (status ?? 'UNKNOWN').toUpperCase(),
                        style: TextStyle(
                          color: _getStatusColor(status),
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Order Info Section
            const Text('Order Information', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Card(
              elevation: 1,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    _buildInfoRow('Order ID', widget.orderId),
                    const Divider(),
                    _buildInfoRow('Placed On', orderDate != null ? DateFormat('MMM dd, yyyy - hh:mm a').format(orderDate) : 'Unknown'),
                    if (status == 'claimed' && claimedDate != null) ...[
                       const Divider(),
                       _buildInfoRow('Redeemed On', DateFormat('MMM dd, yyyy - hh:mm a').format(claimedDate)),
                    ]
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Receipt Section
            if (receiptUrl != null) ...[
              const Text('Payment Proof', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Card(
                elevation: 1,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: ListTile(
                  leading: const Icon(Icons.receipt_long, color: Colors.blue),
                  title: const Text('View Uploaded Receipt'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _showReceiptDialog(context, receiptUrl),
                ),
              ),
              const SizedBox(height: 24),
            ],

            // Customer Rating Section (Only for claimed orders)
            if (status == 'claimed') ...[
              const Text('Customer Rating', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              _buildRatingSection(),
            ],

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(flex: 2, child: Text(label, style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.w500))),
          Expanded(flex: 3, child: Text(value, style: const TextStyle(fontWeight: FontWeight.w600), textAlign: TextAlign.right)),
        ],
      ),
    );
  }
}
