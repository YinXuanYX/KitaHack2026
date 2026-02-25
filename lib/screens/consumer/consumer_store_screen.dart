import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'checkout/consumer_checkout_screen.dart';
import 'consumer_item_detail_screen.dart';

class ConsumerStoreScreen extends StatelessWidget {
  final String vendorId;
  final String storeName;

  const ConsumerStoreScreen({
    super.key,
    required this.vendorId,
    required this.storeName,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(storeName),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('inventory')
            .where('vendorId', isEqualTo: vendorId)
            .where('status', isEqualTo: 'available')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Text(
                'No items currently available at\n$storeName',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey[600], fontSize: 16),
              ),
            );
          }

          final items = snapshot.data!.docs;

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index].data() as Map<String, dynamic>;
              return _buildStoreItem(context, item);
            },
          );
        },
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
