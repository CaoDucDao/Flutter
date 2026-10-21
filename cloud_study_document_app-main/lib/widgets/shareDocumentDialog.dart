// ============================================================================
// Hộp thoại Chia sẻ Tài liệu & Quản lý Phân quyền (Supabase Permissions Modal)
// ============================================================================

import 'package:flutter/material.dart';
import '../struct/studyDocument.dart';
import '../struct/documentPermission.dart';
import '../struct/supabaseDocumentService.dart';
import '../struct/firebaseAuthService.dart';

class ShareDocumentDialog extends StatefulWidget {
  final StudyDocument document;

  const ShareDocumentDialog({
    super.key,
    required this.document,
  });

  static Future<void> show(BuildContext context, StudyDocument document) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => ShareDocumentDialog(document: document),
    );
  }

  @override
  State<ShareDocumentDialog> createState() => _ShareDocumentDialogState();
}

class _ShareDocumentDialogState extends State<ShareDocumentDialog> {
  final _emailController = TextEditingController();
  final _supabaseService = SupabaseDocumentService();
  DocumentPermissionRole _selectedRole = DocumentPermissionRole.viewer;
  bool _isLoading = false;
  List<DocumentPermission> _permissions = [];

  @override
  void initState() {
    super.initState();
    _loadPermissions();
  }

  Future<void> _loadPermissions() async {
    setState(() => _isLoading = true);
    final perms = await _supabaseService.getPermissionsForDocument(widget.document.id);
    if (mounted) {
      setState(() {
        _permissions = perms;
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _handleShare() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng nhập địa chỉ email người nhận')),
      );
      return;
    }

    setState(() => _isLoading = true);
    final success = await _supabaseService.shareDocument(
      documentId: widget.document.id,
      targetEmail: email,
      role: _selectedRole,
    );

    if (mounted) {
      setState(() => _isLoading = false);
      if (success) {
        _emailController.clear();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Expanded(child: Text('Đã cấp quyền truy cập tài liệu cho $email!')),
              ],
            ),
            backgroundColor: const Color(0xFF2E7D32),
            behavior: SnackBarBehavior.floating,
          ),
        );
        _loadPermissions();
      }
    }
  }

  Future<void> _handleRevoke(DocumentPermission perm) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Thu hồi quyền truy cập?'),
        content: Text('Bạn có chắc muốn xóa quyền của ${perm.userEmail}? Người này sẽ không thể truy cập tài liệu nữa.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Thu hồi'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _supabaseService.revokePermission(
        documentId: widget.document.id,
        targetUserId: perm.userId,
      );
      _loadPermissions();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final ownerEmail = widget.document.ownerEmail ?? 'caoducdao17022005@gmail.com';

    return Container(
      padding: EdgeInsets.only(
        top: 20,
        left: 20,
        right: 20,
        bottom: 20 + bottomInset,
      ),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.share_rounded, color: Colors.blue.shade700, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Chia sẻ tài liệu',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      widget.document.title,
                      style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Nhập email & chọn quyền
          Text(
            'Thêm người nhận',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface),
          ),
          const SizedBox(height: 8),

          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    hintText: 'Nhập email (ví dụ: member@gmail.com)',
                    hintStyle: TextStyle(fontSize: 13, color: Colors.grey.shade400),
                    prefixIcon: const Icon(Icons.mail_outline_rounded, size: 20),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: DropdownButton<DocumentPermissionRole>(
                  value: _selectedRole,
                  underline: const SizedBox(),
                  items: const [
                    DropdownMenuItem(
                      value: DocumentPermissionRole.viewer,
                      child: Text('Người xem', style: TextStyle(fontSize: 13)),
                    ),
                    DropdownMenuItem(
                      value: DocumentPermissionRole.editor,
                      child: Text('Chỉnh sửa', style: TextStyle(fontSize: 13)),
                    ),
                  ],
                  onChanged: (val) {
                    if (val != null) setState(() => _selectedRole = val);
                  },
                ),
              ),
            ],
          ),

          // Gợi ý thành viên nhanh trong nhóm
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: FirebaseAuthService.teamMembers
                  .where((m) => m.email.toLowerCase() != ownerEmail.toLowerCase())
                  .map((m) {
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: ActionChip(
                    avatar: const Icon(Icons.person_add_alt_1_rounded, size: 14),
                    label: Text(m.displayName, style: const TextStyle(fontSize: 11)),
                    onPressed: () {
                      _emailController.text = m.email;
                    },
                  ),
                );
              }).toList(),
            ),
          ),

          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1E88E5),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              icon: _isLoading
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.person_add_rounded, size: 18),
              label: const Text('Cấp quyền truy cập (Supabase RLS)', style: TextStyle(fontWeight: FontWeight.bold)),
              onPressed: _isLoading ? null : _handleShare,
            ),
          ),

          const SizedBox(height: 20),
          const Divider(),
          const SizedBox(height: 10),

          // Danh sách người đã được cấp quyền
          Row(
            children: [
              const Text(
                'Danh sách người có quyền truy cập',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.green.shade200),
                ),
                child: Text(
                  'RLS Đang bật',
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.green.shade800),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          Expanded(
            child: ListView(
              children: [
                // Chủ sở hữu (Owner)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    backgroundColor: Colors.indigo.shade100,
                    child: Icon(Icons.stars_rounded, color: Colors.indigo.shade700, size: 20),
                  ),
                  title: Text(ownerEmail, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  subtitle: const Text('Chủ sở hữu (Toàn quyền quản trị)', style: TextStyle(fontSize: 11, color: Colors.grey)),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.indigo.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Owner',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.indigo.shade700),
                    ),
                  ),
                ),

                // Danh sách được chia sẻ
                ..._permissions.map((perm) {
                  final isEditor = perm.role == DocumentPermissionRole.editor;
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(
                      backgroundColor: isEditor ? Colors.orange.shade100 : Colors.teal.shade100,
                      child: Icon(
                        isEditor ? Icons.edit_note_rounded : Icons.visibility_rounded,
                        color: isEditor ? Colors.orange.shade800 : Colors.teal.shade800,
                        size: 20,
                      ),
                    ),
                    title: Text(perm.displayName ?? perm.userEmail, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                    subtitle: Text(perm.userEmail, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: isEditor ? Colors.orange.shade50 : Colors.teal.shade50,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            perm.role.displayName,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: isEditor ? Colors.orange.shade800 : Colors.teal.shade800,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.remove_circle_outline_rounded, color: Colors.red, size: 20),
                          tooltip: 'Thu hồi quyền',
                          onPressed: () => _handleRevoke(perm),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
