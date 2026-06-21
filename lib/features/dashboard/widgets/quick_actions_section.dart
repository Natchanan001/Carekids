import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class QuickAction {
  final String title;
  final IconData icon;
  final Color cardColor;
  final Color iconColor;

  const QuickAction({
    required this.title,
    required this.icon,
    required this.cardColor,
    required this.iconColor,
  });
}

/// 🌟 Section "Quick Action": พื้นหลัง gradient เขียว->ฟ้า->เหลือง พร้อมการ์ดเลื่อนแนวนอน
class QuickActionsSection extends StatelessWidget {
  const QuickActionsSection({super.key, required this.onActionTap});

  final ValueChanged<String> onActionTap;

  static final List<QuickAction> _actions = [
    const QuickAction(
      title: 'Calculator\nDose',
      icon: Icons.medication_liquid,
      cardColor: Color(0xFFB9EAD4),
      iconColor: Color(0xFF1F9D6B),
    ),
    const QuickAction(
      title: 'Medication\nLog',
      icon: Icons.assignment_outlined,
      cardColor: Color(0xFFBBD3F7),
      iconColor: Color(0xFF2F6FE0),
    ),
    const QuickAction(
      title: 'Symptom\nLog',
      icon: Icons.sick_outlined,
      cardColor: Color(0xFFF7DCA8),
      iconColor: Color(0xFFB8791A),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 20),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF8FD3A8), Color(0xFFAFD8E8), Color(0xFFF3DFAE)],
          stops: [0.0, 0.55, 1.0],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              'Quick Action',
              style: GoogleFonts.baloo2(fontSize: 22, fontWeight: FontWeight.w700, color: const Color(0xFF1A1A1A)),
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 175,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              children: [
                for (final action in _actions)
                  Padding(
                    padding: const EdgeInsets.only(right: 14),
                    child: _QuickActionCard(action: action, onTap: () => onActionTap(action.title.replaceAll('\n', ' '))),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickActionCard extends StatelessWidget {
  const _QuickActionCard({required this.action, required this.onTap});

  final QuickAction action;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 150,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: action.cardColor,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 8, offset: const Offset(0, 3))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            action.title,
            style: GoogleFonts.baloo2(fontSize: 15, fontWeight: FontWeight.w700, color: action.iconColor, height: 1.15),
          ),
          const Spacer(),
          Align(
            alignment: Alignment.centerRight,
            child: Container(
              width: 56,
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.55),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(action.icon, size: 30, color: action.iconColor),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onTap,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: action.iconColor,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              ),
              child: Text('Start Now', style: GoogleFonts.baloo2(fontSize: 12, fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }
}