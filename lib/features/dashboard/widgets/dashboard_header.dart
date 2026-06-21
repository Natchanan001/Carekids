import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// 🌟 Header ด้านบนซ้ายของหน้า Dashboard: โลโก้ CareKids (Care สีฟ้า + Kids สีชมพู)
/// พร้อมปุ่มแจ้งเตือน (admin เท่านั้น) และปุ่มเปิด drawer
class DashboardHeader extends StatelessWidget {
  const DashboardHeader({
    super.key,
    required this.isAdmin,
    required this.pendingRequestCount,
    required this.onNotificationsTap,
  });

  final bool isAdmin;
  final int pendingRequestCount;
  final VoidCallback onNotificationsTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _buildLogo(),
          Row(
            children: [
              if (isAdmin) _buildNotificationButton(),
              Builder(
                builder: (context) => IconButton(
                  icon: const Icon(Icons.menu),
                  onPressed: () => Scaffold.of(context).openDrawer(),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLogo() {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: DecoratedBox(
            decoration: BoxDecoration(
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 8, offset: const Offset(0, 3))],
            ),
            child: IntrinsicWidth(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.only(left: 10, right: 4),
                    color: const Color.fromARGB(255, 73, 163, 247),
                    child: Text(
                      'Care',
                      style: GoogleFonts.baloo2(fontSize: 27, fontWeight: FontWeight.w600, color: Colors.white),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.only(left: 4, right: 10),
                    color: const Color.fromARGB(255, 244, 96, 153),
                    child: Text(
                      'Kids',
                      style: GoogleFonts.baloo2(fontSize: 27, fontWeight: FontWeight.w600, color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        Positioned(
          top: -3,
          right: -3,
          child: Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: const Color(0xFF8BC34A),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNotificationButton() {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        IconButton(
          icon: const Icon(Icons.notifications_outlined),
          onPressed: onNotificationsTap,
        ),
        if (pendingRequestCount > 0)
          Positioned(
            right: 4,
            top: 4,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
              constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
              child: Text(
                '$pendingRequestCount',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontSize: 10),
              ),
            ),
          ),
      ],
    );
  }
}