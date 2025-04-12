import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
// Hide AuthProvider from firebase_auth to avoid conflict
import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import 'package:provider/provider.dart'; // Import Provider
import 'auth_provider.dart'; // Import AuthProvider

class RewardsScreen extends StatelessWidget {
  const RewardsScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Get user data from AuthProvider
    final authProvider = context.watch<AuthProvider>();
    final userData = authProvider.userData;
    final userPoints =
        userData?['pointsBalance'] ?? 0; // Get points from provider
    // final userTier = userData?['currentTier'] ?? 'Bronze'; // Get tier if needed directly in build

    return Scaffold(
      appBar: AppBar(
        title: const Text('Available Rewards'),
        // Consider adding points display to AppBar
        // actions: [
        //   Padding(
        //     padding: const EdgeInsets.only(right: 16.0),
        //     child: Center(child: Text('Points: $userPoints', style: TextStyle(fontSize: 16))),
        //   )
        // ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('rewards')
            .where('isActive', isEqualTo: true)
            .orderBy('pointsCost') // Optional: Order by cost
            .snapshots(),
        builder: (context, snapshot) {
          // ... existing error/loading handling ...
          if (snapshot.hasError) {
            return const Center(child: Text('Error fetching rewards'));
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final rewardsDocs = snapshot.data?.docs ?? [];
          if (rewardsDocs.isEmpty) {
            return const Center(child: Text('No active rewards found'));
          }

          return ListView.builder(
            itemCount: rewardsDocs.length,
            itemBuilder: (context, index) {
              final doc = rewardsDocs[index];
              final data = doc.data() as Map<String, dynamic>; // Cast data
              final name = data['name'] ?? '';
              final description = data['description'] ?? '';
              final pointsCost = data['pointsCost'] ?? 0;
              final tierRequired = data['tierRequired'] ?? 'Bronze';
              final canAfford = userPoints >= pointsCost;
              // Add tier check if needed for enabling button
              // final canAccessTier = _tierIsEligible(userTier, tierRequired);
              // final canRedeem = canAfford && canAccessTier;

              return Card(
                margin: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: ListTile(
                  title: Text(name),
                  subtitle: Text(description),
                  trailing: Text('Cost: $pointsCost pts'),
                  onTap: canAfford // Use canRedeem if tier check is added
                      ? () {
                          _confirmRedeem(
                            context,
                            doc.id,
                            name,
                            pointsCost,
                            tierRequired,
                            data['availableQuantity'], // Pass quantity
                            authProvider, // Pass provider for checks inside
                          );
                        }
                      : null,
                  enabled: canAfford, // Use canRedeem if tier check is added
                  tileColor:
                      canAfford ? null : Colors.grey.shade300, // Visual hint
                ),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _confirmRedeem(
    BuildContext context,
    String rewardId,
    String rewardName,
    int pointsCost,
    String tierRequired,
    int? availableQuantity,
    AuthProvider authProvider, // Receive provider
  ) async {
    // Perform checks using provider data before showing dialog
    final userData = authProvider.userData;
    final userPoints = userData?['pointsBalance'] ?? 0;
    final userTier = userData?['currentTier'] ?? 'Bronze';

    if (userPoints < pointsCost) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Not enough points')),
      );
      return;
    }
    if (!_tierIsEligible(userTier, tierRequired)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Reward requires $tierRequired tier or higher')),
      );
      return;
    }
    if (availableQuantity != null && availableQuantity <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Reward is out of stock')),
      );
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Confirm Redemption'),
        content: Text('Redeem "$rewardName" for $pointsCost points?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Redeem'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      // Pass provider to redeem function
      await _redeemReward(context, rewardId, rewardName, pointsCost,
          tierRequired, availableQuantity, authProvider);
    }
  }

  Future<void> _redeemReward(
    BuildContext context,
    String rewardId,
    String rewardName,
    int pointsCost,
    String tierRequired,
    int? availableQuantity,
    AuthProvider authProvider, // Receive provider
  ) async {
    // User object is already available in provider
    final user = authProvider.user;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('User not signed in')),
      );
      return;
    }
    final userId = user.uid;
    final redemptionId =
        FirebaseFirestore.instance.collection('redemptions').doc().id;
    final now = Timestamp.now();
    // Consider a more robust validation code generation method
    final validationCode =
        '${DateTime.now().millisecondsSinceEpoch % 1000000}'.padLeft(6, '0');

    try {
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final userRef =
            FirebaseFirestore.instance.collection('users').doc(userId);
        final rewardRef =
            FirebaseFirestore.instance.collection('rewards').doc(rewardId);
        final redemptionRef = FirebaseFirestore.instance
            .collection('redemptions')
            .doc(redemptionId);
        final pointHistoryRef = userRef.collection('pointHistory').doc();

        // Re-fetch user and reward inside transaction for consistency
        final userSnap = await transaction.get(userRef);
        final rewardSnap = await transaction.get(rewardRef);

        // --- Checks inside transaction ---
        if (!userSnap.exists) throw Exception('User document not found');
        if (!rewardSnap.exists || !(rewardSnap.data()?['isActive'] == true)) {
          throw Exception('Reward not available');
        }

        final userData = userSnap.data()!;
        final rewardData = rewardSnap.data()!;
        final currentPoints = userData['pointsBalance'] ?? 0;
        final currentTier = userData['currentTier'] ?? 'Bronze';
        final rewardTierReq = rewardData['tierRequired'] ?? 'Bronze';
        final qty = (rewardData['availableQuantity']) as int?; // Nullable int

        if (currentPoints < pointsCost) throw Exception('Not enough points');
        if (!_tierIsEligible(currentTier, rewardTierReq)) {
          throw Exception(
              'Ineligible tier ($currentTier vs $rewardTierReq required)');
        }
        if (qty != null && qty <= 0) throw Exception('Reward out of stock');
        // --- End Checks ---

        // --- Updates inside transaction ---
        transaction
            .update(userRef, {'pointsBalance': currentPoints - pointsCost});

        if (qty != null) {
          // Only update quantity if it exists
          transaction.update(rewardRef, {'availableQuantity': qty - 1});
        }

        transaction.set(redemptionRef, {
          'userId': userId,
          'rewardId': rewardId,
          'rewardName': rewardName,
          'pointsCost': pointsCost,
          'timestamp': now,
          'status': 'completed', // Or 'pending_validation' if needed
          'validationCode': validationCode,
          'userEmail': userData['email'], // Store email for easier lookup
          'userDisplayName': userData['displayName'], // Store name
        });

        transaction.set(pointHistoryRef, {
          'timestamp': now,
          'pointsChange': -pointsCost,
          'description': 'Redemption: $rewardName',
          'type': 'redemption', // Add type for filtering
          'rewardId': rewardId,
        });
        // --- End Updates ---
      });

      // On success, trigger refresh in AuthProvider
      await authProvider.refreshUserData();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Redemption complete! Your code: $validationCode')),
      );
      // Optionally navigate or show code prominently
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Redemption failed: ${e.toString()}')),
      );
      // Refresh user data even on failure to ensure UI consistency
      await authProvider.refreshUserData();
    }
  }

  // Keep tier eligibility logic (can be moved to a utility class later)
  bool _tierIsEligible(String userTier, String rewardTier) {
    // Define tier hierarchy
    const tierHierarchy = {
      'Bronze': 1,
      'Silver': 2,
      'Gold': 3,
      'Platinum': 4,
    };
    final userLevel = tierHierarchy[userTier] ?? 0;
    final requiredLevel = tierHierarchy[rewardTier] ?? 0;
    return userLevel >= requiredLevel;
  }

  // Remove local _updateTierAndBadges, _determineTier, _checkAndAwardBadges
  // These updates should happen centrally or be triggered by AuthProvider/Service
  // Future<void> _updateTierAndBadges(String userId) async { ... }
  // String _determineTier(int points) { ... }
  // Future<void> _checkAndAwardBadges(...) async { ... }
}
