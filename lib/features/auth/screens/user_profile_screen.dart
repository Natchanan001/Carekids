import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class UserProfileScreen extends StatefulWidget {
  const UserProfileScreen({super.key});

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  bool _isLoading = true;
  bool _isSaving = false;
  String? _role;

  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    setState(() => _isLoading = true);
    try {
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser!;
      final profile = await supabase
          .from('profiles')
          .select('first_name, last_name, phone_number, role')
          .eq('id', user.id)
          .single();

      _firstNameController.text = profile['first_name']?.toString() ?? '';
      _lastNameController.text = profile['last_name']?.toString() ?? '';
      _phoneController.text = profile['phone_number']?.toString() ?? '';
      _emailController.text = user.email ?? '';
      _role = profile['role'];
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load profile: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _save() async {
    if (_firstNameController.text.trim().isEmpty ||
        _lastNameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Name cannot be empty')),
      );
      return;
    }

    final phoneDigitsOnly = RegExp(r'^[0-9]+$');
    if (_phoneController.text.trim().isNotEmpty &&
        !phoneDigitsOnly.hasMatch(_phoneController.text.trim())) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Phone number must contain digits only')),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      final supabase = Supabase.instance.client;
      final userId = supabase.auth.currentUser!.id;
      final currentEmail = supabase.auth.currentUser!.email;

      await supabase.from('profiles').update({
        'first_name': _firstNameController.text.trim(),
        'last_name': _lastNameController.text.trim(),
        'phone_number': _phoneController.text.trim(),
      }).eq('id', userId);

      final newEmail = _emailController.text.trim();
      // 🌟 แยก flow การเปลี่ยนอีเมล เพราะ Supabase ต้องยืนยันที่อีเมลใหม่ก่อนเปลี่ยนจริง
      if (newEmail.isNotEmpty && newEmail != currentEmail) {
        await supabase.auth.updateUser(UserAttributes(email: newEmail));
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Profile updated. Check your new email inbox to confirm the change.'),
              duration: Duration(seconds: 5),
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Profile updated ✅')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update profile: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      appBar: AppBar(
        title: const Text('Profile'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Column(
                      children: [
                        CircleAvatar(
                          radius: 40,
                          backgroundColor: Colors.purple.shade100,
                          child: Text(
                            _firstNameController.text.isNotEmpty
                                ? _firstNameController.text[0].toUpperCase()
                                : '?',
                            style: const TextStyle(fontSize: 28, color: Colors.black87),
                          ),
                        ),
                        const SizedBox(height: 8),
                        if (_role != null)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                            decoration: BoxDecoration(
                              color: _role == 'admin' ? Colors.blue.shade50 : Colors.green.shade50,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              _role == 'admin' ? 'Parent (Admin)' : 'Caregiver',
                              style: TextStyle(
                                fontSize: 12,
                                color: _role == 'admin' ? Colors.blue.shade800 : Colors.green.shade800,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),

                  const Text('Account Information',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 12),

                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8)],
                    ),
                    child: Column(
                      children: [
                        TextField(
                          controller: _firstNameController,
                          decoration: const InputDecoration(
                              labelText: 'First Name', border: OutlineInputBorder()),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _lastNameController,
                          decoration: const InputDecoration(
                              labelText: 'Last Name', border: OutlineInputBorder()),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _emailController,
                          decoration: const InputDecoration(
                              labelText: 'Email', border: OutlineInputBorder()),
                          keyboardType: TextInputType.emailAddress,
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _phoneController,
                          decoration: const InputDecoration(
                              labelText: 'Phone Number', border: OutlineInputBorder()),
                          keyboardType: TextInputType.phone,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isSaving ? null : _save,
                      child: _isSaving
                          ? const SizedBox(
                              height: 20, width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Text('Save Changes'),
                    ),
                  ),

                  const SizedBox(height: 32),
                  const Text('App Settings',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 12),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8)],
                    ),
                    child: ListTile(
                      leading: const Icon(Icons.settings_outlined),
                      title: const Text('App Settings'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('App settings is coming soon 🚧')),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}