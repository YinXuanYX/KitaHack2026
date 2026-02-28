import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class AuthService extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  User? get currentUser => _auth.currentUser;

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  Future<UserCredential?> signUpWithEmailAndPassword({
    required String email,
    required String password,
    required String name,
    required String phone,
    required String role, 
    // optional fields for vendors
    String? storeName,
    double? lat,
    double? lng,
  }) async {
    try {
      UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Create the user document in Firestore based on role
      Map<String, dynamic> userData = {
        'uid': userCredential.user!.uid,
        'email': email,
        'name': name,
        'phone': phone,
        'role': role,
        'createdAt': FieldValue.serverTimestamp(),
      };

      if (role == 'vendor') {
        userData['storeName'] = storeName ?? name;
        if (lat != null && lng != null) {
          userData['lat'] = lat;
          userData['lng'] = lng;
        }
        userData['paymentQrUrl'] = ''; 
      }

      await _firestore.collection('users').doc(userCredential.user!.uid).set(userData);

      return userCredential;
    } on FirebaseAuthException catch (e) {
      if (kDebugMode) {
        print('Error signing up: ${e.code} - ${e.message}');
      }
      rethrow;
    }
  }

  Future<UserCredential?> signInWithEmailAndPassword(String email, String password) async {
    try {
      UserCredential userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      return userCredential;
    } on FirebaseAuthException catch (e) {
      if (kDebugMode) {
        print('Error signing in: ${e.code} - ${e.message}');
      }
      rethrow;
    }
  }

  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } on FirebaseAuthException catch (e) {
      if (kDebugMode) {
        print('Error sending reset password email: ${e.code} - ${e.message}');
      }
      rethrow;
    }
  }

  Future<void> signOut() async {
    await _auth.signOut();
  }
}
