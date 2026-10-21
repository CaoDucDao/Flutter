import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

// ============================================================
// Dịch vụ Xác thực Firebase & Đăng nhập Google (Google Sign-In)
// Phục vụ Checklist 6 & 7: Phương án tích hợp Cloud & Quản trị Phân quyền IAM
// ============================================================

/// Model thông tin người dùng hỗ trợ phân quyền IAM và Google Account
class MockFirebaseUser {
  final String uid;
  final String email;
  final String displayName;
  final String photoUrl;
  final String role;
  final String msv;

  const MockFirebaseUser({
    required this.uid,
    required this.email,
    required this.displayName,
    this.photoUrl = '',
    this.role = 'Editor',
    this.msv = '',
  });

  /// Alias tương thích với Firebase User property photoURL
  String get photoURL => photoUrl;

  /// Hỗ trợ truy cập dạng Map như member['displayName'] để tương thích mọi màn hình
  dynamic operator [](String key) {
    switch (key) {
      case 'uid':
        return uid;
      case 'email':
        return email;
      case 'displayName':
        return displayName;
      case 'photoUrl':
      case 'photoURL':
        return photoUrl;
      case 'role':
        return role;
      case 'msv':
        return msv;
      default:
        return null;
    }
  }
}

class FirebaseAuthService with ChangeNotifier {
  static final FirebaseAuthService _instance = FirebaseAuthService._internal();
  factory FirebaseAuthService() => _instance;

  FirebaseAuthService._internal() {
    // Tự động đồng bộ khi Firebase Auth thật thay đổi trạng thái
    try {
      _firebaseAuth.authStateChanges().listen((user) {
        notifyListeners();
      });
    } catch (_) {}
  }

  // Instance Firebase Authentication
  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;

  // Instance Google Sign-In
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: ['email', 'profile'],
  );

  // Lưu trữ user khi chọn đăng nhập demo/IAM
  MockFirebaseUser? _selectedUser;

  // Danh sách 3 tài khoản kiểm thử theo phân quyền IAM / Supabase
  static const List<MockFirebaseUser> teamMembers = [
     MockFirebaseUser(
    uid: 'user-dao-2351170581',
    email: 'caoducdao17022005@gmail.com',
    displayName: 'Cao Đức Đạo',
    role: 'Owner / Trưởng nhóm',
    msv: '2351170581',
  ),
    MockFirebaseUser(
      uid: 'user-dao17022005',
      email: 'dao17022005@gmail.com',
      displayName: 'Cao Đức Đạo (Editor)',
      role: 'Editor / Chỉnh sửa',
      msv: '2351170581',
    ),
    MockFirebaseUser(
      uid: 'user-daokoaiyeu',
      email: 'daokoaiyeu@gmail.com',
      displayName: 'Đạo Không Ai Yêu (Editor)',
      role: 'Editor / Chỉnh sửa',
      msv: 'TEST-EDITOR',
    ),
    MockFirebaseUser(
      uid: 'user-teokhung1702',
      email: 'teokhung1702@gmail.com',
      displayName: 'Tèo Khùng (Viewer)',
      role: 'Viewer / Người xem',
      msv: 'TEST-VIEWER',
    ),
  ];

  /// Lấy vai trò IAM của user dựa trên email
  static String getRoleForEmail(String email) {
    final member = teamMembers.firstWhere(
      (m) => m.email.toLowerCase() == email.toLowerCase(),
      orElse: () => MockFirebaseUser(
        uid: '',
        email: email,
        displayName: '',
        role: 'Viewer',
      ),
    );
    return member.role;
  }

  /// Trả về User hiện tại: ưu tiên tài khoản kiểm thử đã chọn (_selectedUser), sau đó fallback về Firebase Auth thật
  MockFirebaseUser? get currentUser {
    if (_selectedUser != null) {
      return _selectedUser;
    }
    try {
      final fbUser = _firebaseAuth.currentUser;
      if (fbUser != null) {
        return MockFirebaseUser(
          uid: fbUser.uid,
          email: fbUser.email ?? '',
          displayName: (fbUser.displayName != null && fbUser.displayName!.isNotEmpty)
              ? fbUser.displayName!
              : (fbUser.email?.split('@').first ?? 'Người dùng Google'),
          photoUrl: fbUser.photoURL ?? '',
          role: getRoleForEmail(fbUser.email ?? ''),
          msv: '',
        );
      }
    } catch (_) {}
    return null;
  }

  /// Kiểm tra trạng thái đã đăng nhập
  bool get isSignedIn => currentUser != null;

  /// Tên hiển thị người dùng
  String get displayName => currentUser?.displayName ?? 'Người dùng';

  /// Email người dùng
  String get email => currentUser?.email ?? '';

  /// URL ảnh đại diện
  String get photoUrl => currentUser?.photoUrl ?? '';

  /// UID người dùng
  String get uid => currentUser?.uid ?? '';

  /// Vai trò IAM
  String get role => currentUser?.role ?? 'Viewer';

  /// Stream theo dõi thay đổi trạng thái xác thực
  Stream<User?> get authStateChanges => _firebaseAuth.authStateChanges();

  // ============================================================
  // ĐĂNG NHẬP BẰNG GOOGLE HOẶC CHỌN TÀI KHOẢN NHÓM
  // ============================================================

  /// Đăng nhập với bất kỳ tài khoản Email nào (Hỗ trợ kiểm thử không giới hạn)
  Future<MockFirebaseUser> signInWithCustomEmail({
    required String email,
    String? displayName,
    String? role,
  }) async {
    final cleanEmail = email.trim();
    final name = (displayName != null && displayName.trim().isNotEmpty)
        ? displayName.trim()
        : cleanEmail.split('@').first;
    final userRole = role ?? getRoleForEmail(cleanEmail);

    final user = MockFirebaseUser(
      uid: 'user-${cleanEmail.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_')}',
      email: cleanEmail,
      displayName: name,
      role: userRole,
      msv: 'ID-${DateTime.now().millisecond}',
    );

    _selectedUser = user;
    notifyListeners();
    return user;
  }

  /// Đăng nhập bằng Google thật (Hỗ trợ chọn bất kỳ tài khoản Google nào)
  Future<MockFirebaseUser?> signInWithGoogle({MockFirebaseUser? user}) async {
    // Nếu chọn trực tiếp tài khoản từ danh sách
    if (user != null) {
      _selectedUser = user;
      notifyListeners();
      return _selectedUser;
    }

    try {
      if (kIsWeb) {
        // Trên nền tảng Web: Sử dụng signInWithPopup của Firebase Auth
        // Tham số prompt: select_account buộc Google luôn hiển thị danh sách để bạn chọn tài khoản mong muốn
        final GoogleAuthProvider googleProvider = GoogleAuthProvider();
        googleProvider.setCustomParameters({'prompt': 'select_account'});

        final UserCredential userCredential = await _firebaseAuth.signInWithPopup(googleProvider);
        final fbUser = userCredential.user;
        if (fbUser != null) {
          _selectedUser = MockFirebaseUser(
            uid: fbUser.uid,
            email: fbUser.email ?? '',
            displayName: (fbUser.displayName != null && fbUser.displayName!.isNotEmpty)
                ? fbUser.displayName!
                : (fbUser.email?.split('@').first ?? 'Người dùng Google'),
            photoUrl: fbUser.photoURL ?? '',
            role: getRoleForEmail(fbUser.email ?? ''),
            msv: '',
          );

          notifyListeners();
          return _selectedUser;
        }
        return null;
      } else {
        // Trên Android / iOS: Dùng plugin google_sign_in
        await _googleSignIn.signOut();
        final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
        if (googleUser == null) return null;

        final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
        final OAuthCredential credential = GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        );

        final UserCredential userCredential = await _firebaseAuth.signInWithCredential(credential);
        final fbUser = userCredential.user;
        if (fbUser != null) {
          _selectedUser = MockFirebaseUser(
            uid: fbUser.uid,
            email: fbUser.email ?? googleUser.email,
            displayName: fbUser.displayName ?? googleUser.displayName ?? 'Người dùng Google',
            photoUrl: fbUser.photoURL ?? googleUser.photoUrl ?? '',
            role: getRoleForEmail(fbUser.email ?? googleUser.email),
            msv: '',
          );

          notifyListeners();
          return _selectedUser;
        }
        return null;
      }
    } catch (e) {
      debugPrint('[FirebaseAuth] Google Sign-In error: $e');
      rethrow;
    }
  }

  // ============================================================
  // ĐĂNG XUẤT
  // ============================================================

  Future<void> signOut() async {
    _selectedUser = null;
    try {
      await _googleSignIn.signOut();
    } catch (_) {}
    try {
      await _firebaseAuth.signOut();
    } catch (_) {}
    notifyListeners();
  }
}
