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
          // Check and potentially update tier after fetching from Firestore
          _checkAndUpdateTierLocally(); // Add this check
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

  // Method to determine tier based on points
  String _determineTier(int points) {
    // Use lifetimePoints for tier calculation
    if (points >= 10000) return 'Platinum';
    if (points >= 5000) return 'Gold';
    if (points >= 1000) return 'Silver';
    return 'Bronze';
  }

  // Helper method to check and update tier in local _userData
  void _checkAndUpdateTierLocally() {
    if (_userData == null) return;

    final int lifetimePoints = _userData!['lifetimePoints'] ?? 0;
    final String currentTier = _userData!['currentTier'] ?? 'Bronze';
    final String newTier = _determineTier(lifetimePoints);

    if (newTier != currentTier) {
      print("Tier updated locally: $currentTier -> $newTier");
      _userData!['currentTier'] = newTier;
      // Note: This local change won't be saved to Firestore automatically here.
      // It will be reflected in the UI until the next refresh from Firestore
      // unless the calling function also updates Firestore.
    }
  }

  // Method to update user data locally (for demo purposes)
  void updateLocalUserData(Map<String, dynamic> newData) {
    _userData = newData;
    // Check and update tier after local data update
    _checkAndUpdateTierLocally();
    notifyListeners(); // Notify listeners that data has changed
    print("AuthProvider updated with local data: $_userData");
  }

  // Optional: Method to manually refresh user data if needed
  Future<void> refreshUserData() async {
    if (_user != null) {
      await _onAuthStateChanged(
          _user); // Re-run the fetch logic (which now includes tier check)
    }
  }
}
