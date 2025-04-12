import 'dart:convert'; // Import dart:convert for jsonEncode
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // Import Firestore
import 'package:qr_flutter/qr_flutter.dart'; // Import qr_flutter
import 'login_screen.dart'; // Import LoginScreen for navigation after sign out
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_svg/flutter_svg.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({Key? key}) : super(key: key);

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Map<String, dynamic>? _userData;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchUserData();
  }

  Future<void> _fetchUserData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() {
        _error = "User not logged in.";
        _isLoading = false;
      });
      return;
    }

    try {
      final docSnap = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      if (docSnap.exists) {
        setState(() {
          _userData = docSnap.data();
          _isLoading = false;
        });
      } else {
        setState(() {
          _error = "User data not found.";
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = "Error fetching user data: $e";
        _isLoading = false;
      });
    }
  }

  Future<void> _signOut(BuildContext context) async {
    await GoogleSignIn().signOut();
    await FirebaseAuth.instance.signOut();
    // Navigate back to login screen and remove all previous routes
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => const LoginScreen()),
      (Route<dynamic> route) => false,
    );
  }

  String _generateQrData() {
    if (_userData == null) return '';

    // Safely access data, providing defaults or handling nulls
    Timestamp? lastScanTimestamp =
        _userData!['lastRoomScanTimestamp'] as Timestamp?;
    Timestamp? createdAtTimestamp = _userData!['createdAt'] as Timestamp?;

    final data = {
      'uid': _userData!['uid'] ?? 'N/A',
      'displayName': _userData!['displayName'] ?? 'N/A',
      'email': _userData!['email'] ?? 'N/A',
      'currentTier': _userData!['currentTier'] ?? 'Bronze',
      'lastRoomScanTimestamp': lastScanTimestamp
          ?.millisecondsSinceEpoch, // Send as epoch milliseconds or null
      'lifetimePoints': _userData!['lifetimePoints'] ?? 0,
      'createdAt': createdAtTimestamp
          ?.millisecondsSinceEpoch, // Send as epoch milliseconds or null
    };
    return jsonEncode(data);
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      body: Container(
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
            // Decorative elements
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
              child: _isLoading
                  ? _buildLoadingIndicator()
                  : _error != null
                      ? _buildErrorState()
                      : SingleChildScrollView(
                          padding: EdgeInsets.all(24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              _buildProfileHeader(),
                              SizedBox(height: 32),
                              _buildTierStatusCard(),
                              SizedBox(height: 24),
                              _buildQrCodeSection(),
                              SizedBox(height: 32),
                              _buildPointsCard(),
                              SizedBox(height: 24),
                              _buildBadgesSection(),
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

  Widget _buildProfileHeader() {
    return Column(
      children: [
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
                _userData!['photoUrl'] ?? 'https://via.placeholder.com/150'),
            child: _userData!['photoUrl'] == null
                ? Icon(Icons.person, size: 48, color: Colors.white)
                : null,
          ),
        ),
        SizedBox(height: 16),
        Text(
          _userData!['displayName'] ?? 'Guest User',
          style: GoogleFonts.playfairDisplay(
            fontSize: 28,
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        Text(
          _userData!['email'] ?? 'No email provided',
          style: GoogleFonts.poppins(
            fontSize: 14,
            color: Colors.white70,
          ),
        ),
      ],
    );
  }
  // TODO Remove this at some time
  // This is a placeholder for the profile header widget.
  /* Widget _buildProfileHeader() {
    return Column(
      children: [
        Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2),
            boxShadow: [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 10,
                offset: Offset(0, 4)),
            ],
          ),
          child: CircleAvatar(
            radius: 48,
            backgroundImage: NetworkImage(
              _userData!['photoUrl'] ?? 'https://via.placeholder.com/150'),
            child: _userData!['photoUrl'] == null
                ? Icon(Icons.person, size: 48, color: Colors.white)
                : null,
          ),
        ),
        SizedBox(height: 16),
        Text(
          _userData!['displayName'] ?? 'Guest User',
          style: GoogleFonts.playfairDisplay(
            fontSize: 28,
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        Text(
          _userData!['email'] ?? 'No email provided',
          style: GoogleFonts.poppins(
            fontSize: 14,
            color: Colors.white70,
          ),
        ),
      ],
    );
  } */

  Widget _buildTierStatusCard() {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Text(
            'Current Tier',
            style: GoogleFonts.poppins(
              color: Colors.white70,
              fontSize: 14,
            ),
          ),
          SizedBox(height: 8),
          Text(
            _userData!['currentTier'] ?? 'Bronze',
            style: GoogleFonts.playfairDisplay(
              fontSize: 32,
              color: Colors.amber,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: 16),
          LinearProgressIndicator(
            value: (_userData!['lifetimePoints'] ?? 0) / 1000,
            backgroundColor: Colors.white12,
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF079992)),
            minHeight: 8,
          ),
          SizedBox(height: 8),
          Text(
            '${_userData!['lifetimePoints'] ?? 0} / 1000 points to next tier',
            style: GoogleFonts.poppins(
              color: Colors.white70,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQrCodeSection() {
    return Column(
      children: [
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
                data: _generateQrData(),
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

  Widget _buildPointsCard() {
    return Container(
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
                style: GoogleFonts.poppins(
                  color: Colors.white70,
                  fontSize: 14,
                ),
              ),
              Text(
                '${_userData!['pointsBalance'] ?? 0}',
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

  Widget _buildBadgesSection() {
    // Replace with actual badge data
    final dummyBadges = ['Eco Warrior', 'Frequent Visitor', 'Luxury Seeker'];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
            itemCount: dummyBadges.length,
            itemBuilder: (context, index) {
              return Container(
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
                      dummyBadges[index],
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
    return ElevatedButton.icon(
      onPressed: () => _signOut(context),
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

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 48, color: Colors.red),
          SizedBox(height: 16),
          Text(
            _error!,
            style: GoogleFonts.poppins(color: Colors.white),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 24),
          ElevatedButton(
            onPressed: _fetchUserData,
            child: Text('Retry'),
          ),
        ],
      ),
    );
  }
}

class _FloatingCircle extends StatelessWidget {
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
