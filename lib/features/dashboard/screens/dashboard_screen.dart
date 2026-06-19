import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:carekids/shared/models/child_profile.dart';
import 'package:carekids/features/children/screens/add_child_screen.dart';
import 'package:carekids/shared/utils/date_utils.dart';
import 'package:carekids/shared/utils/mock_events.dart';
import 'package:carekids/features/dashboard/screens/calendar_screen.dart';
import 'package:carekids/features/dashboard/screens/notification_screen.dart';
import 'package:carekids/features/auth/screens/family_invite_screen.dart';
import 'package:carekids/features/auth/screens/account_switcher_screen.dart';
import 'package:carekids/features/auth/screens/user_profile_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  bool _isLoading = true;
  String? _role;
  String? _familyId;
  String? _firstName;
  List<ChildProfile> _children = [];
  int _selectedIndex = 0;
  bool _cardVisible = false;
  int _pendingRequestCount = 0;

  DateTime? _selectedCalendarDate;
  late final int _daysInCurrentMonth;
  static const double _calendarItemExtent = 82;
  late final ScrollController _calendarScrollController;

  @override
  void initState() {
    super.initState();
    final today = MockEvents.today;
    _selectedCalendarDate = today;
    _daysInCurrentMonth = daysInMonth(today.year, today.month);

    _calendarScrollController = ScrollController(
      initialScrollOffset: (today.day - 1) * _calendarItemExtent,
    );

    _loadData();
  }

  @override
  void dispose() {
    _calendarScrollController.dispose();
    super.dispose();
  }

  bool get _isAdmin => _role == 'admin';

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final supabase = Supabase.instance.client;
    final userId = supabase.auth.currentUser!.id;

    try {
      final profile = await supabase
          .from('profiles')
          .select('role, family_id, first_name, last_name')
          .eq('id', userId)
          .single();

      _role = profile['role'];
      _familyId = profile['family_id'];
      _firstName = profile['first_name'];

      final childrenData = await supabase
          .from('children')
          .select()
          .eq('family_id', _familyId!)
          .order('created_at');

      _children = childrenData.map<ChildProfile>((c) => ChildProfile.fromMap(c)).toList();

      if (_selectedIndex >= _children.length) {
        _selectedIndex = 0;
      }

      if (_isAdmin) {
        final pending = await supabase
            .from('join_requests')
            .select('id')
            .eq('family_id', _familyId!)
            .eq('status', 'pending');
        _pendingRequestCount = (pending as List).length;
      } else {
        _pendingRequestCount = 0;
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
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
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
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Weight updated ✅')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to update weight: $e')));
      }
    }
  }

  // 🌟 ใหม่: confirm ก่อนสลับไปดูเด็กคนอื่น (แตะคนเดิมซ้ำยังคงแค่ toggle การ์ดเหมือนเดิม ไม่ต้อง confirm)
  Future<void> _confirmSwitchChild(int index) async {
    if (index == _selectedIndex) {
      setState(() => _cardVisible = !_cardVisible);
      return;
    }

    final child = _children[index];
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Switch profile?'),
        content: Text("Switch to ${child.name}'s profile?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Switch')),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() {
        _selectedIndex = index;
        _cardVisible = true;
      });
    }
  }

  // 🌟 ใหม่: popup menu ตอนกดค้างที่เด็กซึ่งกำลัง active อยู่ (Admin เท่านั้น)
  void _showChildOptionsMenu(ChildProfile child) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(child.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.photo_camera_outlined),
                title: const Text('Change Photo'),
                onTap: () {
                  Navigator.pop(context);
                  _changeChildPhoto(child);
                },
              ),
              ListTile(
                leading: const Icon(Icons.edit_outlined),
                title: const Text('Edit Name'),
                onTap: () {
                  Navigator.pop(context);
                  _editChildName(child);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  // 🌟 ใหม่: เปลี่ยนรูปเด็ก เลือกจากคลังภาพ (gallery) แล้วอัปโหลดขึ้น Supabase Storage
  Future<void> _changeChildPhoto(ChildProfile child) async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
    if (pickedFile == null) return;

    try {
      final supabase = Supabase.instance.client;
      final bytes = await pickedFile.readAsBytes();
      final path = '${child.id}.jpg';

      await supabase.storage.from('child-photos').uploadBinary(
            path,
            bytes,
            fileOptions: const FileOptions(upsert: true, contentType: 'image/jpeg'),
          );

      final publicUrl = supabase.storage.from('child-photos').getPublicUrl(path);
      // 🌟 ใส่ timestamp กัน cache รูปเก่าค้าง ไม่งั้นรูปใหม่จะไม่อัปเดตในแอป
      final cacheBustedUrl = '$publicUrl?t=${DateTime.now().millisecondsSinceEpoch}';

      await supabase.from('children').update({'photo_url': cacheBustedUrl}).eq('id', child.id);

      await _loadData();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Photo updated ✅')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to update photo: $e')));
      }
    }
  }

  // 🌟 ใหม่: แก้ไขชื่อเด็ก
  Future<void> _editChildName(ChildProfile child) async {
    final controller = TextEditingController(text: child.name);
    final newName = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Name'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: "Child's Name", border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              if (controller.text.trim().isEmpty) return;
              Navigator.pop(context, controller.text.trim());
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (newName == null || newName == child.name) return;

    try {
      await Supabase.instance.client.from('children').update({'name': newName}).eq('id', child.id);
      await _loadData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Name updated ✅')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to update name: $e')));
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

  Future<void> _goToNotifications() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const NotificationScreen()),
    );
    _loadData();
  }

  Future<void> _goToUserProfile() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const UserProfileScreen()),
    );
    _loadData();
  }

  void _showComingSoon(String featureName) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$featureName is coming soon 🚧')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      drawer: _buildDrawer(),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _children.isEmpty
                ? _buildEmptyState()
                : _buildContent(),
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Drawer _buildDrawer() {
    return Drawer(
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.all(20),
              child: Text('Menu', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            ),
            const Divider(),
            if (_isAdmin && _familyId != null)
              ListTile(
                leading: const Icon(Icons.qr_code),
                title: const Text('View Invitation Code'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => FamilyInviteScreen(familyId: _familyId!)),
                  );
                },
              ),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: const Text('Sign Out (Debug)'),
              onTap: () async {
                Navigator.pop(context);
                await Supabase.instance.client.auth.signOut();
              },
            ),
            if (_isAdmin)
              ListTile(
                leading: const Icon(Icons.group_add_outlined),
                title: const Text('Manage Join Requests'),
                onTap: () {
                  Navigator.pop(context);
                  _goToNotifications();
                },
              ),
            const Spacer(),
            const Divider(),
            ListTile(
              leading: CircleAvatar(
                radius: 16,
                backgroundColor: Colors.purple.shade100,
                child: Text(
                  (_firstName != null && _firstName!.isNotEmpty) ? _firstName![0].toUpperCase() : '',
                  style: const TextStyle(fontSize: 12, color: Colors.black87),
                ),
              ),
              title: Text(_firstName ?? 'Account'),
              subtitle: const Text('Switch account'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AccountSwitcherScreen()),
                );
              },
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 8)],
                ),
                child: Row(
                  children: const [
                    Text('Care', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF2F80ED))),
                    Text('Kids', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFFEB5C8C))),
                  ],
                ),
              ),
              Positioned(
                top: -2,
                right: -2,
                child: Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: Colors.green,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 1.5),
                  ),
                ),
              ),
            ],
          ),
          Row(
            children: [
              if (_isAdmin)
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.notifications_outlined),
                      onPressed: _goToNotifications,
                    ),
                    if (_pendingRequestCount > 0)
                      Positioned(
                        right: 4,
                        top: 4,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                          constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                          child: Text(
                            '$_pendingRequestCount',
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Colors.white, fontSize: 10),
                          ),
                        ),
                      ),
                  ],
                ),
              Builder(
                builder: (context) => IconButton(
                  icon: const Icon(Icons.menu),
                  onPressed: () => Scaffold.of(context).openDrawer(),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Column(
      children: [
        _buildHeader(),
        Expanded(
          child: Center(
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
          ),
        ),
      ],
    );
  }

  Widget _buildContent() {
    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          _buildHeader(),
          const SizedBox(height: 16),
          _buildAvatarRow(),
          if (_cardVisible && _children.isNotEmpty) ...[
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: _buildChildCard(_children[_selectedIndex]),
            ),
          ],
          const SizedBox(height: 24),
          _buildQuickActions(),
          const SizedBox(height: 24),
          Padding(padding: const EdgeInsets.symmetric(horizontal: 20), child: _buildNextReminder()),
          const SizedBox(height: 24),
          Padding(padding: const EdgeInsets.symmetric(horizontal: 20), child: _buildCalendar()),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildAvatarRow() {
    return SizedBox(
      height: 90,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        children: [
          for (int i = 0; i < _children.length; i++)
            Padding(padding: const EdgeInsets.only(right: 16), child: _buildChildAvatar(_children[i], i)),
          if (_isAdmin) _buildAddChildAvatar(),
        ],
      ),
    );
  }

  Widget _buildChildAvatar(ChildProfile child, int index) {
    final isSelected = index == _selectedIndex;
    return GestureDetector(
      onTap: () => _confirmSwitchChild(index),
      // 🌟 long press เปิดเมนูได้เฉพาะ Admin และต้องเป็นเด็กที่ active (เลือกอยู่) เท่านั้น
      onLongPress: (_isAdmin && isSelected) ? () => _showChildOptionsMenu(child) : null,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: isSelected ? const Color(0xFF2F80ED) : Colors.transparent, width: 2),
            ),
            child: CircleAvatar(
              radius: 26,
              backgroundColor: child.gender == 'female' ? Colors.pink.shade100 : Colors.blue.shade100,
              backgroundImage: child.photoUrl != null ? NetworkImage(child.photoUrl!) : null,
              child: child.photoUrl == null
                  ? Text(
                      child.name.isNotEmpty ? child.name[0].toUpperCase() : '?',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
                    )
                  : null,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            child.name,
            style: TextStyle(
              fontSize: 12,
              color: isSelected ? const Color(0xFF2F80ED) : Colors.black87,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAddChildAvatar() {
    return GestureDetector(
      onTap: _goToAddChild,
      child: Column(
        children: [
          CircleAvatar(radius: 28, backgroundColor: Colors.grey.shade200, child: const Icon(Icons.add, color: Colors.grey)),
          const SizedBox(height: 6),
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
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: child.gender == 'female' ? Colors.pink.shade100 : Colors.blue.shade100,
                backgroundImage: child.photoUrl != null ? NetworkImage(child.photoUrl!) : null,
                child: child.photoUrl == null
                    ? Text(child.name.isNotEmpty ? child.name[0].toUpperCase() : '?',
                        style: const TextStyle(fontWeight: FontWeight.bold))
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(child.name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              ),
              if (child.gender != null)
                Icon(child.gender == 'female' ? Icons.female : Icons.male,
                    color: child.gender == 'female' ? Colors.pink : Colors.blue),
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
                  const Text('Current weight', style: TextStyle(fontSize: 13, color: Colors.grey)),
                  const SizedBox(height: 4),
                  Text('${child.weightKg} kg', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                ],
              ),
              if (_isAdmin) ElevatedButton(onPressed: () => _updateWeight(child), child: const Text('Update')),
            ],
          ),
          if (child.isWeightStale) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(color: Colors.orange.shade50, borderRadius: BorderRadius.circular(8)),
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
          if (_isAdmin) ...[
            const SizedBox(height: 12),
            Text(
              'Tip: long-press this child\'s avatar above to change photo or edit name',
              style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildQuickActions() {
    final actions = [
      _QuickAction(title: 'Calculator\nDose', icon: Icons.medication_liquid,
          gradient: const [Color(0xFFB7F0D8), Color(0xFFEAFBF2)], iconColor: const Color(0xFF1F9D6B)),
      _QuickAction(title: 'Medication\nLog', icon: Icons.assignment_outlined,
          gradient: const [Color(0xFFBFDBFF), Color(0xFFEAF3FF)], iconColor: const Color(0xFF2F6FE0)),
      _QuickAction(title: 'Symptom\nLog', icon: Icons.sick_outlined,
          gradient: const [Color(0xFFFFD9A0), Color(0xFFFFF3E0)], iconColor: const Color(0xFFE08A1F)),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 20),
          child: Text('Quick Action', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 170,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            children: [
              for (final action in actions)
                Padding(padding: const EdgeInsets.only(right: 14), child: _buildQuickActionCard(action)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildQuickActionCard(_QuickAction action) {
    return Container(
      width: 150,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(colors: action.gradient, begin: Alignment.topLeft, end: Alignment.bottomRight),
      ),
      child: Stack(
        children: [
          Positioned(right: -10, bottom: -10, child: Icon(action.icon, size: 80, color: Colors.white.withOpacity(0.4))),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(action.title, style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: action.iconColor)),
              const Spacer(),
              ElevatedButton(
                onPressed: () => _showComingSoon(action.title.replaceAll('\n', ' ')),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black87,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                ),
                child: const Text('Start Now', style: TextStyle(fontSize: 12)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNextReminder() {
    final reminders = [
      {'time': '12:30 AM', 'name': 'Paracetamol', 'dose': '3.5 ML', 'icon': Icons.wb_sunny_outlined, 'color': Colors.orange},
      {'time': '7:00 PM', 'name': 'Paracetamol', 'dose': '3.5 ML', 'icon': Icons.nightlight_round, 'color': Colors.indigo},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: const [
            Text('Next Reminder', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            SizedBox(width: 6),
            Icon(Icons.alarm, size: 20, color: Colors.black54),
          ],
        ),
        const SizedBox(height: 12),
        for (final r in reminders)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8)],
              ),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: (r['color'] as Color).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(r['icon'] as IconData, color: r['color'] as Color),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${r['time']} | ${r['name']}', style: const TextStyle(fontWeight: FontWeight.w600)),
                        Text(r['dose'] as String, style: const TextStyle(color: Colors.grey, fontSize: 12)),
                      ],
                    ),
                  ),
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: Colors.pink.shade50,
                    child: const Icon(Icons.medication, color: Colors.pink, size: 18),
                  ),
                ],
              ),
            ),
          ),
        Text('* Sample reminder — actual medication schedule arrives with Feature 002',
            style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
      ],
    );
  }

  Widget _buildCalendar() {
    final today = MockEvents.today;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Calendar', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            IconButton(
              icon: const Icon(Icons.calendar_month, color: Color(0xFF2F80ED)),
              tooltip: 'Full calendar',
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => CalendarScreen())),
            ),
          ],
        ),
        const SizedBox(height: 4),
        SizedBox(
          height: 100,
          child: ListView.builder(
            controller: _calendarScrollController,
            scrollDirection: Axis.horizontal,
            itemCount: _daysInCurrentMonth,
            itemExtent: _calendarItemExtent,
            itemBuilder: (context, index) {
              final date = DateTime(today.year, today.month, index + 1);
              final isSelected = isSameDate(date, _selectedCalendarDate!);
              final isToday = isSameDate(date, today);
              final eventLabel = MockEvents.eventFor(date);
              final hasEvent = eventLabel != null;

              Color backgroundColor;
              Color textColor;
              Color subTextColor;

              if (isSelected) {
                backgroundColor = const Color(0xFF2F80ED);
                textColor = Colors.white;
                subTextColor = Colors.white70;
              } else if (hasEvent) {
                backgroundColor = Colors.orange.shade50;
                textColor = Colors.black87;
                subTextColor = Colors.orange.shade800;
              } else {
                backgroundColor = Colors.white;
                textColor = Colors.black87;
                subTextColor = Colors.grey;
              }

              return GestureDetector(
                onTap: () => setState(() => _selectedCalendarDate = date),
                child: Container(
                  width: 72,
                  margin: const EdgeInsets.only(right: 10),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: backgroundColor,
                    borderRadius: BorderRadius.circular(14),
                    border: hasEvent && !isSelected ? Border.all(color: Colors.orange.shade200) : null,
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6)],
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(weekdayShortNames[date.weekday - 1], style: TextStyle(fontSize: 12, color: subTextColor)),
                      const SizedBox(height: 3),
                      Text('${date.day}', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: textColor)),
                      const SizedBox(height: 3),
                      Text(
                        isToday ? 'Today' : (eventLabel ?? 'No item'),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 10, color: subTextColor),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 12),
        _buildCalendarDetailPanel(),
      ],
    );
  }

  Widget _buildCalendarDetailPanel() {
    final eventLabel = MockEvents.eventFor(_selectedCalendarDate!);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6)],
      ),
      child: Row(
        children: [
          Icon(eventLabel != null ? Icons.event_available : Icons.event_busy,
              color: eventLabel != null ? const Color(0xFF2F80ED) : Colors.grey),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              eventLabel != null
                  ? '$eventLabel on ${_selectedCalendarDate!.day}/${_selectedCalendarDate!.month}'
                  : 'No appointments on ${_selectedCalendarDate!.day}/${_selectedCalendarDate!.month}',
              style: const TextStyle(fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomNav() {
    final initial = (_firstName != null && _firstName!.isNotEmpty) ? _firstName![0].toUpperCase() : null;

    return BottomNavigationBar(
      type: BottomNavigationBarType.fixed,
      currentIndex: 0,
      selectedItemColor: const Color(0xFF2F80ED),
      unselectedItemColor: Colors.grey,
      onTap: (index) {
        if (index == 0) return;
        if (index == 3) {
          // 🌟 เปลี่ยนจาก coming soon -> เปิดหน้า User Profile จริง
          _goToUserProfile();
          return;
        }
        _showComingSoon('This section');
      },
      items: [
        const BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
        const BottomNavigationBarItem(icon: Icon(Icons.calendar_today), label: 'Schedule'),
        const BottomNavigationBarItem(icon: Icon(Icons.location_on_outlined), label: 'Hospital'),
        BottomNavigationBarItem(
          icon: CircleAvatar(
            radius: 12,
            backgroundColor: Colors.purple.shade100,
            child: initial != null
                ? Text(initial, style: const TextStyle(fontSize: 11, color: Colors.black87))
                : const Icon(Icons.person, size: 14, color: Colors.black54),
          ),
          label: 'Account',
        ),
      ],
    );
  }
}

class _QuickAction {
  final String title;
  final IconData icon;
  final List<Color> gradient;
  final Color iconColor;

  _QuickAction({required this.title, required this.icon, required this.gradient, required this.iconColor});
}