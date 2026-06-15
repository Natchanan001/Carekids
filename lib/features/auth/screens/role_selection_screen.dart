import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:carekids/features/auth/screens/role_selection_screen.dart';

class RoleSelectionScreen extends StatelessWidget {
  final void Function(String role) onRoleSelected;

  const RoleSelectionScreen({super.key, required this.onRoleSelected});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('Welcome to CareKids! 👋',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              const Text('Who are you in the family?',
                  style: TextStyle(fontSize: 16, color: Colors.grey)),
              const SizedBox(height: 32),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => onRoleSelected('admin'),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Text('I am a parent (create a new family)'),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => onRoleSelected('caregiver'),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Text('I am a caregiver (have an invitation code)'),
                  ),
                ),
              ),

              TextButton(
                onPressed: () async {
                  await Supabase.instance.client.auth.signOut();
                  // AuthGate จะ detect แล้วเด้งไป LoginScreen ให้เองอัตโนมัติ
                },
                child: const Text('Sign out (debug)'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}