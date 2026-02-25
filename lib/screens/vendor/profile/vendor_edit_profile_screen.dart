import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:image_picker/image_picker.dart';
import '../../components/map_picker_screen.dart';

class VendorEditProfileScreen extends StatefulWidget {
  final Map<String, dynamic> initialData;

  const VendorEditProfileScreen({super.key, required this.initialData});

  @override
  State<VendorEditProfileScreen> createState() => _VendorEditProfileScreenState();
}

class _VendorEditProfileScreenState extends State<VendorEditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _storeNameController;
  late TextEditingController _phoneController;
  late TextEditingController _emailController;
  
  LatLng? _selectedLocation;
  String? _profileImageUrl;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _storeNameController = TextEditingController(text: widget.initialData['storeName'] ?? '');
    _phoneController = TextEditingController(text: widget.initialData['phone'] ?? '');
    _emailController = TextEditingController(text: FirebaseAuth.instance.currentUser?.email ?? '');
    _profileImageUrl = widget.initialData['profileImageUrl'];
    
    final double? lat = widget.initialData['lat'];
    final double? lng = widget.initialData['lng'];
    if (lat != null && lng != null) {
      _selectedLocation = LatLng(lat, lng);
    }
  }

  Future<void> _pickProfileImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery, imageQuality: 20, maxWidth: 600);
    
    if (image != null) {
      setState(() => _isSaving = true);
      try {
        final bytes = await image.readAsBytes();
        final base64String = base64Encode(bytes);
        final imageUrl = 'data:image/jpeg;base64,$base64String';
        
        final user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
            'profileImageUrl': imageUrl,
          });
          setState(() {
            _profileImageUrl = imageUrl;
          });
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profile picture updated successfully!')));
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error updating profile picture: $e')));
        }
      } finally {
        if (mounted) setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _saveChanges() async {
    if (!_formKey.currentState!.validate()) return;
    
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() => _isSaving = true);

    try {
      if (user.email != _emailController.text.trim()) {
         await user.verifyBeforeUpdateEmail(_emailController.text.trim());
         if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Verification email sent to new address. Please verify to change email.')));
         }
      }

      await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
        'storeName': _storeNameController.text.trim(),
        'phone': _phoneController.text.trim(),
        if (_selectedLocation != null) 'lat': _selectedLocation!.latitude,
        if (_selectedLocation != null) 'lng': _selectedLocation!.longitude,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profile updated successfully!')));
        Navigator.pop(context, true); // Go back and indicate success
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error updating profile: $e')));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _resetPassword() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.email == null) return;

    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: user.email!);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Password reset email sent! Check your inbox.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Edit Store Profile')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Stack(
                  children: [
                    CircleAvatar(
                      radius: 60,
                      backgroundColor: Colors.grey[200],
                      backgroundImage: _profileImageUrl != null && _profileImageUrl!.isNotEmpty
                          ? (_profileImageUrl!.startsWith('data:image') 
                              ? MemoryImage(base64Decode(_profileImageUrl!.split(',').last)) 
                              : NetworkImage(_profileImageUrl!) as ImageProvider)
                          : null,
                      child: _profileImageUrl == null || _profileImageUrl!.isEmpty
                          ? const Icon(Icons.storefront, size: 60, color: Colors.grey)
                          : null,
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: GestureDetector(
                        onTap: _pickProfileImage,
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.primary,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.camera_alt, color: Colors.white, size: 20),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              
              TextFormField(
                controller: _storeNameController,
                decoration: InputDecoration(
                  labelText: 'Store Name',
                  prefixIcon: const Icon(Icons.badge_outlined),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                validator: (value) => value == null || value.isEmpty ? 'Please enter a store name' : null,
              ),
              const SizedBox(height: 16),
              
              TextFormField(
                controller: _phoneController,
                decoration: InputDecoration(
                  labelText: 'Phone Number',
                  prefixIcon: const Icon(Icons.phone_outlined),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                keyboardType: TextInputType.phone,
                validator: (value) => value == null || value.isEmpty ? 'Please enter your phone number' : null,
              ),
              const SizedBox(height: 16),
              
              TextFormField(
                controller: _emailController,
                decoration: InputDecoration(
                  labelText: 'Email Address',
                  prefixIcon: const Icon(Icons.email_outlined),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                keyboardType: TextInputType.emailAddress,
                validator: (value) {
                  if (value == null || value.isEmpty) return 'Please enter your email';
                  if (!value.contains('@')) return 'Please enter a valid email';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              
              // Map Picker Button
              OutlinedButton.icon(
                onPressed: () async {
                  final LatLng? picked = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => MapPickerScreen(initialLocation: _selectedLocation),
                    ),
                  );
                  if (picked != null) {
                    setState(() {
                      _selectedLocation = picked;
                    });
                  }
                },
                icon: const Icon(Icons.map_outlined),
                label: Text(_selectedLocation == null 
                   ? 'Pick Store Location on Map' 
                   : 'Location Set: ${_selectedLocation!.latitude.toStringAsFixed(4)}, ${_selectedLocation!.longitude.toStringAsFixed(4)}'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  side: BorderSide(color: _selectedLocation == null ? Colors.red : Colors.green),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Update your coordinates to make sure consumers can find your store exactly on the map.',
                style: TextStyle(color: Colors.grey, fontSize: 12),
              ),
              
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: _isSaving ? null : _saveChanges,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Theme.of(context).colorScheme.onPrimary,
                ),
                child: _isSaving 
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text('Save Changes', style: TextStyle(fontSize: 16)),
              ),
              
              const SizedBox(height: 24),
              const Divider(),
              const SizedBox(height: 24),
              
              OutlinedButton.icon(
                onPressed: _resetPassword,
                icon: const Icon(Icons.lock_reset),
                label: const Text('Send Password Reset Email'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _storeNameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    super.dispose();
  }
}
