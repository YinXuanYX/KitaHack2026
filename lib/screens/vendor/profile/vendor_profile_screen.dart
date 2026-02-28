import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'dart:convert';
import 'vendor_edit_profile_screen.dart';
import '../../../services/rating_service.dart';
import '../../../services/theme_provider.dart';

class VendorProfileScreen extends StatefulWidget {
  const VendorProfileScreen({super.key});

  @override
  State<VendorProfileScreen> createState() => _VendorProfileScreenState();
}

class _VendorProfileScreenState extends State<VendorProfileScreen> {
  Map<String, dynamic>? _vendorData;
  bool _isLoading = true;
  final RatingService _ratingService = RatingService();
  double _averageRating = 0.0;
  int _ratingCount = 0;

  @override
  void initState() {
    super.initState();
    _loadVendorData();
    _loadRatingData();
  }

  Future<void> _loadRatingData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      final result = await _ratingService.getVendorAverageRating(user.uid);
      if (mounted) {
        setState(() {
          _averageRating = result['average'] as double;
          _ratingCount = result['count'] as int;
        });
      }
    } catch (_) {}
  }

  Future<void> _loadVendorData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      if (doc.exists) {
        setState(() {
          _vendorData = doc.data() as Map<String, dynamic>;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error loading profile: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showProfileImage(BuildContext context, String imageUrl) {
    if (imageUrl.isEmpty) return;
    
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
             ClipOval(
               child: imageUrl.startsWith('data:image')
                  ? Image.memory(base64Decode(imageUrl.split(',').last), width: 300, height: 300, fit: BoxFit.cover)
                  : Image.network(imageUrl, width: 300, height: 300, fit: BoxFit.cover),
             ),
             const SizedBox(height: 16),
             TextButton(
               onPressed: () => Navigator.pop(context),
               child: const Text('Close', style: TextStyle(color: Colors.white, fontSize: 18)),
             ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final user = FirebaseAuth.instance.currentUser;
    final themeProvider = context.watch<ThemeProvider>();

    final storeName = _vendorData?['storeName'] ?? 'Store Name';
    final profileImageUrl = _vendorData?['profileImageUrl'];
    final phone = _vendorData?['phone'] ?? 'No phone provided';

    return Scaffold(
      appBar: AppBar(title: const Text('Store Profile')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: GestureDetector(
                onTap: () {
                  if (profileImageUrl != null) {
                    _showProfileImage(context, profileImageUrl);
                  }
                },
                child: CircleAvatar(
                  radius: 60,
                  backgroundColor: Colors.grey[200],
                  backgroundImage: profileImageUrl != null && profileImageUrl.isNotEmpty
                      ? (profileImageUrl.startsWith('data:image') 
                          ? MemoryImage(base64Decode(profileImageUrl.split(',').last)) 
                          : NetworkImage(profileImageUrl) as ImageProvider)
                      : null,
                  child: profileImageUrl == null || profileImageUrl.isEmpty
                      ? const Icon(Icons.storefront, size: 60, color: Colors.grey)
                      : null,
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              storeName,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              user?.email ?? '',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey, fontSize: 16),
            ),
            const SizedBox(height: 12),
            // Average Rating Display
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ...List.generate(5, (index) {
                  return Icon(
                    index < _averageRating.round()
                        ? Icons.star_rounded
                        : Icons.star_border_rounded,
                    color: index < _averageRating.round()
                        ? Colors.amber
                        : Colors.grey[300],
                    size: 24,
                  );
                }),
                const SizedBox(width: 8),
                Text(
                  _ratingCount > 0
                      ? '${_averageRating.toStringAsFixed(1)} ($_ratingCount reviews)'
                      : 'No reviews yet',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),
            
            Card(
              elevation: 0,
              color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.phone_outlined),
                      title: const Text('Phone Number'),
                      subtitle: Text(phone),
                    ),
                    const Divider(),
                    ListTile(
                      leading: const Icon(Icons.map_outlined),
                      title: const Text('Location'),
                      subtitle: Text(_vendorData?['lat'] != null ? 'Coordinates Set' : 'No location set'),
                    ),
                    const Divider(),
                    SwitchListTile(
                      secondary: const Icon(Icons.dark_mode_outlined),
                      title: const Text('Dark Mode'),
                      value: themeProvider.isDarkMode,
                      onChanged: (value) {
                        themeProvider.toggleTheme(value);
                      },
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => VendorEditProfileScreen(initialData: _vendorData ?? {}),
                  ),
                );
                
                // Refresh if changes were made
                if (result == true) {
                  setState(() => _isLoading = true);
                  _loadVendorData();
                }
              },
              icon: const Icon(Icons.edit),
              label: const Text('Edit Profile', style: TextStyle(fontSize: 16)),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
