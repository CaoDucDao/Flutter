// ============================================================================
// Widget Hiển thị & Chuyển đổi nhanh Tài khoản người dùng (Account Switcher)
// Cho phép chuyển đổi qua lại giữa các tài khoản kiểm thử ngay trên Header của App
// ============================================================================

import 'package:flutter/material.dart';
import '../struct/firebaseAuthService.dart';

class UserAccountSwitcher extends StatelessWidget {
  const UserAccountSwitcher({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = FirebaseAuthService();
    final user = authService.currentUser;
    final displayName = user?.displayName ?? 'Khách';
    final role = user?.role ?? 'Chưa đăng nhập';
    final email = user?.email ?? '';

    Color badgeColor;
    if (role.toLowerCase().contains('owner')) {
      badgeColor = const Color(0xFFD81B60);
    } else if (role.toLowerCase().contains('editor')) {
      badgeColor = Colors.orange.shade800;
    } else {
      badgeColor = Colors.teal.shade700;
    }

    return PopupMenuButton<String>(
      tooltip: 'Tài khoản: $displayName',
      padding: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      offset: const Offset(0, 48),
      onSelected: (val) async {
        if (val == 'sign_out') {
          await authService.signOut();
        } else {
          final target = FirebaseAuthService.teamMembers.firstWhere(
            (m) => m.email == val,
            orElse: () => FirebaseAuthService.teamMembers.first,
          );
          await authService.signInWithGoogle(user: target);
        }
      },
      itemBuilder: (context) => [
        // Header info
        PopupMenuItem<String>(
          enabled: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                displayName,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black87),
              ),
              Text(
                email,
                style: const TextStyle(fontSize: 11, color: Colors.grey),
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: badgeColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  role,
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: badgeColor),
                ),
              ),
              const Divider(),
            ],
          ),
        ),
        const PopupMenuItem<String>(
          enabled: false,
          child: Text(
            'CHUYỂN NHANH TÀI KHOẢN:',
            style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey),
          ),
        ),
        // Danh sách các tài khoản kiểm thử
        ...FirebaseAuthService.teamMembers.map((m) {
          final isCurrent = m.email == email;
          return PopupMenuItem<String>(
            value: m.email,
            child: Row(
              children: [
                Icon(
                  isCurrent ? Icons.check_circle_rounded : Icons.account_circle_outlined,
                  size: 18,
                  color: isCurrent ? badgeColor : Colors.grey.shade600,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        m.displayName,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                          color: isCurrent ? badgeColor : Colors.black87,
                        ),
                      ),
                      Text(
                        m.role,
                        style: const TextStyle(fontSize: 10, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }),
        const PopupMenuDivider(),
        const PopupMenuItem<String>(
          value: 'sign_out',
          child: Row(
            children: [
              Icon(Icons.logout_rounded, size: 18, color: Colors.red),
              SizedBox(width: 8),
              Text('Đăng xuất về màn hình chọn', style: TextStyle(color: Colors.red, fontSize: 13, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: badgeColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: badgeColor.withOpacity(0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 12,
              backgroundColor: badgeColor,
              child: Text(
                displayName.isNotEmpty ? displayName[0] : 'U',
                style: const TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(width: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 120),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    displayName,
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    role.split('/').first.trim(),
                    style: TextStyle(fontSize: 9, color: badgeColor, fontWeight: FontWeight.w600),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 4),
            Icon(Icons.arrow_drop_down_rounded, size: 18, color: badgeColor),
          ],
        ),
      ),
    );
  }
}
