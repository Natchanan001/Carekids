import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:carekids/shared/models/child_profile.dart';
import 'package:carekids/features/children/screens/add_child_screen.dart';
import 'package:carekids/shared/utils/date_utils.dart';
import 'package:carekids/shared/utils/mock_events.dart';
import 'package:carekids/features/dashboard/screens/notification_screen.dart';
import 'package:carekids/features/auth/screens/user_profile_screen.dart';
import 'package:carekids/features/dashboard/models/family_member.dart';
import 'package:carekids/features/dashboard/services/dashboard_repository.dart';
import 'package:carekids/features/dashboard/widgets/background_blobs.dart';
import 'package:carekids/features/dashboard/widgets/dashboard_header.dart';
import 'package:carekids/features/dashboard/widgets/welcome_message.dart';
import 'package:carekids/features/dashboard/widgets/child_avatar_row.dart';
import 'package:carekids/features/dashboard/widgets/child_card.dart';
import 'package:carekids/features/dashboard/widgets/quick_actions_section.dart';
import 'package:carekids/features/dashboard/widgets/next_reminder_section.dart';
import 'package:carekids/features/dashboard/widgets/date_calendar_section.dart';
import 'package:carekids/features/dashboard/widgets/dashboard_bottom_nav.dart';
import 'package:carekids/features/dashboard/widgets/family_drawer.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final _repository = DashboardRepository(Supabase.instance.client);

  bool _isLoading = true;
  String? _role;
  String? _familyId;
  String? _firstName;
  String? _familyName;
  String? _currentUserId;
  List<ChildProfile> _children = [];
  List<FamilyMember> _familyMembers = [];
  int _selectedIndex = 0;
  bool _cardVisible = false;
  int _pendingRequestCount = 0;

  DateTime? _selectedCalendarDate;
  late final int _daysInCurrentMonth;
  static const double _calendarItemExtent = 114;
  late final ScrollController _calendarScrollController;

  bool get _isAdmin => _role == 'admin';

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

  // ---------------------------------------------------------------------
  // Data loading
  // ---------------------------------------------------------------------

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    try {
      final data = await _repository.loadDashboardData();

      _role = data.role;
      _familyId = data.familyId;
      _firstName = data.firstName;
      _familyName = data.familyName;
      _currentUserId = Supabase.instance.client.auth.currentUser!.id;
      _familyMembers = data.familyMembers;
      _children = data.children;
      _pendingRequestCount = data.pendingRequestCount;

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

  // ---------------------------------------------------------------------
  // Family member actions (called from FamilyDrawer)
  // ---------------------------------------------------------------------

  Future<void> _editMemberName(FamilyMember member, String newName) async {
    try {
      await _repository.updateMemberDisplayName(memberId: member.id, newName: newName);

      setState(() {
        final index = _familyMembers.indexWhere((m) => m.id == member.id);
        if (index != -1) {
          _familyMembers[index] = member.copyWith(displayName: newName);
        }
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Display name updated ✅')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update display name: $e')),
        );
      }
    }
  }

  Future<void> _editFamilyName(String newName) async {
    if (_familyId == null) return;

    try {
      await _repository.updateFamilyName(familyId: _familyId!, newName: newName);

      setState(() {
        _familyName = newName;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Family name updated ✅')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update family name: $e')),
        );
      }
    }
  }

  Future<void> _changeMemberRole(FamilyMember member, String newRole) async {
    try {
      await _repository.updateMemberRole(memberId: member.id, newRole: newRole);

      setState(() {
        final index = _familyMembers.indexWhere((m) => m.id == member.id);
        if (index != -1) {
          _familyMembers[index] = _familyMembers[index].copyWith(role: newRole);
        }
        if (member.id == _currentUserId) {
          _role = newRole; // 🌟 sync role ตัวเอง เผื่อกด demote/promote ตัวเอง (มีผลกับ _isAdmin ทันที)
        }
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Role updated ✅')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update role: $e')),
        );
      }
    }
  }

  Future<void> _removeMember(FamilyMember member, {required bool isSelfLeaving}) async {
    try {
      await _repository.removeMemberFromFamily(member.id);

      setState(() {
        _familyMembers.removeWhere((m) => m.id == member.id);
      });

      if (mounted && !isSelfLeaving) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${member.displayName} removed from family')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to remove member: $e')),
        );
      }
      return;
    }

    if (isSelfLeaving && mounted) {
      await _repository.signOut();
    }
  }

  // ---------------------------------------------------------------------
  // Child profile actions
  // ---------------------------------------------------------------------

  // 🌟 confirm ก่อนสลับไปดูเด็กคนอื่น (แตะคนเดิมซ้ำยังคงแค่ toggle การ์ดเหมือนเดิม ไม่ต้อง confirm)
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

  // 🌟 popup menu ตอนกดค้างที่เด็กซึ่งกำลัง active อยู่ (Admin เท่านั้น)
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
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Colors.red),
                title: const Text('Delete this child profile', style: TextStyle(color: Colors.red)),
                onTap: () {
                  Navigator.pop(context);
                  _confirmDeleteChild(child);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  // 🌟 เปลี่ยนรูปเด็ก เลือกจากคลังภาพ (gallery) แล้วอัปโหลดขึ้น Supabase Storage
  Future<void> _changeChildPhoto(ChildProfile child) async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
    if (pickedFile == null) return;

    try {
      final bytes = await pickedFile.readAsBytes();
      await _repository.uploadChildPhoto(childId: child.id, bytes: bytes);
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

  // 🌟 แก้ไขชื่อเด็ก
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
      await _repository.updateChildName(childId: child.id, newName: newName);
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

  // 🌟 Destructive Deletion Guardrail สำหรับ child profile (admin เท่านั้นที่เข้าถึงเมนูนี้ได้
  // เพราะ onLongPress ใน ChildAvatarRow เช็ค isAdmin ไว้แล้วตั้งแต่ต้นทาง)
  //
  // กฎ:
  // 1. ถ้าเหลือเด็กคนเดียวในระบบ -> บล็อกการลบทันที ป้องกัน empty state
  // 2. ถ้ามีหลายคน -> ต้องผ่าน confirm dialog แบบ high-visibility เตือนชัดเจนว่า
  //    ลบถาวร ข้อมูลกู้คืนไม่ได้ ก่อนลบจริง
  Future<void> _confirmDeleteChild(ChildProfile child) async {
    if (_children.length <= 1) {
      await showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text("Can't Delete Profile"),
          content: Text(
            '${child.name} is the only child profile in this family. '
            'At least one profile must remain. Add another child profile before deleting this one.',
          ),
          actions: [
            ElevatedButton(onPressed: () => Navigator.pop(context), child: const Text('OK')),
          ],
        ),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: const [
            Icon(Icons.warning_amber_rounded, color: Colors.red),
            SizedBox(width: 8),
            Expanded(child: Text('Delete Profile Permanently?')),
          ],
        ),
        content: Text(
          'This will permanently delete ${child.name}\'s profile, including all medication logs, '
          'weight history, and reminders. This action cannot be undone and the data cannot be recovered.\n\n'
          'Are you absolutely sure you want to continue?',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete Permanently'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await _repository.deleteChild(child.id);

      setState(() {
        if (_selectedIndex >= _children.length - 1) {
          _selectedIndex = 0; // 🌟 กันชี้ index เกินขอบ list หลังลบคนที่อยู่ท้ายๆ list
        }
      });
      await _loadData();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${child.name}\'s profile has been deleted')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete profile: $e')),
        );
      }
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

    try {
      await _repository.updateChildWeight(childId: child.id, weightKg: result);
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

  // ---------------------------------------------------------------------
  // Navigation helpers
  // ---------------------------------------------------------------------

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

  // ---------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(
        textTheme: GoogleFonts.baloo2TextTheme(Theme.of(context).textTheme),
      ),
      child: Scaffold(
        backgroundColor: const Color(0xFFF8F9FB),
        drawer: FamilyDrawer(
          familyName: _familyName,
          familyMembers: _familyMembers,
          currentUserId: _currentUserId,
          currentUserFirstName: _firstName,
          isAdmin: _isAdmin,
          familyId: _familyId,
          onEditMemberName: _editMemberName,
          onEditFamilyName: _editFamilyName,
          onChangeMemberRole: _changeMemberRole,
          onRemoveMember: _removeMember,
          onManageJoinRequests: _goToNotifications,
          onSignOut: () => _repository.signOut(),
        ),
        body: Stack(
          children: [
            // 🌟 วงกลมพื้นหลังสีเขียวจางๆ — fixed ตามจอ ไม่เลื่อนตาม scroll
            if (!_isLoading && _children.isNotEmpty) const BackgroundBlobs(),
            SafeArea(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _children.isEmpty
                      ? _buildEmptyState()
                      : _buildContent(),
            ),
          ],
        ),
        bottomNavigationBar: DashboardBottomNav(
          firstName: _firstName,
          onAccountTap: _goToUserProfile,
          onOtherTap: _showComingSoon,
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Column(
      children: [
        DashboardHeader(
          isAdmin: _isAdmin,
          pendingRequestCount: _pendingRequestCount,
          onNotificationsTap: _goToNotifications,
        ),
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
          DashboardHeader(
            isAdmin: _isAdmin,
            pendingRequestCount: _pendingRequestCount,
            onNotificationsTap: _goToNotifications,
          ),
          WelcomeMessage(familyName: _familyName),
          const SizedBox(height: 16),
          ChildAvatarRow(
            children: _children,
            selectedIndex: _selectedIndex,
            isAdmin: _isAdmin,
            onSelect: _confirmSwitchChild,
            onLongPressSelected: _showChildOptionsMenu,
            onAddChild: _goToAddChild,
          ),
          if (_cardVisible && _children.isNotEmpty) ...[
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: ChildCard(
                child: _children[_selectedIndex],
                isAdmin: _isAdmin,
                onUpdateWeight: () => _updateWeight(_children[_selectedIndex]),
              ),
            ),
          ],
          const SizedBox(height: 24),
          QuickActionsSection(onActionTap: _showComingSoon),
          const SizedBox(height: 24),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: NextReminderSection(),
          ),
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: DateCalendarSection(
              daysInCurrentMonth: _daysInCurrentMonth,
              calendarItemExtent: _calendarItemExtent,
              scrollController: _calendarScrollController,
              selectedDate: _selectedCalendarDate!,
              onDateSelected: (date) => setState(() => _selectedCalendarDate = date),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}