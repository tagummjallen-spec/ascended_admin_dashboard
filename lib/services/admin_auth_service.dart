import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AdminAuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Stream<User?> get authState => _auth.authStateChanges();

  Future<User?> signIn(String email, String password) async {
    final cred = await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    // Verify admin role
    final doc = await _firestore.collection('users').doc(cred.user!.uid).get();
    final data = doc.data();
    if (data == null || data['role'] != 'admin') {
      await _auth.signOut();
      throw Exception('Access denied. This dashboard is for administrators only.');
    }
    return cred.user;
  }

  Future<void> signOut() => _auth.signOut();
}

final adminAuthServiceProvider = Provider((ref) => AdminAuthService());
final adminAuthStateProvider = StreamProvider((ref) => ref.watch(adminAuthServiceProvider).authState);
