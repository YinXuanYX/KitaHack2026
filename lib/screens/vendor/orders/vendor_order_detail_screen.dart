import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class VendorOrderDetailScreen extends StatelessWidget {
  final Map<String, dynamic> orderData;
  final String orderId;

  const VendorOrderDetailScreen({
    super.key,
    required this.orderId,
    required this.orderData,
  });

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

  @override
  Widget build(BuildContext context) {
    final title = orderData['itemTitle'] ?? 'Unknown Item';
    final price = (orderData['itemPrice'] as num?)?.toDouble() ?? 0.0;
    final status = orderData['status'] as String?;
    final receiptUrl = orderData['receiptUrl'] as String?;
    final imageUrl = orderData['itemImageUrl'] as String?;
    
    DateTime? orderDate;
    if (orderData['createdAt'] != null) {
      orderDate = (orderData['createdAt'] as Timestamp).toDate();
    }

    DateTime? claimedDate;
    if (orderData['claimedAt'] != null) {
      claimedDate = (orderData['claimedAt'] as Timestamp).toDate();
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
                        color: _getStatusColor(status).withOpacity(0.1),
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
                    _buildInfoRow('Order ID', orderId),
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
