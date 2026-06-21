import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// 🌟 Bottom navigation: Home / Schedule / Hospital / Account (ชื่อบัญชีผู้ใช้ที่ login อยู่)
class DashboardBottomNav extends StatelessWidget {
  const DashboardBottomNav({
    super.key,
    required this.firstName,
    required this.onAccountTap,
    required this.onOtherTap,
  });

  final String? firstName;
  final VoidCallback onAccountTap;
  final ValueChanged<String> onOtherTap;

  @override
  Widget build(BuildContext context) {
    final initial = (firstName != null && firstName!.isNotEmpty) ? firstName![0].toUpperCase() : null;
    final userDisplayName = (firstName != null && firstName!.isNotEmpty) ? firstName! : 'Account';

    return BottomNavigationBar(
      type: BottomNavigationBarType.fixed,
      currentIndex: 0,
      backgroundColor: Colors.white,
      selectedItemColor: const Color(0xFF5B9DF0),
      unselectedItemColor: const Color(0xFF8A8A8A),
      selectedLabelStyle: GoogleFonts.baloo2(fontSize: 11, fontWeight: FontWeight.w600),
      unselectedLabelStyle: GoogleFonts.baloo2(fontSize: 11, fontWeight: FontWeight.w500),
      elevation: 8,
      onTap: (index) {
        if (index == 0) return;
        if (index == 3) {
          onAccountTap();
          return;
        }
        onOtherTap('This section');
      },
      items: [
        const BottomNavigationBarItem(icon: Icon(Icons.home_outlined), activeIcon: Icon(Icons.home), label: 'Home'),
        const BottomNavigationBarItem(icon: Icon(Icons.calendar_today_outlined), label: 'Schedule'),
        const BottomNavigationBarItem(icon: Icon(Icons.location_on_outlined), label: 'Hospital'),
        BottomNavigationBarItem(
          icon: Container(
            padding: const EdgeInsets.all(1.5),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFF5B9DF0), width: 1.5),
            ),
            child: CircleAvatar(
              radius: 11,
              backgroundColor: Colors.purple.shade100,
              child: initial != null
                  ? Text(initial, style: const TextStyle(fontSize: 10, color: Colors.black87))
                  : const Icon(Icons.person, size: 13, color: Colors.black54),
            ),
          ),
          label: userDisplayName,
        ),
      ],
    );
  }
}