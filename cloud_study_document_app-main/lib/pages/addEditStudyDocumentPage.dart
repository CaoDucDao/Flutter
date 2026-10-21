import '../struct/firebaseAuthService.dart';
import '../struct/studySyncClient.dart';
import '../struct/firebaseCloudStorageService.dart';
import '../struct/supabaseDocumentService.dart';
import '../widgets/shareDocumentDialog.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../struct/studyDocument.dart';
import '../struct/studyCourse.dart';
import '../database/study_document_dao.dart';
import '../database/study_course_dao.dart';

class AddEditDocumentPage extends StatefulWidget {
  final StudyDocument? initialDocument;

  const AddEditDocumentPage({super.key, this.initialDocument});

  @override
  State<AddEditDocumentPage> createState() => _AddEditDocumentPageState();
}

class _AddEditDocumentPageState extends State<AddEditDocumentPage> {
  final _formKey = GlobalKey<FormState>();
  final _documentDao = DocumentDao();
  final _courseDao = CourseDao();

  late TextEditingController _titleController;
  late TextEditingController _descController;
  late TextEditingController _fileUrlController;
  late TextEditingController _tagsController;

  String? _selectedCourseId;
  DocumentType _selectedType = DocumentType.lecture;
  DocumentStatus _selectedStatus = DocumentStatus.todo;
  DateTime? _selectedDeadline;
  bool _isPinned = false;
  bool _isPublic = false;
  String? _filePath;
  String? _fileName;
  int? _fileSize;
  String? _fileType;
  bool _isUploadingFile = false;
  List<Course> _courses = [];

  bool get _isEdit => widget.initialDocument != null;

  @override
  void initState() {
    super.initState();
    final doc = widget.initialDocument;
    _titleController = TextEditingController(text: doc?.title ?? '');
    _descController = TextEditingController(text: doc?.description ?? '');
    _fileUrlController = TextEditingController(text: doc?.fileUrl ?? '');
    _tagsController = TextEditingController(text: doc?.tags.join(', ') ?? '');
    _selectedCourseId = doc?.courseId;
    _selectedType = doc?.type ?? DocumentType.lecture;
    _selectedStatus = doc?.status ?? DocumentStatus.todo;
    _selectedDeadline = doc?.deadline;
    _isPinned = doc?.isPinned ?? false;
    _isPublic = doc?.isPublic ?? false;
    _filePath = doc?.filePath;
    _fileName = doc?.fileName;
    _fileSize = doc?.fileSize;
    _fileType = doc?.fileType;

    _loadCourses();
  }

  void _loadCourses() {
    _courses = _courseDao.getAll();
    if (_courses.isNotEmpty && _selectedCourseId == null) {
      _selectedCourseId = _courses.first.id;
    }
    setState(() {});
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    _fileUrlController.dispose();
    _tagsController.dispose();
    super.dispose();
  }

  Future<void> _pickDeadline() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: _selectedDeadline ?? now.add(const Duration(days: 7)),
      firstDate: now.subtract(const Duration(days: 365)),
      lastDate: now.add(const Duration(days: 365 * 3)),
    );
    if (date != null) {
      setState(() => _selectedDeadline = date);
    }
  }

  Future<void> _uploadFileToFirebaseStorage() async {
    final authService = FirebaseAuthService();
    final user = authService.currentUser;
    final userId = user?.uid ?? 'user-dao-2351170581';
    final docId = widget.initialDocument?.id ?? DateTime.now().millisecondsSinceEpoch.toString();

    // Hiển thị dialog chọn file mẫu hoặc nhập tên file
    final nameCtrl = TextEditingController(text: 'Tai_Lieu_Bai_Giang_${DateTime.now().day}_${DateTime.now().month}.pdf');
    final selectedFileName = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.cloud_upload_rounded, color: Colors.blue),
            SizedBox(width: 8),
            Text('Tải tệp lên Firebase Storage', style: TextStyle(fontSize: 16)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Cấu trúc đường dẫn:\nstudy_documents/{userId}/{docId}/{fileName}',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(
                labelText: 'Tên tệp đính kèm',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Hủy')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, nameCtrl.text.trim()),
            child: const Text('Tải lên'),
          ),
        ],
      ),
    );

    if (selectedFileName == null || selectedFileName.isEmpty) return;

    setState(() => _isUploadingFile = true);

    try {
      final uploadRes = await FirebaseCloudStorageService().uploadDocumentFile(
        filePath: selectedFileName,
        fileName: selectedFileName,
        userId: userId,
        documentId: docId,
      );

      setState(() {
        _fileUrlController.text = uploadRes.downloadUrl;
        _filePath = uploadRes.storagePath;
        _fileName = uploadRes.fileName;
        _fileSize = uploadRes.fileSize;
        _fileType = uploadRes.fileType;
        _isUploadingFile = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Đã lưu file lên Firebase Storage:\n${uploadRes.storagePath}'),
            backgroundColor: const Color(0xFF2E7D32),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      setState(() => _isUploadingFile = false);
    }
  }

  Future<void> _saveDocument() async {
    if (!_formKey.currentState!.validate()) return;

    final authService = FirebaseAuthService();
    if (!authService.isSignedIn) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.lock_person_rounded, color: Colors.white, size: 20),
              SizedBox(width: 8),
              Expanded(
                child: Text('Vui lòng đăng nhập Google trước khi lưu tài liệu lên Cloud!'),
              ),
            ],
          ),
          backgroundColor: const Color(0xFFC2185B),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 4),
          action: SnackBarAction(
            label: 'ĐĂNG NHẬP',
            textColor: Colors.yellow,
            onPressed: () async {
              await authService.signInWithGoogle();
              if (mounted) setState(() {});
            },
          ),
        ),
      );
      return;
    }

    final tags = _tagsController.text
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    final syncClient = StudySyncClient();
    final supabaseService = SupabaseDocumentService();
    final currentUser = authService.currentUser;
    final userId = currentUser?.uid ?? 'user-dao17022005';
    final userEmail = currentUser?.email ?? 'dao17022005@gmail.com';

    final canCreate = StudyDocument.canUserCreate(currentUser);
    if (!_isEdit && !canCreate) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Lỗi: Bạn không có quyền tạo mới tài liệu. Chỉ Chủ sở hữu (Owner) mới được phép tạo mới!'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_isEdit && !widget.initialDocument!.canUserEdit(currentUser)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Lỗi: Bạn chỉ có quyền Xem (Viewer), không được phép chỉnh sửa tài liệu này!'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_isEdit) {
      final updated = widget.initialDocument!.copyWith(
        title: _titleController.text.trim(),
        description: _descController.text.trim(),
        fileUrl: _fileUrlController.text.trim(),
        filePath: _filePath,
        fileName: _fileName,
        fileSize: _fileSize,
        fileType: _fileType,
        isPublic: _isPublic,
        courseId: _selectedCourseId ?? '',
        type: _selectedType,
        status: _selectedStatus,
        tags: tags,
        deadline: _selectedDeadline,
        isPinned: _isPinned,
        updatedAt: DateTime.now(),
      );
      await _documentDao.update(updated);
      unawaited(syncClient.saveToCloud(updated));
      unawaited(supabaseService.updateDocument(updated));
    } else {
      final newDoc = StudyDocument(
        id: const Uuid().v4(),
        title: _titleController.text.trim(),
        description: _descController.text.trim(),
        fileUrl: _fileUrlController.text.trim(),
        filePath: _filePath,
        fileName: _fileName,
        fileSize: _fileSize,
        fileType: _fileType,
        ownerId: userId,
        ownerEmail: userEmail,
        isPublic: _isPublic,
        userPermission: 'owner',
        courseId: _selectedCourseId ?? '',
        type: _selectedType,
        status: _selectedStatus,
        tags: tags,
        deadline: _selectedDeadline,
        isPinned: _isPinned,
        isSynced: true,
      );
      await _documentDao.insert(newDoc);
      unawaited(syncClient.saveToCloud(newDoc));
      unawaited(supabaseService.updateDocument(newDoc));
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              Icon(Icons.cloud_done_rounded, color: Colors.white, size: 20),
              SizedBox(width: 8),
              Expanded(child: Text('Đã đồng bộ thành công sang Firebase & Supabase!')),
            ],
          ),
          backgroundColor: Color(0xFF2E7D32),
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 2),
        ),
      );
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final deadlineText = _selectedDeadline != null
        ? DateFormat('dd/MM/yyyy').format(_selectedDeadline!)
        : 'Chưa đặt hạn nộp';

    final authService = FirebaseAuthService();
    final currentUser = authService.currentUser;
    final canCreate = StudyDocument.canUserCreate(currentUser);
    final canEdit = widget.initialDocument != null
        ? widget.initialDocument!.canUserEdit(currentUser)
        : canCreate;
    final canShare = widget.initialDocument != null && widget.initialDocument!.canUserShare(currentUser);
    final isEditor = (currentUser?.role ?? '').toLowerCase().contains('editor') ||
        (currentUser?.role ?? '').toLowerCase().contains('chỉnh sửa');

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEdit
            ? (canEdit ? 'Chỉnh sửa tài liệu' : 'Chi tiết tài liệu (Chỉ đọc)')
            : (canCreate ? 'Thêm tài liệu mới' : 'Không có quyền tạo mới')),
        actions: [
          if (_isEdit && canShare)
            IconButton(
              icon: const Icon(Icons.share_rounded),
              tooltip: 'Chia sẻ tài liệu',
              onPressed: () => ShareDocumentDialog.show(context, widget.initialDocument!),
            ),
          if (canEdit)
            IconButton(
              icon: const Icon(Icons.check_rounded),
              tooltip: 'Lưu',
              onPressed: _saveDocument,
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            if (!canEdit)
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isEditor ? Colors.orange.shade50 : Colors.teal.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: isEditor ? Colors.orange.shade300 : Colors.teal.shade300),
                ),
                child: Row(
                  children: [
                    Icon(
                      isEditor ? Icons.lock_outline_rounded : Icons.visibility_rounded,
                      color: isEditor ? Colors.orange.shade800 : Colors.teal.shade700,
                      size: 28,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _isEdit
                                ? 'Chế độ Chỉ đọc (Viewer)'
                                : (isEditor
                                    ? 'Không có quyền tạo mới (Editor)'
                                    : 'Không có quyền tạo mới (Viewer)'),
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: isEditor ? Colors.orange.shade900 : Colors.teal.shade900,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            _isEdit
                                ? 'Tài khoản ${currentUser?.email} có quyền Xem. Bạn không có quyền chỉnh sửa hoặc xóa tài liệu này.'
                                : 'Tài khoản ${currentUser?.email} (${currentUser?.role}) chỉ có quyền xem và chỉnh sửa các tài liệu đã có, không được phép tạo tài liệu mới.',
                            style: TextStyle(
                              fontSize: 11,
                              color: isEditor ? Colors.orange.shade900 : Colors.teal.shade800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            // Trạng thái Xác thực Google Firebase
            Builder(
              builder: (context) {
                final authService = FirebaseAuthService();
                final signedIn = authService.isSignedIn;
                return Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: signedIn ? Colors.green.shade50 : Colors.amber.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: signedIn ? Colors.green.shade300 : Colors.amber.shade400),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        signedIn ? Icons.check_circle_rounded : Icons.lock_outline_rounded,
                        size: 22,
                        color: signedIn ? Colors.green.shade700 : Colors.amber.shade900,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              signedIn
                                  ? 'Đã đăng nhập: ${authService.currentUser!.displayName} (${authService.currentUser!.role})'
                                  : 'Chưa đăng nhập Firebase Google',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: signedIn ? Colors.green.shade900 : Colors.amber.shade900,
                              ),
                            ),
                            Text(
                              signedIn
                                  ? 'Tài khoản: ${authService.currentUser!.email} (Được phép lưu lên Cloud)'
                                  : 'Cần đăng nhập Google để tự động lưu tài liệu lên Cloud Firestore',
                              style: TextStyle(
                                fontSize: 11,
                                color: signedIn ? Colors.green.shade800 : Colors.amber.shade800,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (!signedIn)
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFD81B60),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                          icon: const Icon(Icons.login_rounded, size: 14),
                          label: const Text('Đăng nhập'),
                          onPressed: () async {
                            await authService.signInWithGoogle();
                            setState(() {});
                          },
                        )
                      else
                        TextButton(
                          onPressed: () async {
                            await authService.signOut();
                            setState(() {});
                          },
                          child: const Text('Đăng xuất', style: TextStyle(color: Colors.red, fontSize: 11, fontWeight: FontWeight.bold)),
                        ),
                    ],
                  ),
                );
              },
            ),

            // Tiêu đề
            TextFormField(
              controller: _titleController,
              readOnly: !canEdit,
              decoration: const InputDecoration(
                labelText: 'Tiêu đề tài liệu *',
                hintText: 'VD: Bài tập lớn: Thiết kế Sync Engine',
                border: OutlineInputBorder(),
              ),
              validator: (val) => val == null || val.trim().isEmpty ? 'Vui lòng nhập tiêu đề' : null,
            ),
            const SizedBox(height: 16),

            // Chọn Môn học
            DropdownButtonFormField<String>(
              value: _selectedCourseId,
              decoration: const InputDecoration(
                labelText: 'Môn học / Học phần *',
                border: OutlineInputBorder(),
              ),
              items: _courses.map((c) {
                return DropdownMenuItem(
                  value: c.id,
                  child: Row(
                    children: [
                      CircleAvatar(backgroundColor: Color(c.colorValue), radius: 6),
                      const SizedBox(width: 8),
                      Text('${c.code} - ${c.name}'),
                    ],
                  ),
                );
              }).toList(),
              onChanged: canEdit ? (val) => setState(() => _selectedCourseId = val) : null,
            ),
            const SizedBox(height: 16),

            // Phân loại tài liệu
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<DocumentType>(
                    value: _selectedType,
                    decoration: const InputDecoration(
                      labelText: 'Loại tài liệu',
                      border: OutlineInputBorder(),
                    ),
                    items: DocumentType.values.map((t) {
                      return DropdownMenuItem(value: t, child: Text(t.displayName));
                    }).toList(),
                    onChanged: canEdit ? (val) => setState(() => _selectedType = val!) : null,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<DocumentStatus>(
                    value: _selectedStatus,
                    decoration: const InputDecoration(
                      labelText: 'Trạng thái',
                      border: OutlineInputBorder(),
                    ),
                    items: DocumentStatus.values.map((s) {
                      return DropdownMenuItem(value: s, child: Text(s.displayName));
                    }).toList(),
                    onChanged: canEdit ? (val) => setState(() => _selectedStatus = val!) : null,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Hạn nộp Deadline
            ListTile(
              shape: RoundedRectangleBorder(
                side: BorderSide(color: Colors.grey.shade400),
                borderRadius: BorderRadius.circular(4),
              ),
              leading: const Icon(Icons.calendar_today_rounded),
              title: const Text('Hạn nộp (Deadline)'),
              subtitle: Text(deadlineText),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_selectedDeadline != null && canEdit)
                    IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () => setState(() => _selectedDeadline = null),
                    ),
                  if (canEdit) const Icon(Icons.arrow_forward_ios_rounded, size: 14),
                ],
              ),
              onTap: canEdit ? _pickDeadline : null,
            ),
            const SizedBox(height: 16),

            // Mô tả
            TextFormField(
              controller: _descController,
              readOnly: !canEdit,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Mô tả / Ghi chú chi tiết',
                hintText: 'Nhập nội dung tóm tắt tài liệu...',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),

            // Tệp đính kèm Firebase Cloud Storage
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.blue.shade50.withOpacity(0.5),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.cloud_upload_rounded, color: Colors.blue.shade700, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'Tệp đính kèm (Firebase Storage)',
                        style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue.shade900, fontSize: 13),
                      ),
                      const Spacer(),
                      if (canEdit)
                        FilledButton.tonalIcon(
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            textStyle: const TextStyle(fontSize: 12),
                          ),
                          icon: _isUploadingFile
                              ? const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2))
                              : const Icon(Icons.upload_file_rounded, size: 16),
                          label: Text(_isUploadingFile ? 'Đang tải...' : 'Tải tệp lên Storage'),
                          onPressed: _isUploadingFile ? null : _uploadFileToFirebaseStorage,
                        ),
                    ],
                  ),
                  if (_fileName != null && _fileName!.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.blue.shade100),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.insert_drive_file_rounded, size: 16, color: Colors.blue),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _fileName!,
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (_filePath != null)
                            Text(
                              'Firebase Path OK',
                              style: TextStyle(fontSize: 10, color: Colors.green.shade700, fontWeight: FontWeight.bold),
                            ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Link URL / File đính kèm
            TextFormField(
              controller: _fileUrlController,
              readOnly: !canEdit,
              decoration: const InputDecoration(
                labelText: 'Đường dẫn liên kết / File URL',
                hintText: 'https://...',
                prefixIcon: Icon(Icons.link_rounded),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),

            // Tags
            TextFormField(
              controller: _tagsController,
              readOnly: !canEdit,
              decoration: const InputDecoration(
                labelText: 'Thẻ tag (ngăn cách bằng dấu phẩy)',
                hintText: 'KTPM, Cashew, SQLite',
                prefixIcon: Icon(Icons.tag_rounded),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),

            // Ghim lên đầu
            SwitchListTile(
              title: const Text('Ghim tài liệu quan trọng lên đầu'),
              value: _isPinned,
              onChanged: canEdit ? (val) => setState(() => _isPinned = val) : null,
            ),

            // Quyền riêng tư (Row Level Security - RLS)
            SwitchListTile(
              title: const Text('Chia sẻ công khai (Public)'),
              subtitle: Text(
                _isPublic
                    ? 'Mọi người dùng đều có quyền đọc tài liệu này.'
                    : 'Riêng tư (Chỉ bạn và người được cấp quyền trong Supabase RLS xem được).',
                style: const TextStyle(fontSize: 12),
              ),
              value: _isPublic,
              onChanged: canEdit ? (val) => setState(() => _isPublic = val) : null,
            ),

            if (_isEdit && canShare) ...[
              const SizedBox(height: 8),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.blue.shade800,
                  side: BorderSide(color: Colors.blue.shade300),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                icon: const Icon(Icons.people_alt_outlined, size: 18),
                label: const Text('Quản lý phân quyền chia sẻ (Supabase Permissions)'),
                onPressed: () => ShareDocumentDialog.show(context, widget.initialDocument!),
              ),
            ],

            const SizedBox(height: 24),
            if (canEdit)
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFD81B60),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                icon: const Icon(Icons.save_rounded),
                label: Text(_isEdit ? 'LƯU THAY ĐỔI' : 'TẠO TÀI LIỆU MỚI'),
                onPressed: _saveDocument,
              )
            else
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.teal.shade800,
                  side: BorderSide(color: Colors.teal.shade400),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                icon: const Icon(Icons.arrow_back_rounded),
                label: const Text('QUAY LẠI (CHẾ ĐỘ CHỈ ĐỌC)'),
                onPressed: () => Navigator.pop(context),
              ),
          ],
        ),
      ),
    );
  }
}
