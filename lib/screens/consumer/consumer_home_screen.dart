import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:permission_handler/permission_handler.dart';
import 'checkout/consumer_checkout_screen.dart';
import '../../services/rating_service.dart';

import 'consumer_item_detail_screen.dart';
import 'consumer_store_screen.dart';

class ConsumerHomeScreen extends StatefulWidget {
  const ConsumerHomeScreen({super.key});

  @override
  State<ConsumerHomeScreen> createState() => _ConsumerHomeScreenState();
}

class _ConsumerHomeScreenState extends State<ConsumerHomeScreen> {
  final Completer<GoogleMapController> _controller = Completer();
  final RatingService _ratingService = RatingService();
  
  // Default to somewhere central in KL for the MVP
  static const CameraPosition _initialCameraPosition = CameraPosition(
    target: LatLng(3.1390, 101.6869),
    zoom: 12,
  );

  Set<Marker> _markers = {};
  bool _locationPermissionGranted = false;

  // Store vendor data for bottom sheet
  final Map<String, Map<String, dynamic>> _vendorDataMap = {};

  @override
  void initState() {
    super.initState();
    _requestPermissions();
    _loadVendorMarkers();
  }

  Future<void> _requestPermissions() async {
    final status = await Permission.location.request();
    if (status.isGranted) {
      if (mounted) {
        setState(() {
          _locationPermissionGranted = true;
        });
      }
    }
  }

  Future<void> _loadVendorMarkers() async {
    final QuerySnapshot vendorSnap = await FirebaseFirestore.instance
        .collection('users')
        .where('role', isEqualTo: 'vendor')
        .get();

    final Set<Marker> newMarkers = {};
    for (var doc in vendorSnap.docs) {
      final data = doc.data() as Map<String, dynamic>;
      final double? lat = data['lat'];
      final double? lng = data['lng'];
      final String storeName = data['storeName'] ?? data['name'] ?? 'Store';
      
      if (lat != null && lng != null) {
        // Cache vendor data for bottom sheet
        _vendorDataMap[doc.id] = data;

        newMarkers.add(
          Marker(
            markerId: MarkerId(doc.id),
            position: LatLng(lat, lng),
            icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
            onTap: () => _showStoreOverview(doc.id, storeName, data),
          ),
        );
      }
    }

    setState(() {
      _markers = newMarkers;
    });
  }

  void _showStoreOverview(String vendorId, String storeName, Map<String, dynamic> vendorData) {
    final profileImageUrl = vendorData['profileImageUrl'] as String?;
    final phone = vendorData['phone'] as String? ?? 'No phone number';

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag handle
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Store Image
            CircleAvatar(
              radius: 45,
              backgroundColor: Colors.grey[200],
              backgroundImage: profileImageUrl != null && profileImageUrl.isNotEmpty
                  ? (profileImageUrl.startsWith('data:image')
                      ? MemoryImage(base64Decode(profileImageUrl.split(',').last))
                      : NetworkImage(profileImageUrl) as ImageProvider)
                  : null,
              child: profileImageUrl == null || profileImageUrl.isEmpty
                  ? const Icon(Icons.storefront, size: 40, color: Colors.grey)
                  : null,
            ),
            const SizedBox(height: 16),
            // Store Name
            Text(
              storeName,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            // Phone
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.phone, size: 16, color: Colors.grey[600]),
                const SizedBox(width: 6),
                Text(
                  phone,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Average Rating (loaded async)
            FutureBuilder<Map<String, dynamic>>(
              future: _ratingService.getVendorAverageRating(vendorId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const SizedBox(
                    height: 24,
                    width: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  );
                }

                final average = (snapshot.data?['average'] as double?) ?? 0.0;
                final count = (snapshot.data?['count'] as int?) ?? 0;

                return Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ...List.generate(5, (index) {
                      return Icon(
                        index < average.round()
                            ? Icons.star_rounded
                            : Icons.star_border_rounded,
                        color: index < average.round()
                            ? Colors.amber
                            : Colors.grey[300],
                        size: 22,
                      );
                    }),
                    const SizedBox(width: 8),
                    Text(
                      count > 0
                          ? '${average.toStringAsFixed(1)} ($count)'
                          : 'No reviews',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 24),
            // View Store Button
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () {
                  Navigator.pop(context); // Close bottom sheet
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ConsumerStoreScreen(
                        vendorId: vendorId,
                        storeName: storeName,
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.storefront),
                label: const Text('View Store', style: TextStyle(fontSize: 16)),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox.expand(
      child: Stack(
        children: [
          // Background Map View (needs explicit bounded parent)
          Positioned.fill(
            child: GoogleMap(
              mapType: MapType.normal,
              initialCameraPosition: _initialCameraPosition,
              markers: _markers,
              myLocationEnabled: _locationPermissionGranted,
              myLocationButtonEnabled: _locationPermissionGranted,
              onMapCreated: (GoogleMapController controller) {
                _controller.complete(controller);
              },
            ),
          ),

          // Foreground Draggable Sheet for the Feed
          DraggableScrollableSheet(
            initialChildSize: 0.4,
            minChildSize: 0.1,
            maxChildSize: 0.9,
            builder: (BuildContext context, ScrollController scrollController) {
              return Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(24),
                    topRight: Radius.circular(24),
                  ),
                  boxShadow: [
                    BoxShadow(color: Colors.black12, blurRadius: 10, spreadRadius: 2),
                  ],
                ),
                child: Column(
                  children: [
                    const SizedBox(height: 12),
                    // Drag Handle
                    Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(color: Colors.grey[400], borderRadius: BorderRadius.circular(2))),
                    const SizedBox(height: 16),
                    const Text('Available Nearby', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),

                    // The Feed
                    Expanded(
                      child: StreamBuilder<QuerySnapshot>(
                        stream: FirebaseFirestore.instance
                            .collection('inventory')
                            .where('status', isEqualTo: 'available')
                            .snapshots(),
                        builder: (context, snapshot) {
                          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

                          final items = snapshot.data!.docs;

                          return ListView.builder(
                            controller: scrollController,
                            itemCount: items.length,
                            itemBuilder: (context, index) {
                              final item = items[index].data() as Map<String, dynamic>;
                              return _buildFeedItem(context, item);
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildFeedItem(BuildContext context, Map<String, dynamic> item) {
    final imageUrl = item['imageUrl'] as String?;
    final storeName = item['storeName'] ?? 'Store';

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                    ? Image.memory(base64Decode(imageUrl.split(',').last), width: 60, height: 60, fit: BoxFit.cover)
                    : Image.network(imageUrl, width: 60, height: 60, fit: BoxFit.cover),
              )
            : Container(
                width: 60, height: 60,
                decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(8)),
                child: const Icon(Icons.fastfood, color: Colors.grey),
              ),
        title: Text(item['title'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
             Text(storeName, style: TextStyle(color: Colors.grey[600], fontSize: 13, fontWeight: FontWeight.w500)),
             const SizedBox(height: 2),
             Text(item['description'] ?? '', maxLines: 2, overflow: TextOverflow.ellipsis),
             const SizedBox(height: 4),
             Text('RM ${(item['price'] as num?)?.toDouble().toStringAsFixed(2) ?? "0.00"}', 
                style: TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.bold)),
          ],
        ),
        trailing: ElevatedButton(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ConsumerCheckoutScreen(inventoryItem: item),
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
