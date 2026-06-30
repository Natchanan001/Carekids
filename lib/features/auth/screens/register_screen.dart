import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class RegisterScreen extends StatefulWidget {
  final VoidCallback onSwitchToLogin;

  const RegisterScreen({super.key, required this.onSwitchToLogin});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;

  Future<void> _register() async {
    if (_firstNameController.text.isEmpty ||
        _lastNameController.text.isEmpty ||
        _emailController.text.isEmpty ||
        _phoneController.text.isEmpty ||
        _passwordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in all fields')),
      );
      return;
    }

    final thaiPhonePattern = RegExp(r'^0[0-9]{9}$');
    if (!thaiPhonePattern.hasMatch(_phoneController.text.trim())) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Phone number must be exactly 10 digits and start with 0')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final supabase = Supabase.instance.client;

      await supabase.auth.signUp(
        email: _emailController.text.trim(),
        password: _passwordController.text,
        data: {
          'first_name': _firstNameController.text.trim(),
          'last_name': _lastNameController.text.trim(),
          'phone_number': _phoneController.text.trim(),
        },
      );

      // 🌟 ไม่ต้อง Navigator อะไรเลย — AuthGate ยังมีชีวิตอยู่เสมอ จะ detect session ใหม่
      // แล้วพาไปหน้า Workspace Selection ให้เองอัตโนมัติทันที
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Registration successful!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // helper สร้าง underline TextField ให้ style เหมือนกันทุกช่อง
  Widget _buildField({
    required TextEditingController controller,
    required String label,
    String? hint,
    TextInputType keyboardType = TextInputType.text,
    bool obscure = false,
    Widget? suffix,
    List<TextInputFormatter>? formatters,
    int? maxLength,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: GoogleFonts.baloo2(fontSize: 14, fontWeight: FontWeight.w600, color: const Color(0xFF5B9DF0))),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          obscureText: obscure,
          style: GoogleFonts.baloo2(fontSize: 15),
          inputFormatters: formatters,
          maxLength: maxLength,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: GoogleFonts.baloo2(color: Colors.grey.shade400),
            suffixIcon: suffix,
            counterText: '',
            contentPadding: const EdgeInsets.symmetric(horizontal: 0, vertical: 10),
            enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.grey.shade300)),
            focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF5B9DF0))),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      body: Stack(
        children: [
          // ── ส่วนบน: gradient พื้นหลัง (สีเดียวกับ QuickActionsSection) ──
          Container(
            height: MediaQuery.of(context).size.height * 0.35,
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
                const SizedBox(height: 20),

                // ── โลโก้ CareKids ──
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
                                color: const Color.fromARGB(255, 59, 155, 245),
                                child: Text('Care',
                                    style: GoogleFonts.baloo2(fontSize: 22, fontWeight: FontWeight.w700, color: Colors.white)),
                              ),
                              Container(
                                padding: const EdgeInsets.only(left: 4, right: 10, top: 8, bottom: 8),
                                color: const Color.fromARGB(255, 238, 71, 135),
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

                const SizedBox(height: 14),

                // ── ข้อความ Create Account / Join us! ──
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 28),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Create Account',
                          style: GoogleFonts.baloo2(fontSize: 28, fontWeight: FontWeight.w700, color: const Color(0xFF1A1A1A))),
                      Text('Join us!',
                          style: GoogleFonts.baloo2(fontSize: 28, fontWeight: FontWeight.w700, color: const Color(0xFF1A1A1A))),
                    ],
                  ),
                ),

                const SizedBox(height: 14),

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
                      padding: const EdgeInsets.fromLTRB(28, 28, 28, 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // ── First + Last Name แบบ Row คู่ขนาน ──
                          Row(
                            children: [
                              Expanded(
                                child: _buildField(
                                  controller: _firstNameController,
                                  label: 'First Name',
                                  hint: 'John',
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: _buildField(
                                  controller: _lastNameController,
                                  label: 'Last Name',
                                  hint: 'Doe',
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),

                          _buildField(
                            controller: _emailController,
                            label: 'Email Address',
                            hint: 'your@email.com',
                            keyboardType: TextInputType.emailAddress,
                          ),
                          const SizedBox(height: 20),

                          _buildField(
                            controller: _phoneController,
                            label: 'Phone Number',
                            hint: '0812345678',
                            keyboardType: TextInputType.phone,
                            formatters: [FilteringTextInputFormatter.digitsOnly],
                            maxLength: 10,
                          ),
                          const SizedBox(height: 20),

                          _buildField(
                            controller: _passwordController,
                            label: 'Password',
                            hint: '••••••••',
                            obscure: _obscurePassword,
                            suffix: IconButton(
                              icon: Icon(
                                _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                                color: Colors.grey.shade500,
                                size: 20,
                              ),
                              onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                            ),
                          ),

                          const SizedBox(height: 32),

                          // ── ปุ่ม SIGN UP (gradient ฟ้า→ชมพู) ──
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
                                onPressed: _isLoading ? null : _register,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.transparent,
                                  shadowColor: Colors.transparent,
                                  disabledBackgroundColor: Colors.transparent,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
                                ),
                                child: _isLoading
                                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                    : Text('SIGN UP',
                                        style: GoogleFonts.baloo2(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white, letterSpacing: 1.2)),
                              ),
                            ),
                          ),

                          const SizedBox(height: 20),

                          // ── กลับไป Log In ──
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text('Already have an account?',
                                  style: GoogleFonts.baloo2(fontSize: 13, color: Colors.grey.shade500)),
                              TextButton(
                                onPressed: widget.onSwitchToLogin,
                                style: TextButton.styleFrom(padding: const EdgeInsets.only(left: 6)),
                                child: Text('Log In',
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