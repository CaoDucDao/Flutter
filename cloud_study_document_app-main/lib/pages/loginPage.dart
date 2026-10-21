import 'package:flutter/material.dart';
import '../struct/firebaseAuthService.dart';

// ============================================================
// Trang Đăng nhập - CHỈ CÓ TÀI KHOẢN THẬT (GOOGLE SIGN-IN)
// Người dùng bấm nút và đăng nhập trực tiếp qua Google OAuth thật
// ============================================================

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final FirebaseAuthService _authService = FirebaseAuthService();
  bool _isLoading = false;
  String? _errorMessage;

  /// Đăng nhập bằng Google OAuth thật
  Future<void> _handleGoogleSignIn() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final user = await _authService.signInWithGoogle();
      if (user == null) {
        if (mounted) {
          setState(() {
            _isLoading = false;
            _errorMessage = 'Đã hủy thao tác đăng nhập Google.';
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Đăng nhập Google thất bại: ${e.toString()}';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF9F9FB),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 36),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Header Logo
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFF7D8DF), Color(0xFFE8DEF8)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(22),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFD81B60).withOpacity(0.18),
                        blurRadius: 20,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.school_rounded,
                    color: Color(0xFFD81B60),
                    size: 48,
                  ),
                ),
                const SizedBox(height: 20),

                Text(
                  'Cashew Study',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurface,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Hệ thống Quản lý Tài liệu & Phân quyền Đám mây',
                  style: TextStyle(
                    fontSize: 13,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),

                const SizedBox(height: 28),

                // Card Đăng nhập Chính
                Container(
                  padding: const EdgeInsets.all(28),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.06),
                        blurRadius: 24,
                        offset: const Offset(0, 8),
                      ),
                    ],
                    border: Border.all(
                      color: theme.colorScheme.outlineVariant.withOpacity(0.3),
                    ),
                  ),
                  child: Column(
                    children: [
                      const Text(
                        'Đăng nhập tài khoản',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Vui lòng sử dụng tài khoản Google thật để tiếp tục vào hệ thống',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                      ),
                      const SizedBox(height: 28),

                      // NÚT ĐĂNG NHẬP GOOGLE CHÍNH THỨC
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: OutlinedButton(
                          onPressed: _isLoading ? null : _handleGoogleSignIn,
                          style: OutlinedButton.styleFrom(
                            backgroundColor: Colors.white,
                            side: BorderSide(color: Colors.grey.shade300, width: 1.5),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            elevation: 1,
                            shadowColor: Colors.black.withOpacity(0.08),
                          ),
                          child: _isLoading
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(strokeWidth: 2.2, color: Color(0xFFD81B60)),
                                )
                              : Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Image.network(
                                      'https://www.gstatic.com/firebasejs/ui/2.0.0/images/auth/google.svg',
                                      width: 22,
                                      height: 22,
                                      errorBuilder: (context, error, stackTrace) => const Icon(
                                        Icons.g_mobiledata_rounded,
                                        color: Colors.red,
                                        size: 26,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    const Text(
                                      'Đăng nhập bằng Google',
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.black87,
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      ),

                      // Hiển thị thông báo lỗi
                      if (_errorMessage != null) ...[
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.red.shade50,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.red.shade200),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.error_outline_rounded, color: Colors.red.shade700, size: 20),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  _errorMessage!,
                                  style: TextStyle(color: Colors.red.shade800, fontSize: 12),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                const SizedBox(height: 28),

                // Footer bảo mật
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.verified_user_outlined, size: 14, color: Colors.grey.shade600),
                    const SizedBox(width: 6),
                    Text(
                      'Bảo mật bởi Firebase Authentication & Supabase RLS',
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
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
}
