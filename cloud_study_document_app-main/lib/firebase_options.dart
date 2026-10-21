// File cấu hình Firebase cho dự án "tudydocumentapp-bt" của Cao Đức Đạo
// caoducdao17022005@gmail.com
//
// ignore_for_file: type=lint
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Cấu hình Firebase mặc định cho từng nền tảng (Web, Android, iOS, Windows, macOS)
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        return macos;
      case TargetPlatform.windows:
        return windows;
      case TargetPlatform.linux:
        throw UnsupportedError(
          'DefaultFirebaseOptions chưa được cấu hình cho Linux.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions không hỗ trợ nền tảng này.',
        );
    }
  }

  // ============================================================
  // CẤU HÌNH CHÍNH THỨC TỪ DỰ ÁN FIREBASE: tudydocumentapp-bt
  // ============================================================

  /// Cấu hình Firebase cho nền tảng Web
  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyCXBHYgGlCurkMUPZa8LB6llgTXT0bztZc',
    appId: '1:876467400447:web:6a3a6384ee9f1905b1a6ca',
    messagingSenderId: '876467400447',
    projectId: 'tudydocumentapp-bt',
    authDomain: 'tudydocumentapp-bt.firebaseapp.com',
    storageBucket: 'tudydocumentapp-bt.firebasestorage.app',
    measurementId: 'G-6JGMQE9ZR2',
  );

  /// Cấu hình Firebase cho nền tảng Android
  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyCXBHYgGlCurkMUPZa8LB6llgTXT0bztZc',
    appId: '1:876467400447:android:6a3a6384ee9f1905b1a6ca',
    messagingSenderId: '876467400447',
    projectId: 'tudydocumentapp-bt',
    storageBucket: 'tudydocumentapp-bt.firebasestorage.app',
  );

  /// Cấu hình Firebase cho nền tảng iOS
  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyCXBHYgGlCurkMUPZa8LB6llgTXT0bztZc',
    appId: '1:876467400447:ios:6a3a6384ee9f1905b1a6ca',
    messagingSenderId: '876467400447',
    projectId: 'tudydocumentapp-bt',
    storageBucket: 'tudydocumentapp-bt.firebasestorage.app',
    iosBundleId: 'com.caoducdao.studyDocumentApp',
  );

  /// Cấu hình Firebase cho nền tảng macOS
  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'AIzaSyCXBHYgGlCurkMUPZa8LB6llgTXT0bztZc',
    appId: '1:876467400447:macos:6a3a6384ee9f1905b1a6ca',
    messagingSenderId: '876467400447',
    projectId: 'tudydocumentapp-bt',
    storageBucket: 'tudydocumentapp-bt.firebasestorage.app',
    iosBundleId: 'com.caoducdao.studyDocumentApp',
  );

  /// Cấu hình Firebase cho nền tảng Windows
  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'AIzaSyCXBHYgGlCurkMUPZa8LB6llgTXT0bztZc',
    appId: '1:876467400447:web:6a3a6384ee9f1905b1a6ca',
    messagingSenderId: '876467400447',
    projectId: 'tudydocumentapp-bt',
    storageBucket: 'tudydocumentapp-bt.firebasestorage.app',
  );
}
