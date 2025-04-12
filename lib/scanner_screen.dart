import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ScannerScreen extends StatefulWidget {
  const ScannerScreen({Key? key}) : super(key: key);

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen> {
  bool _isProcessing = false;

  Future<void> _validateAndUpdateQRCode(String qrCodeId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception('No authenticated user found');
    }
    final userId = user.uid;

    await FirebaseFirestore.instance.runTransaction((transaction) async {
      final qrCodeRef =
          FirebaseFirestore.instance.collection('qrCodes').doc(qrCodeId);
      final userRef =
          FirebaseFirestore.instance.collection('users').doc(userId);
      final pointHistoryRef = userRef.collection('pointHistory').doc();

      final qrCodeSnap = await transaction.get(qrCodeRef);
      final userSnap = await transaction.get(userRef);

      if (!qrCodeSnap.exists || !(qrCodeSnap.data()?['isActive'] == true)) {
        throw Exception('Invalid or inactive QR code');
      }
      if (!userSnap.exists) {
        throw Exception('User document not found');
      }

      final qrData = qrCodeSnap.data()!;
      final userData = userSnap.data()!;
      final type = qrData['type'];
      final int pointsValue = qrData['pointsValue'] ?? 0;

      int pointsBalance = userData['pointsBalance'] ?? 0;
      final now = Timestamp.now();

      if (type == 'room') {
        final lastScan = userData['lastRoomScanTimestamp'] as Timestamp?;
        final canScan = lastScan == null ||
            DateTime.now().difference(lastScan.toDate()).inHours >= 24;
        if (!canScan) {
          throw Exception('Already scanned today');
        }
        pointsBalance += pointsValue;
        transaction.update(userRef, {
          'pointsBalance': pointsBalance,
          'lastRoomScanTimestamp': now,
        });
      } else if (type == 'easterEgg') {
        final scannedList =
            List<String>.from(userData['scannedEasterEggIds'] ?? []);
        if (scannedList.contains(qrCodeId)) {
          throw Exception('Already scanned this Easter Egg');
        }
        pointsBalance += pointsValue;
        transaction.update(userRef, {
          'pointsBalance': pointsBalance,
          'scannedEasterEggIds': FieldValue.arrayUnion([qrCodeId]),
        });
      } else if (type == 'receipt') {
        pointsBalance += pointsValue;
        transaction.update(userRef, {
          'pointsBalance': pointsBalance,
          // Optionally handle single-use logic
        });
      } else {
        throw Exception('Unrecognized QR code type');
      }

      transaction.set(pointHistoryRef, {
        'timestamp': now,
        'pointsChange': pointsValue,
        'description': 'Scanned $type: $qrCodeId',
      });
    });

    // After the transaction completes, update tier and check badges
    await _updateTierAndBadges(userId);
  }

  // Example method to update tier and check badges
  Future<void> _updateTierAndBadges(String userId) async {
    final userRef = FirebaseFirestore.instance.collection('users').doc(userId);
    final userSnap = await userRef.get();
    if (!userSnap.exists) return;

    final userData = userSnap.data()!;
    int pointsBalance = userData['pointsBalance'] ?? 0;

    // 1) Update Tiers
    final newTier = _determineTier(pointsBalance);
    final currentTier = userData['currentTier'] ?? 'Bronze';
    if (newTier != currentTier) {
      await userRef.update({'currentTier': newTier});
      // Optionally notify user of tier change
    }

    // 2) Check Badge criteria
    await _checkAndAwardBadges(userRef, userData);
  }

  String _determineTier(int points) {
    // Example thresholds, adapt as needed
    if (points >= 10000) return 'Platinum';
    if (points >= 5000) return 'Gold';
    if (points >= 1000) return 'Silver';
    return 'Bronze';
  }

  Future<void> _checkAndAwardBadges(
      DocumentReference userRef, Map<String, dynamic> userData) async {
    // Example logic: check how many Easter Eggs scanned
    final scannedEasterEggIds =
        List<String>.from(userData['scannedEasterEggIds'] ?? []);
    final earnedBadgesRef = userRef.collection('earnedBadges');

    if (scannedEasterEggIds.length >= 5) {
      // Check if badge already awarded
      final existingBadge = await earnedBadgesRef.doc('eggHunter').get();
      if (!existingBadge.exists) {
        await earnedBadgesRef.doc('eggHunter').set({
          'name': 'Egg Hunter',
          'description': 'Scanned 5 Easter Eggs!',
          'timestampEarned': Timestamp.now(),
        });
        // Optionally notify user of new badge
      }
    }

    // Add more badge checks here...
  }

  void processScan(String qrCodeId) {
    debugPrint("Prepared payload for processScan: {qrCodeId: $qrCodeId}");
    _validateAndUpdateQRCode(qrCodeId).then((_) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Points updated successfully!')),
      );
    }).catchError((error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString())),
      );
    });
  }

  void _onDetect(BarcodeCapture capture) {
    if (_isProcessing) return;
    final List<Barcode> barcodes = capture.barcodes;
    if (barcodes.isNotEmpty) {
      final String? rawValue = barcodes.first.rawValue;
      if (rawValue != null) {
        setState(() {
          _isProcessing = true;
        });
        // Provide immediate feedback
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Scanned QR Code ID: $rawValue')),
        );
        // Trigger backend process (stubbed)
        processScan(rawValue);
        // Prevent rapid re-scanning using a cooldown period
        Future.delayed(const Duration(seconds: 3), () {
          setState(() {
            _isProcessing = false;
          });
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('QR Scanner'),
      ),
      body: MobileScanner(
        onDetect: _onDetect,
      ),
    );
  }
}
