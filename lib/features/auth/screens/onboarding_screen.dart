import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  // Step 1 - Family Name
  final _familyNameController = TextEditingController();

  // Step 2 - Child Information
  final _childNameController = TextEditingController();
  final _weightController = TextEditingController();
  DateTime? _selectedBirthdate;
  bool _isLoading = false;

  void _nextPage() {
    _pageController.nextPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
    setState(() => _currentPage++);
  }

  Future<void> _saveAndFinish() async {
    if (_childNameController.text.isEmpty ||
        _weightController.text.isEmpty ||
        _selectedBirthdate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('กรุณากรอกข้อมูลเด็กให้ครบ')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final supabase = Supabase.instance.client;
      final userId = supabase.auth.currentUser!.id;

      // Update family name
      final profile = await supabase
          .from('profiles')
          .select('family_id')
          .eq('id', userId)
          .single();

      final familyId = profile['family_id'];

      await supabase
          .from('families')
          .update({'name': _familyNameController.text.trim()})
          .eq('id', familyId);

      // Add child information
      await supabase.from('children').insert({
        'family_id': familyId,
        'name': _childNameController.text.trim(),
        'birthdate': _selectedBirthdate!.toIso8601String().split('T')[0],
        'weight_kg': double.parse(_weightController.text),
      });

      // mark onboarding complete by updating profile
      await supabase
          .from('profiles')
          .update({'onboarding_complete': true})
          .eq('id', userId);

      // AuthGate จะ detect และไป Dashboard เอง
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('เกิดข้อผิดพลาด: $e')),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Progress indicator
            Padding(
              padding: const EdgeInsets.all(24),
              child: Row(
                children: List.generate(3, (index) {
                  return Expanded(
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      height: 4,
                      decoration: BoxDecoration(
                        color: index <= _currentPage
                            ? Colors.blue
                            : Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  );
                }),
              ),
            ),

            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _buildStep1(),
                  _buildStep2(),
                  _buildStep3(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Step 1: Welcome + Set Family Name
  Widget _buildStep1() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 32),
          const Text('Welcome to CareKids!',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text('Get started by setting your family name',
              style: TextStyle(fontSize: 16, color: Colors.grey)),
          const SizedBox(height: 32),
          TextField(
            controller: _familyNameController,
            decoration: const InputDecoration(
              labelText: 'Family Name e.g., The Smiths',
              border: OutlineInputBorder(),
            ),
          ),
          const Spacer(),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _familyNameController.text.isEmpty ? null : _nextPage,
              child: const Text('Next'),
            ),
          ),
        ],
      ),
    );
  }

  // Step 2: Add Child Information
  Widget _buildStep2() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 32),
          const Text('Add Child Information 👶',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text('This information is used to calculate appropriate medication dosages',
              style: TextStyle(fontSize: 16, color: Colors.grey)),
          const SizedBox(height: 32),
          TextField(
            controller: _childNameController,
            decoration: const InputDecoration(
              labelText: 'Child\'s Name',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _weightController,
            decoration: const InputDecoration(
              labelText: 'Weight (kg)',
              border: OutlineInputBorder(),
            ),
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 16),
          OutlinedButton(
            onPressed: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: DateTime.now(),
                firstDate: DateTime(2000),
                lastDate: DateTime.now(),
              );
              if (picked != null) {
                setState(() => _selectedBirthdate = picked);
              }
            },
            child: Text(_selectedBirthdate == null
                ? 'Select Birthdate'
                : 'Birthdate: ${_selectedBirthdate!.day}/${_selectedBirthdate!.month}/${_selectedBirthdate!.year}'),
          ),
          const Spacer(),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _nextPage,
              child: const Text('Next'),
            ),
          ),
        ],
      ),
    );
  }

  // Step 3: Invite Caregivers (Skip Option)
  Widget _buildStep3() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 32),
          const Text('Invite Caregivers 👨‍👩‍👧',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text(
              'Share this code with your parents, guardians, or caregivers to join your family.',
              style: TextStyle(fontSize: 16, color: Colors.grey)),
          const SizedBox(height: 32),
          FutureBuilder(
            future: Supabase.instance.client
                .from('profiles')
                .select('family_id')
                .eq('id', Supabase.instance.client.auth.currentUser!.id)
                .single(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const CircularProgressIndicator();
              return FutureBuilder(
                future: Supabase.instance.client
                    .from('families')
                    .select('invite_code')
                    .eq('id', snapshot.data!['family_id'])
                    .single(),
                builder: (context, familySnapshot) {
                  if (!familySnapshot.hasData) {
                    return const CircularProgressIndicator();
                  }
                  final code = familySnapshot.data!['invite_code'];
                  return Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(code,
                            style: const TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 4)),
                        IconButton(
                          icon: const Icon(Icons.copy),
                          onPressed: () {
                            // copy to clipboard
                          },
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
          const Spacer(),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _saveAndFinish,
              child: _isLoading
                  ? const CircularProgressIndicator()
                  : const Text('Get Started with CareKids!'),
            ),
          ),
          TextButton(
            onPressed: _isLoading ? null : _saveAndFinish,
            child: const Text('Skip for Now Invite Later'),
          ),
        ],
      ),
    );
  }
}