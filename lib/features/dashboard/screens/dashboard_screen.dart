import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:carekids/shared/models/child_profile.dart';
import 'package:carekids/features/children/screens/add_child_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  bool _isLoading = true;
  String? _role;
  String? _familyId;
  List<ChildProfile> _children = [];
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  bool get _isAdmin => _role == 'admin';

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final supabase = Supabase.instance.client;
    final userId = supabase.auth.currentUser!.id;

    try {
      final profile = await supabase
          .from('profiles')
          .select('role, family_id')
          .eq('id', userId)
          .single();

      _role = profile['role'];
      _familyId = profile['family_id'];

      final childrenData = await supabase
          .from('children')
          .select()
          .eq('family_id', _familyId!)
          .order('created_at');

      _children =
          childrenData.map<ChildProfile>((c) => ChildProfile.fromMap(c)).toList();

      if (_selectedIndex >= _children.length) {
        _selectedIndex = 0;
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load data: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _updateWeight(ChildProfile child) async {
    final controller = TextEditingController(text: child.weightKg.toString());

    final result = await showDialog<double>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Update ${child.name}'s weight"),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            labelText: 'Weight (kg)',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final value = double.tryParse(controller.text);
              if (value == null || value <= 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please enter a valid weight')),
                );
                return;
              }
              Navigator.pop(context, value);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (result == null) return;

    final supabase = Supabase.instance.client;
    final userId = supabase.auth.currentUser!.id;

    try {
      await supabase.from('weight_logs').insert({
        'child_id': child.id,
        'weight_kg': result,
        'recorded_by': userId,
      });

      await supabase.from('children').update({
        'weight_kg': result,
        'weight_updated_at': DateTime.now().toIso8601String(),
      }).eq('id', child.id);

      await _loadData();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Weight updated ✅')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update weight: $e')),
        );
      }
    }
  }

  Future<void> _goToAddChild() async {
    if (_familyId == null) return;
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => AddChildScreen(familyId: _familyId!)),
    );
    _loadData();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('CareKids Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.red),
            tooltip: 'Sign Out (Debug)',
            onPressed: () async {
              await Supabase.instance.client.auth.signOut();
              // AuthGate จะ detect แล้วเด้งไป LoginScreen ให้เองอัตโนมัติ
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _children.isEmpty
              ? _buildEmptyState()
              : _buildContent(),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('No child profiles yet 👶',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Text(
              _isAdmin
                  ? 'Add your first child profile to get started'
                  : 'Ask the family admin to add a child profile',
              style: const TextStyle(color: Colors.grey),
              textAlign: TextAlign.center,
            ),
            if (_isAdmin) ...[
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _goToAddChild,
                icon: const Icon(Icons.add),
                label: const Text('Add Child'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    final selectedChild = _children[_selectedIndex];

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SizedBox(
            height: 88,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                for (int i = 0; i < _children.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: _buildChildChip(_children[i], i),
                  ),
                if (_isAdmin)
                  Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: _buildAddChildChip(),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          _buildChildCard(selectedChild),
        ],
      ),
    );
  }

  Widget _buildChildChip(ChildProfile child, int index) {
    final isSelected = index == _selectedIndex;
    return GestureDetector(
      onTap: () => setState(() => _selectedIndex = index),
      child: Column(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: isSelected
                ? Colors.blue
                : (child.gender == 'female'
                    ? Colors.pink.shade100
                    : Colors.blue.shade100),
            child: Text(
              child.name.isNotEmpty ? child.name[0].toUpperCase() : '?',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: isSelected ? Colors.white : Colors.black87,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            child.name,
            style: TextStyle(
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAddChildChip() {
    return GestureDetector(
      onTap: _goToAddChild,
      child: Column(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: Colors.grey.shade200,
            child: const Icon(Icons.add, color: Colors.grey),
          ),
          const SizedBox(height: 4),
          const Text('Add', style: TextStyle(fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildChildCard(ChildProfile child) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(child.name,
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              if (child.gender != null)
                Icon(
                  child.gender == 'female' ? Icons.female : Icons.male,
                  color: child.gender == 'female' ? Colors.pink : Colors.blue,
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(child.ageLabel, style: const TextStyle(color: Colors.grey)),
          const Divider(height: 32),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Current weight',
                      style: TextStyle(fontSize: 13, color: Colors.grey)),
                  const SizedBox(height: 4),
                  Text('${child.weightKg} kg',
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                ],
              ),
              if (_isAdmin)
                ElevatedButton(
                  onPressed: () => _updateWeight(child),
                  child: const Text('Update'),
                ),
            ],
          ),

          if (child.isWeightStale) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.warning_amber, color: Colors.orange.shade700, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      "Weight hasn't been updated in over a week. Update it for accurate dosage calculations.",
                      style: TextStyle(fontSize: 12, color: Colors.orange.shade900),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}