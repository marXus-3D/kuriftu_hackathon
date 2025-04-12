import 'package:flutter/material.dart';
import 'scanner_screen.dart';
import 'profile_screen.dart';
// ...existing or additional imports...

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  final List<Widget> _pages = const [
    _DashboardContent(),
    ScannerScreen(),
    ProfileScreen(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(
              icon: Icon(Icons.qr_code_scanner), label: 'Scanner'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
        ],
        onTap: _onItemTapped,
      ),
    );
  }
}

class _DashboardContent extends StatelessWidget {
  const _DashboardContent({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Replace these sample values with data from your state management solution
    final userName = 'User Name';
    final pointsBalance = 100;
    final currentTier = 'Bronze';

    return Scaffold(
      appBar: AppBar(
        title: Text('Welcome, $userName!'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Text('Your Points: $pointsBalance',
                style: const TextStyle(fontSize: 20)),
            Text('Tier: $currentTier', style: const TextStyle(fontSize: 18)),
            const SizedBox(height: 20),
            // Placeholder for recent activity or active challenges
            const Text('Recent Activity / Challenges (Placeholder)'),
          ],
        ),
      ),
    );
  }
}
