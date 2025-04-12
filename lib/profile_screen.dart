import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
// ...existing or additional imports...

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({Key? key}) : super(key: key);

  Future<void> _signOut(BuildContext context) async {
    await GoogleSignIn().signOut();
    await FirebaseAuth.instance.signOut();
    Navigator.popUntil(context, (route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    // Replace with actual state data from your provider/Bloc/etc.
    final userDisplayName = 'User Name';
    final userEmail = 'user@example.com';
    final userPhotoUrl =
        'https://via.placeholder.com/150'; // Display placeholder if null

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            if (userPhotoUrl.isNotEmpty)
              CircleAvatar(
                backgroundImage: NetworkImage(userPhotoUrl),
                radius: 40,
              ),
            const SizedBox(height: 16),
            Text(userDisplayName, style: const TextStyle(fontSize: 18)),
            Text(userEmail, style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => _signOut(context),
              child: const Text('Sign Out'),
            ),
            // Placeholders for "Point History" and "Earned Badges"
            const SizedBox(height: 16),
            const Text('Point History (Placeholder)'),
            const SizedBox(height: 8),
            const Text('Earned Badges (Placeholder)'),
          ],
        ),
      ),
    );
  }
}
