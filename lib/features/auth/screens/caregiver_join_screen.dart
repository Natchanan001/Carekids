import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:carekids/features/dashboard/screens/dashboard_screen.dart'; 

class CaregiverJoinScreen extends StatefulWidget {
  const CaregiverJoinScreen({super.key});

  @override
  State<CaregiverJoinScreen> createState() => _CaregiverJoinScreenState();
}

class _CaregiverJoinScreenState extends State<CaregiverJoinScreen> {
  final _codeController = TextEditingController();
  bool _isLoading = false;

  // จุดแก้ที่ 2: เพิ่มตัวแปรสเตทคุมการกดย้อนกลับแบบไดนามิกหลังจากทำงานสำเร็จ
  bool _joinFinished = false;

  Future<void> _join() async {
    setState(() => _isLoading = true);
    final supabase = Supabase.instance.client;

    try {
      final user = supabase.auth.currentUser!;
      final meta = user.userMetadata ?? {};

      // ค้นหา family จาก invite code
      final family = await supabase
          .from('families')
          .select('id')
          .eq('invite_code', _codeController.text.trim())
          .maybeSingle();

      if (family == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Invitation code not found')),
          );
        }
        return;
      }

      // สร้าง profile เป็น caregiver
      await supabase.from('profiles').insert({
        'id': user.id,
        'family_id': family['id'],
        'first_name': meta['first_name'] ?? '',
        'last_name': meta['last_name'] ?? '',
        'role': 'caregiver',
        'onboarding_complete': true,
      });

      // จุดแก้ที่ 3: สับสวิตช์ล็อกปุ่ม Back และใช้ pushAndRemoveUntil วาร์ปเคลียร์ Stack ส่งไปหน้า Dashboard ตรง ๆ
      if (mounted) {
        setState(() => _joinFinished = true);

        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const DashboardScreen()),
          (route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // จุดแก้ที่ 4: นำ PopScope มาห่อหุ้ม Scaffold เพื่อคุมสิทธิ์ปุ่ม Back ตามสเตท
    return PopScope(
      canPop: !_joinFinished, // ล็อกทันทีเมื่อสลับสเตทเป็น true หลังจากกดเข้าร่วมครอบครัวสำเร็จ
      child: Scaffold(
        appBar: AppBar(title: const Text('Join Family')),
        body: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const Text('Enter the invitation code you received from a parent',
                  style: TextStyle(fontSize: 16, color: Colors.grey)),
              const SizedBox(height: 24),
              TextField(
                controller: _codeController,
                decoration: const InputDecoration(
                  labelText: 'Invitation Code',
                  border: OutlineInputBorder(),
                ),
                textCapitalization: TextCapitalization.characters,
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _join,
                  child: _isLoading
                      ? const CircularProgressIndicator()
                      : const Text('Join Family'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}