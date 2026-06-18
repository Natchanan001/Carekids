import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:carekids/shared/models/saved_account.dart';
import 'package:carekids/shared/utils/account_manager.dart';
import 'package:carekids/features/auth/screens/add_account_login_screen.dart';
import 'package:carekids/features/auth/screens/add_account_register_screen.dart';

class AccountSwitcherScreen extends StatefulWidget {
  const AccountSwitcherScreen({super.key});

  @override
  State<AccountSwitcherScreen> createState() => _AccountSwitcherScreenState();
}

class _AccountSwitcherScreenState extends State<AccountSwitcherScreen> {
  List<SavedAccount> _accounts = [];
  bool _isLoading = true;
  bool _isSwitching = false;

  @override
  void initState() {
    super.initState();
    _loadAccounts();
  }

  Future<void> _loadAccounts() async {
    setState(() => _isLoading = true);
    _accounts = await AccountManager.getSavedAccounts();
    if (mounted) setState(() => _isLoading = false);
  }

  String? get _currentUserId => Supabase.instance.client.auth.currentUser?.id;

  Future<void> _switchTo(SavedAccount account) async {
    if (account.userId == _currentUserId) {
      Navigator.of(context).popUntil((route) => route.isFirst);
      return;
    }

    setState(() => _isSwitching = true);
    try {
      await Supabase.instance.client.auth.setSession(account.refreshToken);
      // 🌟 เด้งกลับ root ทีเดียว ให้ AuthGate แสดงหน้าที่ถูกต้องของบัญชีใหม่เอง
      // (Dashboard / Onboarding / Pending / Workspace Selection ตามสถานะจริง)
      if (mounted) Navigator.of(context).popUntil((route) => route.isFirst);
    } catch (e) {
      await AccountManager.removeAccount(account.userId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Session expired for ${account.displayName}. Please log in again.',
            ),
          ),
        );
        _loadAccounts();
      }
    } finally {
      if (mounted) setState(() => _isSwitching = false);
    }
  }

  Future<void> _removeAccount(SavedAccount account) async {
    await AccountManager.removeAccount(account.userId);
    _loadAccounts();
  }

  void _showAddAccountSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    'Add Account',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.login),
                  title: const Text('Log in to existing account'),
                  onTap: () {
                    Navigator.pop(context); // ปิด sheet
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const AddAccountLoginScreen(),
                      ),
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.person_add),
                  title: const Text('Create new account'),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const AddAccountRegisterScreen(),
                      ),
                    );
                  },
                ),
              ]
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Switch Account')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Stack(
              children: [
                ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    if (_accounts.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 40),
                        child: Center(
                          child: Text('No saved accounts yet on this device', style: TextStyle(color: Colors.grey)),
                        ),
                      ),
                    for (final account in _accounts) _buildAccountTile(account),
                    const SizedBox(height: 12),
                    ListTile(
                      leading: const CircleAvatar(
                        backgroundColor: Color(0xFFE8EEF9),
                        child: Icon(Icons.add, color: Color(0xFF2F80ED)),
                      ),
                      title: const Text('Add Account'),
                      onTap: _showAddAccountSheet,
                    ),
                  ],
                ),
                if (_isSwitching)
                  Container(
                    color: Colors.black.withOpacity(0.2),
                    child: const Center(child: CircularProgressIndicator()),
                  ),
              ],
            ),
    );
  }

  Widget _buildAccountTile(SavedAccount account) {
    final isCurrent = account.userId == _currentUserId;

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: isCurrent ? const Color(0xFF2F80ED) : Colors.grey.shade300,
        child: Text(account.initial, style: TextStyle(color: isCurrent ? Colors.white : Colors.black87)),
      ),
      title: Text(account.displayName),
      subtitle: Text(account.role == null ? account.email : '${account.email} · ${account.role}'),
      trailing: isCurrent
          ? const Text('Current', style: TextStyle(color: Color(0xFF2F80ED), fontWeight: FontWeight.bold))
          : IconButton(
              icon: const Icon(Icons.close, size: 18, color: Colors.grey),
              onPressed: () => _removeAccount(account),
              tooltip: 'Remove from this device',
            ),
      onTap: () => _switchTo(account),
    );
  }
}