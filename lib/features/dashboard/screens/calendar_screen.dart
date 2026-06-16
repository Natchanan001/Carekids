import 'package:flutter/material.dart';
import 'package:carekids/shared/utils/date_utils.dart';
import 'package:carekids/shared/utils/mock_events.dart';
import 'package:carekids/features/dashboard/screens/month_view_screen.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  // 🌟 จำกัดช่วงปีที่เลื่อนดูได้ (50 ปีย้อนหลัง / 50 ปีล่วงหน้า) กว้างพอใช้งานจริง
  static const int _yearsBack = 50;
  static const int _yearsForward = 50;

  late PageController _pageController;
  late int _initialPageIndex;

  @override
  void initState() {
    super.initState();
    _initialPageIndex = _yearsBack; // index นี้ = ปีปัจจุบัน
    _pageController = PageController(initialPage: _initialPageIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  int _yearForIndex(int index) => DateTime.now().year - _yearsBack + index;

  void _goToToday() {
    _pageController.animateToPage(
      _initialPageIndex,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  void _openMonth(int year, int month) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MonthViewScreen(initialMonth: DateTime(year, month, 1)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      appBar: AppBar(
        title: const Text('Calendar'),
        actions: [
          TextButton(onPressed: _goToToday, child: const Text('Today')),
        ],
      ),
      body: PageView.builder(
        controller: _pageController,
        itemCount: _yearsBack + _yearsForward + 1,
        itemBuilder: (context, index) {
          final year = _yearForIndex(index);
          return _buildYearPage(year);
        },
      ),
    );
  }

  Widget _buildYearPage(int year) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Text(
            '$year',
            style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
          ),
        ),
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 0.8,
            ),
            itemCount: 12,
            itemBuilder: (context, index) {
              final month = index + 1;
              return _MiniMonth(
                year: year,
                month: month,
                onTap: () => _openMonth(year, month),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _MiniMonth extends StatelessWidget {
  final int year;
  final int month;
  final VoidCallback onTap;

  const _MiniMonth({
    required this.year,
    required this.month,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final today = MockEvents.today;
    final isCurrentMonth = year == today.year && month == today.month;
    final totalDays = daysInMonth(year, month);
    final firstWeekday = DateTime(year, month, 1).weekday; // 1=Mon..7=Sun
    final leadingBlanks = firstWeekday - 1;
    final totalCells = leadingBlanks + totalDays;
    final rows = (totalCells / 7).ceil();

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: isCurrentMonth
              ? Border.all(color: const Color(0xFF2F80ED), width: 1.4)
              : null,
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6),
          ],
        ),
        child: Column(
          children: [
            Text(
              monthShortNames[month - 1],
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: isCurrentMonth ? const Color(0xFF2F80ED) : Colors.black87,
              ),
            ),
            const SizedBox(height: 3),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: List.generate(rows, (rowIndex) {
                  return Expanded(
                    child: Row(
                      children: List.generate(7, (colIndex) {
                        final cellIndex = rowIndex * 7 + colIndex;
                        final dayNumber = cellIndex - leadingBlanks + 1;
                        final isValidDay = dayNumber >= 1 && dayNumber <= totalDays;
                        final isToday =
                            isValidDay && isCurrentMonth && dayNumber == today.day;

                        return Expanded(
                          child: Center(
                            child: !isValidDay
                                ? const SizedBox.shrink()
                                : Container(
                                    width: 12,
                                    height: 12,
                                    alignment: Alignment.center,
                                    decoration: isToday
                                        ? const BoxDecoration(
                                            color: Color(0xFF2F80ED),
                                            shape: BoxShape.circle,
                                          )
                                        : null,
                                    child: Text(
                                      '$dayNumber',
                                      style: TextStyle(
                                        fontSize: 7,
                                        color: isToday ? Colors.white : Colors.black54,
                                      ),
                                    ),
                                  ),
                          ),
                        );
                      }),
                    ),
                  );
                }),
              ),
            ),
          ],
        ),
      ),
    );
  }
}