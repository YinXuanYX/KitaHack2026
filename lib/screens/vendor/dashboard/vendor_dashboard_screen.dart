import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import '../../../services/vendor_service.dart';

class VendorDashboardScreen extends StatefulWidget {
  const VendorDashboardScreen({super.key});

  @override
  State<VendorDashboardScreen> createState() => _VendorDashboardScreenState();
}

class _VendorDashboardScreenState extends State<VendorDashboardScreen> {
  final VendorService _vendorService = VendorService();
  bool _isUploadingQr = false;

  Future<void> _uploadQrCode() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery, imageQuality: 20, maxWidth: 600);
    
    if (image != null) {
      setState(() => _isUploadingQr = true);
      try {
        await _vendorService.updatePaymentQr(File(image.path));
        if (mounted) {
           ScaffoldMessenger.of(context).showSnackBar(
             const SnackBar(content: Text('Payment QR Code updated successfully!')),
           );
        }
      } catch (e) {
        if (mounted) {
           ScaffoldMessenger.of(context).showSnackBar(
             SnackBar(content: Text('Failed to upload QR Code: $e')),
           );
        }
      } finally {
        if (mounted) setState(() => _isUploadingQr = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final vendorId = _vendorService.currentUserId;

    if (vendorId == null) {
      return const Center(child: Text('Not authenticated'));
    }

    // Stream claimed orders for analytics
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('orders')
          .where('vendorId', isEqualTo: vendorId)
          .where('status', isEqualTo: 'claimed')
          .snapshots(),
      builder: (context, snapshot) {
        double totalRevenue = 0;
        int foodSavedKg = 0; // Estimation: 1 order = ~1kg saved

        if (snapshot.hasData) {
          final orders = snapshot.data!.docs;
          foodSavedKg = orders.length; // 1 kg per order
          
          // To get exactly revenue we'd need a join with Inventory. 
          // For MVP, we are assuming ~RM10 average or we need a cloud function.
          // Let's do a basic estimation for MVP purposes or do async fetches.
          // Since it's MVP, we'll estimate total orders * RM10 as placeholder, 
          // or we can stream Inventory items separately.
          totalRevenue = orders.length * 10.0; // Placeholder average
        }

              return SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildStatCard(context, 'Estimated Revenue', 'RM ${totalRevenue.toStringAsFixed(2)}', Icons.attach_money),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(child: _buildStatCard(context, 'Food Saved', '$foodSavedKg kg', Icons.eco, color: Colors.green)),
                      ],
                    ),
                    const SizedBox(height: 32),
                    Text(
                      'Payment Setup',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    // Current QR Status
                    StreamBuilder<DocumentSnapshot>(
                      stream: FirebaseFirestore.instance.collection('users').doc(vendorId).snapshots(),
                      builder: (context, userSnap) {
                        String? qrUrl;
                        if (userSnap.hasData && userSnap.data!.data() != null) {
                           final data = userSnap.data!.data() as Map<String, dynamic>;
                           qrUrl = data['paymentQrUrl'] as String?;
                        }

                        return Card(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              children: [
                                 qrUrl != null && qrUrl.isNotEmpty
                                   ? (qrUrl.startsWith('data:image')
                                       ? Image.memory(base64Decode(qrUrl.split(',').last), height: 150, fit: BoxFit.contain)
                                       : Image.network(qrUrl, height: 150, fit: BoxFit.contain))
                                   : const Icon(Icons.qr_code_2, size: 64, color: Colors.grey),
                                 const SizedBox(height: 16),
                                 Text(
                                   qrUrl != null 
                                     ? 'Your DuitNow QR is active. Consumers will see this during checkout.'
                                     : 'Upload your DuitNow QR to receive payments directly from consumers.',
                                   textAlign: TextAlign.center,
                                 ),
                                 const SizedBox(height: 16),
                                 ElevatedButton.icon(
                                   onPressed: _isUploadingQr ? null : _uploadQrCode,
                                   icon: _isUploadingQr 
                                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                                      : const Icon(Icons.upload),
                                   label: Text(qrUrl != null ? 'Update QR Code' : 'Upload QR Code'),
                                 ),
                              ],
                            ),
                          ),
                        );
                      }
                    ),
                  ],
                ),
              );
      },
    );
  }

  Widget _buildStatCard(BuildContext context, String title, String value, IconData icon, {Color? color}) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Icon(icon, size: 32, color: color ?? Theme.of(context).colorScheme.primary),
            const SizedBox(height: 8),
            Text(value, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(title, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey[600])),
          ],
        ),
      ),
    );
  }
}
