import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
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
  String? _familyName;
  List<ChildProfile> _children = [];
  int _selectedIndex = 0;
  bool _cardVisible = false;
  int _pendingRequestCount = 0;

  DateTime? _selectedCalendarDate;
  late final int _daysInCurrentMonth;
  static const double _calendarItemExtent = 114;
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
          .select('role, family_id, first_name, last_name, families(name)')
          .eq('id', userId)
          .single();

      _role = profile['role'];
      _familyId = profile['family_id'];
      _firstName = profile['first_name'];
      _familyName = profile['families']?['name'];

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
    return Theme(
      data: Theme.of(context).copyWith(
        textTheme: GoogleFonts.baloo2TextTheme(Theme.of(context).textTheme),
      ),
      child: Scaffold(
        backgroundColor: const Color(0xFFF8F9FB),
        drawer: _buildDrawer(),
        body: Stack(
          children: [
            // 🌟 วงกลมพื้นหลังสีเขียวจางๆ แบบ organic blob — fixed ตามจอ ไม่เลื่อนตาม scroll
            if (!_isLoading && _children.isNotEmpty) ..._buildBackgroundBlobs(),
            SafeArea(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _children.isEmpty
                      ? _buildEmptyState()
                      : _buildContent(),
            ),
          ],
        ),
        bottomNavigationBar: _buildBottomNav(),
      ),
    );
  }

  // 🌟 blob ตกแต่งพื้นหลัง อยู่นิ่งบริเวณกลาง-ล่างของจอ (แถว Next Reminder / Date)
  List<Widget> _buildBackgroundBlobs() {
    return [
      Positioned(
        top: 280,
        right: -60,
        child: _blobShape(220, const Color(0xFF8FD9A0).withOpacity(0.30)),
      ),
      Positioned(
        top: 480,
        left: -90,
        child: _blobShape(260, const Color(0xFF8FD9A0).withOpacity(0.22)),
      ),
    ];
  }

  Widget _blobShape(double size, Color color) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(size * 0.4),
            topRight: Radius.circular(size * 0.55),
            bottomLeft: Radius.circular(size * 0.55),
            bottomRight: Radius.circular(size * 0.45),
          ),
        ),
      ),
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

// logo CareKids ด้านบนซ้ายของหน้า Dashboard
  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 8, offset: const Offset(0, 3))],
                  ),
                  child: IntrinsicWidth(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.only(left: 10, right: 4, top: 0, bottom: 0),
                          color: const Color.fromARGB(255, 73, 163, 247),
                          child: Text(
                            'Care',
                            style: GoogleFonts.baloo2(fontSize: 27, fontWeight: FontWeight.w600, color: Colors.white),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.only(left: 4, right: 10, top: 0, bottom: 0),
                          color: const Color.fromARGB(255, 244, 96, 153),
                          child: Text(
                            'Kids',
                            style: GoogleFonts.baloo2(fontSize: 27, fontWeight: FontWeight.w600, color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Positioned(
                top: -3,
                right: -3,
                child: Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: const Color(0xFF8BC34A),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
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

  Widget _buildWelcomeMessage() {
    final familyLabel = (_familyName != null && _familyName!.isNotEmpty) ? _familyName! : 'Family';
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
      child: Text(
        'Welcome ! $familyLabel',
        style: GoogleFonts.baloo2(fontSize: 22, fontWeight: FontWeight.w700, color: const Color(0xFF1A1A1A)),
      ),
    );
  }

  Widget _buildContent() {
    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          _buildHeader(),
          _buildWelcomeMessage(),
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

  // 🌟 ลำดับ avatar โดยให้เด็กที่ active อยู่ซ้ายสุดเสมอ (สลับแล้วเลื่อนสมูท)
  List<ChildProfile> get _orderedChildren {
    if (_children.isEmpty) return _children;
    final ordered = List<ChildProfile>.from(_children);
    final selected = ordered.removeAt(_selectedIndex);
    ordered.insert(0, selected);
    return ordered;
  }
// ขนาดไอคอนอวาตาร์เด็ก
  static const double _avatarSlotWidth = 84;
  static const double _avatarSelectedRadius = 35;
  static const double _avatarNormalRadius = 26;
  static const double _avatarAddRadius = 22;

  Widget _buildAvatarRow() {
    final ordered = _orderedChildren;
    final itemCount = ordered.length + (_isAdmin ? 1 : 0);
    final rowWidth = itemCount * _avatarSlotWidth;

    return SizedBox(
      height: 96,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: SizedBox(
          width: rowWidth,
          height: 96,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              for (int i = 0; i < ordered.length; i++)
                AnimatedPositioned(
                  key: ValueKey('child_${ordered[i].id}'),
                  duration: const Duration(milliseconds: 320),
                  curve: Curves.easeOutCubic,
                  left: i * _avatarSlotWidth,
                  top: 0,
                  child: SizedBox(
                    width: _avatarSlotWidth,
                    child: _buildChildAvatar(ordered[i], _children.indexOf(ordered[i])),
                  ),
                ),
              if (_isAdmin)
                AnimatedPositioned(
                  key: const ValueKey('add_child'),
                  duration: const Duration(milliseconds: 320),
                  curve: Curves.easeOutCubic,
                  left: ordered.length * _avatarSlotWidth,
                  top: 0,
                  child: SizedBox(
                    width: _avatarSlotWidth,
                    child: _buildAddChildAvatar(),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildChildAvatar(ChildProfile child, int index) {
    final isSelected = index == _selectedIndex;
    final radius = isSelected ? _avatarSelectedRadius : _avatarNormalRadius;

    return GestureDetector(
      onTap: () => _confirmSwitchChild(index),
      // 🌟 long press เปิดเมนูได้เฉพาะ Admin และต้องเป็นเด็กที่ active (เลือกอยู่) เท่านั้น
      onLongPress: (_isAdmin && isSelected) ? () => _showChildOptionsMenu(child) : null,
      child: Column(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 320),
            curve: Curves.easeOutCubic,
            padding: const EdgeInsets.all(2.5),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: isSelected ? const Color(0xFF5B9DF0) : Colors.transparent, width: 2.5),
            ),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 320),
              curve: Curves.easeOutCubic,
              width: radius * 2,
              height: radius * 2,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: child.gender == 'female' ? Colors.pink.shade100 : Colors.blue.shade100,
                image: child.photoUrl != null
                    ? DecorationImage(image: NetworkImage(child.photoUrl!), fit: BoxFit.cover)
                    : null,
              ),
              alignment: Alignment.center,
              child: child.photoUrl == null
                  ? Text(
                      child.name.isNotEmpty ? child.name[0].toUpperCase() : '?',
                      style: TextStyle(fontSize: isSelected ? 20 : 18, fontWeight: FontWeight.bold, color: Colors.black87),
                    )
                  : null,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            child.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.baloo2(
              fontSize: 13,
              color: isSelected ? const Color(0xFF5B9DF0) : const Color(0xFF333333),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAddChildAvatar() {
    return GestureDetector(
      onTap: _goToAddChild,
      child: Padding(
        padding: EdgeInsets.only(top: _avatarSelectedRadius - _avatarAddRadius + 2.5),
        child: Container(
          width: _avatarAddRadius * 2,
          height: _avatarAddRadius * 2,
          decoration: const BoxDecoration(
            color: Color(0xFF8AA624),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.add, color: Colors.white, size: 24),
        ),
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
      _QuickAction(
        title: 'Calculator\nDose',
        icon: Icons.medication_liquid,
        cardColor: const Color(0xFFB9EAD4),
        iconColor: const Color(0xFF1F9D6B),
      ),
      _QuickAction(
        title: 'Medication\nLog',
        icon: Icons.assignment_outlined,
        cardColor: const Color(0xFFBBD3F7),
        iconColor: const Color(0xFF2F6FE0),
      ),
      _QuickAction(
        title: 'Symptom\nLog',
        icon: Icons.sick_outlined,
        cardColor: const Color(0xFFF7DCA8),
        iconColor: const Color(0xFFB8791A),
      ),
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 20),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF8FD3A8), Color(0xFFAFD8E8), Color(0xFFF3DFAE)],
          stops: [0.0, 0.55, 1.0],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              'Quick Action',
              style: GoogleFonts.baloo2(fontSize: 22, fontWeight: FontWeight.w700, color: const Color(0xFF1A1A1A)),
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 175,
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
      ),
    );
  }

  Widget _buildQuickActionCard(_QuickAction action) {
    return Container(
      width: 150,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: action.cardColor,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 8, offset: const Offset(0, 3))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            action.title,
            style: GoogleFonts.baloo2(fontSize: 15, fontWeight: FontWeight.w700, color: action.iconColor, height: 1.15),
          ),
          const Spacer(),
          Align(
            alignment: Alignment.centerRight,
            child: Container(
              width: 56,
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.55),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(action.icon, size: 30, color: action.iconColor),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => _showComingSoon(action.title.replaceAll('\n', ' ')),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: action.iconColor,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              ),
              child: Text('Start Now', style: GoogleFonts.baloo2(fontSize: 12, fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNextReminder() {
    final reminders = [
      {
        'time': '8 AM',
        'name': 'Paracetamol',
        'dose': '3.5 ML',
        'icon': Icons.wb_sunny_outlined,
        'iconBg': const Color(0xFFE8825A),
        'cardBg': const Color(0xFFFCF3E3),
        'doseColor': const Color(0xFFD9A441),
      },
      {
        'time': '6 PM',
        'name': 'Paracetamol',
        'dose': '3.5 ML',
        'icon': Icons.nightlight_round,
        'iconBg': const Color(0xFF5B9DF0),
        'cardBg': const Color(0xFFEAF2FC),
        'doseColor': const Color(0xFF5B9DF0),
      },
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('Next Reminder', style: GoogleFonts.baloo2(fontSize: 22, fontWeight: FontWeight.w700, color: const Color(0xFF1A1A1A))),
            const SizedBox(width: 6),
            const Icon(Icons.alarm, size: 22, color: Colors.black54),
          ],
        ),
        const SizedBox(height: 14),
        for (final r in reminders)
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: r['cardBg'] as Color,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: r['iconBg'] as Color,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(r['icon'] as IconData, color: Colors.white, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        RichText(
                          text: TextSpan(
                            style: GoogleFonts.baloo2(fontSize: 15, fontWeight: FontWeight.w700, color: const Color(0xFF1A1A1A)),
                            children: [
                              TextSpan(text: '${r['time']}  '),
                              TextSpan(text: '| ', style: TextStyle(color: Colors.grey.shade400)),
                              TextSpan(text: r['name'] as String, style: const TextStyle(fontWeight: FontWeight.w500)),
                            ],
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          r['dose'] as String,
                          style: GoogleFonts.baloo2(color: r['doseColor'] as Color, fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                  // 🌟 Placeholder: ในอนาคตจะเป็นรูปถ่ายขวดยาจริงที่ผู้ปกครองอัปโหลด (Feature 004)
                  CircleAvatar(
                    radius: 21,
                    backgroundColor: Colors.pink.shade100,
                    child: const Icon(Icons.medication, color: Colors.pink, size: 20),
                  ),
                ],
              ),
            ),
          ),
        Text('* Sample reminder — actual medication schedule arrives with Feature 004',
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
            Text('Date', style: GoogleFonts.baloo2(fontSize: 22, fontWeight: FontWeight.w700, color: const Color(0xFF1A1A1A))),
            IconButton(
              icon: const Icon(Icons.calendar_month, color: Color.fromARGB(255, 192, 118, 131)),
              tooltip: 'Full calendar',
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => CalendarScreen())),
            ),
          ],
        ),
        const SizedBox(height: 4),
        SizedBox(
          height: 136,
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

              IconData? eventIcon;
              if (hasEvent) {
                final lower = eventLabel!.toLowerCase();
                if (lower.contains('vaccine')) {
                  eventIcon = Icons.vaccines_outlined;
                } else if (lower.contains('doctor')) {
                  eventIcon = Icons.medical_services_outlined;
                } else {
                  eventIcon = Icons.event_note_outlined;
                }
              }

              return _DateCard(
                weekday: weekdayShortNames[date.weekday - 1],
                day: date.day,
                isToday: isToday,
                isSelected: isSelected,
                hasEvent: hasEvent,
                eventIcon: eventIcon,
                onTap: () => setState(() => _selectedCalendarDate = date),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(eventLabel != null ? Icons.event_available : Icons.event_busy,
              color: eventLabel != null ? const Color.fromARGB(255, 176, 123, 92) : Colors.grey, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              eventLabel != null
                  ? '$eventLabel on ${_selectedCalendarDate!.day}/${_selectedCalendarDate!.month}/${_selectedCalendarDate!.year}'
                  : 'No appointments on ${_selectedCalendarDate!.day}/${_selectedCalendarDate!.month}/${_selectedCalendarDate!.year}',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.baloo2(fontSize: 13, fontWeight: FontWeight.w500, height: 1.3),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomNav() {
    final initial = (_firstName != null && _firstName!.isNotEmpty) ? _firstName![0].toUpperCase() : null;
    final userDisplayName = (_firstName != null && _firstName!.isNotEmpty) ? _firstName! : 'Account';

    return BottomNavigationBar(
      type: BottomNavigationBarType.fixed,
      currentIndex: 0,
      backgroundColor: Colors.white,
      selectedItemColor: const Color(0xFF5B9DF0),
      unselectedItemColor: const Color(0xFF8A8A8A),
      selectedLabelStyle: GoogleFonts.baloo2(fontSize: 11, fontWeight: FontWeight.w600),
      unselectedLabelStyle: GoogleFonts.baloo2(fontSize: 11, fontWeight: FontWeight.w500),
      elevation: 8,
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
        const BottomNavigationBarItem(icon: Icon(Icons.home_outlined), activeIcon: Icon(Icons.home), label: 'Home'),
        const BottomNavigationBarItem(icon: Icon(Icons.calendar_today_outlined), label: 'Schedule'),
        const BottomNavigationBarItem(icon: Icon(Icons.location_on_outlined), label: 'Hospital'),
        BottomNavigationBarItem(
          icon: Container(
            padding: const EdgeInsets.all(1.5),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFF5B9DF0), width: 1.5),
            ),
            child: CircleAvatar(
              radius: 11,
              backgroundColor: Colors.purple.shade100,
              child: initial != null
                  ? Text(initial, style: const TextStyle(fontSize: 10, color: Colors.black87))
                  : const Icon(Icons.person, size: 13, color: Colors.black54),
            ),
          ),
          label: userDisplayName,
        ),
      ],
    );
  }
}

class _QuickAction {
  final String title;
  final IconData icon;
  final Color cardColor;
  final Color iconColor;

  _QuickAction({required this.title, required this.icon, required this.cardColor, required this.iconColor});
}

// 🌟 การ์ดวันที่: สี dusty rose เข้มล็อคไว้ที่ "วันนี้" เท่านั้น ไม่ขยับตามวันที่ถูกเลือก
// วันที่ถูกเลือก (ไม่ใช่วันนี้) ใช้ dusty rose อ่อน ตัวหนังสือเข้ม
// วันที่มี event (ไม่ได้เลือก/ไม่ใช่วันนี้) ยังคงใช้สีพีชเดิม พร้อมไอคอน event (ไม่มี text บอกชื่อ event แล้ว)
// ตอนกดค้างจะมี overlay สีเทาอ่อนชั่วคราว ปล่อยนิ้วแล้วกลับสีปกติ
class _DateCard extends StatefulWidget {
  final String weekday;
  final int day;
  final bool isToday;
  final bool isSelected;
  final bool hasEvent;
  final IconData? eventIcon;
  final VoidCallback onTap;

  const _DateCard({
    required this.weekday,
    required this.day,
    required this.isToday,
    required this.isSelected,
    required this.hasEvent,
    required this.eventIcon,
    required this.onTap,
  });

  @override
  State<_DateCard> createState() => _DateCardState();
}

class _DateCardState extends State<_DateCard> {
  bool _isPressed = false;

  static const Color _todayColor = Color.fromARGB(255, 186, 111, 125);
  static const Color _selectedLightColor = Color(0xFFF3DBE0);
  static const Color _eventColor = Color.fromARGB(255, 255, 217, 193);
  static const Color _normalColor = Color(0xFFF1F1F3);
  static const Color _pressedOverlay = Color(0xFFE3E3E5);

  @override
  Widget build(BuildContext context) {
    Color backgroundColor;
    Color textColor;
    Color subTextColor;

    if (widget.isToday) {
      backgroundColor = _todayColor;
      textColor = Colors.white;
      subTextColor = Colors.white70;
    } else if (widget.isSelected) {
      backgroundColor = _selectedLightColor;
      textColor = const Color(0xFF1A1A1A);
      subTextColor = const Color(0xFF8A5A63);
    } else if (widget.hasEvent) {
      backgroundColor = _eventColor;
      textColor = const Color(0xFF1A1A1A);
      subTextColor = const Color(0xFF6B6B6B);
    } else {
      backgroundColor = _normalColor;
      textColor = const Color(0xFF1A1A1A);
      subTextColor = Colors.grey.shade400;
    }

    // 🌟 ลูกเล่นตอนกดค้าง: ทับด้วยสีเทาอ่อนชั่วคราว ไม่เปลี่ยน state จริง
    if (_isPressed) {
      backgroundColor = Color.alphaBlend(_pressedOverlay.withOpacity(0.55), backgroundColor);
    }

    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) => setState(() => _isPressed = false),
      onTapCancel: () => setState(() => _isPressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        width: 100,
        margin: const EdgeInsets.only(right: 14),
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(20),
          boxShadow: widget.isToday
              ? [BoxShadow(color: _todayColor.withOpacity(0.35), blurRadius: 10, offset: const Offset(0, 4))]
              : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(widget.weekday,
                style: GoogleFonts.baloo2(fontSize: 16, color: subTextColor, fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            Text('${widget.day}',
                style: GoogleFonts.baloo2(fontSize: 30, fontWeight: FontWeight.w700, color: textColor)),
            const SizedBox(height: 8),
            if (widget.eventIcon != null)
              Icon(widget.eventIcon, size: 22, color: subTextColor),
          ],
        ),
      ),
    );
  }
}