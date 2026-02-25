import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:convert';
import 'consumer_edit_profile_screen.dart';

class ConsumerProfileScreen extends StatefulWidget {
  const ConsumerProfileScreen({super.key});

  @override
  State<ConsumerProfileScreen> createState() => _ConsumerProfileScreenState();
}

class _ConsumerProfileScreenState extends State<ConsumerProfileScreen> {
  Map<String, dynamic>? _consumerData;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadConsumerData();
  }

  Future<void> _loadConsumerData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      if (doc.exists) {
        setState(() {
          _consumerData = doc.data() as Map<String, dynamic>;
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
      return const Center(child: CircularProgressIndicator());
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
       return const Center(child: Text('Not logged in.'));
    }

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('orders').where('consumerId', isEqualTo: user.uid).where('status', isEqualTo: 'claimed').snapshots(),
      builder: (context, ordersSnap) {
        int foodSaved = 0;
        if (ordersSnap.hasData) {
          foodSaved = ordersSnap.data!.docs.length; // Assuming 1kg per order
        }

        final profileImageUrl = _consumerData?['profileImageUrl'];
        final name = _consumerData?['name'] ?? 'User';
        final phone = _consumerData?['phone'] ?? 'No phone provided';

        return SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 20),
              Center(
                child: GestureDetector(
                  onTap: () {
                    if (profileImageUrl != null) {
                      _showProfileImage(context, profileImageUrl);
                    }
                  },
                  child: CircleAvatar(
                    radius: 50,
                    backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                    backgroundImage: profileImageUrl != null && profileImageUrl.isNotEmpty
                        ? (profileImageUrl.startsWith('data:image') 
                            ? MemoryImage(base64Decode(profileImageUrl.split(',').last)) 
                            : NetworkImage(profileImageUrl) as ImageProvider)
                        : null,
                    child: profileImageUrl == null || profileImageUrl.isEmpty
                        ? Icon(Icons.person, size: 50, color: Theme.of(context).colorScheme.primary)
                        : null,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                name,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                user.email ?? '', 
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Colors.grey),
              ),
              const SizedBox(height: 32),

              // Statistics
              Row(
                children: [
                  Expanded(child: _buildStatCard(context, 'Food Saved', '$foodSaved kg', Icons.eco, Colors.green)),
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
                      builder: (context) => ConsumerEditProfileScreen(initialData: _consumerData ?? {}),
                    ),
                  );
                  
                  if (result == true) {
                    setState(() => _isLoading = true);
                    _loadConsumerData();
                  }
                },
                icon: const Icon(Icons.edit),
                label: const Text('Edit Profile', style: TextStyle(fontSize: 16)),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 80), // Padding for bottom navbar
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatCard(BuildContext context, String title, String value, IconData icon, Color color) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
             Icon(icon, size: 32, color: color),
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
