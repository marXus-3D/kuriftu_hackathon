import 'dart:convert'; // Import dart:convert for jsonEncode
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
// Hide AuthProvider from firebase_auth to avoid conflict
import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import 'package:google_sign_in/google_sign_in.dart';
// Remove Firestore import if only reading from provider
// import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart'; // Import Provider
import 'package:qr_flutter/qr_flutter.dart';
import 'login_screen.dart';
import 'package:google_fonts/google_fonts.dart';
import 'auth_provider.dart'; // Import AuthProvider

class ProfileScreen extends StatefulWidget {
  // Keep StatefulWidget if _signOut needs context
  const ProfileScreen({Key? key}) : super(key: key);

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  // Remove local state variables
  // Map<String, dynamic>? _userData;
  // bool _isLoading = true;
  // String? _error;

  // Remove initState and _fetchUserData
  // @override
  // void initState() { ... }
  // Future<void> _fetchUserData() async { ... }

  Future<void> _signOut(BuildContext context) async {
    // Keep sign out logic
    await GoogleSignIn().signOut();
    await FirebaseAuth.instance.signOut();
    // Accessing provider here is fine, but context is needed for navigation
    Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
      // Use rootNavigator if needed
      MaterialPageRoute(builder: (context) => const LoginScreen()),
      (Route<dynamic> route) => false,
    );
  }

  String _generateQrData(Map<String, dynamic>? userData) {
    // Pass userData as argument
    if (userData == null) return '';

    Timestamp? lastScanTimestamp =
        userData['lastRoomScanTimestamp'] as Timestamp?;
    Timestamp? createdAtTimestamp = userData['createdAt'] as Timestamp?;

    final data = {
      'uid': userData['uid'] ?? 'N/A',
      'displayName': userData['displayName'] ?? 'N/A',
      'email': userData['email'] ?? 'N/A',
      'currentTier': userData['currentTier'] ?? 'Bronze',
      'lastRoomScanTimestamp': lastScanTimestamp?.millisecondsSinceEpoch,
      'lifetimePoints': userData['lifetimePoints'] ?? 0,
      'createdAt': createdAtTimestamp?.millisecondsSinceEpoch,
    };
    return jsonEncode(data);
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    // Get AuthProvider instance
    final authProvider = context.watch<AuthProvider>();

    return Scaffold(
      body: Container(
        // ... existing decoration ...
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
            // ... existing decorative elements ...
            Positioned(
              top: size.height * 0.1,
              right: 20,
              child: _FloatingCircle(size: 40),
            ),
            Positioned(
              bottom: size.height * 0.15,
              left: 30,
              child: _FloatingCircle(size: 60),
            ),

            SafeArea(
              // Use authProvider state for UI
              child: authProvider.isLoading
                  ? _buildLoadingIndicator()
                  : authProvider.error != null
                      ? _buildErrorState(authProvider.error!,
                          authProvider) // Pass provider to retry
                      : authProvider.userData == null
                          ? _buildErrorState("User data not found.",
                              authProvider) // Handle null userData
                          : SingleChildScrollView(
                              padding: EdgeInsets.all(24),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  _buildProfileHeader(
                                      authProvider.userData!), // Pass userData
                                  SizedBox(height: 32),
                                  _buildTierStatusCard(
                                      authProvider.userData!), // Pass userData
                                  SizedBox(height: 24),
                                  _buildQrCodeSection(
                                      authProvider.userData!), // Pass userData
                                  SizedBox(height: 32),
                                  _buildPointsCard(
                                      authProvider.userData!), // Pass userData
                                  SizedBox(height: 24),
                                  _buildBadgesSection(
                                      authProvider.userData!), // Pass userData
                                  SizedBox(height: 32),
                                  _buildSignOutButton(),
                                ],
                              ),
                            ),
            ),
          ],
        ),
      ),
    );
  }

  // Update build methods to accept userData Map
  Widget _buildProfileHeader(Map<String, dynamic> userData) {
    return Column(
      children: [
        // ... existing avatar ...
        Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2),
            boxShadow: [
              BoxShadow(
                  color: Colors.black26, blurRadius: 10, offset: Offset(0, 4)),
            ],
          ),
          child: CircleAvatar(
            radius: 48,
            backgroundImage: NetworkImage(
                userData['photoUrl'] ?? 'https://via.placeholder.com/150'),
            child: userData['photoUrl'] == null
                ? Icon(Icons.person, size: 48, color: Colors.white)
                : null,
          ),
        ),
        SizedBox(height: 16),
        Text(
          userData['displayName'] ?? 'Guest User',
          // ... existing style ...
          style: GoogleFonts.playfairDisplay(
            fontSize: 28,
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        Text(
          userData['email'] ?? 'No email provided',
          // ... existing style ...
          style: GoogleFonts.poppins(
            fontSize: 14,
            color: Colors.white70,
          ),
        ),
      ],
    );
  }

  Widget _buildTierStatusCard(Map<String, dynamic> userData) {
    // Calculate progress based on userData
    // Example: Assuming 1000 points for next tier (Silver) from Bronze
    int points = userData['lifetimePoints'] ?? 0;
    int pointsForNextTier = 1000; // Define thresholds properly
    double progress = (points % pointsForNextTier) / pointsForNextTier;
    String nextTierMessage = "$points / $pointsForNextTier points to next tier";
    // Add logic for higher tiers

    return Container(
      // ... existing decoration ...
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Text(
            'Current Tier',
            // ... existing style ...
            style: GoogleFonts.poppins(
              color: Colors.white70,
              fontSize: 14,
            ),
          ),
          SizedBox(height: 8),
          Text(
            userData['currentTier'] ?? 'Bronze',
            // ... existing style ...
            style: GoogleFonts.playfairDisplay(
              fontSize: 32,
              color: Colors.amber,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: 16),
          LinearProgressIndicator(
            value: progress, // Use calculated progress
            // ... existing style ...
            backgroundColor: Colors.white12,
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF079992)),
            minHeight: 8,
          ),
          SizedBox(height: 8),
          Text(
            nextTierMessage, // Use dynamic message
            // ... existing style ...
            style: GoogleFonts.poppins(
              color: Colors.white70,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQrCodeSection(Map<String, dynamic> userData) {
    return Column(
      children: [
        // ... existing title ...
        Text(
          'Membership QR Code',
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        SizedBox(height: 16),
        Container(
          // ... existing decoration ...
          padding: EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                  color: Colors.black26, blurRadius: 10, offset: Offset(0, 4)),
            ],
          ),
          child: Column(
            children: [
              QrImageView(
                data: _generateQrData(userData), // Pass userData
                // ... existing style ...
                version: QrVersions.auto,
                size: 180,
                eyeStyle: QrEyeStyle(
                  eyeShape: QrEyeShape.square,
                  color: Color(0xFF0A3D62),
                ),
                dataModuleStyle: QrDataModuleStyle(
                  dataModuleShape: QrDataModuleShape.circle,
                  color: Color(0xFF0A3D62),
                ),
              ),
              // ... existing text ...
              SizedBox(height: 16),
              Text(
                'Scan at any Kuriftu facility',
                style: GoogleFonts.poppins(
                  color: Color(0xFF0A3D62),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPointsCard(Map<String, dynamic> userData) {
    return Container(
      // ... existing decoration ...
      padding: EdgeInsets.symmetric(vertical: 16, horizontal: 24),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Available Points',
                // ... existing style ...
                style: GoogleFonts.poppins(
                  color: Colors.white70,
                  fontSize: 14,
                ),
              ),
              Text(
                '${userData['pointsBalance'] ?? 0}', // Use userData
                // ... existing style ...
                style: GoogleFonts.playfairDisplay(
                  fontSize: 36,
                  color: Colors.amber,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          Icon(Icons.stars_rounded, size: 40, color: Colors.amber),
        ],
      ),
    );
  }

  Widget _buildBadgesSection(Map<String, dynamic> userData) {
    // TODO: Fetch actual badges from userData or a subcollection
    final dummyBadges = ['Eco Warrior', 'Frequent Visitor', 'Luxury Seeker'];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ... existing title ...
        Text(
          'Earned Badges',
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        SizedBox(height: 16),
        SizedBox(
          height: 100,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: dummyBadges.length, // Use actual badge count later
            itemBuilder: (context, index) {
              return Container(
                // ... existing decoration ...
                margin: EdgeInsets.only(right: 16),
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.emoji_events_rounded, color: Colors.amber),
                    SizedBox(height: 8),
                    Text(
                      dummyBadges[index], // Use actual badge name later
                      // ... existing style ...
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSignOutButton() {
    // Keep sign out button as is, uses local _signOut method
    return ElevatedButton.icon(
      onPressed: () => _signOut(context),
      // ... existing style ...
      icon: Icon(Icons.logout, color: Colors.white),
      label: Text(
        'Sign Out',
        style: GoogleFonts.poppins(
          color: Colors.white,
          fontWeight: FontWeight.w600,
        ),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.red.withOpacity(0.8),
        padding: EdgeInsets.symmetric(horizontal: 32, vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(15),
        ),
      ),
    );
  }

  Widget _buildLoadingIndicator() {
    // Keep loading indicator as is
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: Colors.white),
          SizedBox(height: 16),
          Text(
            'Loading Profile...',
            style: GoogleFonts.poppins(color: Colors.white),
          ),
        ],
      ),
    );
  }

  // Update error state to include retry mechanism
  Widget _buildErrorState(String errorMsg, AuthProvider authProvider) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 48, color: Colors.red),
          SizedBox(height: 16),
          Text(
            errorMsg, // Use error message from provider
            style: GoogleFonts.poppins(color: Colors.white),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 24),
          ElevatedButton(
            onPressed: () =>
                authProvider.refreshUserData(), // Call refresh method
            child: Text('Retry'),
          ),
          SizedBox(height: 16), // Add sign out button in error state too
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.withOpacity(0.8)),
            onPressed: () => _signOut(context),
            child: Text('Sign Out',
                style: GoogleFonts.poppins(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

// Keep _FloatingCircle as is
class _FloatingCircle extends StatelessWidget {
  // ... existing code ...
  final double size;

  const _FloatingCircle({required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withOpacity(0.1),
      ),
    );
  }
}
