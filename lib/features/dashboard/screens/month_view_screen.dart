import 'package:flutter/material.dart';
import 'package:carekids/shared/utils/date_utils.dart';
import 'package:carekids/shared/utils/mock_events.dart';

class MonthViewScreen extends StatefulWidget {
  final DateTime initialMonth; // วันใดก็ได้ในเดือนที่ต้องการเปิดดู

  const MonthViewScreen({super.key, required this.initialMonth});

  @override
  State<MonthViewScreen> createState() => _MonthViewScreenState();
}

class _MonthViewScreenState extends State<MonthViewScreen> {
  // 🌟 ช่วงเดือนที่เลื่อนดูได้ (1900-2100) กว้างพอใช้งานจริง
  static const int _baseYear = 1900;
  static const int _endYear = 2100;
  static const int _totalMonths = (_endYear - _baseYear + 1) * 12;

  late PageController _pageController;
  late int _initialIndex;
  late DateTime _visibleMonth;
  late DateTime _selectedDate;

  int _indexForMonth(DateTime d) => (d.year - _baseYear) * 12 + (d.month - 1);

  DateTime _monthForIndex(int index) {
    final year = _baseYear + index ~/ 12;
    final month = (index % 12) + 1;
    return DateTime(year, month, 1);
  }

  @override
  void initState() {
    super.initState();
    _visibleMonth = DateTime(widget.initialMonth.year, widget.initialMonth.month, 1);
    _initialIndex = _indexForMonth(_visibleMonth);
    _pageController = PageController(initialPage: _initialIndex);

    final today = MockEvents.today;
    _selectedDate = (_visibleMonth.year == today.year && _visibleMonth.month == today.month)
        ? today
        : _visibleMonth;
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _goToToday() {
    final today = MockEvents.today;
    final todayIndex = _indexForMonth(DateTime(today.year, today.month, 1));
    setState(() {
      _visibleMonth = DateTime(today.year, today.month, 1);
      _selectedDate = today;
    });
    _pageController.animateToPage(
      todayIndex,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      appBar: AppBar(
        title: Text('${monthFullNames[_visibleMonth.month - 1]} ${_visibleMonth.year}'),
        actions: [
          TextButton(onPressed: _goToToday, child: const Text('Today')),
        ],
      ),
      body: Column(
        children: [
          _buildWeekdayHeader(),
          Expanded(
            child: PageView.builder(
              controller: _pageController,
              itemCount: _totalMonths,
              onPageChanged: (index) {
                final newMonth = _monthForIndex(index);
                final today = MockEvents.today;
                setState(() {
                  _visibleMonth = newMonth;
                  _selectedDate =
                      (newMonth.year == today.year && newMonth.month == today.month)
                          ? today
                          : newMonth;
                });
              },
              itemBuilder: (context, index) => _buildMonthGrid(_monthForIndex(index)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: _buildDetailPanel(),
          ),
        ],
      ),
    );
  }

  Widget _buildWeekdayHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: weekdayShortNames
            .map((d) => Expanded(
                  child: Center(
                    child: Text(d, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                  ),
                ))
            .toList(),
      ),
    );
  }

  Widget _buildMonthGrid(DateTime monthDate) {
    final year = monthDate.year;
    final month = monthDate.month;
    final totalDays = daysInMonth(year, month);
    final firstWeekday = DateTime(year, month, 1).weekday; // 1=Mon..7=Sun
    final leadingBlanks = firstWeekday - 1;
    final totalCells = leadingBlanks + totalDays;
    final rows = (totalCells / 7).ceil();
    final today = MockEvents.today;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Column(
        children: List.generate(rows, (rowIndex) {
          return Expanded(
            child: Row(
              children: List.generate(7, (colIndex) {
                final cellIndex = rowIndex * 7 + colIndex;
                final dayNumber = cellIndex - leadingBlanks + 1;
                final isValidDay = dayNumber >= 1 && dayNumber <= totalDays;

                if (!isValidDay) {
                  return const Expanded(child: SizedBox());
                }

                final date = DateTime(year, month, dayNumber);
                final isToday = isSameDate(date, today);
                final isSelected = isSameDate(date, _selectedDate);
                final hasEvent = MockEvents.hasEvent(date);

                return Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _selectedDate = date),
                    child: Container(
                      margin: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? const Color(0xFF2F80ED)
                            : (isToday ? const Color(0xFF2F80ED).withOpacity(0.12) : null),
                        shape: BoxShape.circle,
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            '$dayNumber',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                              color: isSelected
                                  ? Colors.white
                                  : (isToday ? const Color(0xFF2F80ED) : Colors.black87),
                            ),
                          ),
                          if (hasEvent)
                            Container(
                              margin: const EdgeInsets.only(top: 2),
                              width: 4,
                              height: 4,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: isSelected ? Colors.white : Colors.orange,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildDetailPanel() {
    final eventLabel = MockEvents.eventFor(_selectedDate);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6)],
      ),
      child: Row(
        children: [
          Icon(
            eventLabel != null ? Icons.event_available : Icons.event_busy,
            color: eventLabel != null ? const Color(0xFF2F80ED) : Colors.grey,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              eventLabel != null
                  ? '$eventLabel on ${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}'
                  : 'No appointments on ${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}',
              style: const TextStyle(fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}