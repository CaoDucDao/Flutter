import 'dart:convert';

enum DocumentType {
  lecture,
  exercise,
  reference,
}

extension DocumentTypeExtension on DocumentType {
  String get displayName {
    switch (this) {
      case DocumentType.lecture:
        return 'Bài giảng';
      case DocumentType.exercise:
        return 'Bài tập';
      case DocumentType.reference:
        return 'Tài liệu tham khảo';
    }
  }

  String get keyName => name;

  static DocumentType fromString(String? value) {
    if (value == null) return DocumentType.lecture;
    return DocumentType.values.firstWhere(
      (e) => e.name.toLowerCase() == value.toLowerCase(),
      orElse: () => DocumentType.lecture,
    );
  }
}

enum DocumentStatus {
  todo,
  inProgress,
  completed,
}

extension DocumentStatusExtension on DocumentStatus {
  String get displayName {
    switch (this) {
      case DocumentStatus.todo:
        return 'Cần học';
      case DocumentStatus.inProgress:
        return 'Đang học';
      case DocumentStatus.completed:
        return 'Đã hoàn thành';
    }
  }

  static DocumentStatus fromString(String? value) {
    if (value == null) return DocumentStatus.todo;
    return DocumentStatus.values.firstWhere(
      (e) => e.name.toLowerCase() == value.toLowerCase(),
      orElse: () => DocumentStatus.todo,
    );
  }
}

class StudyDocument {
  final String id;
  final String title;
  final String courseId;
  final DocumentType type;
  final DocumentStatus status;
  final String description;
  
  // Thông tin liên kết Firebase Cloud Storage
  final String fileUrl;
  final String? filePath; // Cấu trúc: study_documents/{userId}/{docId}/{fileName}
  final String? fileName;
  final int? fileSize;
  final String? fileType;

  // Quyền sở hữu và Supabase Permissions
  final String ownerId;
  final String? ownerEmail;
  final bool isPublic;
  final String? userPermission; // 'owner', 'editor', 'viewer'

  final List<String> tags;
  final DateTime? deadline;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isPinned;
  final bool isSynced;

  StudyDocument({
    required this.id,
    required this.title,
    required this.courseId,
    required this.type,
    this.status = DocumentStatus.todo,
    this.description = '',
    this.fileUrl = '',
    this.filePath,
    this.fileName,
    this.fileSize,
    this.fileType,
    this.ownerId = '',
    String? ownerEmail,
    this.isPublic = false,
    this.userPermission = 'owner',
    this.tags = const [],
    this.deadline,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.isPinned = false,
    this.isSynced = false,
  })  : ownerEmail = (ownerEmail != null && ownerEmail.isNotEmpty) ? ownerEmail : 'dao17022005@gmail.com',
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  static bool canUserCreate(dynamic user) {
    if (user == null) return false;
    final role = (user.role ?? '').toString().toLowerCase();
    // DUY NHẤT CHỦ SỞ HỮU (OWNER / TRƯỞNG NHÓM) MỚI CÓ QUYỀN TẠO MỚI TÀI LIỆU
    // EDITOR VÀ VIEWER KHÔNG ĐƯỢC PHÉP TẠO MỚI (EDITOR CHỈ CÓ QUYỀN XEM VÀ CHỈNH SỬA)
    return role.contains('owner') || role.contains('trưởng nhóm');
  }

  bool canUserEdit(dynamic user) {
    if (user == null) return false;
    final email = (user.email ?? '').toString().toLowerCase();
    final role = (user.role ?? '').toString().toLowerCase();

    // 1. Nếu tài khoản có vai trò Viewer / Người xem:
    // Tuyệt đối không được chỉnh sửa trừ khi chính là người tạo ra tài liệu
    if (role.contains('viewer') || role.contains('người xem')) {
      if (ownerEmail?.toLowerCase() == email && email.isNotEmpty) return true;
      return false;
    }

    // 2. Chủ sở hữu (Owner) hoặc Trưởng nhóm
    if (ownerEmail?.toLowerCase() == email && email.isNotEmpty) return true;
    if (role.contains('owner') || role.contains('trưởng nhóm')) return true;

    // 3. Người biên tập (Editor)
    if (role.contains('editor') || role.contains('chỉnh sửa')) return true;
    if (userPermission == 'editor' || userPermission == 'admin') return true;

    return false;
  }

  bool canUserDelete(dynamic user) {
    if (user == null) return false;
    final email = (user.email ?? '').toString().toLowerCase();
    final role = (user.role ?? '').toString().toLowerCase();

    // DUY NHẤT CHỦ SỞ HỮU (OWNER) MỚI CÓ QUYỀN XÓA TÀI LIỆU
    // Editor và Viewer TUYỆT ĐỐI KHÔNG ĐƯỢC XÓA
    if (role.contains('editor') || role.contains('viewer') || role.contains('người xem') || role.contains('chỉnh sửa')) {
      if (ownerEmail?.toLowerCase() == email && email.isNotEmpty) return true;
      return false;
    }

    if (ownerEmail?.toLowerCase() == email && email.isNotEmpty) return true;
    if (role.contains('owner') || role.contains('trưởng nhóm')) return true;
    return false;
  }

  bool canUserShare(dynamic user) {
    if (user == null) return false;
    final email = (user.email ?? '').toString().toLowerCase();
    final role = (user.role ?? '').toString().toLowerCase();

    // DUY NHẤT CHỦ SỞ HỮU (OWNER) MỚI CÓ QUYỀN CHIA SẺ TÀI LIỆU
    // Editor và Viewer KHÔNG ĐƯỢC PHÉP CHIA SẺ
    if (role.contains('editor') || role.contains('viewer') || role.contains('người xem') || role.contains('chỉnh sửa')) {
      if (ownerEmail?.toLowerCase() == email && email.isNotEmpty) return true;
      return false;
    }

    if (ownerEmail?.toLowerCase() == email && email.isNotEmpty) return true;
    if (role.contains('owner') || role.contains('trưởng nhóm')) return true;
    return false;
  }

  bool canUserView(dynamic user) {
    if (isPublic) return true;
    if (user == null) return false;
    final email = (user.email ?? '').toString().toLowerCase();
    final role = (user.role ?? '').toString().toLowerCase();
    if (ownerEmail?.toLowerCase() == email && email.isNotEmpty) return true;
    if (role.contains('owner') || role.contains('trưởng nhóm')) return true;
    if (role.contains('editor') || role.contains('viewer') || role.contains('chỉnh sửa') || role.contains('người xem')) return true;
    if (userPermission != null && userPermission != 'none') return true;
    return false;
  }

  String getDisplayPermission(dynamic user) {
    if (user == null) return 'Không có quyền';
    if (canUserDelete(user)) return 'Owner';
    if (canUserEdit(user)) return 'Editor';
    return 'Viewer';
  }

  bool get canEdit => userPermission == null || userPermission == 'owner' || userPermission == 'editor' || userPermission == 'admin';
  bool get isOwner => userPermission == 'owner' || userPermission == null;

  StudyDocument copyWith({
    String? id,
    String? title,
    String? courseId,
    DocumentType? type,
    DocumentStatus? status,
    String? description,
    String? fileUrl,
    String? filePath,
    String? fileName,
    int? fileSize,
    String? fileType,
    String? ownerId,
    String? ownerEmail,
    bool? isPublic,
    String? userPermission,
    List<String>? tags,
    DateTime? deadline,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isPinned,
    bool? isSynced,
  }) {
    return StudyDocument(
      id: id ?? this.id,
      title: title ?? this.title,
      courseId: courseId ?? this.courseId,
      type: type ?? this.type,
      status: status ?? this.status,
      description: description ?? this.description,
      fileUrl: fileUrl ?? this.fileUrl,
      filePath: filePath ?? this.filePath,
      fileName: fileName ?? this.fileName,
      fileSize: fileSize ?? this.fileSize,
      fileType: fileType ?? this.fileType,
      ownerId: ownerId ?? this.ownerId,
      ownerEmail: ownerEmail ?? this.ownerEmail,
      isPublic: isPublic ?? this.isPublic,
      userPermission: userPermission ?? this.userPermission,
      tags: tags ?? this.tags,
      deadline: deadline ?? this.deadline,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isPinned: isPinned ?? this.isPinned,
      isSynced: isSynced ?? this.isSynced,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'course_id': courseId,
      'document_type': type.name,
      'type': type.name,
      'status': status.name,
      'description': description,
      'file_url': fileUrl,
      'file_path': filePath,
      'file_name': fileName,
      'file_size': fileSize,
      'file_type': fileType,
      'owner_id': ownerId,
      'owner_email': ownerEmail,
      'is_public': isPublic ? 1 : 0,
      'tags': jsonEncode(tags),
      'deadline': deadline?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'is_pinned': isPinned ? 1 : 0,
      'is_synced': isSynced ? 1 : 0,
    };
  }

  factory StudyDocument.fromMap(Map<String, dynamic> map) {
    List<String> parsedTags = [];
    if (map['tags'] != null) {
      if (map['tags'] is List) {
        parsedTags = List<String>.from(map['tags']);
      } else {
        try {
          parsedTags = List<String>.from(jsonDecode(map['tags'].toString()));
        } catch (_) {
          parsedTags = map['tags'].toString().split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
        }
      }
    }

    final typeVal = map['document_type'] ?? map['type'];
    final owner = (map['owner_id'] ?? map['ownerId'] ?? '') as String;
    final isPub = map['is_public'] == true || map['is_public'] == 1;

    return StudyDocument(
      id: (map['id'] ?? '') as String,
      title: (map['title'] ?? '') as String,
      courseId: (map['course_id'] ?? map['courseId'] ?? '') as String,
      type: DocumentTypeExtension.fromString(typeVal as String?),
      status: DocumentStatusExtension.fromString(map['status'] as String?),
      description: (map['description'] ?? '') as String,
      fileUrl: (map['file_url'] ?? map['fileUrl'] ?? '') as String,
      filePath: (map['file_path'] ?? map['filePath']) as String?,
      fileName: (map['file_name'] ?? map['fileName']) as String?,
      fileSize: map['file_size'] is int ? map['file_size'] as int : int.tryParse(map['file_size']?.toString() ?? ''),
      fileType: (map['file_type'] ?? map['fileType']) as String?,
      ownerId: owner,
      ownerEmail: (map['owner_email'] ?? map['ownerEmail']) as String?,
      isPublic: isPub,
      userPermission: (map['permission_role'] ?? map['user_permission'] ?? 'owner') as String?,
      tags: parsedTags,
      deadline: map['deadline'] != null ? DateTime.tryParse(map['deadline'].toString()) : null,
      createdAt: map['created_at'] != null ? DateTime.tryParse(map['created_at'].toString()) ?? DateTime.now() : DateTime.now(),
      updatedAt: map['updated_at'] != null ? DateTime.tryParse(map['updated_at'].toString()) ?? DateTime.now() : DateTime.now(),
      isPinned: (map['is_pinned'] == 1 || map['is_pinned'] == true),
      isSynced: (map['is_synced'] == 1 || map['is_synced'] == true),
    );
  }
}
