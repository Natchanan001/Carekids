import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
// หน้าเก่า ไม่ใช่แล้ว !!!!!!
class CaregiverJoinScreen extends StatefulWidget {
  final VoidCallback onFinished;
  final VoidCallback? onBack; // 🌟 เพิ่มตัวแปรรับฟังก์ชัน Callback ย้อนกลับ

  const CaregiverJoinScreen({
    super.key,
    required this.onFinished,
    this.onBack, // 🌟 ใส่ใน constructor
  });

  @override
  State<CaregiverJoinScreen> createState() => _CaregiverJoinScreenState();
}

class _CaregiverJoinScreenState extends State<CaregiverJoinScreen> {
  final _codeController = TextEditingController();
  bool _isLoading = false;

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
            const SnackBar(
              content: Text('Invitation code not found'),
            ),
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

      if (mounted) {
        widget.onFinished();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Join Family'),
        // 🌟 เพิ่มปุ่มย้อนกลับตรงนี้เพื่อไปเรียกใช้คำสั่งเคลียร์สเตทโรลใน AuthGate
        leading: widget.onBack != null
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: widget.onBack,
              )
            : null,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const Text(
              'Enter the invitation code you received from a parent',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey,
              ),
            ),
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
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                        ),
                      )
                    : const Text('Join Family'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}