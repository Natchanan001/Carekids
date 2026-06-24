import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:carekids/features/auth/screens/auth_gate.dart';

// home: const AuthGate(), --- IGNORE ---

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await dotenv.load(fileName: ".env");

  // 🌟 ใช้ค่า default ของ supabase_flutter (PKCE flow) ไม่เปลี่ยนเป็น implicit
  // เพราะ implicit flow ลดความปลอดภัยฝั่ง mobile (เสี่ยงแอปอื่นขโมย session ได้ง่ายขึ้น)
  // PKCE รองรับ resetPasswordForEmail/AuthChangeEvent.passwordRecovery อยู่แล้วตามเอกสารทางการ
  // ถ้าทดสอบ deep link carekids://reset-password แล้ว passwordRecovery event ไม่ทำงาน
  // ให้เช็คเวอร์ชัน supabase_flutter ก่อน (เคยมี bug เก่าในเวอร์ชันก่อนหน้าที่แก้ไปแล้ว)
  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL']!,
    anonKey: dotenv.env['SUPABASE_ANON_KEY']!,
  );

  runApp(const CareKids());
}

class CareKids extends StatelessWidget {
  const CareKids({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
      ),
      home: const AuthGate(),
    );
  }
}