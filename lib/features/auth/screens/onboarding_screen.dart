import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:carekids/features/dashboard/screens/dashboard_screen.dart';
import 'package:carekids/features/auth/screens/role_selection_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  // 🌟 จุดแก้ที่ 1: เพิ่มตัวแปรเช็กสถานะการสิ้นสุดออนบอร์ดดิ้ง เพื่อเอาไปคุมสิทธิ์การกดย้อนกลับแบบไดนามิก
  bool _onboardingFinished = false;

  // Step 1 - Family Name
  final _familyNameController = TextEditingController();

  // Step 2 - Child Information
  final _childNameController = TextEditingController();
  final _weightController = TextEditingController();
  DateTime? _selectedBirthdate;
  String? _selectedGender; // 'male' or 'female'
  bool _isLoading = false;

  void _nextPage() {
    _pageController.nextPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
    setState(() => _currentPage++);
  }

  void _prevPage() {
    _pageController.previousPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
    setState(() => _currentPage--);
  }

  // STEP 1 -> สร้าง family + profile (role: admin) ครั้งแรกที่กด "Next"
  Future<void> _createFamilyAndProfile() async {
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser!;
    final meta = user.userMetadata ?? {};

    final family = await supabase
        .from('families')
        .insert({'name': '${_familyNameController.text.trim()}\'s Family'})
        .select()
        .single();

    await supabase.from('profiles').insert({
      'id': user.id,
      'family_id': family['id'],
      'first_name': meta['first_name'] ?? '',
      'last_name': meta['last_name'] ?? '',
      'role': 'admin',
      'onboarding_complete': false,
    });
  }

  Future<void> _handleStep1Next() async {
    if (_familyNameController.text.isEmpty) return;

    setState(() => _isLoading = true);
    try {
      await _createFamilyAndProfile();
      _nextPage();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('An error occurred.: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // STEP 3 -> เพิ่มข้อมูลเด็ก + mark onboarding complete
  Future<void> _saveAndFinish() async {
    if (_childNameController.text.isEmpty ||
        _weightController.text.isEmpty ||
        _selectedBirthdate == null ||
        _selectedGender == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in all child information')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final supabase = Supabase.instance.client;
      final userId = supabase.auth.currentUser!.id;

      final profile = await supabase
          .from('profiles')
          .select('family_id')
          .eq('id', userId)
          .single();

      final familyId = profile['family_id'];

      // Add child information
      await supabase.from('children').insert({
        'family_id': familyId,
        'name': _childNameController.text.trim(),
        'birthdate': _selectedBirthdate!.toIso8601String().split('T')[0],
        'weight_kg': double.parse(_weightController.text),
        'gender': _selectedGender,
      });

      // mark onboarding complete by updating profile
      await supabase
          .from('profiles')
          .update({'onboarding_complete': true})
          .eq('id', userId);

      // จุดแก้ที่ 2: สลับสเตทเป็น true เพื่อล็อกไม่ให้กดย้อนกลับระบบหลังวาร์ปไปหน้า Dashboard แล้ว
      if (mounted) {
        setState(() => _onboardingFinished = true);

        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const DashboardScreen()),
          (route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('An error occurred.: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleSkip() async {
    setState(() => _isLoading = true);
    try {
      final supabase = Supabase.instance.client;
      final userId = supabase.auth.currentUser!.id;

      await supabase
          .from('profiles')
          .update({'onboarding_complete': true})
          .eq('id', userId);

      // จุดแก้ที่ 3: สลับสเตทฝั่ง Skip เป็น true เพื่อทำการล็อกไม่ให้กด Back ย้อนกลับมา
      if (mounted) {
        setState(() => _onboardingFinished = true);

        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const DashboardScreen()),
          (route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('An error occurred.: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // จุดแก้ที่ 4: นำ PopScope มาห่อหุ้ม Scaffold หลัก เพื่อตรวจสอบสิทธิ์การกดย้อนกลับแบบไดนามิกตามสเตทปัจจุบัน
    return PopScope(
      canPop: !_onboardingFinished, // ถ้าออนบอร์ดดิ่งเสร็จแล้ว (true) canPop จะเป็น false ทันที บล็อกไม่ให้กดย้อนกลับ
      child: Scaffold(
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
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              labelText: 'Family Name e.g., The Smiths',
              border: OutlineInputBorder(),
            ),
          ),
          const Spacer(),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                onPressed: () {
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute(
                        builder: (context) => const RoleSelectionScreen(),
                      ),
                    );
                  },
                  child: const Text('Back'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: (_familyNameController.text.isEmpty || _isLoading)
                      ? null
                      : _handleStep1Next,
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Next'),
                ),
              ),
            ],
          )
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

          // Gender selector
          const Text('Gender', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: ChoiceChip(
                  label: const Text('Male'),
                  selected: _selectedGender == 'male',
                  onSelected: (_) => setState(() => _selectedGender = 'male'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ChoiceChip(
                  label: const Text('Female'),
                  selected: _selectedGender == 'female',
                  onSelected: (_) => setState(() => _selectedGender = 'female'),
                ),
              ),
            ],
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
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _prevPage,
                  child: const Text('Back'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: _nextPage,
                  child: const Text('Next'),
                ),
              ),
            ],
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
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _isLoading ? null : _prevPage,
                  child: const Text('Back'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _saveAndFinish,
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Get Started with CareKids!'),
                ),
              ),
            ],
          ),
          TextButton(
            onPressed: _isLoading ? null : _handleSkip,
            child: const Text('Skip for Now, Invite Later'),
          ),
        ],
      ),
    );
  }
}