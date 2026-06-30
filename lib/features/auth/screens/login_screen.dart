import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
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
  bool _obscurePassword = true;

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
      backgroundColor: const Color(0xFFF8F9FB),
      // 🌟 ลบ AppBar เดิมออก ใช้ layout แบบ full-screen แทน
      body: Stack(
        children: [
          // ── ส่วนบน: gradient พื้นหลัง (สีจาก QuickActionsSection) ──
          Container(
            height: MediaQuery.of(context).size.height * 0.42,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF8FD3A8), Color(0xFFAFD8E8), Color(0xFFF3DFAE)],
                stops: [0.0, 0.55, 1.0],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),

          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 24),

                // ── โลโก้ CareKids (Care ฟ้า + Kids ชมพู) ──
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 28),
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(24),
                        child: IntrinsicWidth(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                padding: const EdgeInsets.only(left: 10, right: 4, top: 8, bottom: 8),
                                color: const Color.fromARGB(255, 48, 147, 239),
                                child: Text('Care',
                                    style: GoogleFonts.baloo2(fontSize: 22, fontWeight: FontWeight.w700, color: Colors.white)),
                              ),
                              Container(
                                padding: const EdgeInsets.only(left: 4, right: 10, top: 8, bottom: 8),
                                color: const Color.fromARGB(255, 243, 78, 141),
                                child: Text('Kids',
                                    style: GoogleFonts.baloo2(fontSize: 22, fontWeight: FontWeight.w700, color: Colors.white)),
                              ),
                            ],
                          ),
                        ),
                      ),
                      Positioned(
                        top: -3,
                        right: -3,
                        child: Container(
                          width: 11,
                          height: 11,
                          decoration: BoxDecoration(
                            color: const Color(0xFF8BC34A),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // ── ข้อความ Hello + Sign in! ──
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 28),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Hello',
                          style: GoogleFonts.baloo2(fontSize: 32, fontWeight: FontWeight.w700, color: const Color(0xFF1A1A1A))),
                      Text('Sign in!',
                          style: GoogleFonts.baloo2(fontSize: 32, fontWeight: FontWeight.w700, color: const Color(0xFF1A1A1A))),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // ── กล่องขาวลอยทับ gradient ──
                Expanded(
                  child: Container(
                    width: double.infinity,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(32),
                        topRight: Radius.circular(32),
                      ),
                      boxShadow: [
                        BoxShadow(color: Color(0x14000000), blurRadius: 20, offset: Offset(0, -4)),
                      ],
                    ),
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(28, 32, 28, 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // ── ช่อง Email ──
                          Text('Email',
                              style: GoogleFonts.baloo2(fontSize: 14, fontWeight: FontWeight.w600, color: const Color(0xFF5B9DF0))),
                          const SizedBox(height: 6),
                          TextField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            style: GoogleFonts.baloo2(fontSize: 15),
                            decoration: InputDecoration(
                              hintText: 'your@email.com',
                              hintStyle: GoogleFonts.baloo2(color: Colors.grey.shade400),
                              suffixIcon: const Icon(Icons.check, color: Color(0xFF8FD3A8), size: 18),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 0, vertical: 10),
                              enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.grey.shade300)),
                              focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF5B9DF0))),
                            ),
                          ),

                          const SizedBox(height: 22),

                          // ── ช่อง Password ──
                          Text('Password',
                              style: GoogleFonts.baloo2(fontSize: 14, fontWeight: FontWeight.w600, color: const Color(0xFF5B9DF0))),
                          const SizedBox(height: 6),
                          TextField(
                            controller: _passwordController,
                            obscureText: _obscurePassword,
                            style: GoogleFonts.baloo2(fontSize: 15),
                            decoration: InputDecoration(
                              hintText: '••••••••',
                              hintStyle: GoogleFonts.baloo2(color: Colors.grey.shade400),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                                  color: Colors.grey.shade500,
                                  size: 20,
                                ),
                                onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                              ),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 0, vertical: 10),
                              enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.grey.shade300)),
                              focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF5B9DF0))),
                            ),
                          ),

                          // ── Forgot Password? ──
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: _isLoading ? null : _forgotPassword,
                              style: TextButton.styleFrom(padding: EdgeInsets.zero),
                              child: Text('Forgot password?',
                                  style: GoogleFonts.baloo2(fontSize: 13, color: Colors.grey.shade600)),
                            ),
                          ),

                          const SizedBox(height: 24),

                          // ── ปุ่ม SIGN IN (gradient ฟ้า→ชมพู) ──
                          SizedBox(
                            width: double.infinity,
                            height: 52,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: _isLoading
                                    ? null
                                    : const LinearGradient(
                                        colors: [Color(0xFF5B9DF0), Color(0xFFEE7BA8)],
                                        begin: Alignment.centerLeft,
                                        end: Alignment.centerRight,
                                      ),
                                color: _isLoading ? Colors.grey.shade300 : null,
                                borderRadius: BorderRadius.circular(26),
                                boxShadow: _isLoading
                                    ? null
                                    : [BoxShadow(color: const Color(0xFF5B9DF0).withOpacity(0.35), blurRadius: 12, offset: const Offset(0, 4))],
                              ),
                              child: ElevatedButton(
                                onPressed: _isLoading ? null : _login,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.transparent,
                                  shadowColor: Colors.transparent,
                                  disabledBackgroundColor: Colors.transparent,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
                                ),
                                child: _isLoading
                                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                    : Text('SIGN IN',
                                        style: GoogleFonts.baloo2(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white, letterSpacing: 1.2)),
                              ),
                            ),
                          ),

                          const SizedBox(height: 24),

                          // ── Sign Up link ──
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text("Don't have account?",
                                  style: GoogleFonts.baloo2(fontSize: 13, color: Colors.grey.shade500)),
                              TextButton(
                                onPressed: widget.onSwitchToRegister,
                                style: TextButton.styleFrom(padding: const EdgeInsets.only(left: 6)),
                                child: Text('Sign up',
                                    style: GoogleFonts.baloo2(fontSize: 14, fontWeight: FontWeight.w700, color: const Color(0xFF5B9DF0))),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}