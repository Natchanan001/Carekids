import 'dart:async'; 
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:carekids/features/auth/screens/login_screen.dart';
import 'package:carekids/features/auth/screens/register_screen.dart';
import 'package:carekids/features/auth/screens/reset_password_screen.dart';
import 'package:carekids/features/auth/screens/onboarding_screen.dart';
import 'package:carekids/features/auth/screens/workspace_selection_screen.dart';
import 'package:carekids/features/auth/screens/join_family_screen.dart';
import 'package:carekids/features/auth/screens/pending_approval_screen.dart';
import 'package:carekids/features/dashboard/screens/dashboard_screen.dart';
import 'package:carekids/shared/models/saved_account.dart';
import 'package:carekids/shared/utils/account_manager.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  bool _showRegister = false;
  bool _isPasswordRecovery = false; // 🌟 true เมื่อเข้าแอปผ่านลิงก์ reset password ในอีเมล

  String? _selectedPath;
  Future<Map<String, dynamic>?>? _profileFuture;
  Future<Map<String, dynamic>?>? _joinRequestFuture;
  String? _lastUserId;
  
  StreamSubscription<AuthState>? _authStateSubscription; // 🌟 ประกาศตัวแปรเก็บ Listener

  // 🌟 เพิ่ม initState ดักฟัง token refresh ตามรูป
  @override
  void initState() {
    super.initState();
    // ฟัง token refresh event เพื่ออัปเดต saved account ให้มี token ล่าสุดเสมอ
    // 🌟 และฟัง passwordRecovery event ตอนผู้ใช้กดลิงก์ reset password จากอีเมล
    // (Supabase SDK จะ emit event นี้เองอัตโนมัติเมื่อแอปถูกเปิดผ่าน deep link
    // carekids://reset-password ที่ตั้งค่าไว้ใน Supabase Dashboard)
    _authStateSubscription = Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      final event = data.event;
      final session = data.session;

      if (event == AuthChangeEvent.passwordRecovery) {
        setState(() => _isPasswordRecovery = true);
        return;
      }

      if (session != null && (event == AuthChangeEvent.tokenRefreshed || event == AuthChangeEvent.signedIn)) {
        _persistAccount(session);
      }
    });
  }

  // 🌟 เพิ่ม dispose เพื่อเคลียร์ Listener ออกตอนปิดหน้าจอนี้ทิ้ง (ป้องกัน memory leak)
  @override
  void dispose() {
    _authStateSubscription?.cancel();
    super.dispose();
  }

  void _ensureFuturesLoaded(Session session) {
    final userId = session.user.id;
    if (_lastUserId == userId && _profileFuture != null) return;
    _lastUserId = userId;
    _profileFuture = _fetchProfile(userId);
    _joinRequestFuture = _fetchJoinRequest(userId);

    // บันทึกบัญชีนี้เข้า local account history ทันทีที่ detect session ใหม่/เปลี่ยน
    _persistAccount(session);
  }

  Future<Map<String, dynamic>?> _fetchProfile(String userId) {
    return Supabase.instance.client
        .from('profiles')
        .select('onboarding_complete, role, first_name, last_name')
        .eq('id', userId)
        .maybeSingle();
  }

  Future<Map<String, dynamic>?> _fetchJoinRequest(String userId) {
    return Supabase.instance.client
        .from('join_requests')
        .select('status')
        .eq('user_id', userId)
        .order('created_at', ascending: false)
        .limit(1)
        .maybeSingle();
  }

  // บันทึก/อัปเดตบัญชีลง local storage ให้ Account Switcher ใช้สลับได้
  Future<void> _persistAccount(Session session, {Map<String, dynamic>? profile}) async {
    try {
      final user = session.user;
      final meta = user.userMetadata ?? {};
      await AccountManager.saveAccount(SavedAccount(
        userId: user.id,
        email: user.email ?? '',
        firstName: profile?['first_name'] ?? meta['first_name'] ?? '',
        lastName: profile?['last_name'] ?? meta['last_name'] ?? '',
        role: profile?['role'],
        refreshToken: session.refreshToken ?? '',
        lastUsedAt: DateTime.now(),
      ));
    } catch (_) {
      // แค่ feature เสริมสำหรับ debug ไม่ block flow หลักถ้าเขียน local storage ไม่ได้
    }
  }

  void refreshAll() {
    final session = Supabase.instance.client.auth.currentSession;
    if (session == null) return;
    setState(() {
      _profileFuture = _fetchProfile(session.user.id);
      _joinRequestFuture = _fetchJoinRequest(session.user.id);
    });
  }

  void selectPath(String path) => setState(() => _selectedPath = path);
  void resetPath() => setState(() => _selectedPath = null);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: Supabase.instance.client.auth.onAuthStateChange,
      builder: (context, snapshot) {
        final session = Supabase.instance.client.auth.currentSession;

        // 🌟 ถ้าเพิ่งเข้ามาผ่านลิงก์ reset password ให้โชว์หน้านี้ก่อนเสมอ
        // ไม่ปล่อยให้ flow ปกติ (login/dashboard) ทำงานทับ แม้จะมี session ชั่วคราวแล้วก็ตาม
        if (_isPasswordRecovery) {
          return ResetPasswordScreen(
            onResetComplete: () => setState(() => _isPasswordRecovery = false),
          );
        }

        if (session == null) {
          _profileFuture = null;
          _joinRequestFuture = null;
          _lastUserId = null;
          _selectedPath = null;

          if (_showRegister) {
            return RegisterScreen(onSwitchToLogin: () => setState(() => _showRegister = false));
          }
          return LoginScreen(onSwitchToRegister: () => setState(() => _showRegister = true));
        }

        _ensureFuturesLoaded(session);

        return FutureBuilder(
          future: _profileFuture,
          builder: (context, profileSnapshot) {
            if (profileSnapshot.connectionState != ConnectionState.done) {
              return const Scaffold(body: Center(child: CircularProgressIndicator()));
            }
            if (profileSnapshot.hasError) {
              return Scaffold(body: Center(child: Text('Error: ${profileSnapshot.error}')));
            }

            final profile = profileSnapshot.data;

            if (profile != null) {
              // อัปเดต local account history ด้วย role/name ล่าสุดจาก profile
              _persistAccount(session, profile: profile);

              final onboardingComplete = profile['onboarding_complete'] ?? false;
              if (!onboardingComplete) {
                return OnboardingScreen(onFinished: refreshAll);
              }
              return const DashboardScreen();
            }

            return FutureBuilder(
              future: _joinRequestFuture,
              builder: (context, joinSnapshot) {
                if (joinSnapshot.connectionState != ConnectionState.done) {
                  return const Scaffold(body: Center(child: CircularProgressIndicator()));
                }

                final status = joinSnapshot.data?['status'];

                if (status == 'pending') {
                  return PendingApprovalScreen(onResolved: refreshAll);
                }

                if (_selectedPath == 'create') {
                  return OnboardingScreen(onFinished: refreshAll, onBack: resetPath);
                }
                if (_selectedPath == 'join') {
                  return JoinFamilyScreen(onSubmitted: refreshAll, onBack: resetPath);
                }

                return WorkspaceSelectionScreen(onPathSelected: selectPath);
              },
            );
          },
        );
      },
    );
  }
}