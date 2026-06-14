import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:carekids/features/auth/screens/login_screen.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: Supabase.instance.client.auth.onAuthStateChange,
      builder: (context, snapshot) {
        final session = Supabase.instance.client.auth.currentSession;
        if (session != null) {
          // มี session แล้ว → ไป Dashboard (เดี๋ยวทำทีหลังเฟสอื่น)
          return const Scaffold(
            body: Center(child: Text('Signed in successfully! Redirecting to Dashboard...')),
          );
        }
        return const LoginScreen();
      },
    );
  }
}