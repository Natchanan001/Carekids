import 'package:flutter/material.dart';
import 'package:carekids/shared/models/child_profile.dart';

/// 🌟 การ์ดข้อมูลเด็กที่เลือกอยู่: ชื่อ, อายุ, น้ำหนักปัจจุบัน, ปุ่มอัปเดตน้ำหนัก (admin เท่านั้น)
/// และคำเตือนถ้าน้ำหนักไม่ได้อัปเดตเกิน 1 สัปดาห์
class ChildCard extends StatelessWidget {
  const ChildCard({
    super.key,
    required this.child,
    required this.isAdmin,
    required this.onUpdateWeight,
  });

  final ChildProfile child;
  final bool isAdmin;
  final VoidCallback onUpdateWeight;

  @override
  Widget build(BuildContext context) {
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
              if (isAdmin) ElevatedButton(onPressed: onUpdateWeight, child: const Text('Update')),
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
          if (isAdmin) ...[
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
}