import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:kuriftu_hackathon/home_screen.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _isSigningIn = false;

  Future<void> _signInWithGoogle() async {
    FirebaseAuth.instance.signInWithEmailAndPassword(
        email: 'marcus.h1620@gmail.com', password: 'password123');
    print('User created successfully!');
    Navigator.pushReplacement(
        context, MaterialPageRoute(builder: (context) => HomeScreen()));

    return;
    setState(() {
      _isSigningIn = true;
    });
    try {
      final googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) {
        // User cancelled the sign-in
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Sign-in cancelled')),
        );
        return;
      }
      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      UserCredential userCredential =
          await FirebaseAuth.instance.signInWithCredential(credential);

      final user = userCredential.user;
      if (user != null) {
        final docRef =
            FirebaseFirestore.instance.collection('users').doc(user.uid);
        final docSnap = await docRef.get();
        final fcmToken = await FirebaseMessaging.instance.getToken();

        if (!docSnap.exists) {
          // Add 'uid' field during document creation
          await docRef.set({
            'uid': user.uid, // Store UID as a field
            'displayName': user.displayName ?? '',
            'email': user.email ?? '',
            'photoUrl': user.photoURL ?? '',
            'pointsBalance': 0,
            'currentTier': 'Bronze',
            'lastRoomScanTimestamp': null,
            'scannedEasterEggIds': [],
            'lifetimePoints': 0,
            'fcmToken': fcmToken ?? '',
            'createdAt': FieldValue.serverTimestamp(), // Add creation timestamp
          });
        } else {
          // Update existing user data (UID field should already exist)
          await docRef.update({
            'displayName': user.displayName ?? '',
            'email': user.email ?? '',
            'photoUrl': user.photoURL ?? '',
            'fcmToken': fcmToken ?? '',
            // No need to update 'uid' here as it's immutable and set on creation
          });
        }
        // Debug log basic user info.
        debugPrint(
            'User signed in: ${user.uid}, ${user.displayName}, ${user.email}');
        // Navigate to HomeScreen (MyHomePage)
        Navigator.pushReplacement(
            context, MaterialPageRoute(builder: (context) => HomeScreen()));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error signing in: $e')),
      );
      print(e.toString()); // Print the error for debugging
    } finally {
      setState(() {
        _isSigningIn = false;
      });
    }
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
            // Floating decorative elements
            Positioned(
              top: size.height * 0.15,
              left: 20,
              child: _FloatingCircle(size: 40),
            ),
            Positioned(
              top: size.height * 0.3,
              right: 30,
              child: _FloatingCircle(size: 60),
            ),
            Positioned(
              bottom: size.height * 0.2,
              left: 50,
              child: _FloatingCircle(size: 30),
            ),

            SafeArea(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // Logo and Heading
                  Column(
                    children: [
                      SvgPicture.asset(
                        'assets/resort_logo.svg',
                        height: size.height * 0.2,
                      ),
                      SizedBox(height: 20),
                      Text(
                        'Kuriftu Rewards',
                        style: GoogleFonts.playfairDisplay(
                          fontSize: 32,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          letterSpacing: 1.2,
                        ),
                      ),
                      SizedBox(height: 10),
                      Text(
                        'Your Gateway to Exclusive Benefits',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          color: Colors.white70,
                        ),
                      ),
                    ],
                  ),

                  // Sign In Button
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 40),
                    child: AnimatedContainer(
                      duration: Duration(milliseconds: 300),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(15),
                        boxShadow: _isSigningIn
                            ? []
                            : [
                                BoxShadow(
                                  color: Colors.black26,
                                  blurRadius: 10,
                                  offset: Offset(0, 4),
                                )
                              ],
                      ),
                      child: ElevatedButton(
                        onPressed: _isSigningIn ? null : _signInWithGoogle,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Color(0xFF0A3D62),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(15)),
                          padding: EdgeInsets.symmetric(
                              vertical: 16, horizontal: 30),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Image.asset(
                              'assets/google_logo.png',
                              height: 24,
                            ),
                            SizedBox(width: 15),
                            Text(
                              'Continue with Google',
                              style: GoogleFonts.poppins(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Footer Text
                  Padding(
                    padding: const EdgeInsets.only(bottom: 20),
                    child: Text(
                      'Earn points with every stay\nUnlock exclusive rewards & benefits',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                    ),
                  )
                ],
              ),
            ),

            // Loading Overlay
            if (_isSigningIn)
              Container(
                color: Colors.black54,
                child: Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
              ),
          ],
        ),
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
