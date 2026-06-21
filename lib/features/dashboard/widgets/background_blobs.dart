import 'package:flutter/material.dart';

/// 🌟 วงกลมพื้นหลังสีเขียวจางๆ แบบ organic blob — fixed ตามจอ ไม่เลื่อนตาม scroll
/// ใช้ภายใน Stack ของ DashboardScreen ก่อน SafeArea/เนื้อหาหลัก
class BackgroundBlobs extends StatelessWidget {
  const BackgroundBlobs({super.key});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned(
          top: 280,
          right: -60,
          child: _BlobShape(size: 220, color: const Color(0xFF8FD9A0).withOpacity(0.30)),
        ),
        Positioned(
          top: 480,
          left: -90,
          child: _BlobShape(size: 260, color: const Color(0xFF8FD9A0).withOpacity(0.22)),
        ),
      ],
    );
  }
}

class _BlobShape extends StatelessWidget {
  const _BlobShape({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
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
}