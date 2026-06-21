// 🌟 Model: สมาชิกในครอบครัว (ใช้แสดงผลใน Drawer และจัดการ role/display name)
//
// หมายเหตุเรื่อง isOwner:
// ยังไม่มี column families.owner_id ใน schema จริง จึงคำนวณค่านี้แบบ heuristic
// (สมมติว่า admin ที่ created_at เก่าที่สุดคือผู้สร้างแฟมิลี่) ใน DashboardRepository
// TODO: เมื่อมี families.owner_id แล้ว ให้เปลี่ยนมาเช็คจาก field นั้นโดยตรงแทน heuristic นี้
class FamilyMember {
  final String id;
  final String displayName;
  final String role; // 'admin' (Parent) หรือ 'caregiver'
  final bool isOwner; // true ถ้าเป็นผู้สร้างครอบครัว (ห้ามออกแฟมิลี่เองจนกว่าจะโอนสิทธิ์)

  const FamilyMember({
    required this.id,
    required this.displayName,
    required this.role,
    required this.isOwner,
  });

  FamilyMember copyWith({String? displayName, String? role, bool? isOwner}) {
    return FamilyMember(
      id: id,
      displayName: displayName ?? this.displayName,
      role: role ?? this.role,
      isOwner: isOwner ?? this.isOwner,
    );
  }
}