import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../models/auth_action_result.dart';
import '../services/auth_service.dart';

/// Controller điều phối các luồng xác thực của QuizMaster.
/// View chỉ gửi dữ liệu và hiển thị kết quả; Controller gọi AuthService.
class AuthController extends ChangeNotifier {
  AuthController({AuthService? authService})
      : _authService = authService ?? AuthService();

  final AuthService _authService;

  bool _isLoading = false;
  bool _isCheckingVerification = false;
  bool _isResendingVerification = false;
  bool _disposed = false;

  bool get isLoading => _isLoading;
  bool get isCheckingVerification => _isCheckingVerification;
  bool get isResendingVerification => _isResendingVerification;
  String get currentUserEmail => _authService.currentUser?.email ?? '';

  void _setLoading(bool value) {
    _isLoading = value;
    _notifyListeners();
  }

  void _setCheckingVerification(bool value) {
    _isCheckingVerification = value;
    _notifyListeners();
  }

  void _setResendingVerification(bool value) {
    _isResendingVerification = value;
    _notifyListeners();
  }

  void _notifyListeners() {
    if (!_disposed) {
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  /// Đăng nhập thông qua AuthService để luôn kiểm tra/cấp custom claim.
  Future<AuthActionResult> login({
    required String email,
    required String password,
  }) async {
    final normalizedEmail = email.trim();

    if (normalizedEmail.isEmpty || password.isEmpty) {
      return const AuthActionResult.failure(
        'Vui lòng nhập đầy đủ email và mật khẩu',
      );
    }

    _setLoading(true);
    try {
      await _authService.login(
        email: normalizedEmail,
        password: password,
      );
      return const AuthActionResult.success('Đăng nhập thành công!');
    } on FirebaseAuthException catch (error) {
      return AuthActionResult.failure(_loginErrorMessage(error));
    } catch (error) {
      return AuthActionResult.failure('Đăng nhập thất bại: $error');
    } finally {
      _setLoading(false);
    }
  }

  /// Đăng ký Firebase, cấp claim, đồng bộ hồ sơ Supabase và gửi email xác minh.
  Future<AuthActionResult> register({
    required String fullName,
    required String email,
    required String password,
    required String confirmPassword,
  }) async {
    final normalizedName = fullName.trim();
    final normalizedEmail = email.trim();

    if (normalizedName.isEmpty ||
        normalizedEmail.isEmpty ||
        password.isEmpty ||
        confirmPassword.isEmpty) {
      return const AuthActionResult.failure(
        'Vui lòng nhập đầy đủ thông tin',
      );
    }

    if (password.length < 6) {
      return const AuthActionResult.failure(
        'Mật khẩu phải có ít nhất 6 ký tự',
      );
    }

    if (password != confirmPassword) {
      return const AuthActionResult.failure(
        'Mật khẩu xác nhận không khớp',
      );
    }

    _setLoading(true);
    try {
      await _authService.register(
        email: normalizedEmail,
        password: password,
        fullName: normalizedName,
      );
      return const AuthActionResult.success(
        'Đăng ký thành công! Hãy kiểm tra email để xác minh.',
      );
    } on FirebaseAuthException catch (error) {
      return AuthActionResult.failure(_registerErrorMessage(error));
    } catch (error) {
      return AuthActionResult.failure('Đăng ký thất bại: $error');
    } finally {
      _setLoading(false);
    }
  }

  /// Gửi email đặt lại mật khẩu.
  Future<AuthActionResult> resetPassword(String email) async {
    final normalizedEmail = email.trim();
    if (normalizedEmail.isEmpty) {
      return const AuthActionResult.failure(
        'Vui lòng nhập email để đặt lại mật khẩu.',
      );
    }

    _setLoading(true);
    try {
      await _authService.resetPassword(normalizedEmail);
      return const AuthActionResult.success(
        'Đã gửi email đặt lại mật khẩu.',
      );
    } on FirebaseAuthException catch (error) {
      return AuthActionResult.failure(
        error.message ?? 'Không thể gửi email đặt lại mật khẩu.',
      );
    } catch (error) {
      return AuthActionResult.failure(
        'Không thể gửi email đặt lại mật khẩu: $error',
      );
    } finally {
      _setLoading(false);
    }
  }

  /// Tải lại tài khoản từ Firebase và kiểm tra trạng thái xác minh email.
  Future<AuthActionResult> checkEmailVerification() async {
    if (_authService.currentUser == null) {
      return const AuthActionResult.failure('Bạn chưa đăng nhập.');
    }

    _setCheckingVerification(true);
    try {
      await _authService.reloadUser();
      final isVerified = _authService.currentUser?.emailVerified ?? false;
      if (isVerified) {
        return const AuthActionResult.success(
          'Xác minh email thành công!',
        );
      }
      return const AuthActionResult.failure(
        'Bạn chưa xác minh email. Hãy kiểm tra hộp thư.',
      );
    } on FirebaseAuthException catch (error) {
      return AuthActionResult.failure(
        'Lỗi Firebase: ${error.message ?? error.code}',
      );
    } catch (error) {
      return AuthActionResult.failure(
        'Không thể kiểm tra xác minh: $error',
      );
    } finally {
      _setCheckingVerification(false);
    }
  }

  /// Gửi lại email xác minh cho tài khoản hiện tại.
  Future<AuthActionResult> resendVerificationEmail() async {
    if (_authService.currentUser == null) {
      return const AuthActionResult.failure('Bạn chưa đăng nhập.');
    }

    _setResendingVerification(true);
    try {
      await _authService.sendVerificationEmail();
      return const AuthActionResult.success('Đã gửi lại email xác minh!');
    } on FirebaseAuthException catch (error) {
      return AuthActionResult.failure(
        'Lỗi Firebase: ${error.message ?? error.code}',
      );
    } catch (error) {
      return AuthActionResult.failure('Không thể gửi email: $error');
    } finally {
      _setResendingVerification(false);
    }
  }

  /// Đăng xuất tài khoản hiện tại.
  Future<AuthActionResult> logout() async {
    try {
      await _authService.logout();
      return const AuthActionResult.success('Đã đăng xuất.');
    } catch (error) {
      return AuthActionResult.failure('Không thể đăng xuất: $error');
    }
  }

  String _loginErrorMessage(FirebaseAuthException error) {
    switch (error.code) {
      case 'user-not-found':
        return 'Không tìm thấy tài khoản này.';
      case 'wrong-password':
      case 'invalid-credential':
        return 'Email hoặc mật khẩu không chính xác.';
      case 'invalid-email':
        return 'Email không hợp lệ.';
      case 'user-disabled':
        return 'Tài khoản đã bị vô hiệu hóa.';
      case 'too-many-requests':
        return 'Bạn thử quá nhiều lần. Vui lòng thử lại sau.';
      default:
        return error.message ?? 'Đăng nhập thất bại.';
    }
  }

  String _registerErrorMessage(FirebaseAuthException error) {
    switch (error.code) {
      case 'email-already-in-use':
        return 'Email này đã được sử dụng.';
      case 'invalid-email':
        return 'Email không hợp lệ.';
      case 'weak-password':
        return 'Mật khẩu quá yếu. Vui lòng chọn mật khẩu khác.';
      case 'operation-not-allowed':
        return 'Phương thức đăng ký hiện chưa được bật.';
      default:
        return error.message ?? 'Đăng ký thất bại.';
    }
  }
}
