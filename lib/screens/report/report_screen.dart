import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ReportScreen extends StatefulWidget {
  final String? reportedUserId;
  final String? reportedUserName;

  const ReportScreen({
    super.key,
    this.reportedUserId,
    this.reportedUserName,
  });

  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  final _formKey = GlobalKey<FormState>();
  final _descriptionController = TextEditingController();
  bool _isSubmitting = false;

  late String _selectedType;
  late List<String> _reportTypes;

  @override
  void initState() {
    super.initState();
    if (widget.reportedUserId != null) {
      _reportTypes = ['Scam', 'Harassment', 'Missing In Action', 'Other'];
      _selectedType = 'Scam';
    } else {
      _reportTypes = ['Bug', 'Suggestion', 'Other'];
      _selectedType = 'Bug';
    }
  }

  Future<void> _submitReport() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSubmitting = true;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('User not logged in');

      await FirebaseFirestore.instance.collection('reports').add({
        'reporterId': user.uid,
        'type': _selectedType,
        'description': _descriptionController.text.trim(),
        'reportedUserId': widget.reportedUserId,
        'reportedUserName': widget.reportedUserName,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Report submitted successfully. Thank you.'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to submit: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.reportedUserId != null ? 'Report Seller' : 'Feedback & Support'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (widget.reportedUserId != null) ...[
                Card(
                  color: Theme.of(context).colorScheme.errorContainer,
                  elevation: 0,
                  margin: const EdgeInsets.only(bottom: 24),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      children: [
                        Icon(Icons.warning_amber_rounded, color: Theme.of(context).colorScheme.error),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'You are reporting \${widget.reportedUserName ?? "this seller"}. Our trust and safety team will review this.',
                            style: TextStyle(color: Theme.of(context).colorScheme.onErrorContainer),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],

              const Text(
                'Reason for report',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: _selectedType,
                decoration: InputDecoration(
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                ),
                items: _reportTypes.map((type) {
                  return DropdownMenuItem(
                    value: type,
                    child: Text(type),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      _selectedType = value;
                    });
                  }
                },
              ),
              const SizedBox(height: 24),

              const Text(
                'Description',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _descriptionController,
                maxLines: 6,
                decoration: InputDecoration(
                  hintText: 'Please provide more details...',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  alignLabelWithHint: true,
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter a description';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 32),

              ElevatedButton(
                onPressed: _isSubmitting ? null : _submitReport,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  backgroundColor: widget.reportedUserId != null ? Colors.red.shade600 : Theme.of(context).colorScheme.primary,
                  foregroundColor: Colors.white,
                ),
                child: _isSubmitting
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Submit Report', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }
}
