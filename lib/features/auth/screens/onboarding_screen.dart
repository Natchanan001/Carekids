import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:carekids/features/auth/screens/role_selection_screen.dart';

class OnboardingScreen extends StatefulWidget {
  final VoidCallback onFinished;
  final VoidCallback? onBack;

  const OnboardingScreen({
    super.key,
    required this.onFinished,
    this.onBack, 
  });

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
  String? _selectedGender; 
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

  // STEP 1 
  Future<void> _createFamilyAndProfile() async {
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser!;

    final existingProfile = await supabase
        .from('profiles')
        .select()
        .eq('id', user.id)
        .maybeSingle();

    if (existingProfile == null) {
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
    } else {
      await supabase
          .from('families')
          .update({'name': '${_familyNameController.text.trim()}\'s Family'})
          .eq('id', existingProfile['family_id']);
    }
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
          SnackBar(content: Text('An error occurred: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // 🌟 เพิ่มฟังก์ชันสำหรับตรวจสอบหน้า 2 ก่อนกดไปหน้า 3
  void _handleStep2Next() {
    // 1. ดักกรอกไม่ครบ
    if (_childNameController.text.isEmpty ||
        _weightController.text.isEmpty ||
        _selectedBirthdate == null ||
        _selectedGender == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in all child information 👶')),
      );
      return;
    }

    // 2. ดักน้ำหนักมั่ว (เผื่อพิมพ์ตัวหนังสือมา)
    if (double.tryParse(_weightController.text) == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Weight must be a number (e.g., 15.5) ⚖️')),
      );
      return;
    }

    _nextPage();
  }

  // 🌟 ยุบรวมฟังก์ชันจบ Onboarding (ทั้งตอนรับ Invite และตอนข้าม) มาไว้ที่เดียวกัน
  Future<void> _finishOnboarding() async {
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

// 🌟 นำข้อมูลเด็กมาบันทึกลงตรงนี้! ป้องกันปัญหากด Skip แล้วข้อมูลเด็กหาย
      final childResponse = await supabase
          .from('children')
          .insert({
            'family_id': familyId,
            'name': _childNameController.text.trim(),
            'birthdate': _selectedBirthdate!.toIso8601String().split('T')[0],
            'weight_kg': double.parse(_weightController.text),
            'gender': _selectedGender,
          })
          .select()
          .single();

      // 🌟 บันทึก weight log ครั้งแรก ให้ history ต่อเนื่องกับ weight_logs
      await supabase.from('weight_logs').insert({
        'child_id': childResponse['id'],
        'weight_kg': double.parse(_weightController.text),
        'recorded_by': userId,
      });

      // อัปเดตสถานะว่าจบกระบวนการแล้ว
      await supabase
          .from('profiles')
          .update({'onboarding_complete': true})
          .eq('id', userId);

      if (mounted) {
        widget.onFinished(); // ปล่อยเข้า Dashboard
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('An error occurred: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
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

  // Step 1
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
                    if (widget.onBack != null) {
                      widget.onBack!();
                    }
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

  // Step 2
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

          const Text('Gender', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: ChoiceChip(
                  showCheckmark: true, // 🌟 เพิ่มติ๊กถูกให้ชัดเจน
                  selectedColor: Colors.blue.shade100, // 🌟 ใส่สีตอนเลือก
                  label: const Text('Male'),
                  selected: _selectedGender == 'male',
                  onSelected: (selected) {
                    // 🌟 ดักเช็กให้รับค่าเมื่อถูกจิ้มจริงๆ เท่านั้น
                    if (selected) setState(() => _selectedGender = 'male');
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ChoiceChip(
                  showCheckmark: true,
                  selectedColor: Colors.pink.shade100,
                  label: const Text('Female'),
                  selected: _selectedGender == 'female',
                  onSelected: (selected) {
                    if (selected) setState(() => _selectedGender = 'female');
                  },
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
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
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
                  // 🌟 เปลี่ยนมาใช้ฟังก์ชันตรวจหน้าด่าน _handleStep2Next ที่เราสร้างใหม่
                  onPressed: _handleStep2Next,
                  child: const Text('Next'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Step 3
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
                  // 🌟 ให้โยงไปที่ _finishOnboarding
                  onPressed: _isLoading ? null : _finishOnboarding,
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
            // 🌟 ให้โยงไปที่ _finishOnboarding เหมือนกันเป๊ะ เพราะต้องเซฟเด็กลง DB ด้วยจ้า!
            onPressed: _isLoading ? null : _finishOnboarding,
            child: const Text('Skip for Now, Invite Later'),
          ),
        ],
      ),
    );
  }
}