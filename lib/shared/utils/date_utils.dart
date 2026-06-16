// Date helper functions ใช้ร่วมกันหลายหน้า (Dashboard, Calendar, Month view)

int daysInMonth(int year, int month) => DateTime(year, month + 1, 0).day;

bool isSameDate(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

const List<String> monthShortNames = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

const List<String> monthFullNames = [
  'January', 'February', 'March', 'April', 'May', 'June',
  'July', 'August', 'September', 'October', 'November', 'December',
];

const List<String> weekdayShortNames = [
  'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun',
];