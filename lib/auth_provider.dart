import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // Import Firestore

class AuthProvider with ChangeNotifier {
  User? _user;
  Map<String, dynamic>? _userData;
  bool _isLoading = false;
  String? _error;

  AuthProvider() {
    FirebaseAuth.instance.authStateChanges().listen(_onAuthStateChanged);
  }

  User? get user => _user;
  Map<String, dynamic>? get userData => _userData;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> _onAuthStateChanged(User? user) async {
    _user = user;
    if (user != null) {
      _isLoading = true;
      _error = null;
      _userData = null; // Clear previous data
      notifyListeners(); // Notify UI about loading state

      try {
        final docSnap = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();
        if (docSnap.exists) {
          _userData = docSnap.data();
          _error = null;
        } else {
          _userData = null;
          _error = "User data not found in Firestore.";
        }
      } catch (e) {
        _userData = null;
        _error = "Error fetching user data: ${e.toString()}";
        print("Error fetching user data: $e"); // Log the error
      } finally {
        _isLoading = false;
        notifyListeners(); // Notify UI about fetched data/error
      }
    } else {
      // User logged out
      _userData = null;
      _isLoading = false;
      _error = null;
      notifyListeners(); // Notify UI about logged out state
    }
  }

  // Optional: Method to manually refresh user data if needed
  Future<void> refreshUserData() async {
    if (_user != null) {
      await _onAuthStateChanged(_user); // Re-run the fetch logic
    }
  }
}
