import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PendingApprovalScreen extends StatefulWidget {
  final VoidCallback onResolved;

  const PendingApprovalScreen({super.key, required this.onResolved});

  @override
  State<PendingApprovalScreen> createState() => _PendingApprovalScreenState();
}

class _PendingApprovalScreenState extends State<PendingApprovalScreen> {
  Timer? _pollTimer;
  bool _checking = false;
  bool _isCancelling = false;
  

  @override
  void initState() {
    super.initState();
    _pollTimer = Timer.periodic(const Duration(seconds: 4), (_) => _checkStatus());
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _checkStatus() async {
    if (_checking) return;
    _checking = true;

    try {
      final supabase = Supabase.instance.client;
      final userId = supabase.auth.currentUser!.id;

      final profile = await supabase
          .from('profiles')
          .select('id')
          .eq('id', userId)
          .maybeSingle();

      if (profile != null) {
        _pollTimer?.cancel();
        widget.onResolved();
        return;
      }

      final joinRequest = await supabase
          .from('join_requests')
          .select('status')
          .eq('user_id', userId)
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();

      if (joinRequest == null) {
        // ไม่มี profile และไม่มี join_request เหลืออยู่ -> ถูก Reject
        _pollTimer?.cancel();
        if (mounted) {
          await showDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) => AlertDialog(
              title: const Text('Request Declined'),
              content: const Text(
                  'The family admin declined your request to join. Please check the invitation code with them or try again.'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('OK'),
                ),
              ],
            ),
          );
          widget.onResolved();
        }
      }
    } catch (_) {
      // เงียบไว้ก่อน รอ poll รอบถัดไป
    } finally {
      _checking = false;
    }
  }

  Future<void> _cancelRequest() async {
  setState(() => _isCancelling = true);
  try {
    final supabase = Supabase.instance.client;
    final userId = supabase.auth.currentUser!.id;

    await supabase
        .from('join_requests')
        .delete()
        .eq('user_id', userId)
        .eq('status', 'pending');

    if (mounted) widget.onResolved();
  } catch (e) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to cancel: $e')),
      );
    }
  } finally {
    if (mounted) setState(() => _isCancelling = false);
  }
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.hourglass_top, size: 64, color: Colors.orange),
                const SizedBox(height: 24),
                const Text('Waiting for Approval',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                const Text(
                  'Your request to join the family has been sent. The family admin needs to approve it before you can continue.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 32),
                const CircularProgressIndicator(),
                const SizedBox(height: 24),
                
                OutlinedButton(
                  onPressed: _isCancelling ? null : _cancelRequest,
                  style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                  child: _isCancelling
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Cancel Request'),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () async {
                    await Supabase.instance.client.auth.signOut();
                  },
                  child: const Text('Sign out'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}