import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../../services/vendor_service.dart'; // Reusing image upload logic
import '../consumer_main_screen.dart';

class ConsumerCheckoutScreen extends StatefulWidget {
  final Map<String, dynamic> inventoryItem;

  const ConsumerCheckoutScreen({super.key, required this.inventoryItem});

  @override
  State<ConsumerCheckoutScreen> createState() => _ConsumerCheckoutScreenState();
}

class _ConsumerCheckoutScreenState extends State<ConsumerCheckoutScreen> {
  bool _isLoading = true;
  bool _isProcessingPayment = false;
  String? _vendorQrUrl;
  File? _receiptImage;

  @override
  void initState() {
    super.initState();
    _fetchVendorQr();
  }

  Future<void> _fetchVendorQr() async {
    try {
      final vendorId = widget.inventoryItem['vendorId'];
      final doc = await FirebaseFirestore.instance.collection('users').doc(vendorId).get();
      if (doc.exists) {
        setState(() {
          _vendorQrUrl = doc.data()?['paymentQrUrl'];
        });
      }
    } catch (e) {
       // Ignore for MVP, just handle null
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _pickReceipt() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery, imageQuality: 20, maxWidth: 600);
    if (pickedFile != null) {
      setState(() {
        _receiptImage = File(pickedFile.path);
      });
    }
  }

  Future<void> _processCheckout() async {
    if (_receiptImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please upload your payment receipt.')),
      );
      return;
    }

    setState(() => _isProcessingPayment = true);

    try {
      final consumerId = FirebaseAuth.instance.currentUser?.uid;
      if (consumerId == null) throw Exception('Not logged in');

      final vendorId = widget.inventoryItem['vendorId'];
      final inventoryId = widget.inventoryItem['id'];

      // 1. Transaction to update inventory (prevent double booking)
      final inventoryRef = FirebaseFirestore.instance.collection('inventory').doc(inventoryId);
      
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final snapshot = await transaction.get(inventoryRef);
        if (!snapshot.exists || snapshot.data()?['status'] != 'available') {
          throw Exception('Item is no longer available!');
        }
        transaction.update(inventoryRef, {'status': 'reserved'});
      });

      // 2. Upload Receipt (reusing VendorService upload logic for MVP)
      final vendorService = VendorService();
      final receiptUrl = await vendorService.uploadImage(_receiptImage!, 'receipts');

      // 3. Create Order
      final orderRef = FirebaseFirestore.instance.collection('orders').doc();
      await orderRef.set({
        'id': orderRef.id,
        'consumerId': consumerId,
        'vendorId': vendorId,
        'inventoryId': inventoryId,
        'itemTitle': widget.inventoryItem['title'],
        'itemPrice': widget.inventoryItem['price'],
        'status': 'pending', // Was 'reserved', changed to 'pending'
        'receiptUrl': receiptUrl,
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
         ScaffoldMessenger.of(context).showSnackBar(
           const SnackBar(content: Text('Reservation successful! Vendor is reviewing your payment.')),
         );
         Navigator.pushAndRemoveUntil(
           context,
           MaterialPageRoute(builder: (context) => const ConsumerMainScreen(initialIndex: 1)),
           (route) => false,
         );
      }

    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Checkout failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _isProcessingPayment = false);
    }
  }

  @override
  Widget build(BuildContext context) {

    final price = (widget.inventoryItem['price'] as num?)?.toDouble() ?? 0.0;
    final title = widget.inventoryItem['title'] ?? 'Item';

    return Scaffold(
      appBar: AppBar(title: const Text('Checkout')),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Reserve $title', style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 8),
                Text('Total: RM ${price.toStringAsFixed(2)}', style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Theme.of(context).colorScheme.primary)),
                const SizedBox(height: 32),
                
                const Text('Step 1: Scan & Pay', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                const SizedBox(height: 16),
                
                if (_vendorQrUrl != null && _vendorQrUrl!.isNotEmpty)
                  Center(
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: _vendorQrUrl!.startsWith('data:image')
                            ? Image.memory(base64Decode(_vendorQrUrl!.split(',').last), height: 200, fit: BoxFit.contain)
                            : Image.network(_vendorQrUrl!, height: 200, fit: BoxFit.contain),
                      ),
                    ),
                  )
                else
                  const Card(
                     child: Padding(
                        padding: EdgeInsets.all(32.0),
                        child: Center(child: Text('Vendor has not set up DuitNow QR.\nPlease pay at counter.')),
                     ),
                  ),
                
                const SizedBox(height: 32),
                const Text('Step 2: Upload Receipt', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                const SizedBox(height: 16),
                
                GestureDetector(
                  onTap: _pickReceipt,
                  child: Container(
                    height: 120,
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey[400]!),
                    ),
                    child: _receiptImage != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.file(_receiptImage!, fit: BoxFit.cover),
                          )
                        : const Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.receipt_long, size: 40, color: Colors.grey),
                                SizedBox(height: 8),
                                Text('Tap to upload payment proof', style: TextStyle(color: Colors.grey)),
                              ],
                            ),
                          ),
                  ),
                ),
                
                const SizedBox(height: 48),
                ElevatedButton(
                  onPressed: _isProcessingPayment ? null : _processCheckout,
                   style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Theme.of(context).colorScheme.onPrimary,
                  ),
                  child: _isProcessingPayment 
                     ? const CircularProgressIndicator(color: Colors.white)
                     : const Text('Confirm Reservation', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
    );
  }
}
