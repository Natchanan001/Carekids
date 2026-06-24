import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class LoginScreen extends StatefulWidget {
  final VoidCallback onSwitchToRegister;

  const LoginScreen({super.key, required this.onSwitchToRegister});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;

  Future<void> _login() async {
    setState(() => _isLoading = true);
    try {
      await Supabase.instance.client.auth.signInWithPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
      // 🌟 ไม่ต้อง Navigator อะไรเลย — AuthGate ยังมีชีวิตอยู่เสมอ จะ detect แล้วไปต่อเองอัตโนมัติ
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to log in: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // 🌟 Forgot Password: เปิด dialog ให้กรอกอีเมล แล้วส่งคำขอ reset ผ่าน Supabase
  // หมายเหตุ: ต้องเปิด "Confirm email" ใน Supabase Auth settings ก่อน ไม่งั้นอีเมล
  // reset จะส่งไม่ถึงผู้ใช้จริง (ใช้ได้เฉพาะอีเมลที่เป็นกล่องจดหมายจริงเท่านั้น)
  Future<void> _forgotPassword() async {
    final controller = TextEditingController(text: _emailController.text.trim());

    final email = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Reset Password'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Enter your email address and we\'ll send you a link to reset your password.'),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              autofocus: true,
              decoration: const InputDecoration(labelText: 'Email', border: OutlineInputBorder()),
              keyboardType: TextInputType.emailAddress,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              final value = controller.text.trim();
              if (value.isEmpty) return;
              Navigator.pop(dialogContext, value);
            },
            child: const Text('Send Reset Link'),
          ),
        ],
      ),
    );

    if (email == null || email.isEmpty) return;

    try {
      await Supabase.instance.client.auth.resetPasswordForEmail(
        email,
        redirectTo: 'carekids://reset-password',
      );
      if (mounted) {
        // 🌟 ข้อความนี้แสดงเหมือนกันไม่ว่าอีเมลจะมีอยู่ในระบบหรือไม่ (security best practice
        // ป้องกันคนนอกเอาฟอร์มนี้ไปเดาว่าอีเมลไหนมี/ไม่มีบัญชีในระบบ)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('If an account exists for this email, a reset link has been sent.'),
            duration: Duration(seconds: 5),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send reset link: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Log In')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            TextField(
              controller: _emailController,
              decoration: const InputDecoration(labelText: 'Email'),
              keyboardType: TextInputType.emailAddress,
            ),
            TextField(
              controller: _passwordController,
              decoration: const InputDecoration(labelText: 'Password'),
              obscureText: true,
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: _isLoading ? null : _forgotPassword,
                child: const Text('Forgot Password?'),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _login,
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Log In'),
              ),
            ),
            TextButton(
              onPressed: widget.onSwitchToRegister,
              child: const Text("Don't have an account? Sign Up"),
            ),
          ],
        ),
      ),
    );
  }
}