import 'dart:convert'; // Import dart:convert for jsonDecode
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
// Hide AuthProvider from firebase_auth to avoid conflict
import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import 'package:permission_handler/permission_handler.dart'; // Import permission_handler
import 'package:provider/provider.dart'; // Import Provider
import 'auth_provider.dart'; // Import local AuthProvider

class ScannerScreen extends StatefulWidget {
  const ScannerScreen({Key? key}) : super(key: key);

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen> {
  bool _isProcessing = false;
  bool _flashEnabled = false;
  bool _cameraFacingFront = false;
  String? _lastScanResult;
  PermissionStatus _cameraPermissionStatus =
      PermissionStatus.denied; // Track permission status
  final MobileScannerController _scannerController =
      MobileScannerController(); // Create controller instance

  @override
  void initState() {
    super.initState();
    _requestCameraPermission();
  }

  // Request camera permission
  Future<void> _requestCameraPermission() async {
    final status = await Permission.camera.request();
    setState(() {
      _cameraPermissionStatus = status;
    });
  }

  // Dispose controller
  @override
  void dispose() {
    _scannerController.dispose();
    super.dispose();
  }

  Future<void> _validateAndUpdateQRCode(Map<String, dynamic> qrDataMap) async {
    // Accept Map
    // Access AuthProvider for user ID and refreshing data
    final authProvider = context.read<AuthProvider>();
    final user = authProvider.user;

    if (user == null) {
      throw Exception('No authenticated user found');
    }
    final userId = user.uid;

    // Extract data from the map
    final String? qrCodeId = qrDataMap['id'] as String?;
    final String? type = qrDataMap['type'] as String?;
    final int pointsValue =
        (qrDataMap['points'] as num?)?.toInt() ?? 0; // Handle num type

    if (qrCodeId == null || type == null) {
      throw Exception('Invalid QR code data: Missing id or type');
    }

    await FirebaseFirestore.instance.runTransaction((transaction) async {
      // Use qrCodeId from the map to reference the document
      final qrCodeRef =
          FirebaseFirestore.instance.collection('qrCodes').doc(qrCodeId);
      final userRef =
          FirebaseFirestore.instance.collection('users').doc(userId);
      final pointHistoryRef = userRef.collection('pointHistory').doc();

      final qrCodeSnap =
          await transaction.get(qrCodeRef); // Validate against Firestore doc
      final userSnap = await transaction.get(userRef);

      // Validate using Firestore document data
      if (!qrCodeSnap.exists || !(qrCodeSnap.data()?['isActive'] == true)) {
        throw Exception('Invalid or inactive QR code (Firestore)');
      }
      if (!userSnap.exists) {
        throw Exception('User document not found');
      }

      // Use Firestore data for validation checks where appropriate (e.g., isUsed)
      final firestoreQrData = qrCodeSnap.data()!;
      final userData = userSnap.data()!;
      final int lifetimePoints = userData['lifetimePoints'] ?? 0;
      int pointsBalance = userData['pointsBalance'] ?? 0;
      final now = Timestamp.now();

      // --- Update logic based on type (using type from qrDataMap) ---
      if (type == 'room') {
        final lastScan = userData['lastRoomScanTimestamp'] as Timestamp?;
        final canScan = lastScan == null ||
            DateTime.now().difference(lastScan.toDate()).inHours >= 24;
        if (!canScan) {
          throw Exception('Room QR already scanned within the last 24 hours');
        }
        pointsBalance += pointsValue;
        transaction.update(userRef, {
          'pointsBalance': pointsBalance,
          'lastRoomScanTimestamp': now,
          'lifetimePoints': lifetimePoints + pointsValue,
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
          'lifetimePoints': lifetimePoints + pointsValue,
        });
      } else if (type == 'service') {
        // Changed from 'receipt' to 'service'
        // Check Firestore document for 'isUsed' status
        if (firestoreQrData['isUsed'] == true) {
          throw Exception('Service QR code already used');
        }
        pointsBalance += pointsValue;
        transaction.update(userRef, {
          'pointsBalance': pointsBalance,
          'lifetimePoints': lifetimePoints + pointsValue,
        });
        // Mark the service QR code as used in Firestore
        transaction.update(qrCodeRef,
            {'isUsed': true, 'usedBy': userId, 'usedTimestamp': now});
      } else {
        throw Exception('Unrecognized QR code type: $type');
      }
      // --- End update logic ---

      // --- Add point history ---
      // Use data from qrDataMap for a richer description
      String description = 'Scanned $type: ${qrDataMap['name'] ?? qrCodeId}';
      if (type == 'room') {
        description = 'Scanned Room: ${qrDataMap['roomNumber'] ?? qrCodeId}';
      } else if (type == 'easterEgg') {
        description =
            'Scanned Easter Egg: ${qrDataMap['location'] ?? qrCodeId}';
      } else if (type == 'service') {
        description =
            'Scanned Service: ${qrDataMap['serviceType'] ?? qrDataMap['name'] ?? qrCodeId}';
      }

      transaction.set(pointHistoryRef, {
        'timestamp': now,
        'pointsChange': pointsValue,
        'description': description, // Use richer description
        'type': 'scan',
        'qrCodeId': qrCodeId,
        'qrDataType': type, // Store the type from QR
        // Optionally store other relevant data from qrDataMap
        'qrData': qrDataMap,
      });
      // --- End point history ---
    });

    // ... rest of the function (_updateTierAndBadges, refreshUserData) ...
    await _updateTierAndBadges(userId);
    await authProvider.refreshUserData();
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

  void processScan(Map<String, dynamic> qrDataMap) {
    // Accept Map
    // Update UI state for feedback
    setState(() {
      // Show a more user-friendly processing message if possible
      _lastScanResult = 'Processing: ${qrDataMap['type'] ?? 'QR Code'}...';
      _isProcessing = true;
    });

    _validateAndUpdateQRCode(qrDataMap).then((_) {
      // Pass Map
      if (!mounted) return;
      setState(() {
        _lastScanResult = 'Success! Points updated.';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Points updated successfully!'),
          backgroundColor: Colors.green,
        ),
      );
    }).catchError((error) {
      if (!mounted) return;
      String errorMsg = error.toString();
      // Simplify common error messages
      if (errorMsg.startsWith('Exception: ')) {
        errorMsg = errorMsg.substring('Exception: '.length);
      }
      setState(() {
        _lastScanResult = 'Error: $errorMsg';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMsg),
          backgroundColor: Colors.red,
        ),
      );
    }).whenComplete(() {
      if (!mounted) return;
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) {
          setState(() {
            _isProcessing = false;
          });
        }
      });
    });
  }

  void _onDetect(BarcodeCapture capture) {
    if (_isProcessing) return;
    final List<Barcode> barcodes = capture.barcodes;
    if (barcodes.isNotEmpty) {
      final String? rawValue = barcodes.first.rawValue;
      if (rawValue != null) {
        try {
          // Attempt to decode the rawValue as JSON
          final Map<String, dynamic> qrDataMap = jsonDecode(rawValue);

          // Optional: Basic validation of the map structure
          if (qrDataMap.containsKey('id') && qrDataMap.containsKey('type')) {
            // Avoid processing the exact same JSON content immediately
            // (Comparing maps directly can be tricky, use ID for simplicity here)
            if (qrDataMap['id'] != _lastScanResult?.split(': ').last) {
              processScan(qrDataMap); // Pass the parsed map
            }
          } else {
            // Handle cases where JSON is valid but missing required fields
            if (!_isProcessing) {
              // Prevent multiple error messages for the same invalid scan
              setState(() {
                _isProcessing = true;
                _lastScanResult = 'Error: Invalid QR data structure.';
              });
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text('Invalid QR data structure.'),
                  backgroundColor: Colors.orange));
              Future.delayed(const Duration(seconds: 3),
                  () => setState(() => _isProcessing = false));
            }
          }
        } catch (e) {
          // Handle cases where rawValue is not valid JSON
          if (!_isProcessing) {
            // Prevent multiple error messages
            setState(() {
              _isProcessing = true;
              _lastScanResult = 'Error: Not a valid JSON QR code.';
            });
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text('Not a valid loyalty QR code.'),
                backgroundColor: Colors.orange));
            Future.delayed(const Duration(seconds: 3),
                () => setState(() => _isProcessing = false));
          }
          print("Error decoding QR JSON: $e");
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      // Use AppBar for back button and title consistently
      appBar: _buildAppBar(),
      // Set background color for the whole scaffold
      backgroundColor: Color(0xFF0A3D62),
      body: Container(
        // Apply gradient to the body container
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF0A3D62),
              Color(0xFF079992),
            ],
          ),
        ),
        child: Stack(
          children: [
            // Conditionally build scanner based on permission
            if (_cameraPermissionStatus == PermissionStatus.granted)
              _buildScannerView()
            else
              _buildPermissionMessage(), // Show message if permission not granted

            // Overlay Elements (Viewfinder, Scan Result, Controls)
            // These are positioned relative to the Stack
            Positioned.fill(
              child: Column(
                // Keep AppBar space empty if using Scaffold AppBar
                // SizedBox(height: kToolbarHeight + MediaQuery.of(context).padding.top),
                children: [
                  Expanded(
                    child: Stack(
                      alignment: Alignment.center, // Center viewfinder paint
                      children: [
                        _buildViewfinderOverlay(size),
                        _buildScanResultOverlay(), // Positioned within the stack
                      ],
                    ),
                  ),
                  _buildScannerControls(),
                ],
              ),
            ),

            // Processing Overlay
            if (_isProcessing) _buildProcessingOverlay(),
          ],
        ),
      ),
    );
  }

  // Extracted Scanner View Builder
  Widget _buildScannerView() {
    return Positioned.fill(
      // Ensure MobileScanner fills the space
      child: ClipRRect(
        // Optional: Clip if needed
        // borderRadius: BorderRadius.circular(30), // Consider removing if it causes issues
        child: MobileScanner(
          onDetect: _onDetect,
          // Pass the controller instance directly
          // Remove direct assignment of torchEnabled and cameraFacing here
          controller: _scannerController,
          // Consider adding error builder
          errorBuilder: (context, error, child) {
            print("MobileScanner Error: $error"); // Log error
            return Center(
                child: Text('Camera Error: $error',
                    style: TextStyle(color: Colors.red)));
          },
        ),
      ),
    );
  }

  // Extracted Permission Message Builder
  Widget _buildPermissionMessage() {
    String message;
    bool showSettingsButton = false;
    if (_cameraPermissionStatus == PermissionStatus.denied) {
      message = 'Camera permission is required to scan QR codes.';
    } else if (_cameraPermissionStatus == PermissionStatus.permanentlyDenied) {
      message =
          'Camera permission is permanently denied. Please enable it in app settings.';
      showSettingsButton = true;
    } else {
      message = 'Requesting camera permission...'; // Or loading state
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.no_photography, size: 60, color: Colors.white70),
            SizedBox(height: 16),
            Text(
              message,
              style: GoogleFonts.poppins(color: Colors.white, fontSize: 16),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 20),
            if (showSettingsButton)
              ElevatedButton(
                onPressed: openAppSettings, // Open app settings
                child: Text('Open Settings'),
              )
            else if (_cameraPermissionStatus == PermissionStatus.denied)
              ElevatedButton(
                onPressed: _requestCameraPermission, // Retry request
                child: Text('Grant Permission'),
              )
          ],
        ),
      ),
    );
  }

  // Use PreferredSizeWidget for AppBar
  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.transparent, // Make AppBar transparent
      elevation: 0,
      leading: IconButton(
        icon: Icon(Icons.arrow_back, color: Colors.white),
        onPressed: () => Navigator.pop(context),
      ),
      title: Text(
        'Scan QR Code',
        style: GoogleFonts.playfairDisplay(
          color: Colors.white,
          fontSize: 24,
          fontWeight: FontWeight.w600,
        ),
      ),
      centerTitle: true,
    );
  }

  // Extracted Processing Overlay
  Widget _buildProcessingOverlay() {
    return Container(
      color: Colors.black54,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.amber),
            ),
            SizedBox(height: 16),
            Text(
              'Processing...',
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontSize: 18,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildViewfinderOverlay(Size size) {
    // Calculate viewfinder size and position
    final viewfinderSize = size.width * 0.7;
    final topOffset = (size.height -
            viewfinderSize -
            kToolbarHeight -
            MediaQuery.of(context).padding.top -
            100) /
        2; // Adjust 100 based on bottom controls height

    return CustomPaint(
      size: size, // Ensure CustomPaint covers the whole area
      painter: _ViewfinderPainter(
        viewfinderRect: Rect.fromCenter(
          center: Offset(size.width / 2,
              topOffset + viewfinderSize / 2), // Center the rect
          width: viewfinderSize,
          height: viewfinderSize,
        ),
      ),
      // Child is no longer needed here if painter draws the background dimming
    );
  }

  Widget _buildScanResultOverlay() {
    // Positioned at the bottom, above controls
    return Positioned(
      bottom: 100, // Adjust based on controls height
      left: 0,
      right: 0,
      child: AnimatedOpacity(
        opacity: _lastScanResult != null ? 1 : 0,
        duration: Duration(milliseconds: 300),
        child: Container(
          margin: EdgeInsets.symmetric(horizontal: 40),
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.7),
            borderRadius: BorderRadius.circular(15),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                // Change icon based on success/error/processing
                _isProcessing
                    ? Icons.hourglass_top
                    : (_lastScanResult?.startsWith('Error:') ?? false)
                        ? Icons.error_outline
                        : Icons.check_circle,
                color: Colors.amber,
              ),
              SizedBox(width: 12),
              Flexible(
                child: Text(
                  _lastScanResult ?? '',
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 14,
                  ),
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis, // Prevent overflow
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildScannerControls() {
    // Positioned at the very bottom
    return Container(
      padding: const EdgeInsets.only(bottom: 30.0, top: 10.0), // Add padding
      color: Colors.transparent, // Ensure controls background is transparent
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // Flash Button
          IconButton(
            icon: Icon(
              // Use controller.torchState to reflect actual state if needed,
              // or keep using local _flashEnabled for visual feedback before state updates
              _flashEnabled ? Icons.flash_on : Icons.flash_off,
              color: Colors.white,
              size: 32,
            ),
            tooltip: 'Toggle Flash',
            onPressed: () async {
              // Make async if needed
              await _scannerController.toggleTorch(); // Use controller method
              // Update local state for immediate UI feedback if desired
              setState(() => _flashEnabled = !_flashEnabled);
            },
          ),
          // Placeholder/Indicator (Optional)
          Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              // border: Border.all(color: Colors.white.withOpacity(0.5), width: 3),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.qr_code_scanner, // Keep scanner icon
              color: Colors.white.withOpacity(0.7),
              size: 40,
            ),
          ),
          // Switch Camera Button
          IconButton(
            icon: Icon(
              Icons.cameraswitch,
              color: Colors.white,
              size: 32,
            ),
            tooltip: 'Switch Camera',
            onPressed: () async {
              // Make async
              await _scannerController.switchCamera(); // Use controller method
              // Update local state for immediate UI feedback if desired
              setState(() => _cameraFacingFront = !_cameraFacingFront);
            },
          ),
        ],
      ),
    );
  }
}

// Updated Painter to draw dimming and clear viewfinder area
class _ViewfinderPainter extends CustomPainter {
  final Rect viewfinderRect;
  final double cornerLength;
  final double cornerStrokeWidth;
  final Color cornerColor;
  final Color overlayColor;

  _ViewfinderPainter({
    required this.viewfinderRect,
    this.cornerLength = 30.0,
    this.cornerStrokeWidth = 4.0,
    this.cornerColor = Colors.amber,
    this.overlayColor =
        const Color.fromRGBO(0, 0, 0, 0.5), // Semi-transparent black
  });

  @override
  void paint(Canvas canvas, Size size) {
    final backgroundPaint = Paint()..color = overlayColor;

    final cornerPaint = Paint()
      ..color = cornerColor
      ..strokeWidth = cornerStrokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round; // Nicer corners

    // Draw the overlay background covering the whole screen
    // Then clear the viewfinder area
    canvas.drawPath(
      Path.combine(
        PathOperation.difference,
        Path()
          ..addRect(
              Rect.fromLTWH(0, 0, size.width, size.height)), // Full screen rect
        Path()
          ..addRRect(RRect.fromRectAndRadius(
              viewfinderRect,
              Radius.circular(
                  12))), // Clear viewfinder area with rounded corners
      ),
      backgroundPaint,
    );

    // Draw viewfinder corners
    // Top-left
    canvas.drawLine(viewfinderRect.topLeft + Offset(0, cornerLength),
        viewfinderRect.topLeft, cornerPaint);
    canvas.drawLine(viewfinderRect.topLeft + Offset(cornerLength, 0),
        viewfinderRect.topLeft, cornerPaint);

    // Top-right
    canvas.drawLine(viewfinderRect.topRight - Offset(0, -cornerLength),
        viewfinderRect.topRight, cornerPaint);
    canvas.drawLine(viewfinderRect.topRight - Offset(cornerLength, 0),
        viewfinderRect.topRight, cornerPaint);

    // Bottom-left
    canvas.drawLine(viewfinderRect.bottomLeft - Offset(0, cornerLength),
        viewfinderRect.bottomLeft, cornerPaint);
    canvas.drawLine(viewfinderRect.bottomLeft + Offset(cornerLength, 0),
        viewfinderRect.bottomLeft, cornerPaint);

    // Bottom-right
    canvas.drawLine(viewfinderRect.bottomRight - Offset(0, cornerLength),
        viewfinderRect.bottomRight, cornerPaint);
    canvas.drawLine(viewfinderRect.bottomRight - Offset(cornerLength, 0),
        viewfinderRect.bottomRight, cornerPaint);
  }

  @override
  bool shouldRepaint(covariant _ViewfinderPainter oldDelegate) =>
      oldDelegate.viewfinderRect != viewfinderRect ||
      oldDelegate.cornerColor != cornerColor ||
      oldDelegate.overlayColor != overlayColor;
}
