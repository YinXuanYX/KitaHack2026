import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  
  final snap = await FirebaseFirestore.instance.collection('users').where('role', isEqualTo: 'vendor').get();
  for (var doc in snap.docs) {
    print('Vendor ${doc.id}: ${doc.data()}');
    
    final ratings = await FirebaseFirestore.instance.collection('ratings').where('vendorId', isEqualTo: doc.id).get();
    print('Ratings for ${doc.id}: ${ratings.docs.length}');
  }
}
