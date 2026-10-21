import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../struct/studyDocument.dart';
import '../struct/studyCourse.dart';
import '../struct/firebaseAuthService.dart';
import '../database/study_course_dao.dart';
import '../pages/addEditStudyDocumentPage.dart';
import 'shareDocumentDialog.dart';

typedef DocumentCard = StudyDocumentCard;

class StudyDocumentCard extends StatelessWidget {
  final StudyDocument document;
  final ValueChanged<DocumentStatus>? onStatusChanged;
  final VoidCallback? onDelete;
  final Course? course;
  final VoidCallback? onTap;

  const StudyDocumentCard({
    super.key,
    required this.document,
    this.onStatusChanged,
    this.onDelete,
    this.course,
    this.onTap,
  });

  String _formatDate(DateTime date) {
    return DateFormat('dd/MM/yyyy').format(date);
  }

  Color _getTypeColor(DocumentType type) {
    switch (type) {
      case DocumentType.lecture:
        return Colors.blue;
      case DocumentType.exercise:
        return Colors.orange;
      case DocumentType.reference:
        return Colors.teal;
    }
  }

  String _getTypeLabel(DocumentType type) {
    switch (type) {
      case DocumentType.lecture:
        return "Bài giảng";
      case DocumentType.exercise:
        return "Bài tập";
      case DocumentType.reference:
        return "Tài liệu tham khảo";
    }
  }

  IconData _getTypeIcon(DocumentType type) {
    switch (type) {
      case DocumentType.lecture:
        return Icons.menu_book_rounded;
      case DocumentType.exercise:
        return Icons.assignment_rounded;
      case DocumentType.reference:
        return Icons.auto_stories_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final typeColor = _getTypeColor(document.type);
    final isDone = document.status == DocumentStatus.completed;
    final isOverdue = document.deadline != null &&
        document.deadline!.isBefore(DateTime.now()) &&
        !isDone;

    final authService = FirebaseAuthService();
    final currentUser = authService.currentUser;
    final canEdit = document.canUserEdit(currentUser);
    final canDelete = document.canUserDelete(currentUser);
    final canShare = document.canUserShare(currentUser);
    final userRole = document.getDisplayPermission(currentUser);

    final courseDao = CourseDao();
    final Course? resolvedCourse = course ?? (document.courseId.isNotEmpty
        ? courseDao.getById(document.courseId)
        : null);

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withOpacity(0.3),
        ),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap ??
              () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => AddEditDocumentPage(initialDocument: document),
                  ),
                );
              },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Tag Row
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: typeColor.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(_getTypeIcon(document.type), size: 13, color: typeColor),
                          const SizedBox(width: 5),
                          Text(
                            _getTypeLabel(document.type),
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: typeColor),
                          ),
                        ],
                      ),
                    ),

                    if (resolvedCourse != null) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                        decoration: BoxDecoration(
                          color: Color(resolvedCourse.colorValue).withOpacity(0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          resolvedCourse.code,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Color(resolvedCourse.colorValue),
                          ),
                        ),
                      ),
                    ],

                    const SizedBox(width: 8),
                    _buildRoleBadge(userRole),

                    const Spacer(),

                    if (document.isPinned)
                      const Padding(
                        padding: EdgeInsets.only(right: 6),
                        child: Icon(Icons.push_pin_rounded, size: 16, color: Colors.amber),
                      ),

                    if (document.isSynced)
                      const Padding(
                        padding: EdgeInsets.only(right: 6),
                        child: Icon(Icons.cloud_done_rounded, size: 16, color: Colors.teal),
                      ),

                    PopupMenuButton<String>(
                      icon: Icon(Icons.more_horiz_rounded, size: 20, color: theme.colorScheme.onSurfaceVariant),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onSelected: (val) {
                        if (val == 'share') {
                          if (canShare) {
                            ShareDocumentDialog.show(context, document);
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Chỉ Chủ sở hữu (Owner) mới có quyền chia sẻ tài liệu!'),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        } else if (val == 'edit' || val == 'view') {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => AddEditDocumentPage(initialDocument: document),
                            ),
                          );
                        } else if (val == 'delete') {
                          if (canDelete && onDelete != null) {
                            _showDeleteConfirmationDialog(context);
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Chỉ Chủ sở hữu (Owner) mới có quyền xóa tài liệu!'),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        }
                      },
                      itemBuilder: (context) => [
                        if (canShare)
                          const PopupMenuItem(
                            value: 'share',
                            child: Row(
                              children: [
                                Icon(Icons.share_outlined, size: 16, color: Colors.blue),
                                SizedBox(width: 8),
                                Text('Chia sẻ tài liệu', style: TextStyle(color: Colors.blue)),
                              ],
                            ),
                          ),
                        if (canEdit)
                          const PopupMenuItem(
                            value: 'edit',
                            child: Row(
                              children: [
                                Icon(Icons.edit_outlined, size: 16),
                                SizedBox(width: 8),
                                Text('Chỉnh sửa'),
                              ],
                            ),
                          )
                        else
                          const PopupMenuItem(
                            value: 'view',
                            child: Row(
                              children: [
                                Icon(Icons.visibility_outlined, size: 16, color: Colors.teal),
                                SizedBox(width: 8),
                                Text('Xem chi tiết (Chỉ đọc)', style: TextStyle(color: Colors.teal)),
                              ],
                            ),
                          ),
                        if (canDelete)
                          const PopupMenuItem(
                            value: 'delete',
                            child: Row(
                              children: [
                                Icon(Icons.delete_outline_rounded, size: 16, color: Colors.red),
                                SizedBox(width: 8),
                                Text('Xóa tài liệu', style: TextStyle(color: Colors.red)),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ],
                ),

                const SizedBox(height: 10),

                // Title
                Text(
                  document.title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    // decoration: isDone ? TextDecoration.lineThrough : null,
                    color: isDone ? Colors.grey : theme.colorScheme.onSurface,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),

                if (document.description.isNotEmpty) ...[
                  const SizedBox(height: 5),
                  Text(
                    document.description,
                    style: TextStyle(fontSize: 13, color: theme.colorScheme.onSurfaceVariant),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],

                const SizedBox(height: 12),

                // Footer: Deadline, Status, Toggle
                Row(
                  children: [
                    if (document.deadline != null) ...[
                      Icon(
                        Icons.schedule_rounded,
                        size: 14,
                        color: isOverdue ? Colors.red : Colors.grey,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _formatDate(document.deadline!),
                        style: TextStyle(
                          fontSize: 12,
                          color: isOverdue ? Colors.red : Colors.grey.shade700,
                          fontWeight: isOverdue ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                      const SizedBox(width: 10),
                    ],

                    _buildStatusBadge(document.status),

                    const Spacer(),

                    // Toggle complete button
                    InkWell(
                      borderRadius: BorderRadius.circular(20),
                      onTap: () {
                        if (!canEdit) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Row(
                                children: [
                                  Icon(Icons.lock_rounded, color: Colors.white, size: 18),
                                  SizedBox(width: 8),
                                  Expanded(
                                    child: Text('Tài khoản Viewer chỉ có quyền đọc. Không thể thay đổi trạng thái hoàn thành!'),
                                  ),
                                ],
                              ),
                              backgroundColor: Colors.orange,
                              behavior: SnackBarBehavior.floating,
                              duration: Duration(seconds: 2),
                            ),
                          );
                          return;
                        }
                        if (onStatusChanged != null) {
                          onStatusChanged!(
                            isDone ? DocumentStatus.inProgress : DocumentStatus.completed,
                          );
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: isDone ? Colors.green.withOpacity(0.15) : Colors.grey.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isDone ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                              size: 14,
                              color: isDone ? Colors.green.shade700 : Colors.grey.shade700,
                            ),
                            const SizedBox(width: 5),
                            Text(
                              isDone ? 'Đã xong' : 'Hoàn thành',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: isDone ? Colors.green.shade700 : Colors.grey.shade700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRoleBadge(String role) {
    Color bg;
    Color fg;
    IconData icon;
    String label = role;

    switch (role.toLowerCase()) {
      case 'owner':
        bg = const Color(0xFFD81B60).withOpacity(0.12);
        fg = const Color(0xFFD81B60);
        icon = Icons.workspace_premium_rounded;
        label = 'Owner';
        break;
      case 'editor':
        bg = Colors.orange.withOpacity(0.12);
        fg = Colors.orange.shade800;
        icon = Icons.edit_note_rounded;
        label = 'Editor';
        break;
      default:
        bg = Colors.teal.withOpacity(0.12);
        fg = Colors.teal.shade700;
        icon = Icons.visibility_rounded;
        label = 'Viewer';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: fg.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: fg),
          const SizedBox(width: 3),
          Text(
            label,
            style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: fg),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirmationDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.delete_forever_rounded, color: Colors.red),
            SizedBox(width: 8),
            Text('Xác nhận xóa tài liệu'),
          ],
        ),
        content: Text('Bạn có chắc chắn muốn xóa "${document.title}" không? Chỉ Chủ sở hữu mới được phép xóa.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('HỦY'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              if (onDelete != null) onDelete!();
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text('XÓA'),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(DocumentStatus status) {
    Color bg;
    Color fg;
    String label;

    switch (status) {
      case DocumentStatus.completed:
        bg = Colors.green.withOpacity(0.12);
        fg = Colors.green.shade700;
        label = 'Đã hoàn thành';
        break;
      case DocumentStatus.inProgress:
        bg = Colors.amber.withOpacity(0.15);
        fg = Colors.orange.shade800;
        label = 'Đang học';
        break;
      case DocumentStatus.todo:
        bg = Colors.grey.withOpacity(0.12);
        fg = Colors.grey.shade700;
        label = 'Cần học';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: fg),
      ),
    );
  }
}
