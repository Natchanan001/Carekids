import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AdminApprovalScreen extends StatefulWidget {
  const AdminApprovalScreen({super.key});

  @override
  State<AdminApprovalScreen> createState() => _AdminApprovalScreenState();
}

class _AdminApprovalScreenState extends State<AdminApprovalScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _pendingRequests = [];

  @override
  void initState() {
    super.initState();
    _loadRequests();
  }

  Future<void> _loadRequests() async {
    setState(() => _isLoading = true);
    try {
      final data = await Supabase.instance.client
          .from('join_requests')
          .select()
          .eq('status', 'pending')
          .order('created_at');

      _pendingRequests = List<Map<String, dynamic>>.from(data);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load requests: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _reject(Map<String, dynamic> request) async {
    try {
      await Supabase.instance.client
          .from('join_requests')
          .delete()
          .eq('id', request['id']);
      _loadRequests();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to decline: $e')),
        );
      }
    }
  }

  Future<void> _accept(Map<String, dynamic> request) async {
    final chosenRole = await showDialog<String>(
      context: context,
      builder: (context) {
        String? selected;
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: Text(
                  'Assign a role for ${request['requester_first_name']} ${request['requester_last_name']}'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  RadioListTile<String>(
                    title: const Text('Parent (Admin)'),
                    subtitle: const Text('Full access, same as you'),
                    value: 'admin',
                    groupValue: selected,
                    onChanged: (v) => setStateDialog(() => selected = v),
                  ),
                  RadioListTile<String>(
                    title: const Text('Caregiver'),
                    subtitle: const Text('Limited access to sensitive data'),
                    value: 'caregiver',
                    groupValue: selected,
                    onChanged: (v) => setStateDialog(() => selected = v),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: selected == null ? null : () => Navigator.pop(context, selected),
                  child: const Text('Confirm'),
                ),
              ],
            );
          },
        );
      },
    );

    if (chosenRole == null) return;

    try {
      final supabase = Supabase.instance.client;
      final adminId = supabase.auth.currentUser!.id;

      await supabase.from('join_requests').update({
        'status': 'approved',
        'resolved_at': DateTime.now().toIso8601String(),
        'resolved_by': adminId,
      }).eq('id', request['id']);

      await supabase.from('profiles').insert({
        'id': request['user_id'],
        'family_id': request['family_id'],
        'first_name': request['requester_first_name'],
        'last_name': request['requester_last_name'],
        'phone_number': request['requester_phone'],
        'role': chosenRole,
        'onboarding_complete': true,
      });

      _loadRequests();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Approved ✅')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to approve: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Pending Join Requests')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _pendingRequests.isEmpty
              ? const Center(child: Text('No pending requests 🎉'))
              : RefreshIndicator(
                  onRefresh: _loadRequests,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _pendingRequests.length,
                    itemBuilder: (context, index) {
                      final r = _pendingRequests[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${r['requester_first_name']} ${r['requester_last_name']}',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                              ),
                              if ((r['requester_phone'] ?? '').isNotEmpty)
                                Text(r['requester_phone'], style: const TextStyle(color: Colors.grey)),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton(
                                      onPressed: () => _reject(r),
                                      style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                                      child: const Text('Decline'),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: ElevatedButton(
                                      onPressed: () => _accept(r),
                                      child: const Text('Accept'),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}