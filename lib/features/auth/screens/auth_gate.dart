import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:carekids/features/auth/screens/login_screen.dart';
import 'package:carekids/features/auth/screens/onboarding_screen.dart';

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
              .single(),
          builder: (context, profileSnapshot) {
            if (!profileSnapshot.hasData) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }

            final profile = profileSnapshot.data!;
            final onboardingComplete =
                profile['onboarding_complete'] ?? false;

            if (!onboardingComplete) return const OnboardingScreen();

            // เดี๋ยวเปลี่ยนเป็น DashboardScreen ตอนทำ F004
            return const Scaffold(
              body: Center(child: Text('Dashboard 🏠')),
            );
          },
        );
      },
    );
  }
}