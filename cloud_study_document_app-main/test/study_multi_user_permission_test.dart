// ============================================================================
// KIỂM THỬ (TESTING) LUỒNG HOẠT ĐỘNG & PHÂN QUYỀN TRUY CẬP TÀI LIỆU
// Kiểm thử trên 3+ tài khoản người dùng:
// 1. User A (Owner): caoducdao17022005@gmail.com - Toàn quyền (Create, Read, Update, Delete, Share)
// 2. User B (Editor): phamvanhung21122004@gmail.com - Quyền Xem và Chỉnh sửa (Read, Update)
// 3. User C (Viewer): trinhtrungkien2004@gmail.com - Quyền Chỉ xem (Read only)
// 4. User D (Stranger): outsider@gmail.com - Không có quyền với tài liệu riêng tư
// ============================================================================

import 'package:flutter_test/flutter_test.dart';
import 'package:study_document_app/struct/studyDocument.dart';
import 'package:study_document_app/struct/documentPermission.dart';
import 'package:study_document_app/struct/firebaseCloudStorageService.dart';
import 'package:study_document_app/struct/firebaseAuthService.dart';
import 'package:study_document_app/database/database_helper.dart';
import 'package:study_document_app/database/study_document_dao.dart';

// Mô phỏng bộ kiểm tra chính sách RLS (Row Level Security Engine) phía Client/Backend
class MockRlsSecurityEngine {
  final Map<String, StudyDocument> documents = {};
  final List<DocumentPermission> permissions = [];

  void addDocument(StudyDocument doc) {
    documents[doc.id] = doc;
  }

  void addPermission(DocumentPermission perm) {
    permissions.removeWhere((p) => p.documentId == perm.documentId && p.userId == perm.userId);
    permissions.add(perm);
  }

  void revokePermission(String documentId, String userId) {
    permissions.removeWhere((p) => p.documentId == documentId && p.userId == userId);
  }

  /// Kiểm tra RLS Policy: SELECT (Đọc tài liệu)
  bool canReadDocument(String documentId, String requestingUserId) {
    final doc = documents[documentId];
    if (doc == null) return false;

    // 1. Chủ sở hữu (Owner)
    if (doc.ownerId == requestingUserId) return true;

    // 2. Tài liệu công khai (Public)
    if (doc.isPublic) return true;

    // 3. Có bản ghi trong document_permissions
    return permissions.any((p) => p.documentId == documentId && p.userId == requestingUserId);
  }

  /// Kiểm tra RLS Policy: UPDATE (Sửa thông tin tài liệu)
  bool canUpdateDocument(String documentId, String requestingUserId) {
    final doc = documents[documentId];
    if (doc == null) return false;

    // 1. Chủ sở hữu (Owner)
    if (doc.ownerId == requestingUserId) return true;

    // 2. Có quyền 'editor' hoặc 'admin'
    return permissions.any((p) =>
        p.documentId == documentId &&
        p.userId == requestingUserId &&
        (p.role == DocumentPermissionRole.editor || p.role == DocumentPermissionRole.admin));
  }

  /// Kiểm tra RLS Policy: DELETE (Xóa tài liệu)
  bool canDeleteDocument(String documentId, String requestingUserId) {
    final doc = documents[documentId];
    if (doc == null) return false;

    // Duy nhất chủ sở hữu (Owner) mới có quyền xóa
    return doc.ownerId == requestingUserId;
  }

  /// Kiểm tra RLS Policy: SHARE (Cấp quyền chia sẻ tài liệu cho người khác)
  bool canShareDocument(String documentId, String requestingUserId) {
    final doc = documents[documentId];
    if (doc == null) return false;

    // Chỉ chủ sở hữu mới có quyền phân quyền
    return doc.ownerId == requestingUserId;
  }
}

void main() {
  group('Kiểm thử luồng phân quyền Supabase RLS & Firebase Storage (3 Tài khoản)', () {
    late MockRlsSecurityEngine rlsEngine;
    late DocumentDao documentDao;

    // Khởi tạo thông tin 3 tài khoản người dùng thử nghiệm
    final userAOwner = FirebaseAuthService.teamMembers.firstWhere(
      (m) => m.email == 'caoducdao17022005@gmail.com',
    );
    final userBEditor = FirebaseAuthService.teamMembers.firstWhere(
      (m) => m.email == 'daokoaiyeu@gmail.com',
    );
    final userCViewer = FirebaseAuthService.teamMembers.firstWhere(
      (m) => m.email == 'teokhung1702@gmail.com',
    );
    const userDStranger = MockFirebaseUser(
      uid: 'user-stranger-999',
      email: 'outsider@gmail.com',
      displayName: 'Người dùng lạ',
    );

    setUp(() {
      rlsEngine = MockRlsSecurityEngine();
      documentDao = DocumentDao(database: AppDatabase());
    });

    test('1. Kiểm thử User A (Owner): Upload file lên Firebase Storage và tạo tài liệu', () async {
      final docId = 'doc-ktpm-2026';
      final fileName = 'Bao_Cao_Kien_Truc_Cashew.pdf';

      // 1.1 Upload lên Firebase Storage
      final uploadRes = await FirebaseCloudStorageService().uploadDocumentFile(
        filePath: fileName,
        fileName: fileName,
        userId: userAOwner.uid,
        documentId: docId,
      );

      expect(uploadRes.downloadUrl, contains('firebasestorage.googleapis.com'));
      expect(uploadRes.storagePath, 'study_documents/${userAOwner.uid}/$docId/${uploadRes.storagePath.split('/').last}');
      expect(uploadRes.fileType, 'application/pdf');

      // 1.2 Tạo bản ghi Document lưu vào CSDL
      final doc = StudyDocument(
        id: docId,
        title: 'Báo cáo Kiến trúc Phần mềm Cashew',
        courseId: 'c1',
        type: DocumentType.lecture,
        ownerId: userAOwner.uid,
        ownerEmail: userAOwner.email,
        filePath: uploadRes.storagePath,
        fileUrl: uploadRes.downloadUrl,
        fileName: uploadRes.fileName,
        fileSize: uploadRes.fileSize,
        fileType: uploadRes.fileType,
        isPublic: false, // Tài liệu riêng tư
      );

      rlsEngine.addDocument(doc);
      await documentDao.insert(doc);

      // Kiểm tra quyền của Owner
      expect(rlsEngine.canReadDocument(docId, userAOwner.uid), isTrue, reason: 'Owner phải đọc được tài liệu');
      expect(rlsEngine.canUpdateDocument(docId, userAOwner.uid), isTrue, reason: 'Owner phải sửa được tài liệu');
      expect(rlsEngine.canDeleteDocument(docId, userAOwner.uid), isTrue, reason: 'Owner phải xóa được tài liệu');
      expect(rlsEngine.canShareDocument(docId, userAOwner.uid), isTrue, reason: 'Owner phải có quyền chia sẻ');
    });

    test('2. Kiểm thử User A chia sẻ tài liệu cho User B (Editor) và User C (Viewer)', () async {
      final docId = 'doc-ktpm-2026';
      final doc = StudyDocument(
        id: docId,
        title: 'Báo cáo Kiến trúc Phần mềm',
        courseId: 'c1',
        type: DocumentType.lecture,
        ownerId: userAOwner.uid,
        ownerEmail: userAOwner.email,
        isPublic: false,
      );
      rlsEngine.addDocument(doc);

      // Cấp quyền Editor cho User B
      final permEditor = DocumentPermission(
        id: 'perm-1',
        documentId: docId,
        userId: userBEditor.uid,
        userEmail: userBEditor.email,
        displayName: userBEditor.displayName,
        role: DocumentPermissionRole.editor,
        sharedBy: userAOwner.uid,
      );
      rlsEngine.addPermission(permEditor);

      // Cấp quyền Viewer cho User C
      final permViewer = DocumentPermission(
        id: 'perm-2',
        documentId: docId,
        userId: userCViewer.uid,
        userEmail: userCViewer.email,
        displayName: userCViewer.displayName,
        role: DocumentPermissionRole.viewer,
        sharedBy: userAOwner.uid,
      );
      rlsEngine.addPermission(permViewer);

      // Xác minh danh sách quyền đã cấp
      expect(rlsEngine.permissions.length, 2);
    });

    test('3. Kiểm thử quyền hạn User B (Editor - Phạm Văn Hưng)', () async {
      final docId = 'doc-ktpm-2026';
      final doc = StudyDocument(
        id: docId,
        title: 'Báo cáo Kiến trúc Phần mềm',
        courseId: 'c1',
        type: DocumentType.lecture,
        ownerId: userAOwner.uid,
        ownerEmail: userAOwner.email,
        isPublic: false,
      );
      rlsEngine.addDocument(doc);
      rlsEngine.addPermission(DocumentPermission(
        id: 'perm-1',
        documentId: docId,
        userId: userBEditor.uid,
        userEmail: userBEditor.email,
        role: DocumentPermissionRole.editor,
        sharedBy: userAOwner.uid,
      ));

      // 3.1 Quyền Xem: Được phép
      expect(rlsEngine.canReadDocument(docId, userBEditor.uid), isTrue);

      // 3.2 Quyền Cập nhật thông tin tài liệu: Được phép (Editor)
      expect(rlsEngine.canUpdateDocument(docId, userBEditor.uid), isTrue);

      // 3.3 Quyền Xóa tài liệu: BỊ TỪ CHỐI (Chỉ Owner mới được xóa)
      expect(rlsEngine.canDeleteDocument(docId, userBEditor.uid), isFalse);

      // 3.4 Quyền Chia sẻ lại cho người khác: BỊ TỪ CHỐI
      expect(rlsEngine.canShareDocument(docId, userBEditor.uid), isFalse);
    });

    test('4. Kiểm thử quyền hạn User C (Viewer - Trịnh Trung Kiên)', () async {
      final docId = 'doc-ktpm-2026';
      final doc = StudyDocument(
        id: docId,
        title: 'Báo cáo Kiến trúc Phần mềm',
        courseId: 'c1',
        type: DocumentType.lecture,
        ownerId: userAOwner.uid,
        ownerEmail: userAOwner.email,
        isPublic: false,
      );
      rlsEngine.addDocument(doc);
      rlsEngine.addPermission(DocumentPermission(
        id: 'perm-2',
        documentId: docId,
        userId: userCViewer.uid,
        userEmail: userCViewer.email,
        role: DocumentPermissionRole.viewer,
        sharedBy: userAOwner.uid,
      ));

      // 4.1 Quyền Xem: Được phép (Viewer)
      expect(rlsEngine.canReadDocument(docId, userCViewer.uid), isTrue);

      // 4.2 Quyền Chỉnh sửa: BỊ TỪ CHỐI (Viewer chỉ được đọc)
      expect(rlsEngine.canUpdateDocument(docId, userCViewer.uid), isFalse);

      // 4.3 Quyền Xóa tài liệu: BỊ TỪ CHỐI
      expect(rlsEngine.canDeleteDocument(docId, userCViewer.uid), isFalse);
    });

    test('5. Kiểm thử User D (Người lạ không có quyền & trường hợp Public)', () async {
      final docId = 'doc-ktpm-2026';
      final privateDoc = StudyDocument(
        id: docId,
        title: 'Tài liệu riêng tư',
        courseId: 'c1',
        type: DocumentType.lecture,
        ownerId: userAOwner.uid,
        isPublic: false,
      );
      rlsEngine.addDocument(privateDoc);

      // 5.1 Khi tài liệu là Private: User D BỊ CHẶN hoàn toàn bởi RLS
      expect(rlsEngine.canReadDocument(docId, userDStranger.uid), isFalse);
      expect(rlsEngine.canUpdateDocument(docId, userDStranger.uid), isFalse);
      expect(rlsEngine.canDeleteDocument(docId, userDStranger.uid), isFalse);

      // 5.2 Khi tài liệu được chuyển sang Public (Công khai)
      final publicDoc = privateDoc.copyWith(isPublic: true);
      rlsEngine.addDocument(publicDoc);

      // User D ĐƯỢC PHÉP ĐỌC tài liệu công khai
      expect(rlsEngine.canReadDocument(docId, userDStranger.uid), isTrue);

      // Nhưng User D VẪN KHÔNG ĐƯỢC PHÉP SỬA hoặc XÓA
      expect(rlsEngine.canUpdateDocument(docId, userDStranger.uid), isFalse);
      expect(rlsEngine.canDeleteDocument(docId, userDStranger.uid), isFalse);
    });

    test('6. Kiểm thử Thu hồi quyền (Revoke Permission) của User B', () async {
      final docId = 'doc-ktpm-2026';
      final doc = StudyDocument(
        id: docId,
        title: 'Tài liệu mật',
        courseId: 'c1',
        type: DocumentType.lecture,
        ownerId: userAOwner.uid,
        isPublic: false,
      );
      rlsEngine.addDocument(doc);
      rlsEngine.addPermission(DocumentPermission(
        id: 'perm-1',
        documentId: docId,
        userId: userBEditor.uid,
        userEmail: userBEditor.email,
        role: DocumentPermissionRole.editor,
        sharedBy: userAOwner.uid,
      ));

      // Trước khi thu hồi: Có quyền đọc và sửa
      expect(rlsEngine.canReadDocument(docId, userBEditor.uid), isTrue);
      expect(rlsEngine.canUpdateDocument(docId, userBEditor.uid), isTrue);

      // Owner thu hồi quyền của User B
      rlsEngine.revokePermission(docId, userBEditor.uid);

      // Sau khi thu hồi: Bị chặn hoàn toàn
      expect(rlsEngine.canReadDocument(docId, userBEditor.uid), isFalse);
      expect(rlsEngine.canUpdateDocument(docId, userBEditor.uid), isFalse);
    });

    test('7. Kiểm thử ma trận phân quyền trực tiếp trên Model StudyDocument (UI Permission Matrix)', () {
      final doc = StudyDocument(
        id: 'doc-matrix-test',
        title: 'Giáo trình KTPM Phân Quyền',
        courseId: 'c1',
        type: DocumentType.lecture,
        ownerEmail: userAOwner.email,
        ownerId: userAOwner.uid,
        isPublic: false,
      );

      // 1. Kiểm thử User A (Owner): Có đầy đủ các quyền và ĐƯỢC PHÉP TẠO MỚI
      expect(StudyDocument.canUserCreate(userAOwner), isTrue, reason: 'Owner được tạo mới tài liệu');
      expect(doc.canUserView(userAOwner), isTrue, reason: 'Owner phải có quyền xem');
      expect(doc.canUserEdit(userAOwner), isTrue, reason: 'Owner phải có quyền sửa');
      expect(doc.canUserShare(userAOwner), isTrue, reason: 'Owner phải có quyền chia sẻ');
      expect(doc.canUserDelete(userAOwner), isTrue, reason: 'Owner phải có quyền xóa');
      expect(doc.getDisplayPermission(userAOwner), equals('Owner'));

      // 2. Kiểm thử User B (Editor): CHỈ CÓ QUYỀN XEM VÀ SỬA. KHÔNG ĐƯỢC TẠO MỚI, KHÔNG XÓA, KHÔNG CHIA SẺ
      expect(StudyDocument.canUserCreate(userBEditor), isFalse, reason: 'Editor KHÔNG ĐƯỢC tạo mới tài liệu');
      expect(doc.canUserView(userBEditor), isTrue, reason: 'Editor được xem');
      expect(doc.canUserEdit(userBEditor), isTrue, reason: 'Editor được sửa');
      expect(doc.canUserShare(userBEditor), isFalse, reason: 'Editor KHÔNG ĐƯỢC chia sẻ');
      expect(doc.canUserDelete(userBEditor), isFalse, reason: 'Editor KHÔNG ĐƯỢC xóa');
      expect(doc.getDisplayPermission(userBEditor), equals('Editor'));

      // 3. Kiểm thử User C (Viewer): Chỉ có quyền Xem. KHÔNG TẠO MỚI, KHÔNG SỬA, KHÔNG XÓA, KHÔNG CHIA SẺ
      expect(StudyDocument.canUserCreate(userCViewer), isFalse, reason: 'Viewer KHÔNG ĐƯỢC tạo mới tài liệu');
      expect(doc.canUserView(userCViewer), isTrue, reason: 'Viewer được xem');
      expect(doc.canUserEdit(userCViewer), isFalse, reason: 'Viewer KHÔNG ĐƯỢC sửa');
      expect(doc.canUserShare(userCViewer), isFalse, reason: 'Viewer KHÔNG ĐƯỢC chia sẻ');
      expect(doc.canUserDelete(userCViewer), isFalse, reason: 'Viewer KHÔNG ĐƯỢC xóa');
      expect(doc.getDisplayPermission(userCViewer), equals('Viewer'));
    });
  });
}
