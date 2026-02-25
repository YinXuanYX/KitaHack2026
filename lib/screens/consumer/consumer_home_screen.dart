import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:permission_handler/permission_handler.dart';
import 'checkout/consumer_checkout_screen.dart';

import 'consumer_item_detail_screen.dart';
import 'consumer_store_screen.dart';

class ConsumerHomeScreen extends StatefulWidget {
  const ConsumerHomeScreen({super.key});

  @override
  State<ConsumerHomeScreen> createState() => _ConsumerHomeScreenState();
}

class _ConsumerHomeScreenState extends State<ConsumerHomeScreen> {
  final Completer<GoogleMapController> _controller = Completer();
  
  // Default to somewhere central in KL for the MVP
  static const CameraPosition _initialCameraPosition = CameraPosition(
    target: LatLng(3.1390, 101.6869),
    zoom: 12,
  );

  Set<Marker> _markers = {};
  bool _locationPermissionGranted = false;

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
      final String? storeName = data['storeName'] ?? data['name'];
      
      if (lat != null && lng != null) {
        newMarkers.add(
          Marker(
            markerId: MarkerId(doc.id),
            position: LatLng(lat, lng),
            infoWindow: InfoWindow(
              title: storeName,
              snippet: 'Tap to view all items available here',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ConsumerStoreScreen(
                      vendorId: doc.id,
                      storeName: storeName ?? 'Store',
                    ),
                  ),
                );
              },
            ),
            icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
          ),
        );
      }
    }

    setState(() {
      _markers = newMarkers;
    });
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
