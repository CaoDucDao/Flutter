// ============================================================================
// Dịch vụ Kết nối Cơ sở dữ liệu Supabase & Quản lý Phân quyền Tài liệu
// Hỗ trợ:
// 1. Tích hợp Firebase Storage (Upload file) & lưu trữ Metadata sang Supabase
// 2. Tìm kiếm tài liệu (Search theo từ khóa, môn học, loại tài liệu, trạng thái)
// 3. Cập nhật thông tin tài liệu
// 4. Quản lý Quyền chia sẻ (Permissions: Viewer / Editor / Admin) & RLS Policy
// ============================================================================

import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'studyDocument.dart';
import 'documentPermission.dart';
import 'firebaseAuthService.dart';
import 'firebaseCloudStorageService.dart';
import '../database/study_document_dao.dart';

class SupabaseDocumentService {
  static final SupabaseDocumentService _instance = SupabaseDocumentService._internal();
  factory SupabaseDocumentService() => _instance;
  SupabaseDocumentService._internal();

  // Cấu hình kết nối Supabase Project (Có thể thay đổi theo dự án của người dùng)
  String _supabaseUrl = "https://wxtryqylptzrvjebvyxk.supabase.co"; // URL dự án mẫu Supabase
  String _supabaseAnonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.e30.mock_key";

  void setConfig({required String url, required String anonKey}) {
    _supabaseUrl = url.trim().replaceAll(RegExp(r'/$'), '');
    _supabaseAnonKey = anonKey.trim();
  }

  String get supabaseUrl => _supabaseUrl;
  String get supabaseAnonKey => _supabaseAnonKey;

  Map<String, String> _buildHeaders([String? userToken]) {
    return {
      'apikey': _supabaseAnonKey,
      'Authorization': 'Bearer ${userToken ?? _supabaseAnonKey}',
      'Content-Type': 'application/json',
      'Prefer': 'return=representation',
    };
  }

  // Bộ nhớ đệm Mock In-Memory phục vụ offline & thử nghiệm trước khi cấu hình Supabase URL thật
  final List<DocumentPermission> _localPermissions = [];

  // ==========================================================================
  // 1. TẢI TỆP LÊN FIREBASE STORAGE VÀ LƯU METADATA VÀO SUPABASE
  // ==========================================================================
  Future<StudyDocument?> uploadAndCreateDocument({
    required String title,
    required String courseId,
    required DocumentType type,
    String description = '',
    String? localFilePath,
    String? fileName,
    List<String> tags = const [],
    DateTime? deadline,
    bool isPinned = false,
    bool isPublic = false,
    void Function(UploadProgressInfo progress)? onProgress,
  }) async {
    final currentUser = FirebaseAuthService().currentUser;
    final userId = currentUser?.uid ?? 'user-dao-2351170581';
    final userEmail = currentUser?.email ?? 'caoducdao17022005@gmail.com';
    final docId = DateTime.now().millisecondsSinceEpoch.toString();

    String downloadUrl = '';
    String storagePath = '';
    int fileSize = 0;
    String fileType = '';

    // Bước 1: Nếu có đính kèm file, upload lên Firebase Cloud Storage
    if (fileName != null && fileName.isNotEmpty) {
      final uploadRes = await FirebaseCloudStorageService().uploadDocumentFile(
        filePath: localFilePath ?? fileName,
        fileName: fileName,
        userId: userId,
        documentId: docId,
        onProgress: onProgress,
      );
      downloadUrl = uploadRes.downloadUrl;
      storagePath = uploadRes.storagePath;
      fileSize = uploadRes.fileSize;
      fileType = uploadRes.fileType;
    }

    // Bước 2: Tạo đối tượng StudyDocument đầy đủ thông tin
    final newDoc = StudyDocument(
      id: docId,
      title: title,
      courseId: courseId,
      type: type,
      description: description,
      fileUrl: downloadUrl,
      filePath: storagePath,
      fileName: fileName,
      fileSize: fileSize,
      fileType: fileType,
      ownerId: userId,
      ownerEmail: userEmail,
      isPublic: isPublic,
      userPermission: 'owner',
      tags: tags,
      deadline: deadline,
      isPinned: isPinned,
      isSynced: true,
    );

    // Bước 3: Đồng bộ vào Supabase PostgreSQL
    try {
      final url = Uri.parse('$_supabaseUrl/rest/v1/documents');
      final body = jsonEncode({
        'id': newDoc.id,
        'owner_id': newDoc.ownerId,
        'course_id': newDoc.courseId,
        'title': newDoc.title,
        'description': newDoc.description,
        'document_type': newDoc.type.name,
        'status': newDoc.status.name,
        'file_url': newDoc.fileUrl,
        'file_path': newDoc.filePath,
        'file_name': newDoc.fileName,
        'file_size': newDoc.fileSize,
        'file_type': newDoc.fileType,
        'tags': newDoc.tags,
        'deadline': newDoc.deadline?.toIso8601String(),
        'is_pinned': newDoc.isPinned,
        'is_public': newDoc.isPublic,
      });

      await http.post(url, headers: _buildHeaders(), body: body);
    } catch (_) {
      // Offline fallback
    }

    // Lưu vào SQLite/Database cục bộ
    await DocumentDao().insert(newDoc);
    return newDoc;
  }

  // ==========================================================================
  // 2. CHỨC NĂNG TÌM KIẾM TÀI LIỆU (Search & Filter)
  // ==========================================================================
  Future<List<StudyDocument>> searchDocuments({
    String? query,
    String? courseId,
    DocumentType? type,
    DocumentStatus? status,
  }) async {
    // 1. Tìm kiếm trong CSDL cục bộ
    final localDao = DocumentDao();
    final localResults = localDao.filterDocuments(
      query: query,
      courseId: courseId,
      type: type,
      status: status,
    );

    // 2. Nếu có kết nối Supabase, gọi Supabase REST API
    try {
      final queryParams = <String, String>{
        'select': '*',
      };
      if (courseId != null && courseId.isNotEmpty && courseId != 'all') {
        queryParams['course_id'] = 'eq.$courseId';
      }
      if (type != null) {
        queryParams['document_type'] = 'eq.${type.name}';
      }
      if (status != null) {
        queryParams['status'] = 'eq.${status.name}';
      }
      if (query != null && query.trim().isNotEmpty) {
        queryParams['title'] = 'ilike.*${query.trim()}*';
      }

      final uri = Uri.parse('$_supabaseUrl/rest/v1/documents').replace(queryParameters: queryParams);
      final response = await http.get(uri, headers: _buildHeaders()).timeout(const Duration(seconds: 3));

      if (response.statusCode == 200) {
        final List list = jsonDecode(response.body);
        if (list.isNotEmpty) {
          final cloudDocs = list.map((e) => StudyDocument.fromMap(e)).toList();
          // Cập nhật CSDL cục bộ
          for (var doc in cloudDocs) {
            await localDao.saveFromCloud(doc);
          }
          return cloudDocs;
        }
      }
    } catch (_) {
      // Khi offline / timeout, sử dụng kết quả từ local
    }

    return localResults;
  }

  // ==========================================================================
  // 3. CHỨC NĂNG CẬP NHẬT THÔNG TIN TÀI LIỆU
  // ==========================================================================
  Future<bool> updateDocument(StudyDocument doc) async {
    // 1. Cập nhật cục bộ
    await DocumentDao().update(doc);

    // 2. Gửi lệnh cập nhật lên Supabase theo RLS policy
    try {
      final uri = Uri.parse('$_supabaseUrl/rest/v1/documents?id=eq.${doc.id}');
      final body = jsonEncode({
        'title': doc.title,
        'description': doc.description,
        'course_id': doc.courseId,
        'document_type': doc.type.name,
        'status': doc.status.name,
        'file_url': doc.fileUrl,
        'file_path': doc.filePath,
        'file_name': doc.fileName,
        'tags': doc.tags,
        'deadline': doc.deadline?.toIso8601String(),
        'is_pinned': doc.isPinned,
        'is_public': doc.isPublic,
        'updated_at': DateTime.now().toIso8601String(),
      });

      final res = await http.patch(uri, headers: _buildHeaders(), body: body).timeout(const Duration(seconds: 3));
      return res.statusCode >= 200 && res.statusCode < 300;
    } catch (_) {
      return true; // Đã cập nhật thành công ở Local-First
    }
  }

  // ==========================================================================
  // 4. CHỨC NĂNG CHIA SẺ TÀI LIỆU CHO NGƯỜI DÙNG KHÁC (Permissions)
  // ==========================================================================

  /// Lấy danh sách quyền đã cấp cho tài liệu này
  Future<List<DocumentPermission>> getPermissionsForDocument(String documentId) async {
    try {
      final uri = Uri.parse('$_supabaseUrl/rest/v1/document_permissions?document_id=eq.$documentId&select=*');
      final res = await http.get(uri, headers: _buildHeaders()).timeout(const Duration(seconds: 3));
      if (res.statusCode == 200) {
        final List list = jsonDecode(res.body);
        return list.map((e) => DocumentPermission.fromMap(e)).toList();
      }
    } catch (_) {}

    return _localPermissions.where((p) => p.documentId == documentId).toList();
  }

  /// Chia sẻ tài liệu cho một email người dùng cụ thể
  Future<bool> shareDocument({
    required String documentId,
    required String targetEmail,
    required DocumentPermissionRole role,
  }) async {
    final currentUser = FirebaseAuthService().currentUser;
    final sharedBy = currentUser?.uid ?? 'user-dao-2351170581';

    // Tạo ID và ánh xạ người dùng (từ danh sách team / user)
    final targetUser = FirebaseAuthService.teamMembers.firstWhere(
      (m) => m.email.toLowerCase() == targetEmail.trim().toLowerCase(),
      orElse: () => MockFirebaseUser(
        uid: 'user-${targetEmail.hashCode.abs()}',
        email: targetEmail.trim(),
        displayName: targetEmail.split('@').first,
      ),
    );

    final perm = DocumentPermission(
      id: 'perm-${DateTime.now().millisecondsSinceEpoch}',
      documentId: documentId,
      userId: targetUser.uid,
      userEmail: targetUser.email,
      displayName: targetUser.displayName,
      role: role,
      sharedBy: sharedBy,
    );

    // Cập nhật bộ nhớ cục bộ
    _localPermissions.removeWhere((p) => p.documentId == documentId && p.userEmail == perm.userEmail);
    _localPermissions.add(perm);

    // Gửi lên bảng public.document_permissions trên Supabase
    try {
      final uri = Uri.parse('$_supabaseUrl/rest/v1/document_permissions');
      final body = jsonEncode({
        'document_id': perm.documentId,
        'user_id': perm.userId,
        'user_email': perm.userEmail,
        'permission_role': perm.role.name,
        'shared_by': perm.sharedBy,
      });

      final res = await http.post(uri, headers: _buildHeaders(), body: body).timeout(const Duration(seconds: 3));
      return res.statusCode >= 200 && res.statusCode < 300;
    } catch (_) {
      return true;
    }
  }

  /// Thu hồi quyền truy cập (Xóa khỏi danh sách chia sẻ)
  Future<bool> revokePermission({
    required String documentId,
    required String targetUserId,
  }) async {
    _localPermissions.removeWhere((p) => p.documentId == documentId && p.userId == targetUserId);

    try {
      final uri = Uri.parse('$_supabaseUrl/rest/v1/document_permissions?document_id=eq.$documentId&user_id=eq.$targetUserId');
      final res = await http.delete(uri, headers: _buildHeaders()).timeout(const Duration(seconds: 3));
      return res.statusCode >= 200 && res.statusCode < 300;
    } catch (_) {
      return true;
    }
  }

  /// Thay đổi vai trò (Viewer <-> Editor)
  Future<bool> updatePermissionRole({
    required String documentId,
    required String targetUserId,
    required DocumentPermissionRole newRole,
  }) async {
    final idx = _localPermissions.indexWhere((p) => p.documentId == documentId && p.userId == targetUserId);
    if (idx != -1) {
      _localPermissions[idx] = _localPermissions[idx].copyWith(role: newRole);
    }

    try {
      final uri = Uri.parse('$_supabaseUrl/rest/v1/document_permissions?document_id=eq.$documentId&user_id=eq.$targetUserId');
      final body = jsonEncode({'permission_role': newRole.name});
      final res = await http.patch(uri, headers: _buildHeaders(), body: body).timeout(const Duration(seconds: 3));
      return res.statusCode >= 200 && res.statusCode < 300;
    } catch (_) {
      return true;
    }
  }
}
