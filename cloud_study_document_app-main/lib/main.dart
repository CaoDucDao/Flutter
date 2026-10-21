import 'struct/studySyncClient.dart';
import 'struct/firebaseAuthService.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'widgets/navigationSidebar.dart';
import 'pages/homePage.dart';
import 'pages/studyDocumentsPage.dart';
import 'pages/studyCoursesPage.dart';
import 'pages/studyGoalsPage.dart';
import 'pages/studyDocumentSearchPage.dart';
import 'pages/loginPage.dart';

// ============================================================
// ĐIỂM KHỞI ĐẦU ỨNG DỤNG
// Khởi tạo Firebase trước khi chạy ứng dụng Flutter
// ============================================================

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Khởi tạo Firebase với cấu hình tương ứng cho từng nền tảng
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(const CashewStudyApp());
}

class CashewStudyApp extends StatelessWidget {
  const CashewStudyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Quản lý Tài liệu Học tập - Cashew',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFD81B60), // Cashew Pink/Rose accent/
          primary: const Color(0xFFD81B60),
          surface: Colors.white,
          background: const Color(0xFFF9F9FB),
        ),
      ),
      home: const AuthGate(),
    );
  }
}

// ============================================================
// AUTH GATE - Kiểm soát luồng xác thực
// Tự động chuyển giữa LoginPage và MainLayoutScreen
// dựa trên trạng thái đăng nhập Firebase Auth
// ============================================================

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = FirebaseAuthService();
    return ListenableBuilder(
      listenable: authService,
      builder: (context, _) {
        if (authService.isSignedIn) {
          return const MainLayoutScreen();
        }
        return const LoginPage();
      },
    );
  }
}

// ============================================================
// LAYOUT CHÍNH CỦA ỨNG DỤNG (sau khi đã đăng nhập)
// ============================================================

class MainLayoutScreen extends StatefulWidget {
  const MainLayoutScreen({super.key});

  @override
  State<MainLayoutScreen> createState() => _MainLayoutScreenState();
}

class _MainLayoutScreenState extends State<MainLayoutScreen> {
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    StudySyncClient().pullFromCloud();
  }

  void _onNavigate(int index) {
    setState(() => _currentIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width >= 700;

    final pages = [
      HomePage(onNavigate: _onNavigate),
      const StudyDocumentsPage(),
      const CoursesPage(),
      const StudyGoalsPage(),
      const DocumentSearchPage(),
    ];

    if (isDesktop) {
      // Cashew Responsive Desktop Layout with Left Navigation Sidebar
      return Scaffold(
        body: Row(
          children: [
            NavigationSidebar(
              selectedIndex: _currentIndex,
              onDestinationSelected: _onNavigate,
            ),
            Expanded(
              child: IndexedStack(
                index: _currentIndex,
                children: pages,
              ),
            ),
          ],
        ),
      );
    } else {
      // Mobile Layout with Bottom Navigation Bar
      return Scaffold(
        body: IndexedStack(
          index: _currentIndex,
          children: pages,
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _currentIndex,
          onDestinationSelected: _onNavigate,
          destinations: const [
            NavigationDestination(icon: Icon(Icons.home_rounded), label: 'Trang chủ'),
            NavigationDestination(icon: Icon(Icons.menu_book_rounded), label: 'Tài liệu'),
            NavigationDestination(icon: Icon(Icons.school_rounded), label: 'Môn học'),
            NavigationDestination(icon: Icon(Icons.flag_rounded), label: 'Mục tiêu'),
            NavigationDestination(icon: Icon(Icons.search_rounded), label: 'Tìm kiếm'),
          ],
        ),
      );
    }
  }
}
