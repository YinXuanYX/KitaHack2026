import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:intl/intl.dart';
import '../../../services/rating_service.dart';

class ConsumerOrderDetailScreen extends StatefulWidget {
  final Map<String, dynamic> orderData;
  final String orderId;

  const ConsumerOrderDetailScreen({
    super.key,
    required this.orderId,
    required this.orderData,
  });

  @override
  State<ConsumerOrderDetailScreen> createState() => _ConsumerOrderDetailScreenState();
}

class _ConsumerOrderDetailScreenState extends State<ConsumerOrderDetailScreen> {
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
      if (mounted) {
        setState(() => _isLoadingRating = false);
      }
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

  void _showRatingDialog({Map<String, dynamic>? existingRating}) {
    double selectedRating = existingRating != null
        ? (existingRating['rating'] as num).toDouble()
        : 0.0;
    final commentController = TextEditingController(
      text: existingRating?['comment'] ?? '',
    );

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Row(
              children: [
                Icon(
                  existingRating != null ? Icons.edit : Icons.star_rounded,
                  color: Colors.amber,
                ),
                const SizedBox(width: 8),
                Text(existingRating != null ? 'Edit Rating' : 'Rate Order'),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'How was your experience?',
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                  const SizedBox(height: 20),
                  // Star selector
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(5, (index) {
                      final starValue = index + 1.0;
                      return GestureDetector(
                        onTap: () {
                          setDialogState(() {
                            selectedRating = starValue;
                          });
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: AnimatedScale(
                            scale: selectedRating >= starValue ? 1.2 : 1.0,
                            duration: const Duration(milliseconds: 150),
                            child: Icon(
                              selectedRating >= starValue
                                  ? Icons.star_rounded
                                  : Icons.star_border_rounded,
                              color: selectedRating >= starValue
                                  ? Colors.amber
                                  : Colors.grey[400],
                              size: 40,
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                  if (selectedRating > 0) ...[
                    const SizedBox(height: 8),
                    Text(
                      _getRatingLabel(selectedRating),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.amber[800],
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  TextField(
                    controller: commentController,
                    maxLines: 3,
                    decoration: InputDecoration(
                      hintText: 'Add a comment (optional)',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                      fillColor: Colors.grey[50],
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: selectedRating > 0
                    ? () async {
                        Navigator.pop(context);
                        await _submitOrUpdateRating(
                          rating: selectedRating,
                          comment: commentController.text.trim(),
                          existingRatingId: existingRating?['id'],
                        );
                      }
                    : null,
                child: Text(existingRating != null ? 'Update' : 'Submit'),
              ),
            ],
          );
        },
      ),
    );
  }

  String _getRatingLabel(double rating) {
    if (rating >= 5) return 'Excellent!';
    if (rating >= 4) return 'Great!';
    if (rating >= 3) return 'Good';
    if (rating >= 2) return 'Fair';
    return 'Poor';
  }

  Future<void> _submitOrUpdateRating({
    required double rating,
    required String comment,
    String? existingRatingId,
  }) async {
    try {
      if (existingRatingId != null) {
        await _ratingService.updateRating(
          ratingId: existingRatingId,
          rating: rating,
          comment: comment,
        );
      } else {
        await _ratingService.submitRating(
          orderId: widget.orderId,
          vendorId: widget.orderData['vendorId'] ?? '',
          rating: rating,
          comment: comment,
        );
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(existingRatingId != null
                ? 'Rating updated successfully!'
                : 'Rating submitted successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        _loadRating();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to submit rating: $e')),
        );
      }
    }
  }

  Widget _buildRatingSection() {
    if (_isLoadingRating) {
      return const Padding(
        padding: EdgeInsets.all(16.0),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_ratingData != null) {
      // Show existing rating
      final rating = (_ratingData!['rating'] as num).toDouble();
      final comment = _ratingData!['comment'] as String? ?? '';

      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Your Rating',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Card(
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
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    onPressed: () => _showRatingDialog(existingRating: _ratingData),
                    icon: const Icon(Icons.edit, size: 18),
                    label: const Text('Edit Rating'),
                    style: OutlinedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }

    // Show Rate Order button
    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        onPressed: () => _showRatingDialog(),
        icon: const Icon(Icons.star_rounded),
        label: const Text('Rate Order', style: TextStyle(fontSize: 16)),
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16),
          backgroundColor: Colors.amber[700],
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          elevation: 3,
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

            // QR Code Section (Only if confirmed)
            if (status == 'confirmed') ...[
              const Text('Pickup QR Code', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Card(
                elevation: 2,
                color: Colors.green.shade50,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: Colors.green.shade200, width: 2),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    children: [
                      const Text(
                        'Present this QR Code to the vendor to claim your order.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.green, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 24),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10)
                          ]
                        ),
                        child: QrImageView(
                          data: widget.orderId,
                          version: QrVersions.auto,
                          size: 200.0,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ] else if (status == 'pending') ...[
               Card(
                color: Colors.orange.shade50,
                child: const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.orange),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Your order is pending confirmation from the vendor. A QR code will appear here once approved.',
                          style: TextStyle(color: Colors.orange),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],

            // Rating Section (Only for claimed orders)
            if (status == 'claimed') ...[
              const SizedBox(height: 24),
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
