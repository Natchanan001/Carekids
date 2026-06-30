import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:carekids/shared/models/child_profile.dart';

/// 🌟 แถว avatar ของเด็กแต่ละคน + ปุ่มเพิ่มเด็ก (admin เท่านั้น)
/// เด็กที่ active อยู่จะถูกดันไปซ้ายสุดเสมอ พร้อม animation เลื่อนตำแหน่ง/ขยายขนาดแบบสมูท
class ChildAvatarRow extends StatelessWidget {
  const ChildAvatarRow({
    super.key,
    required this.children,
    required this.selectedIndex,
    required this.isAdmin,
    required this.onSelect,
    required this.onLongPressSelected,
    required this.onAddChild,
  });

  final List<ChildProfile> children;
  final int selectedIndex;
  final bool isAdmin;
  final ValueChanged<int> onSelect;
  final ValueChanged<ChildProfile> onLongPressSelected;
  final VoidCallback onAddChild;

  static const double _avatarSlotWidth = 84;
  static const double _avatarSelectedRadius = 35;
  static const double _avatarNormalRadius = 26;
  static const double _avatarAddRadius = 22;

  // 🌟 ลำดับ avatar โดยให้เด็กที่ active อยู่ซ้ายสุดเสมอ (สลับแล้วเลื่อนสมูท)
  List<ChildProfile> get _orderedChildren {
    if (children.isEmpty) return children;
    final ordered = List<ChildProfile>.from(children);
    final selected = ordered.removeAt(selectedIndex);
    ordered.insert(0, selected);
    return ordered;
  }

  @override
  Widget build(BuildContext context) {
    final ordered = _orderedChildren;
    final itemCount = ordered.length + (isAdmin ? 1 : 0);
    final rowWidth = itemCount * _avatarSlotWidth;

    return SizedBox(
      height: 110,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: SizedBox(
          width: rowWidth,
          height: 110,
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
                    child: _ChildAvatar(
                      child: ordered[i],
                      index: children.indexOf(ordered[i]),
                      selectedIndex: selectedIndex,
                      isAdmin: isAdmin,
                      onTap: onSelect,
                      onLongPressSelected: onLongPressSelected,
                    ),
                  ),
                ),
              if (isAdmin)
                AnimatedPositioned(
                  key: const ValueKey('add_child'),
                  duration: const Duration(milliseconds: 320),
                  curve: Curves.easeOutCubic,
                  left: ordered.length * _avatarSlotWidth,
                  top: 0,
                  child: SizedBox(
                    width: _avatarSlotWidth,
                    child: _AddChildAvatar(onTap: onAddChild),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChildAvatar extends StatelessWidget {
  const _ChildAvatar({
    required this.child,
    required this.index,
    required this.selectedIndex,
    required this.isAdmin,
    required this.onTap,
    required this.onLongPressSelected,
  });

  final ChildProfile child;
  final int index;
  final int selectedIndex;
  final bool isAdmin;
  final ValueChanged<int> onTap;
  final ValueChanged<ChildProfile> onLongPressSelected;

  @override
  Widget build(BuildContext context) {
    final isSelected = index == selectedIndex;
    final radius = isSelected ? ChildAvatarRow._avatarSelectedRadius : ChildAvatarRow._avatarNormalRadius;

    return GestureDetector(
      onTap: () => onTap(index),
      // 🌟 long press เปิดเมนูได้เฉพาะ Admin และต้องเป็นเด็กที่ active (เลือกอยู่) เท่านั้น
      onLongPress: (isAdmin && isSelected) ? () => onLongPressSelected(child) : null,
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
              fontSize: isSelected ? 15 : 13,
              color: isSelected ? const Color(0xFF5B9DF0) : const Color(0xFF333333),
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _AddChildAvatar extends StatelessWidget {
  const _AddChildAvatar({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.only(
          top: ChildAvatarRow._avatarSelectedRadius - ChildAvatarRow._avatarAddRadius + 2.5,
        ),
        child: Container(
          width: ChildAvatarRow._avatarAddRadius * 2,
          height: ChildAvatarRow._avatarAddRadius * 2,
          decoration: const BoxDecoration(
            color: Color(0xFF8AA624),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.add, color: Colors.white, size: 24),
        ),
      ),
    );
  }
}