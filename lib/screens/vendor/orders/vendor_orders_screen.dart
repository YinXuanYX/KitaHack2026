import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../services/vendor_service.dart';
import 'vendor_order_detail_screen.dart';

class VendorOrdersScreen extends StatefulWidget {
  const VendorOrdersScreen({super.key});

  @override
  State<VendorOrdersScreen> createState() => _VendorOrdersScreenState();
}

class _VendorOrdersScreenState extends State<VendorOrdersScreen> {
  final VendorService _vendorService = VendorService();

  Future<void> _updateOrderStatus(String orderId, String inventoryId, String newStatus) async {
    try {
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final orderRef = FirebaseFirestore.instance.collection('orders').doc(orderId);
        final inventoryRef = FirebaseFirestore.instance.collection('inventory').doc(inventoryId);

        transaction.update(orderRef, {'status': newStatus});

        if (newStatus == 'rejected') {
          // Revert inventory back to available
          transaction.update(inventoryRef, {'status': 'available'});
        }
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Order $newStatus!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update order: $e')),
        );
      }
    }
  }

  Color _getStatusColor(String? status) {
    switch (status) {
      case 'pending': return Colors.orange;
      case 'confirmed': return Colors.green;
      case 'rejected': return Colors.red;
      case 'claimed': return Colors.grey;
      default: return Colors.black;
    }
  }

  Widget _buildOrderList(String vendorId, List<String> statusFilters) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('orders')
          .where('vendorId', isEqualTo: vendorId)
          .where('status', whereIn: statusFilters)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Text(
              'No orders found in this category.',
              style: const TextStyle(fontSize: 16, color: Colors.grey),
            ),
          );
        }

        var orders = List<QueryDocumentSnapshot>.from(snapshot.data!.docs);
        // Sort descending by creation date
        orders.sort((a, b) {
          final aData = a.data() as Map<String, dynamic>;
          final bData = b.data() as Map<String, dynamic>;
          final aTime = aData['createdAt'] as Timestamp?;
          final bTime = bData['createdAt'] as Timestamp?;
          if (aTime == null && bTime == null) return 0;
          if (aTime == null) return 1;
          if (bTime == null) return -1;
          return bTime.compareTo(aTime);
        });

        return ListView.builder(
          padding: const EdgeInsets.all(16.0),
          itemCount: orders.length,
          itemBuilder: (context, index) {
            final orderData = orders[index].data() as Map<String, dynamic>;
            final orderId = orders[index].id;
            final inventoryId = orderData['inventoryId'];
            final title = orderData['itemTitle'] ?? 'Unknown Item';
            final price = (orderData['itemPrice'] as num?)?.toDouble() ?? 0.0;
            final status = orderData['status'] as String?;

            return Card(
              margin: const EdgeInsets.only(bottom: 16),
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () {
                   Navigator.push(
                     context,
                     MaterialPageRoute(
                       builder: (context) => VendorOrderDetailScreen(
                         orderId: orderId,
                         orderData: orderData,
                       ),
                     ),
                   );
                },
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              title,
                              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                            ),
                          ),
                          Text(
                            'RM ${price.toStringAsFixed(2)}',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              color: Theme.of(context).colorScheme.primary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                         'Status: ${(status ?? "UNKNOWN").toUpperCase()}',
                         style: TextStyle(fontWeight: FontWeight.bold, color: _getStatusColor(status)),
                      ),
                      
                      if (status == 'pending') ...[
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton(
                                onPressed: () => _updateOrderStatus(orderId, inventoryId, 'rejected'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.red.shade100,
                                  foregroundColor: Colors.red.shade900,
                                ),
                                child: const Text('Reject'),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: () => _updateOrderStatus(orderId, inventoryId, 'confirmed'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green.shade600,
                                  foregroundColor: Colors.white,
                                ),
                                child: const Text('Approve'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final vendorId = _vendorService.currentUserId;

    if (vendorId == null) {
      return const Center(child: Text('Not authenticated'));
    }

    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          const TabBar(
            tabs: [
              Tab(text: 'Current Orders'),
              Tab(text: 'Past Orders'),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                _buildOrderList(vendorId, ['pending', 'confirmed']),
                _buildOrderList(vendorId, ['claimed', 'rejected']),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
