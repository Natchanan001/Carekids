import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:carekids/features/auth/screens/login_screen.dart'; // 🌟 อย่าลืมอ้างอิง path ให้ถูกน้า

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('CareKids Dashboard'),
        // 🌟 ใส่ปุ่ม Actions ดีบั๊กไว้ตรงมุมขวาบนของ AppBar
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.red),
            tooltip: 'Sign Out (Debug)',
            onPressed: () async {
              // 1. สั่งเอาเซสชันออกจาก Supabase
              await Supabase.instance.client.auth.signOut();
              
              // 2. ทลาย Stack หน้าจอทั้งหมดทิ้งแล้ววาร์ปกลับไปหน้า LoginScreen แบบคลีนๆ
              if (context.mounted) {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                  (route) => false,
                );
              }
            },
          ),
        ],
      ),
      body: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Welcome to Dashboard 🎉',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text(
              'ปุ่ม Log out ดีบั๊กอยู่มุมขวาบนนะจ๊ะ พส.',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}