import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// 🌟 ข้อความ "Welcome to [ชื่อแฟมิลี่] !" ใต้ header
class WelcomeMessage extends StatelessWidget {
  const WelcomeMessage({super.key, required this.familyName});

  final String? familyName;

  @override
  Widget build(BuildContext context) {
    final familyLabel = (familyName != null && familyName!.isNotEmpty) ? familyName! : 'Family';
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
      child: Text(
        'Welcome to $familyLabel !',
        style: GoogleFonts.baloo2(fontSize: 22, fontWeight: FontWeight.w700, color: const Color(0xFF1A1A1A)),
      ),
    );
  }
}