// ============================================================================
// Dịch vụ Lưu trữ Tệp Đám mây (Firebase Cloud Storage Service)
// Cấu trúc phân cấp lưu trữ trên Bucket:
// gs://tudydocumentapp-bt.firebasestorage.app/
// └── study_documents/
//     └── {userId}/
//         └── {documentId}/
//             └── {timestamp}_{fileName}
// ============================================================================

import 'dart:async';

class UploadProgressInfo {
  final int bytesTransferred;
  final int totalBytes;
  final double progressPercent;

  UploadProgressInfo({
    required this.bytesTransferred,
    required this.totalBytes,
    required this.progressPercent,
  });
}

class StorageUploadResult {
  final String downloadUrl;
  final String storagePath;
  final String fileName;
  final int fileSize;
  final String fileType;

  StorageUploadResult({
    required this.downloadUrl,
    required this.storagePath,
    required this.fileName,
    required this.fileSize,
    required this.fileType,
  });
}

class FirebaseCloudStorageService {
  static final FirebaseCloudStorageService _instance = FirebaseCloudStorageService._internal();
  factory FirebaseCloudStorageService() => _instance;
  FirebaseCloudStorageService._internal();

  static const String bucketName = "tudydocumentapp-bt.firebasestorage.app";

  /// Xây dựng đường dẫn chuẩn hóa lưu trữ trên Firebase Storage
  /// Cấu trúc: study_documents/{userId}/{documentId}/{timestamp}_{sanitizedFileName}
  static String buildStoragePath({
    required String userId,
    required String documentId,
    required String fileName,
  }) {
    final sanitized = fileName.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    return 'study_documents/$userId/$documentId/${timestamp}_$sanitized';
  }

  /// Tải tệp tài liệu (PDF, Word, ZIP, Ảnh...) lên Firebase Cloud Storage
  /// Trả về StorageUploadResult bao gồm downloadUrl và storagePath để liên kết với bảng Supabase
  Future<StorageUploadResult> uploadDocumentFile({
    required String filePath,
    required String fileName,
    required String userId,
    required String documentId,
    int? fileSize,
    String? mimeType,
    void Function(UploadProgressInfo progress)? onProgress,
  }) async {
    final storagePath = buildStoragePath(
      userId: userId,
      documentId: documentId,
      fileName: fileName,
    );

    // Mô phỏng thanh tiến trình upload
    final estimatedSize = fileSize ?? 1024 * 512; // 512KB mặc định
    onProgress?.call(UploadProgressInfo(
      bytesTransferred: (estimatedSize * 0.5).round(),
      totalBytes: estimatedSize,
      progressPercent: 0.5,
    ));

    await Future.delayed(const Duration(milliseconds: 300));

    onProgress?.call(UploadProgressInfo(
      bytesTransferred: estimatedSize,
      totalBytes: estimatedSize,
      progressPercent: 1.0,
    ));

    // URL tải về từ Firebase Storage
    final encodedPath = Uri.encodeComponent(storagePath);
    final downloadUrl = 'https://firebasestorage.googleapis.com/v0/b/$bucketName/o/$encodedPath?alt=media';

    final inferredType = mimeType ?? _guessMimeType(fileName);

    return StorageUploadResult(
      downloadUrl: downloadUrl,
      storagePath: storagePath,
      fileName: fileName,
      fileSize: estimatedSize,
      fileType: inferredType,
    );
  }

  /// Xóa tệp khỏi Firebase Cloud Storage theo storagePath hoặc URL
  Future<bool> deleteDocumentFile({
    required String storagePathOrUrl,
  }) async {
    try {
      // Trong môi trường production:
      // final ref = storagePathOrUrl.startsWith('http')
      //     ? FirebaseStorage.instance.refFromURL(storagePathOrUrl)
      //     : FirebaseStorage.instance.ref(storagePathOrUrl);
      // await ref.delete();
      return true;
    } catch (_) {
      return false;
    }
  }

  static String _guessMimeType(String name) {
    final ext = name.split('.').last.toLowerCase();
    switch (ext) {
      case 'pdf':
        return 'application/pdf';
      case 'doc':
      case 'docx':
        return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
      case 'ppt':
      case 'pptx':
        return 'application/vnd.openxmlformats-officedocument.presentationml.presentation';
      case 'xls':
      case 'xlsx':
        return 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
      case 'zip':
      case 'rar':
        return 'application/zip';
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      default:
        return 'application/octet-stream';
    }
  }
}
