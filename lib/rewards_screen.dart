import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class RewardsScreen extends StatelessWidget {
  const RewardsScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Replace with actual points from your state provider
    final int userPoints = 1500; // Example placeholder

    return Scaffold(
      appBar: AppBar(
        title: const Text('Available Rewards'),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('rewards')
            .where('isActive', isEqualTo: true)
            .snapshots(),
        builder: (context, snapshot) {
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
              final name = doc['name'] ?? '';
              final description = doc['description'] ?? '';
              final pointsCost = doc['pointsCost'] ?? 0;
              final tierRequired = doc['tierRequired'] ?? 'Bronze';
              final canAfford = userPoints >= pointsCost;

              return Card(
                child: ListTile(
                  title: Text(name),
                  subtitle: Text(description),
                  trailing: Text('Cost: $pointsCost'),
                  onTap: canAfford
                      ? () {
                          _confirmRedeem(
                            context,
                            doc.id,
                            name,
                            pointsCost,
                            tierRequired,
                            doc['availableQuantity'],
                          );
                        }
                      : null,
                  // Give a visual hint if user cannot redeem
                  enabled: canAfford,
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
  ) async {
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
      await _redeemReward(context, rewardId, rewardName, pointsCost,
          tierRequired, availableQuantity);
    }
  }

  Future<void> _redeemReward(
    BuildContext context,
    String rewardId,
    String rewardName,
    int pointsCost,
    String tierRequired,
    int? availableQuantity,
  ) async {
    final user = FirebaseAuth.instance.currentUser;
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
    final validationCode =
        DateTime.now().millisecondsSinceEpoch.toString(); // Simple example

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

        final userSnap = await transaction.get(userRef);
        final rewardSnap = await transaction.get(rewardRef);

        if (!userSnap.exists) {
          throw Exception('User document not found');
        }
        if (!rewardSnap.exists || !(rewardSnap.data()?['isActive'] == true)) {
          throw Exception('Reward not available');
        }

        final userData = userSnap.data()!;
        final rewardData = rewardSnap.data()!;
        final currentPoints = userData['pointsBalance'] ?? 0;
        final currentTier = userData['currentTier'] ?? 'Bronze';
        final rewardTier = rewardData['tierRequired'] ?? 'Bronze';
        final qty = (rewardData['availableQuantity'] ?? 999999) as int;

        // Check points and tier
        if (currentPoints < pointsCost) {
          throw Exception('Not enough points');
        }
        // Tier check (a simple example, actual logic may differ)
        // For instance, you might compare numeric tier levels. Here, we do a simple string check.
        if (!_tierIsEligible(currentTier, rewardTier)) {
          throw Exception('Ineligible tier');
        }
        if (qty <= 0) {
          throw Exception('Reward out of stock');
        }

        // Deduct points from user
        transaction.update(userRef, {
          'pointsBalance': currentPoints - pointsCost,
        });

        // Update reward quantity if needed
        if (rewardData.containsKey('availableQuantity')) {
          transaction.update(rewardRef, {
            'availableQuantity': qty - 1,
          });
        }

        // Create redemption doc
        transaction.set(redemptionRef, {
          'userId': userId,
          'rewardId': rewardId,
          'rewardName': rewardName,
          'pointsCost': pointsCost,
          'timestamp': now,
          'status': 'completed',
          'validationCode': validationCode,
        });

        // Add a "Redemption" entry to pointHistory
        transaction.set(pointHistoryRef, {
          'timestamp': now,
          'pointsChange': -pointsCost,
          'description': 'Redemption: $rewardName',
        });
      });

      // On success, also update tier and check badges
      await _updateTierAndBadges(userId);

      // On success
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Redemption complete! Your code: $validationCode')),
      );
      // Optionally navigate to a screen displaying the code
    } catch (e) {
      // Handle failure
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    }
  }

  // Example method to update tier and check badges
  Future<void> _updateTierAndBadges(String userId) async {
    final userRef = FirebaseFirestore.instance.collection('users').doc(userId);
    final userSnap = await userRef.get();
    if (!userSnap.exists) return;

    final userData = userSnap.data()!;
    final pointsBalance = userData['pointsBalance'] ?? 0;

    final newTier = _determineTier(pointsBalance);
    final currentTier = userData['currentTier'] ?? 'Bronze';
    if (newTier != currentTier) {
      await userRef.update({'currentTier': newTier});
      // Optionally notify user of tier change
    }

    await _checkAndAwardBadges(userRef, userData);
  }

  String _determineTier(int points) {
    // Same thresholds as in scanner_screen.dart
    if (points >= 10000) return 'Platinum';
    if (points >= 5000) return 'Gold';
    if (points >= 1000) return 'Silver';
    return 'Bronze';
  }

  Future<void> _checkAndAwardBadges(
      DocumentReference userRef, Map<String, dynamic> userData) async {
    // Example Easter Egg logic, adapt for your badges
    final scannedEasterEggIds =
        List<String>.from(userData['scannedEasterEggIds'] ?? []);
    final earnedBadgesRef = userRef.collection('earnedBadges');

    if (scannedEasterEggIds.length >= 5) {
      final existingBadge = await earnedBadgesRef.doc('eggHunter').get();
      if (!existingBadge.exists) {
        await earnedBadgesRef.doc('eggHunter').set({
          'name': 'Egg Hunter',
          'description': 'Scanned 5 Easter Eggs!',
          'timestampEarned': Timestamp.now(),
        });
      }
    }
    // Additional badge checks...
  }

  // Example tier comparison logic
  bool _tierIsEligible(String userTier, String rewardTier) {
    // Replace with actual logic to rank tiers. For now, we just say if userTier == rewardTier, pass.
    return userTier == rewardTier;
  }
}
