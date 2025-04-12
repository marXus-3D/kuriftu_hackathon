import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:kuriftu_hackathon/home_screen.dart';
import 'main.dart'; // Import the main.dart file to access MyHomePage

class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _isSigningIn = false;

  Future<void> _signInWithGoogle() async {
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
          await docRef.set({
            'displayName': user.displayName ?? '',
            'email': user.email ?? '',
            'photoUrl': user.photoURL ?? '',
            'pointsBalance': 0,
            'currentTier': 'Bronze',
            'lastRoomScanTimestamp': null,
            'scannedEasterEggIds': [],
            'lifetimePoints': 0,
            'fcmToken': fcmToken ?? '',
          });
        } else {
          await docRef.update({
            'displayName': user.displayName ?? '',
            'email': user.email ?? '',
            'photoUrl': user.photoURL ?? '',
            'fcmToken': fcmToken ?? '',
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Login'),
      ),
      body: Center(
        child: _isSigningIn
            ? const CircularProgressIndicator()
            : ElevatedButton.icon(
                icon: Image.asset(
                  'assets/google_logo.png', // Ensure you have the logo asset or replace with an Icon
                  height: 24.0,
                ),
                label: const Text('Sign in with Google'),
                onPressed: _signInWithGoogle,
              ),
      ),
    );
  }
}
