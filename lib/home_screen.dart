import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart'; // Import Provider
import 'scanner_screen.dart';
import 'profile_screen.dart';
import 'auth_provider.dart'; // Import AuthProvider
import 'rewards_screen.dart'; // Import RewardsScreen

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
        child: IndexedStack(
          // Use IndexedStack to keep state of pages
          index: _selectedIndex,
          children: _pages,
        ),
      ),
      bottomNavigationBar: _buildLuxuryNavBar(),
    );
  }

  BottomNavigationBar _buildLuxuryNavBar() {
    return BottomNavigationBar(
      currentIndex: _selectedIndex,
      backgroundColor: Color(0xFF0A3D62),
      selectedItemColor: Colors.amber,
      unselectedItemColor: Colors.white70,
      elevation: 10,
      type: BottomNavigationBarType.fixed, // Ensure labels are always visible
      items: [
        BottomNavigationBarItem(
          icon: Icon(Icons.home_outlined),
          activeIcon: Icon(Icons.home),
          label: 'Home',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.qr_code_scanner_outlined),
          activeIcon: Icon(Icons.qr_code_scanner),
          label: 'Scan',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.person_outline),
          activeIcon: Icon(Icons.person),
          label: 'Profile',
        ),
      ],
      onTap: _onItemTapped,
    );
  }
}

class _DashboardContent extends StatelessWidget {
  const _DashboardContent({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Get user data from AuthProvider
    final authProvider = context.watch<AuthProvider>();
    final userData = authProvider.userData;
    final isLoading = authProvider.isLoading;
    final error = authProvider.error;

    // Handle loading and error states
    if (isLoading && userData == null) {
      // Show loading only if data isn't available yet
      return const Center(
          child: CircularProgressIndicator(color: Colors.white));
    }
    if (error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            'Error loading dashboard: $error',
            style: GoogleFonts.poppins(color: Colors.white),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    if (userData == null) {
      // This case might happen briefly or if Firestore data is missing
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            'Could not load user data.',
            style: GoogleFonts.poppins(color: Colors.white),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    // Extract data safely with defaults
    final userName = userData['displayName'] ?? 'Valued Member';
    final pointsBalance = userData['pointsBalance'] ?? 0;
    final currentTier = userData['currentTier'] ?? 'Bronze';
    // Calculate next tier progress (example logic, adjust as needed)
    final lifetimePoints = userData['lifetimePoints'] ?? 0;
    double nextTierProgress = 0.0;
    if (currentTier == 'Bronze')
      nextTierProgress = (lifetimePoints / 1000).clamp(0.0, 1.0);
    else if (currentTier == 'Silver')
      nextTierProgress =
          ((lifetimePoints - 1000) / 4000).clamp(0.0, 1.0); // 1000 to 5000
    else if (currentTier == 'Gold')
      nextTierProgress =
          ((lifetimePoints - 5000) / 5000).clamp(0.0, 1.0); // 5000 to 10000
    else
      nextTierProgress = 1.0; // Platinum or higher

    return SafeArea(
      child: RefreshIndicator(
        // Add pull-to-refresh
        onRefresh: () => authProvider.refreshUserData(),
        color: Colors.white,
        backgroundColor: Color(0xFF0A3D62),
        child: SingleChildScrollView(
          physics:
              const AlwaysScrollableScrollPhysics(), // Ensure scroll even when content fits
          child: Column(
            children: [
              _buildHeaderCard(
                  userName, pointsBalance, currentTier, nextTierProgress),
              _buildQuickActions(context), // Pass context
              _buildCurrentOffers(),
              _buildRecentActivity(
                  context, userData['uid']), // Pass context and uid
              SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  // Update header card to use fetched data
  Widget _buildHeaderCard(
      String name, int points, String tier, double progress) {
    return Container(
      margin: EdgeInsets.all(16),
      padding: EdgeInsets.all(20),
      // ... existing decoration ...
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Welcome Back,',
                    // ... existing style ...
                    style: GoogleFonts.poppins(
                      color: Colors.white70,
                      fontSize: 14,
                    ),
                  ),
                  Text(
                    name, // Use fetched name
                    // ... existing style ...
                    style: GoogleFonts.poppins(
                      fontSize: 24,
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                // ... existing decoration ...
                decoration: BoxDecoration(
                  color: Colors.amber,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  tier, // Use fetched tier
                  // ... existing style ...
                  style: GoogleFonts.poppins(
                    color: Color(0xFF0A3D62),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              Column(
                children: [
                  Text(
                    'Points Balance',
                    // ... existing style ...
                    style: GoogleFonts.poppins(
                      color: Colors.white70,
                      fontSize: 14,
                    ),
                  ),
                  Text(
                    points.toString(), // Use fetched points
                    // ... existing style ...
                    style: GoogleFonts.playfairDisplay(
                      fontSize: 36,
                      color: Colors.amber,
                      fontWeight: FontWeight.w700, // Make points bold
                    ),
                  ),
                ],
              ),
              Column(
                children: [
                  Text(
                    'Next Tier',
                    // ... existing style ...
                    style: GoogleFonts.poppins(
                      color: Colors.white70,
                      fontSize: 14,
                    ),
                  ),
                  SizedBox(
                    // Add SizedBox for consistent layout
                    width: 60,
                    height: 60, // Define size for CircularProgressIndicator
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        CircularProgressIndicator(
                          value: progress, // Use calculated progress
                          strokeWidth: 6, // Adjust stroke width
                          backgroundColor: Colors.white24,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.amber),
                        ),
                        Text(
                          '${(progress * 100).toInt()}%',
                          // ... existing style ...
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 12, // Adjust font size
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Update quick actions to navigate correctly
  Widget _buildQuickActions(BuildContext context) {
    // Pass context
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'Quick Actions',
              // ... existing style ...
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildActionButton(
                icon: Icons.qr_code_scanner,
                label: 'Scan', // Changed label
                onTap: () {
                  // Navigate to Scanner tab (assuming HomeScreen manages state)
                  final homeScreenState =
                      context.findAncestorStateOfType<_HomeScreenState>();
                  homeScreenState?._onItemTapped(1); // Index 1 is Scanner
                },
              ),
              _buildActionButton(
                icon: Icons.card_giftcard,
                label: 'Redeem',
                onTap: () {
                  // Navigate to Rewards Screen
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => const RewardsScreen()),
                  );
                },
              ),
              _buildActionButton(
                icon: Icons.person, // Changed icon
                label: 'Profile', // Changed label
                onTap: () {
                  // Navigate to Profile tab
                  final homeScreenState =
                      context.findAncestorStateOfType<_HomeScreenState>();
                  homeScreenState?._onItemTapped(2); // Index 2 is Profile
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(
      {required IconData icon,
      required String label,
      required Function onTap}) {
    return Column(
      children: [
        InkWell(
          onTap: () => onTap(),
          borderRadius:
              BorderRadius.circular(30), // Add border radius for ink splash
          child: Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withOpacity(0.1),
            ),
            child: Icon(icon, size: 28, color: Colors.amber),
          ),
        ),
        SizedBox(height: 4),
        Text(
          label,
          style: GoogleFonts.poppins(
            color: Colors.white70,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildCurrentOffers() {
    return Container(
      margin: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'Special Offers',
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildOfferCard('Spa Package', '50% OFF', Icons.spa),
                _buildOfferCard(
                    'Dining Credit', '1000 Points', Icons.restaurant),
                _buildOfferCard('Suite Upgrade', '2500 Points', Icons.king_bed),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOfferCard(String title, String subtitle, IconData icon) {
    return Container(
      width: 150,
      margin: EdgeInsets.only(right: 12),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 32, color: Colors.amber),
          SizedBox(height: 12),
          Text(
            title,
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
          Text(
            subtitle,
            style: GoogleFonts.poppins(
              color: Colors.white70,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentActivity(BuildContext context, String userId) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'Recent Activity',
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('users')
                .doc(userId)
                .collection('pointHistory')
                .orderBy('timestamp', descending: true)
                .limit(5) // Limit to recent activities
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Text('Error loading activity',
                    style: GoogleFonts.poppins(color: Colors.white70));
              }
              if (snapshot.connectionState == ConnectionState.waiting) {
                return Center(
                    child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white),
                ));
              }
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return Text('No recent activity found.',
                    style: GoogleFonts.poppins(color: Colors.white70));
              }

              final activities = snapshot.data!.docs;

              return ListView.builder(
                shrinkWrap: true, // Important inside a Column
                physics:
                    NeverScrollableScrollPhysics(), // Disable ListView scrolling
                itemCount: activities.length,
                itemBuilder: (context, index) {
                  final activity =
                      activities[index].data() as Map<String, dynamic>;
                  final description = activity['description'] ?? 'Activity';
                  final pointsChange = activity['pointsChange'] ?? 0;
                  final timestamp = activity['timestamp'] as Timestamp?;
                  final timeAgo = timestamp != null
                      ? _formatTimeAgo(timestamp.toDate())
                      : '';
                  final isPositive = pointsChange >= 0;

                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Container(
                      padding: EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        isPositive
                            ? Icons.add_circle_outline
                            : Icons.remove_circle_outline,
                        color:
                            isPositive ? Colors.greenAccent : Colors.redAccent,
                      ),
                    ),
                    title: Text(
                      description,
                      style: GoogleFonts.poppins(color: Colors.white),
                    ),
                    subtitle: Text(
                      timeAgo,
                      style: GoogleFonts.poppins(
                          color: Colors.white70, fontSize: 12),
                    ),
                    trailing: Text(
                      '${isPositive ? '+' : ''}$pointsChange pts',
                      style: GoogleFonts.poppins(
                        color:
                            isPositive ? Colors.greenAccent : Colors.redAccent,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }

  // Helper function to format time difference
  String _formatTimeAgo(DateTime time) {
    final difference = DateTime.now().difference(time);
    if (difference.inSeconds < 60) return '${difference.inSeconds}s ago';
    if (difference.inMinutes < 60) return '${difference.inMinutes}m ago';
    if (difference.inHours < 24) return '${difference.inHours}h ago';
    return '${difference.inDays}d ago';
  }
}
