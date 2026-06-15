import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AddChildScreen extends StatefulWidget {
  final String familyId;

  const AddChildScreen({super.key, required this.familyId});

  @override
  State<AddChildScreen> createState() => _AddChildScreenState();
}

class _AddChildScreenState extends State<AddChildScreen> {
  final _nameController = TextEditingController();
  final _weightController = TextEditingController();
  DateTime? _selectedBirthdate;
  String? _selectedGender;
  bool _isLoading = false;

  Future<void> _save() async {
    if (_nameController.text.isEmpty ||
        _weightController.text.isEmpty ||
        _selectedBirthdate == null ||
        _selectedGender == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in all fields')),
      );
      return;
    }

    final weight = double.tryParse(_weightController.text);
    if (weight == null || weight <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Weight must be a valid number')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final supabase = Supabase.instance.client;
      final userId = supabase.auth.currentUser!.id;

      final childResponse = await supabase.from('children').insert({
        'family_id': widget.familyId,
        'name': _nameController.text.trim(),
        'birthdate': _selectedBirthdate!.toIso8601String().split('T')[0],
        'weight_kg': weight,
        'gender': _selectedGender,
      }).select().single();

      await supabase.from('weight_logs').insert({
        'child_id': childResponse['id'],
        'weight_kg': weight,
        'recorded_by': userId,
      });

      if (mounted) Navigator.pop(context);
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
      appBar: AppBar(title: const Text('Add Child Profile')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: "Child's Name",
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
                    showCheckmark: true,
                    selectedColor: Colors.blue.shade100,
                    label: const Text('Male'),
                    selected: _selectedGender == 'male',
                    onSelected: (selected) {
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

            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _save,
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Save'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}