import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:carekids/shared/utils/date_utils.dart';
import 'package:carekids/shared/utils/mock_events.dart';
import 'package:carekids/features/dashboard/screens/calendar_screen.dart';

/// 🌟 Section "Date": แถบเลื่อนวันที่ในเดือนปัจจุบัน + panel แสดงรายละเอียดวันที่เลือก
class DateCalendarSection extends StatelessWidget {
  const DateCalendarSection({
    super.key,
    required this.daysInCurrentMonth,
    required this.calendarItemExtent,
    required this.scrollController,
    required this.selectedDate,
    required this.onDateSelected,
  });

  final int daysInCurrentMonth;
  final double calendarItemExtent;
  final ScrollController scrollController;
  final DateTime selectedDate;
  final ValueChanged<DateTime> onDateSelected;

  @override
  Widget build(BuildContext context) {
    final today = MockEvents.today;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Date', style: GoogleFonts.baloo2(fontSize: 22, fontWeight: FontWeight.w700, color: const Color(0xFF1A1A1A))),
            IconButton(
              icon: const Icon(Icons.calendar_month, color: Color.fromARGB(255, 192, 118, 131)),
              tooltip: 'Full calendar',
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => CalendarScreen())),
            ),
          ],
        ),
        const SizedBox(height: 4),
        SizedBox(
          height: 136,
          child: ListView.builder(
            controller: scrollController,
            scrollDirection: Axis.horizontal,
            itemCount: daysInCurrentMonth,
            itemExtent: calendarItemExtent,
            itemBuilder: (context, index) {
              final date = DateTime(today.year, today.month, index + 1);
              final isSelected = isSameDate(date, selectedDate);
              final isToday = isSameDate(date, today);
              final eventLabel = MockEvents.eventFor(date);
              final hasEvent = eventLabel != null;

              IconData? eventIcon;
              if (hasEvent) {
                final lower = eventLabel.toLowerCase();
                if (lower.contains('vaccine')) {
                  eventIcon = Icons.vaccines_outlined;
                } else if (lower.contains('doctor')) {
                  eventIcon = Icons.medical_services_outlined;
                } else {
                  eventIcon = Icons.event_note_outlined;
                }
              }

              return DateCard(
                weekday: weekdayShortNames[date.weekday - 1],
                day: date.day,
                isToday: isToday,
                isSelected: isSelected,
                hasEvent: hasEvent,
                eventIcon: eventIcon,
                onTap: () => onDateSelected(date),
              );
            },
          ),
        ),
        const SizedBox(height: 12),
        _CalendarDetailPanel(selectedDate: selectedDate),
      ],
    );
  }
}

class _CalendarDetailPanel extends StatelessWidget {
  const _CalendarDetailPanel({required this.selectedDate});

  final DateTime selectedDate;

  @override
  Widget build(BuildContext context) {
    final eventLabel = MockEvents.eventFor(selectedDate);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6)],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(eventLabel != null ? Icons.event_available : Icons.event_busy,
              color: eventLabel != null ? const Color.fromARGB(255, 176, 123, 92) : Colors.grey, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              eventLabel != null
                  ? '$eventLabel on ${selectedDate.day}/${selectedDate.month}/${selectedDate.year}'
                  : 'No appointments on ${selectedDate.day}/${selectedDate.month}/${selectedDate.year}',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.baloo2(fontSize: 13, fontWeight: FontWeight.w500, height: 1.3),
            ),
          ),
        ],
      ),
    );
  }
}

/// 🌟 การ์ดวันที่: สี dusty rose เข้มล็อคไว้ที่ "วันนี้" เท่านั้น ไม่ขยับตามวันที่ถูกเลือก
/// วันที่ถูกเลือก (ไม่ใช่วันนี้) ใช้ dusty rose อ่อน ตัวหนังสือเข้ม
/// วันที่มี event (ไม่ได้เลือก/ไม่ใช่วันนี้) ใช้สีพีช พร้อมไอคอน event (ไม่มี text บอกชื่อ event)
/// ตอนกดค้างจะมี overlay สีเทาอ่อนชั่วคราว ปล่อยนิ้วแล้วกลับสีปกติ
class DateCard extends StatefulWidget {
  const DateCard({
    super.key,
    required this.weekday,
    required this.day,
    required this.isToday,
    required this.isSelected,
    required this.hasEvent,
    required this.eventIcon,
    required this.onTap,
  });

  final String weekday;
  final int day;
  final bool isToday;
  final bool isSelected;
  final bool hasEvent;
  final IconData? eventIcon;
  final VoidCallback onTap;

  @override
  State<DateCard> createState() => _DateCardState();
}

class _DateCardState extends State<DateCard> {
  bool _isPressed = false;

  static const Color _todayColor = Color.fromARGB(255, 186, 111, 125);
  static const Color _selectedLightColor = Color(0xFFF3DBE0);
  static const Color _eventColor = Color.fromARGB(255, 255, 217, 193);
  static const Color _normalColor = Color(0xFFF1F1F3);
  static const Color _pressedOverlay = Color(0xFFE3E3E5);

  @override
  Widget build(BuildContext context) {
    Color backgroundColor;
    Color textColor;
    Color subTextColor;

    if (widget.isToday) {
      backgroundColor = _todayColor;
      textColor = Colors.white;
      subTextColor = Colors.white70;
    } else if (widget.isSelected) {
      backgroundColor = _selectedLightColor;
      textColor = const Color(0xFF1A1A1A);
      subTextColor = const Color(0xFF8A5A63);
    } else if (widget.hasEvent) {
      backgroundColor = _eventColor;
      textColor = const Color(0xFF1A1A1A);
      subTextColor = const Color(0xFF6B6B6B);
    } else {
      backgroundColor = _normalColor;
      textColor = const Color(0xFF1A1A1A);
      subTextColor = Colors.grey.shade400;
    }

    // 🌟 ลูกเล่นตอนกดค้าง: ทับด้วยสีเทาอ่อนชั่วคราว ไม่เปลี่ยน state จริง
    if (_isPressed) {
      backgroundColor = Color.alphaBlend(_pressedOverlay.withOpacity(0.55), backgroundColor);
    }

    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) => setState(() => _isPressed = false),
      onTapCancel: () => setState(() => _isPressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        width: 100,
        margin: const EdgeInsets.only(right: 14),
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(20),
          boxShadow: widget.isToday
              ? [BoxShadow(color: _todayColor.withOpacity(0.35), blurRadius: 10, offset: const Offset(0, 4))]
              : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(widget.weekday,
                style: GoogleFonts.baloo2(fontSize: 16, color: subTextColor, fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            Text('${widget.day}',
                style: GoogleFonts.baloo2(fontSize: 30, fontWeight: FontWeight.w700, color: textColor)),
            const SizedBox(height: 8),
            if (widget.eventIcon != null) Icon(widget.eventIcon, size: 22, color: subTextColor),
          ],
        ),
      ),
    );
  }
}