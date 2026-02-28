import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';

class VendorScanOrderScreen extends StatefulWidget {
  const VendorScanOrderScreen({super.key});

  @override
  State<VendorScanOrderScreen> createState() => _VendorScanOrderScreenState();
}

class _VendorScanOrderScreenState extends State<VendorScanOrderScreen> {
  final MobileScannerController _scannerController = MobileScannerController();
  bool _isProcessing = false;

  Future<void> _pickImageAndScan() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);
    
    if (image == null) return;
    
    setState(() {
      _isProcessing = true;
    });

    try {
      final BarcodeCapture? capture = await _scannerController.analyzeImage(image.path);
      if (capture != null && capture.barcodes.isNotEmpty && capture.barcodes.first.rawValue != null) {
        await _processOrder(capture.barcodes.first.rawValue!);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No QR code found in the selected image.', style: TextStyle(color: Colors.white)), backgroundColor: Colors.red),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error analyzing image: $e', style: const TextStyle(color: Colors.white)), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
         setState(() {
           _isProcessing = false;
         });
      }
    }
  }

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

      // Update to Claimed and record the time
      await docRef.update({
        'status': 'claimed',
        'claimedAt': FieldValue.serverTimestamp(),
      });
      
      // Delete the inventory item so it vanishes from the storefront
      final inventoryId = data['inventoryId'] as String?;
      if (inventoryId != null) {
         await FirebaseFirestore.instance.collection('inventory').doc(inventoryId).delete();
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
      appBar: AppBar(
        title: const Text('Scan Pickup QR'),
        actions: [
          IconButton(
            icon: const Icon(Icons.image),
            tooltip: 'Upload QR Image',
            onPressed: _isProcessing ? null : _pickImageAndScan,
          ),
        ],
      ),
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
