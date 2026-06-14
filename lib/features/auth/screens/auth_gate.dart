import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:carekids/features/auth/screens/login_screen.dart';
import 'package:carekids/features/auth/screens/onboarding_screen.dart';
import 'package:carekids/features/auth/screens/role_selection_screen.dart';
import 'package:carekids/features/dashboard/screens/dashboard_screen.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: Supabase.instance.client.auth.onAuthStateChange,
      builder: (context, snapshot) {
        final session = Supabase.instance.client.auth.currentSession;
        if (session == null) return const LoginScreen();

        return FutureBuilder(
          future: Supabase.instance.client
              .from('profiles')
              .select('onboarding_complete, role')
              .eq('id', session.user.id)
              .maybeSingle(),
          builder: (context, profileSnapshot) {
            if (profileSnapshot.hasError) {
            // profile หาไม่เจอ (เช่น user ถูกลบ) → sign out แล้วกลับไป login
              Future.microtask(() {
                Supabase.instance.client.auth.signOut();
              });
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }
            if (profileSnapshot.hasError) {
              return Scaffold(
                body: Center(child: Text('Error: ${profileSnapshot.error}')),
              );
            }

            final profile = profileSnapshot.data;

            // เคสที่ 1: ยูสเซอร์ใหม่เอี่ยม ถังข้อมูลโปรไฟล์ยังว่างเปล่า (null) ให้สับไปหน้าเลือกบทบาท
            if (profile == null) {
              return const RoleSelectionScreen();
            }

            // เคสที่ 2: มีโปรไฟล์แล้ว แต่ยังดู Onboarding แนะนำแอปไม่จบ ให้ส่งไปหน้า OnboardingScreen
            final onboardingComplete = profile['onboarding_complete'] ?? false;
            if (!onboardingComplete) {
              return const OnboardingScreen();
            }

            // เคสที่ 3: ผ่านทุกด่านหมดแล้ว สับเข้าหน้าหลัก Dashboard สวย ๆ (เดี๋ยวเปลี่ยนร่างตอนทำ F002)
            return const DashboardScreen();
          },
        );
      },
    );
  }
}