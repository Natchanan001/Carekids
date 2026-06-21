import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:carekids/shared/models/child_profile.dart';
import 'package:carekids/features/dashboard/models/family_member.dart';

/// 🌟 ผลลัพธ์การโหลดข้อมูลหน้า Dashboard ทั้งหมดในครั้งเดียว
class DashboardData {
  final String role;
  final String? familyId;
  final String? firstName;
  final String? familyName;
  final List<FamilyMember> familyMembers;
  final List<ChildProfile> children;
  final int pendingRequestCount;

  const DashboardData({
    required this.role,
    required this.familyId,
    required this.firstName,
    required this.familyName,
    required this.familyMembers,
    required this.children,
    required this.pendingRequestCount,
  });

  bool get isAdmin => role == 'admin';
}

/// 🌟 รวม Supabase calls ทั้งหมดที่ DashboardScreen ใช้ไว้ในที่เดียว
/// แยกออกจาก UI เพื่อให้ทดสอบ/แก้ไข logic การดึง-บันทึกข้อมูลได้ง่ายขึ้น
/// โดยไม่ต้องแตะ widget tree
class DashboardRepository {
  DashboardRepository(this._supabase);

  final SupabaseClient _supabase;

  /// โหลดข้อมูลทั้งหมดที่หน้า Dashboard ต้องใช้: โปรไฟล์ผู้ใช้, ชื่อแฟมิลี่,
  /// รายชื่อสมาชิกในแฟมิลี่, รายชื่อเด็ก, จำนวน join request ที่รออนุมัติ
  Future<DashboardData> loadDashboardData() async {
    final userId = _supabase.auth.currentUser!.id;

    final profile = await _supabase
        .from('profiles')
        .select('role, family_id, first_name, last_name, families(name)')
        .eq('id', userId)
        .single();

    final role = profile['role'] as String? ?? 'caregiver';
    final familyId = profile['family_id'] as String?;
    final firstName = profile['first_name'] as String?;
    final familyName = profile['families']?['name'] as String?;

    final familyMembers = familyId != null
        ? await _loadFamilyMembers(familyId: familyId, currentUserId: userId)
        : <FamilyMember>[];

    final children = familyId != null ? await _loadChildren(familyId) : <ChildProfile>[];

    final pendingRequestCount =
        (role == 'admin' && familyId != null) ? await _loadPendingRequestCount(familyId) : 0;

    return DashboardData(
      role: role,
      familyId: familyId,
      firstName: firstName,
      familyName: familyName,
      familyMembers: familyMembers,
      children: children,
      pendingRequestCount: pendingRequestCount,
    );
  }

  /// ดึงสมาชิกทั้งหมดในแฟมิลี่เดียวกัน พร้อมคำนวณ isOwner แบบ heuristic
  ///
  /// ⚠️ HEURISTIC ชั่วคราว: ยังไม่มี families.owner_id ใน schema จริง
  /// จึงสมมติว่า admin ที่ created_at เก่าที่สุดคือผู้สร้างแฟมิลี่ (หัวตี้)
  /// วิธีนี้ไม่แม่นยำ 100% (เช่น ถ้าหัวตี้ตัวจริงโดน remove ไปแล้ว คนถัดไปจะถูกเข้าใจผิดว่าเป็นหัวตี้)
  /// TODO: เพิ่ม column families.owner_id แล้วเปลี่ยนมาเช็คจาก field นั้นโดยตรงแทน heuristic นี้
  Future<List<FamilyMember>> _loadFamilyMembers({
    required String familyId,
    required String currentUserId,
  }) async {
    final membersData = await _supabase
        .from('profiles')
        .select('id, display_name, first_name, last_name, role, family_id, created_at')
        .eq('family_id', familyId)
        .order('created_at'); // เรียงเก่า -> ใหม่ ใช้หา "หัวตี้" แบบ heuristic ด้านล่าง

    final sortedMembers = membersData as List;

    String? heuristicOwnerId;
    for (final m in sortedMembers) {
      if (m['role'] == 'admin') {
        heuristicOwnerId = m['id'] as String;
        break;
      }
    }

    return sortedMembers.map((m) {
      final id = m['id'] as String;
      final firstName = m['first_name'] as String? ?? '';
      final lastName = m['last_name'] as String? ?? '';
      final fullName = [firstName, lastName].where((s) => s.isNotEmpty).join(' ');
      final displayName = (m['display_name'] as String?)?.isNotEmpty == true
          ? m['display_name'] as String
          : (fullName.isNotEmpty ? fullName : 'Member');

      return FamilyMember(
        id: id,
        displayName: displayName,
        role: m['role'] as String? ?? 'caregiver',
        isOwner: id == heuristicOwnerId,
      );
    }).toList();
  }

  Future<List<ChildProfile>> _loadChildren(String familyId) async {
    final childrenData =
        await _supabase.from('children').select().eq('family_id', familyId).order('created_at');
    return childrenData.map<ChildProfile>((c) => ChildProfile.fromMap(c)).toList();
  }

  Future<int> _loadPendingRequestCount(String familyId) async {
    final pending = await _supabase
        .from('join_requests')
        .select('id')
        .eq('family_id', familyId)
        .eq('status', 'pending');
    return (pending as List).length;
  }

  // ---------------------------------------------------------------------
  // Family member mutations
  // ---------------------------------------------------------------------

  Future<void> updateMemberDisplayName({required String memberId, required String newName}) {
    return _supabase.from('profiles').update({'display_name': newName}).eq('id', memberId);
  }

  Future<void> updateMemberRole({required String memberId, required String newRole}) {
    return _supabase.from('profiles').update({'role': newRole}).eq('id', memberId);
  }

  /// นำสมาชิกออกจากแฟมิลี่ด้วยการล้าง family_id (ไม่ลบ profile/บัญชีทั้งหมด)
  /// ผู้ใช้ยังคงมีบัญชีอยู่ สามารถ join แฟมิลี่ใหม่ได้ภายหลัง
  Future<void> removeMemberFromFamily(String memberId) {
    return _supabase.from('profiles').update({'family_id': null}).eq('id', memberId);
  }

  Future<void> signOut() => _supabase.auth.signOut();

  // ---------------------------------------------------------------------
  // Child profile mutations
  // ---------------------------------------------------------------------

  Future<void> updateChildWeight({required String childId, required double weightKg}) async {
    final userId = _supabase.auth.currentUser!.id;

    await _supabase.from('weight_logs').insert({
      'child_id': childId,
      'weight_kg': weightKg,
      'recorded_by': userId,
    });

    await _supabase.from('children').update({
      'weight_kg': weightKg,
      'weight_updated_at': DateTime.now().toIso8601String(),
    }).eq('id', childId);
  }

  Future<void> updateChildName({required String childId, required String newName}) {
    return _supabase.from('children').update({'name': newName}).eq('id', childId);
  }

  Future<String> uploadChildPhoto({required String childId, required Uint8List bytes}) async {
    final path = '$childId.jpg';

    await _supabase.storage.from('child-photos').uploadBinary(
          path,
          bytes,
          fileOptions: const FileOptions(upsert: true, contentType: 'image/jpeg'),
        );

    final publicUrl = _supabase.storage.from('child-photos').getPublicUrl(path);
    // 🌟 ใส่ timestamp กัน cache รูปเก่าค้าง ไม่งั้นรูปใหม่จะไม่อัปเดตในแอป
    final cacheBustedUrl = '$publicUrl?t=${DateTime.now().millisecondsSinceEpoch}';

    await _supabase.from('children').update({'photo_url': cacheBustedUrl}).eq('id', childId);
    return cacheBustedUrl;
  }
}