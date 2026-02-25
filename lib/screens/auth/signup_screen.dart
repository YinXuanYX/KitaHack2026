import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../services/auth_service.dart';
import '../components/map_picker_screen.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _storeNameController = TextEditingController();
  final _authService = AuthService();
  
  LatLng? _selectedLocation;
  
  bool _isLoading = false;
  String _selectedRole = 'consumer'; // 'consumer' or 'vendor'

  Future<void> _signUp() async {
    if (_nameController.text.isEmpty || 
        _emailController.text.isEmpty || 
        _passwordController.text.isEmpty || 
        _phoneController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please fill all required fields')));
      return;
    }

    if (_selectedRole == 'vendor') {
      if (_storeNameController.text.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Vendors must provide a store name')));
        return;
      }
      if (_selectedLocation == null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Vendors must pick a store location on the map')));
        return;
      }
    }

    setState(() => _isLoading = true);
    try {
      await _authService.signUpWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
        name: _nameController.text.trim(),
        phone: _phoneController.text.trim(),
        role: _selectedRole,
        storeName: _selectedRole == 'vendor' ? _storeNameController.text.trim() : null,
        lat: _selectedRole == 'vendor' && _selectedLocation != null ? _selectedLocation!.latitude : null,
        lng: _selectedRole == 'vendor' && _selectedLocation != null ? _selectedLocation!.longitude : null,
      );
      if (mounted) {
        Navigator.pop(context); // Go back to login after success
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Signup failed: ${e.toString()}')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create Account')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: RadioMenuButton<String>(
                      value: 'consumer',
                      groupValue: _selectedRole,
                      onChanged: (val) => setState(() => _selectedRole = val!),
                      child: const Text('Consumer'),
                    ),
                  ),
                  Expanded(
                    child: RadioMenuButton<String>(
                      value: 'vendor',
                      groupValue: _selectedRole,
                      onChanged: (val) => setState(() => _selectedRole = val!),
                      child: const Text('Vendor'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              TextField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: 'Full Name',
                  prefixIcon: const Icon(Icons.person_outline),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _phoneController,
                decoration: InputDecoration(
                  labelText: 'Phone Number',
                  prefixIcon: const Icon(Icons.phone_outlined),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 16),
              if (_selectedRole == 'vendor') ...[
                TextField(
                  controller: _storeNameController,
                  decoration: InputDecoration(
                    labelText: 'Store Name',
                    prefixIcon: const Icon(Icons.storefront_outlined),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
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
                    side: BorderSide(color: _selectedLocation == null ? Colors.grey : Colors.green),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 16),
              ],
              TextField(
                controller: _emailController,
                decoration: InputDecoration(
                  labelText: 'Email',
                  prefixIcon: const Icon(Icons.email_outlined),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _passwordController,
                decoration: InputDecoration(
                  labelText: 'Password',
                  prefixIcon: const Icon(Icons.lock_outline),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                obscureText: true,
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: _isLoading ? null : _signUp,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Theme.of(context).colorScheme.onPrimary,
                ),
                child: _isLoading 
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text('Sign Up', style: TextStyle(fontSize: 16)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    _phoneController.dispose();
    _storeNameController.dispose();
    super.dispose();
  }
}
