import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:carekids/features/auth/screens/qr_scanner_screen.dart';

class JoinFamilyScreen extends StatefulWidget {
  final VoidCallback onSubmitted;
  final VoidCallback onBack;

  const JoinFamilyScreen({super.key, required this.onSubmitted, required this.onBack});

  @override
  State<JoinFamilyScreen> createState() => _JoinFamilyScreenState();
}

class _JoinFamilyScreenState extends State<JoinFamilyScreen> {
  final _codeController = TextEditingController();
  bool _isLoading = false;

  // เพิ่มฟังก์ชัน _scanQr สำหรับเปิดหน้าสแกนคิวอาร์โค้ด
  Future<void> _scanQr() async {
    final result = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const QrScannerScreen()),
    );
    if (result != null && result.isNotEmpty) {
      setState(() => _codeController.text = result.trim());
    }
  }

  Future<void> _submit() async {
    if (_codeController.text.trim().isEmpty) return;

    setState(() => _isLoading = true);
    final supabase = Supabase.instance.client;

    try {
      final user = supabase.auth.currentUser!;
      final meta = user.userMetadata ?? {};

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

      // สร้างคำขอ join แบบ Pending รอ Admin อนุมัติ ไม่สร้าง profile ทันที
      await supabase.from('join_requests').insert({
        'user_id': user.id,
        'family_id': family['id'],
        'requester_first_name': meta['first_name'] ?? '',
        'requester_last_name': meta['last_name'] ?? '',
        'requester_phone': meta['phone_number'] ?? '',
        'status': 'pending',
      });

      if (mounted) {
        widget.onSubmitted();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('An error occurred: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Join Existing Family')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const Text('Enter the invitation code from your family admin',
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
            
            // 🌟 2. เพิ่มปุ่ม Scan QR Code ตรงนี้ตามเรฟ
            SizedBox(
              width: double.infinity, // ทำให้ปุ่มกว้างเท่าช่องกรอกรหัส
              child: OutlinedButton.icon(
                onPressed: _isLoading ? null : _scanQr,
                icon: const Icon(Icons.qr_code_scanner),
                label: const Text('Scan QR Code Instead'),
              ),
            ),
            const SizedBox(height: 24), // 🌟 เพิ่มระยะห่างก่อนถึงปุ่ม Submit จะได้ไม่ชิดเกิน

            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _isLoading ? null : widget.onBack,
                    child: const Text('Back'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _submit,
                    child: _isLoading
                        ? const SizedBox(
                            height: 20, width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Text('Submit Request'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}