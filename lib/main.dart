
import 'package:material_ui/material_ui.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'firebase_options.dart';
import 'theme/app_theme.dart';
import 'views/auth/login_view.dart';
import 'views/auth/verification_view.dart';
import 'screens/home/home_screen.dart';
import 'screens/admin/admin_screen.dart';
import 'services/auth_service.dart';
import 'services/supabase_service.dart';
import 'services/role_service.dart';

// =====================================================
// KHỞI TẠO ỨNG DỤNG
// =====================================================

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    // 1. Khởi tạo Firebase
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    debugPrint('================================');
    debugPrint('FIREBASE INITIALIZED');
    debugPrint(
      'PROJECT ID: ${DefaultFirebaseOptions.currentPlatform.projectId}',
    );

    // 2. Thiết lập lưu phiên đăng nhập lâu dài cho Flutter Web
    if (kIsWeb) {
      await FirebaseAuth.instance.setPersistence(Persistence.LOCAL);

      debugPrint('FIREBASE WEB PERSISTENCE: LOCAL');
    }

    debugPrint('================================');

    // 3. Khởi tạo Supabase
    await SupabaseService.initialize();

    debugPrint('SUPABASE INITIALIZED SUCCESSFULLY');

    // 4. Chạy ứng dụng
    runApp(const QuizMasterApp());
  } catch (e, stackTrace) {
    debugPrint('LOI KHOI TAO QUIZMASTER: $e');
    debugPrint('$stackTrace');

    runApp(InitializationErrorApp(error: e.toString()));
  }
}

// =====================================================
// MÀN HÌNH LỖI KHỞI TẠO
// =====================================================

class InitializationErrorApp extends StatelessWidget {
  final String error;

  const InitializationErrorApp({super.key, required this.error});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 65, color: Colors.red),
                const SizedBox(height: 20),
                const Text(
                  'Không thể khởi tạo QuizMaster',
                  style: TextStyle(fontSize: 21, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(error, textAlign: TextAlign.center),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// =====================================================
// ỨNG DỤNG QUIZMASTER
// =====================================================

class QuizMasterApp extends StatelessWidget {
  const QuizMasterApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'QuizMaster',
      theme: AppTheme.lightTheme,
      home: const AuthGate(),
    );
  }
}

// =====================================================
// KIỂM TRA TRẠNG THÁI ĐĂNG NHẬP
// =====================================================

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.userChanges(),
      builder: (context, snapshot) {
        // Đang tải trạng thái tài khoản
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(color: Color(0xFF6257E8)),
            ),
          );
        }

        // Xử lý lỗi
        if (snapshot.hasError) {
          return Scaffold(
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Có lỗi xảy ra: ${snapshot.error}',
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          );
        }

        final user = snapshot.data;

        // Chưa đăng nhập
        if (user == null) {
          return const LoginView();
        }

        // Đã đăng nhập
        return AuthenticatedUserGate(key: ValueKey(user.uid), user: user);
      },
    );
  }
}

// =====================================================
// KIỂM TRA EMAIL VÀ VAI TRÒ TÀI KHOẢN
// =====================================================

class AuthenticatedUserGate extends StatefulWidget {
  final User user;

  const AuthenticatedUserGate({super.key, required this.user});

  @override
  State<AuthenticatedUserGate> createState() => _AuthenticatedUserGateState();
}

class _AuthenticatedUserGateState extends State<AuthenticatedUserGate>
    with WidgetsBindingObserver {
  late Future<String> _roleFuture;

  bool _handlingLockedAccount = false;

  @override
  void initState() {
    super.initState();

    // Đăng ký theo dõi trạng thái ứng dụng
    WidgetsBinding.instance.addObserver(this);

    _loadRole();
  }

  // ===================================================
  // TẢI VAI TRÒ NGƯỜI DÙNG
  // ===================================================

  void _loadRole() {
    _roleFuture = RoleService.getCurrentRole();
  }

  // ===================================================
  // KIỂM TRA LẠI KHI QUAY LẠI ỨNG DỤNG
  // ===================================================

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkAccountAgain();
    }
  }

  void _checkAccountAgain() {
    if (!mounted || _handlingLockedAccount) return;

    setState(() {
      _loadRole();
    });
  }

  // ===================================================
  // HỦY THEO DÕI TRẠNG THÁI ỨNG DỤNG
  // ===================================================

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // ===================================================
  // THỬ TẢI LẠI VAI TRÒ
  // ===================================================

  void _retry() {
    setState(() {
      _handlingLockedAccount = false;
      _loadRole();
    });
  }

  // ===================================================
  // ĐĂNG XUẤT THÔNG THƯỜNG
  // ===================================================

  Future<void> _logout() async {
    try {
      await AuthService().logout();
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Không thể đăng xuất: $e')));
    }
  }

  // ===================================================
  // TỰ ĐỘNG ĐĂNG XUẤT KHI TÀI KHOẢN BỊ KHÓA
  // ===================================================

  void _logoutLockedAccount() {
    if (_handlingLockedAccount) return;

    _handlingLockedAccount = true;

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Tài khoản đã bị khóa. '
            'Bạn đã bị đăng xuất khỏi QuizMaster.',
          ),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 4),
        ),
      );

      try {
        await AuthService().logout();
      } catch (e) {
        if (!mounted) return;

        setState(() {
          _handlingLockedAccount = false;
        });
      }
    });
  }

  // ===================================================
  // GIAO DIỆN TÀI KHOẢN BỊ KHÓA
  // ===================================================

  Widget _buildLockedAccountScreen() {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.gpp_bad_outlined, size: 75, color: Colors.red),
              const SizedBox(height: 20),
              const Text(
                'Tài khoản đã bị khóa',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              const Text(
                'Tài khoản của bạn hiện không được phép truy cập '
                'QuizMaster. Vui lòng liên hệ quản trị viên '
                'để được hỗ trợ.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              if (_handlingLockedAccount)
                const Column(
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 12),
                    Text('Đang đăng xuất tài khoản...'),
                  ],
                )
              else
                ElevatedButton.icon(
                  onPressed: _logoutLockedAccount,
                  icon: const Icon(Icons.logout),
                  label: const Text('Đăng xuất'),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // ===================================================
  // KIỂM TRA VÀ ĐIỀU HƯỚNG
  // ===================================================

  @override
  Widget build(BuildContext context) {
    // Chưa xác minh email
    if (!widget.user.emailVerified) {
      return const VerificationView();
    }

    return FutureBuilder<String>(
      future: _roleFuture,
      builder: (context, snapshot) {
        // Đang tải vai trò
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(color: Color(0xFF6257E8)),
            ),
          );
        }

        // Phát hiện tài khoản bị khóa
        if (snapshot.hasError && snapshot.error is AccountLockedException) {
          _logoutLockedAccount();
          return _buildLockedAccountScreen();
        }

        // Không thể lấy vai trò hoặc tài khoản không hợp lệ
        if (snapshot.hasError) {
          return Scaffold(
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.lock_outline, size: 65, color: Colors.red),
                    const SizedBox(height: 16),
                    const Text(
                      'Không thể truy cập tài khoản',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text('${snapshot.error}', textAlign: TextAlign.center),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: _retry,
                      child: const Text('Thử lại'),
                    ),
                    TextButton(
                      onPressed: _logout,
                      child: const Text('Đăng xuất'),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        final role = snapshot.data;

        // Super Admin và Admin
        if (role == 'super_admin' || role == 'admin') {
          return const AdminScreen();
        }

        // User thông thường
        if (role == 'user') {
          return const HomeScreen();
        }

        // Vai trò không hợp lệ
        return Scaffold(
          body: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.warning_amber_rounded,
                  size: 60,
                  color: Colors.orange,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Vai trò tài khoản không hợp lệ.',
                  textAlign: TextAlign.center,
                ),
                TextButton(onPressed: _logout, child: const Text('Đăng xuất')),
              ],
            ),
          ),
        );
      },
    );
  }
}
