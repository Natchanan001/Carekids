import 'package:carekids/shared/utils/date_utils.dart';

/// Mock event data — รอเชื่อมฟีเจอร์ปฏิทิน/นัดหมายจริง (Feature 004+) แล้วค่อยลบออก
/// ใช้ตัวกลางนี้ร่วมกันทั้ง Dashboard strip และหน้า Calendar เต็มรูปแบบ
class MockEvents {
  static final DateTime today = dateOnly(DateTime.now());

  static final Map<DateTime, String> _events = {
    today.add(const Duration(days: 1)): 'Vaccine',
    today.add(const Duration(days: 3)): "Doctor's Appointment",
  };

  static String? eventFor(DateTime date) => _events[dateOnly(date)];

  static bool hasEvent(DateTime date) => eventFor(date) != null;
}