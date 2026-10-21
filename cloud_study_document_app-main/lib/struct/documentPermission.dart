// ============================================================================
// Model Phân quyền chia sẻ tài liệu (Document Permissions)
// Ánh xạ trực tiếp với bảng public.document_permissions trên Supabase
// ============================================================================

enum DocumentPermissionRole {
  viewer, // Chỉ đọc / tải về
  editor, // Được chỉnh sửa thông tin tài liệu
  admin,  // Toàn quyền quản lý và chia sẻ
}

extension DocumentPermissionRoleExtension on DocumentPermissionRole {
  String get displayName {
    switch (this) {
      case DocumentPermissionRole.viewer:
        return 'Người xem (Chỉ đọc)';
      case DocumentPermissionRole.editor:
        return 'Người chỉnh sửa (Editor)';
      case DocumentPermissionRole.admin:
        return 'Quản trị viên (Admin)';
    }
  }

  String get shortName {
    switch (this) {
      case DocumentPermissionRole.viewer:
        return 'Xem';
      case DocumentPermissionRole.editor:
        return 'Sửa';
      case DocumentPermissionRole.admin:
        return 'Quản trị';
    }
  }

  static DocumentPermissionRole fromString(String? val) {
    if (val == null) return DocumentPermissionRole.viewer;
    switch (val.toLowerCase()) {
      case 'editor':
        return DocumentPermissionRole.editor;
      case 'admin':
        return DocumentPermissionRole.admin;
      case 'viewer':
      default:
        return DocumentPermissionRole.viewer;
    }
  }
}

class DocumentPermission {
  final String id;
  final String documentId;
  final String userId;
  final String userEmail;
  final String? displayName;
  final DocumentPermissionRole role;
  final String? sharedBy;
  final DateTime createdAt;
  final DateTime updatedAt;

  DocumentPermission({
    required this.id,
    required this.documentId,
    required this.userId,
    required this.userEmail,
    this.displayName,
    this.role = DocumentPermissionRole.viewer,
    this.sharedBy,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  DocumentPermission copyWith({
    String? id,
    String? documentId,
    String? userId,
    String? userEmail,
    String? displayName,
    DocumentPermissionRole? role,
    String? sharedBy,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return DocumentPermission(
      id: id ?? this.id,
      documentId: documentId ?? this.documentId,
      userId: userId ?? this.userId,
      userEmail: userEmail ?? this.userEmail,
      displayName: displayName ?? this.displayName,
      role: role ?? this.role,
      sharedBy: sharedBy ?? this.sharedBy,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'document_id': documentId,
      'user_id': userId,
      'user_email': userEmail,
      'permission_role': role.name,
      'shared_by': sharedBy,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory DocumentPermission.fromMap(Map<String, dynamic> map) {
    return DocumentPermission(
      id: (map['id'] ?? '') as String,
      documentId: (map['document_id'] ?? map['documentId'] ?? '') as String,
      userId: (map['user_id'] ?? map['userId'] ?? '') as String,
      userEmail: (map['user_email'] ?? map['userEmail'] ?? '') as String,
      displayName: map['display_name'] as String?,
      role: DocumentPermissionRoleExtension.fromString(
        map['permission_role'] ?? map['role'],
      ),
      sharedBy: map['shared_by'] as String?,
      createdAt: map['created_at'] != null
          ? DateTime.tryParse(map['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
      updatedAt: map['updated_at'] != null
          ? DateTime.tryParse(map['updated_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}
