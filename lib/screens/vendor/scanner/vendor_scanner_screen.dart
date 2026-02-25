import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class VendorScanOrderScreen extends StatefulWidget {
  const VendorScanOrderScreen({super.key});

  @override
  State<VendorScanOrderScreen> createState() => _VendorScanOrderScreenState();
}

class _VendorScanOrderScreenState extends State<VendorScanOrderScreen> {
  final MobileScannerController _scannerController = MobileScannerController();
  bool _isProcessing = false;

  void _onDetect(BarcodeCapture capture) async {
    if (_isProcessing) return;

    final List<Barcode> barcodes = capture.barcodes;
    if (barcodes.isNotEmpty && barcodes.first.rawValue != null) {
      final String orderId = barcodes.first.rawValue!;
      
      setState(() {
        _isProcessing = true;
      });

      await _processOrder(orderId);
      
      // Wait a bit before allowing another scan
      await Future.delayed(const Duration(seconds: 2));
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  Future<void> _processOrder(String orderId) async {
    try {
      final docRef = FirebaseFirestore.instance.collection('orders').doc(orderId);
      final docSnap = await docRef.get();

      if (!docSnap.exists) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
           const SnackBar(content: Text('Invalid QR Code. Order not found.')),
        );
        return;
      }

      final data = docSnap.data()!;
      final status = data['status'] as String?;

      if (status == 'claimed') {
         if (!mounted) return;
         ScaffoldMessenger.of(context).showSnackBar(
           const SnackBar(content: Text('This order has already been claimed!')),
         );
         return;
      }

      // Update to Claimed
      await docRef.update({'status': 'claimed'});
      
      // Also update inventory status
      final inventoryId = data['inventoryId'] as String?;
      if (inventoryId != null) {
         await FirebaseFirestore.instance.collection('inventory').doc(inventoryId).update({
            'status': 'claimed',
         });
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
         const SnackBar(
           content: Text('Order successfully marked as claimed!'),
           backgroundColor: Colors.green,
         ),
      );

    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
         SnackBar(content: Text('Error processing order: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Scan Pickup QR')),
      body: Stack(
        children: [
          MobileScanner(
            controller: _scannerController,
            onDetect: _onDetect,
          ),
          
          Column(
            mainAxisAlignment: MainAxisAlignment.end,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
               Container(
                 color: Colors.black54,
                 padding: const EdgeInsets.all(24),
                 child: Text(
                    _isProcessing 
                      ? 'Processing Scan...' 
                      : 'Align the Consumer\'s QR code within the frame to fulfill the order.',
                    style: const TextStyle(color: Colors.white, fontSize: 16),
                    textAlign: TextAlign.center,
                 ),
               )
            ],
          ),
          
          if (_isProcessing)
             const Center(
               child: CircularProgressIndicator(),
             ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _scannerController.dispose();
    super.dispose();
  }
}
