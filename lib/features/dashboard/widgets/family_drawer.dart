import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:carekids/features/dashboard/models/family_member.dart';
import 'package:carekids/features/auth/screens/account_switcher_screen.dart';
import 'package:carekids/features/auth/screens/family_invite_screen.dart';

/// 🌟 Drawer หลักของ Dashboard: header ชื่อแฟมิลี่, รายชื่อสมาชิกแบ่งกลุ่ม Parents/Caregivers,
/// เมนู (View Invitation Code / Manage Join Requests / Sign Out), และ footer บัญชีผู้ใช้ปัจจุบัน
///
/// Callback ทั้งหมดส่งกลับไปให้ parent (DashboardScreen) เป็นคนเรียก Supabase จริง
/// เพื่อให้ widget นี้โฟกัสแค่การแสดงผลและ UX ของ popup เท่านั้น
class FamilyDrawer extends StatelessWidget {
  const FamilyDrawer({
    super.key,
    required this.familyName,
    required this.familyMembers,
    required this.currentUserId,
    required this.currentUserFirstName,
    required this.isAdmin,
    required this.familyId,
    required this.onEditMemberName,
    required this.onChangeMemberRole,
    required this.onRemoveMember,
    required this.onManageJoinRequests,
    required this.onSignOut,
  });

  final String? familyName;
  final List<FamilyMember> familyMembers;
  final String? currentUserId;
  final String? currentUserFirstName;
  final bool isAdmin;
  final String? familyId;

  /// เรียกตอนกด Save ใน Edit Display Name popup
  final Future<void> Function(FamilyMember member, String newName) onEditMemberName;

  /// เรียกตอนเลือก role ใหม่ใน Manage Role popup
  final Future<void> Function(FamilyMember member, String newRole) onChangeMemberRole;

  /// เรียกหลัง confirm dialog ของ Remove/Leave แล้ว (isSelfLeaving บอกว่าเป็นการออกเองหรือถูกเตะ)
  final Future<void> Function(FamilyMember member, {required bool isSelfLeaving}) onRemoveMember;

  final VoidCallback onManageJoinRequests;
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) {
    final admins = familyMembers.where((m) => m.role == 'admin').toList();
    final caregivers = familyMembers.where((m) => m.role == 'caregiver').toList();

    return Drawer(
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 🌟 Header: ชื่อครอบครัวตามที่ผู้ใช้ตั้งไว้ตอนสร้างแฟมิลี่
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
              child: Text(
                familyName != null && familyName!.isNotEmpty ? familyName! : 'My Family',
                style: GoogleFonts.baloo2(fontSize: 20, fontWeight: FontWeight.w700, color: const Color(0xFF1A1A1A)),
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 8),
                children: [
                  if (admins.isNotEmpty) ...[
                    _SectionLabel(label: 'Parents'),
                    for (final member in admins) _buildMemberTile(context, member),
                  ],
                  if (caregivers.isNotEmpty) ...[
                    _SectionLabel(label: 'Caregivers'),
                    for (final member in caregivers) _buildMemberTile(context, member),
                  ],
                  const SizedBox(height: 8),
                  const Divider(height: 1),
                  if (isAdmin && familyId != null)
                    ListTile(
                      leading: const Icon(Icons.qr_code),
                      title: const Text('View Invitation Code'),
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => FamilyInviteScreen(familyId: familyId!)),
                        );
                      },
                    ),
                  if (isAdmin)
                    ListTile(
                      leading: const Icon(Icons.group_add_outlined),
                      title: const Text('Manage Join Requests'),
                      onTap: () {
                        Navigator.pop(context);
                        onManageJoinRequests();
                      },
                    ),
                  ListTile(
                    leading: const Icon(Icons.logout, color: Colors.red),
                    title: const Text('Sign Out (Debug)'),
                    onTap: () {
                      Navigator.pop(context);
                      onSignOut();
                    },
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            ListTile(
              leading: CircleAvatar(
                radius: 16,
                backgroundColor: Colors.purple.shade100,
                child: Text(
                  (currentUserFirstName != null && currentUserFirstName!.isNotEmpty)
                      ? currentUserFirstName![0].toUpperCase()
                      : '',
                  style: const TextStyle(fontSize: 12, color: Colors.black87),
                ),
              ),
              title: Text(currentUserFirstName ?? 'Account'),
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

  // 🌟 แต่ละ tile กดค้างเพื่อเปิด popup จัดการสมาชิก
  // Admin: กดค้างได้ทุกคน (ตัวเอง + admin อื่น + caregiver)
  // Caregiver: กดค้างได้แค่ตัวเอง
  Widget _buildMemberTile(BuildContext context, FamilyMember member) {
    final isMe = member.id == currentUserId;
    final canLongPress = isAdmin || isMe;

    return GestureDetector(
      onLongPress: canLongPress ? () => _showMemberOptionsMenu(context, member) : null,
      child: ListTile(
        leading: CircleAvatar(
          radius: 16,
          backgroundColor: member.role == 'admin' ? Colors.blue.shade100 : Colors.orange.shade100,
          child: Text(
            member.displayName.isNotEmpty ? member.displayName[0].toUpperCase() : '?',
            style: const TextStyle(fontSize: 12, color: Colors.black87, fontWeight: FontWeight.bold),
          ),
        ),
        title: Row(
          children: [
            Flexible(child: Text(member.displayName, overflow: TextOverflow.ellipsis)),
            if (isMe) ...[
              const SizedBox(width: 6),
              Text('(You)', style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
            ],
            if (member.isOwner) ...[
              const SizedBox(width: 6),
              const Icon(Icons.star, size: 14, color: Color(0xFFE0A52E)),
            ],
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------
  // Popups
  // ---------------------------------------------------------------------

  void _showMemberOptionsMenu(BuildContext context, FamilyMember member) {
    final isMe = member.id == currentUserId;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(member.displayName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.edit_outlined),
                title: const Text('Edit Display Name'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _showEditNameDialog(context, member);
                },
              ),
              // 🌟 Manage Role: Admin เท่านั้น และจัดการได้ทุกคน (รวมตัวเอง)
              if (isAdmin)
                ListTile(
                  leading: const Icon(Icons.admin_panel_settings_outlined),
                  title: const Text('Manage Role'),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _showRoleManagerSheet(context, member);
                  },
                ),
              // 🌟 Remove/Leave:
              // - Admin มองคนอื่น -> "Remove from Family"
              // - ตัวเองมองตัวเอง (ไม่ว่า role ไหน) -> "Leave Family"
              if (isAdmin && !isMe)
                ListTile(
                  leading: const Icon(Icons.person_remove_outlined, color: Colors.red),
                  title: const Text('Remove from Family', style: TextStyle(color: Colors.red)),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _confirmRemoveMember(context, member, isSelfLeaving: false);
                  },
                ),
              if (isMe)
                ListTile(
                  leading: const Icon(Icons.exit_to_app, color: Colors.red),
                  title: const Text('Leave Family', style: TextStyle(color: Colors.red)),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _confirmRemoveMember(context, member, isSelfLeaving: true);
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _showEditNameDialog(BuildContext context, FamilyMember member) async {
    final controller = TextEditingController(text: member.displayName);

    final newName = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Edit Display Name'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Display name', border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              final value = controller.text.trim();
              if (value.isEmpty) return;
              Navigator.pop(dialogContext, value);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (newName == null || newName == member.displayName) return;
    await onEditMemberName(member, newName);
  }

  void _showRoleManagerSheet(BuildContext context, FamilyMember member) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text('Manage Role: ${member.displayName}',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ),
              const Divider(height: 1),
              RadioListTile<String>(
                value: 'admin',
                groupValue: member.role,
                title: const Text('Parent (Admin)'),
                subtitle: const Text('Full access: manage children, members, and settings'),
                onChanged: (value) {
                  Navigator.pop(sheetContext);
                  if (value != null && value != member.role) onChangeMemberRole(member, value);
                },
              ),
              RadioListTile<String>(
                value: 'caregiver',
                groupValue: member.role,
                title: const Text('Caregiver'),
                subtitle: const Text('Can view and log info, limited management access'),
                onChanged: (value) {
                  Navigator.pop(sheetContext);
                  if (value != null && value != member.role) onChangeMemberRole(member, value);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  // 🌟 Confirm popup ก่อน remove/leave จริง
  // กฎพิเศษ: หัวตี้ (isOwner) ออกแฟมิลี่เองไม่ได้ ต้องโอนสิทธิ์ owner ให้ admin คนอื่นก่อน
  Future<void> _confirmRemoveMember(
    BuildContext context,
    FamilyMember member, {
    required bool isSelfLeaving,
  }) async {
    if (isSelfLeaving && member.isOwner) {
      final hasOtherAdmin = familyMembers.any((m) => m.id != member.id && m.role == 'admin');
      await showDialog(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text("Can't Leave Family"),
          content: Text(
            hasOtherAdmin
                ? 'You are the family owner. Please transfer ownership to another Parent before leaving.'
                : 'You are the only Parent in this family. Add another Parent and transfer ownership before leaving.',
          ),
          actions: [
            ElevatedButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('OK')),
          ],
        ),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(isSelfLeaving ? 'Leave Family?' : 'Remove Member?'),
        content: Text(
          isSelfLeaving
              ? 'Are you sure you want to leave this family? You will lose access to all children\'s data.'
              : 'Are you sure you want to remove ${member.displayName} from this family?',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(isSelfLeaving ? 'Leave' : 'Remove'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    await onRemoveMember(member, isSelfLeaving: isSelfLeaving);
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 6),
      child: Text(
        label,
        style: GoogleFonts.baloo2(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.grey.shade500),
      ),
    );
  }
}