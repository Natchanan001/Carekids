import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class _ReminderData {
  final String time;
  final String name;
  final String dose;
  final IconData icon;
  final Color iconBg;
  final Color cardBg;
  final Color doseColor;

  const _ReminderData({
    required this.time,
    required this.name,
    required this.dose,
    required this.icon,
    required this.iconBg,
    required this.cardBg,
    required this.doseColor,
  });
}

/// 🌟 Section "Next Reminder": แสดงตัวอย่างเตือนยาตอนเช้า/เย็น
/// (ข้อมูล mock ชั่วคราว — รอ Feature 004 เชื่อมตารางเตือนยาจริง)
class NextReminderSection extends StatelessWidget {
  const NextReminderSection({super.key});

  static const List<_ReminderData> _reminders = [
    _ReminderData(
      time: '8 AM',
      name: 'Paracetamol',
      dose: '3.5 ML',
      icon: Icons.wb_sunny_outlined,
      iconBg: Color(0xFFE8825A),
      cardBg: Color(0xFFFCF3E3),
      doseColor: Color(0xFFD9A441),
    ),
    _ReminderData(
      time: '6 PM',
      name: 'Paracetamol',
      dose: '3.5 ML',
      icon: Icons.nightlight_round,
      iconBg: Color(0xFF5B9DF0),
      cardBg: Color(0xFFEAF2FC),
      doseColor: Color(0xFF5B9DF0),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('Next Reminder',
                style: GoogleFonts.baloo2(fontSize: 22, fontWeight: FontWeight.w700, color: const Color(0xFF1A1A1A))),
            const SizedBox(width: 6),
            const Icon(Icons.alarm, size: 22, color: Colors.black54),
          ],
        ),
        const SizedBox(height: 14),
        for (final r in _reminders) _ReminderCard(reminder: r),
        Text('* Sample reminder — actual medication schedule arrives with Feature 004',
            style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
      ],
    );
  }
}

class _ReminderCard extends StatelessWidget {
  const _ReminderCard({required this.reminder});

  final _ReminderData reminder;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: reminder.cardBg,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: reminder.iconBg,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(reminder.icon, color: Colors.white, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  RichText(
                    text: TextSpan(
                      style: GoogleFonts.baloo2(fontSize: 15, fontWeight: FontWeight.w700, color: const Color(0xFF1A1A1A)),
                      children: [
                        TextSpan(text: '${reminder.time}  '),
                        TextSpan(text: '| ', style: TextStyle(color: Colors.grey.shade400)),
                        TextSpan(text: reminder.name, style: const TextStyle(fontWeight: FontWeight.w500)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    reminder.dose,
                    style: GoogleFonts.baloo2(color: reminder.doseColor, fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
            // 🌟 Placeholder: ในอนาคตจะเป็นรูปถ่ายขวดยาจริงที่ผู้ปกครองอัปโหลด (Feature 004)
            CircleAvatar(
              radius: 21,
              backgroundColor: Colors.pink.shade100,
              child: const Icon(Icons.medication, color: Colors.pink, size: 20),
            ),
          ],
        ),
      ),
    );
  }
}