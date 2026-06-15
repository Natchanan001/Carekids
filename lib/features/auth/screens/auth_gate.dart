import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:carekids/features/auth/screens/login_screen.dart';
import 'package:carekids/features/auth/screens/onboarding_screen.dart';
import 'package:carekids/features/auth/screens/role_selection_screen.dart';
import 'package:carekids/features/auth/screens/caregiver_join_screen.dart';
import 'package:carekids/features/dashboard/screens/dashboard_screen.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  String? _selectedRole; // 'admin' or 'caregiver' เลือกไว้ใน session นี้
  Future<Map<String, dynamic>?>? _profileFuture;
  String? _lastUserId;

  void _ensureProfileLoaded(String userId) {
    if (_lastUserId == userId && _profileFuture != null) return;
    _lastUserId = userId;
    _profileFuture = Supabase.instance.client
        .from('profiles')
        .select('onboarding_complete, role')
        .eq('id', userId)
        .maybeSingle();
  }

  void refreshProfile() {
    final session = Supabase.instance.client.auth.currentSession;
    if (session == null) return;
    setState(() {
      _profileFuture = Supabase.instance.client
          .from('profiles')
          .select('onboarding_complete, role')
          .eq('id', session.user.id)
          .maybeSingle();
    });
  }

  void selectRole(String role) {
    setState(() => _selectedRole = role);
  }

  // 🌟 ฟังก์ชันส่งให้หน้าลูกกดย้อนกลับ เพื่อเคลียร์ค่า Role ค้างสเตท
  void clearRole() {
    setState(() => _selectedRole = null);
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: Supabase.instance.client.auth.onAuthStateChange,
      builder: (context, snapshot) {
        final session = Supabase.instance.client.auth.currentSession;

        if (session == null) {
          _profileFuture = null;
          _lastUserId = null;
          _selectedRole = null;
          return const LoginScreen();
        }

        _ensureProfileLoaded(session.user.id);

        return FutureBuilder(
          future: _profileFuture,
          builder: (context, profileSnapshot) {
            if (profileSnapshot.connectionState != ConnectionState.done) {
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

            // ไม่มี profile เลย -> ต้องเลือก role ก่อน
            if (profile == null) {
              if (_selectedRole == 'admin') {
                return OnboardingScreen(
                  onFinished: refreshProfile,
                  onBack: clearRole, // 🌟 ส่งฟังก์ชันเคลียร์ Role ไปให้หน้า Onboarding
                );
              }
              if (_selectedRole == 'caregiver') {
                return CaregiverJoinScreen(
                  onFinished: refreshProfile,
                  onBack: clearRole, // 🌟 ส่งฟังก์ชันเคลียร์ Role ไปให้หน้า Join
                );
              }
              return RoleSelectionScreen(onRoleSelected: selectRole);
            }

            // มี profile แล้วแต่ onboarding ยังไม่เสร็จ (admin ค้างกลางทาง)
            final onboardingComplete = profile['onboarding_complete'] ?? false;
            if (!onboardingComplete) {
              return OnboardingScreen(
                onFinished: refreshProfile,
                onBack: clearRole, // 🌟 ส่งเคลียร์เผื่อกรณีอื่นๆ ด้วย
              );
            }

            return const DashboardScreen();
          },
        );
      },
    );
  }
}