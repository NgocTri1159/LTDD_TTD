import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'supabase_service.dart';
import 'backend_service.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Theo dõi trạng thái đăng nhập
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Lấy tài khoản hiện tại
  User? get currentUser => _auth.currentUser;

  // Kiểm tra tài khoản hiện tại có đăng nhập bằng Email/Mật khẩu không
  bool get hasPasswordProvider {
    final user = _auth.currentUser;
    if (user == null) return false;
    return user.providerData.any((info) => info.providerId == 'password');
  }

  // Đăng ký
  Future<UserCredential> register({
    required String email,
    required String password,
    required String fullName,
  }) async {
    try {
      // 1. Tạo tài khoản Firebase
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      final user = credential.user;

      if (user == null) {
        throw Exception('Không thể tạo tài khoản Firebase');
      }

      // 2. Cập nhật tên người dùng
      await user.updateDisplayName(fullName.trim());

      // 3. Gọi Backend cấp quyền authenticated
      await BackendService.provisionRole();

      // 4. Đồng bộ hồ sơ sang Supabase
      await SupabaseService.syncUserProfile(
        hoTen: fullName.trim(),
      );

      // 5. Gửi email xác minh
      try {
        await user.sendEmailVerification();
        debugPrint('DA GUI EMAIL XAC MINH THANH CONG');
      } on FirebaseAuthException catch (e) {
        debugPrint('LOI GUI EMAIL: ${e.code}');
        debugPrint('CHI TIET: ${e.message}');
        rethrow;
      }

      final tokenResult = await user.getIdTokenResult();

      debugPrint('========== REGISTER SUCCESS ==========');
      debugPrint('UID: ${user.uid}');
      debugPrint('EMAIL: ${user.email}');
      debugPrint('CLAIMS: ${tokenResult.claims}');
      debugPrint('======================================');

      return credential;
    } on FirebaseAuthException catch (e) {
      debugPrint('REGISTER ERROR CODE: ${e.code}');
      debugPrint('REGISTER ERROR MESSAGE: ${e.message}');
      rethrow;
    } catch (e) {
      debugPrint('REGISTER UNKNOWN ERROR: $e');
      rethrow;
    }
  }

  // Đăng nhập Email / Mật khẩu
  Future<UserCredential> login({
    required String email,
    required String password,
  }) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      final user = credential.user;

      if (user != null) {
        var tokenResult = await user.getIdTokenResult(true);

        if (tokenResult.claims?['role'] != 'authenticated') {
          await BackendService.provisionRole();
          tokenResult = await user.getIdTokenResult(true);
        }

        debugPrint('========== FIREBASE CLAIMS ==========');
        debugPrint('UID: ${user.uid}');
        debugPrint('EMAIL: ${user.email}');
        debugPrint('CLAIMS: ${tokenResult.claims}');
        debugPrint('=====================================');
      }

      return credential;
    } catch (e) {
      debugPrint('LOGIN ERROR: $e');
      rethrow;
    }
  }

  // Đăng nhập bằng Google (Web & Mobile)
  Future<UserCredential> loginWithGoogle() async {
    try {
      final googleProvider = GoogleAuthProvider()
        ..addScope('email')
        ..addScope('profile')
        ..setCustomParameters({'prompt': 'select_account'});

      final UserCredential credential = kIsWeb
          ? await _auth.signInWithPopup(googleProvider)
          : await _auth.signInWithProvider(googleProvider);

      final user = credential.user;

      if (user == null) {
        throw Exception('Không lấy được thông tin tài khoản Google.');
      }

      // 1. Kiểm tra và cấp custom claim authenticated nếu chưa có
      var tokenResult = await user.getIdTokenResult(true);
      if (tokenResult.claims?['role'] != 'authenticated') {
        await BackendService.provisionRole();
        tokenResult = await user.getIdTokenResult(true);
      }

      // 2. Đồng bộ hồ sơ sang Supabase (đảm bảo user Google lần đầu có dữ liệu)
      final displayName = (user.displayName != null &&
              user.displayName!.trim().isNotEmpty)
          ? user.displayName!.trim()
          : (user.email?.split('@').first ?? 'Người dùng QuizMaster');

      await SupabaseService.syncUserProfile(hoTen: displayName);

      debugPrint('========== GOOGLE LOGIN SUCCESS ==========');
      debugPrint('UID: ${user.uid}');
      debugPrint('EMAIL: ${user.email}');
      debugPrint('CLAIMS: ${tokenResult.claims}');
      debugPrint('==========================================');

      return credential;
    } on FirebaseAuthException catch (e) {
      debugPrint('GOOGLE LOGIN ERROR CODE: ${e.code}');
      debugPrint('GOOGLE LOGIN ERROR MESSAGE: ${e.message}');
      rethrow;
    } catch (e) {
      debugPrint('GOOGLE LOGIN UNKNOWN ERROR: $e');
      rethrow;
    }
  }

  // Đổi mật khẩu bằng mật khẩu cũ (Firebase Auth)
  Future<void> changePasswordWithOldPassword({
    required String email,
    required String oldPassword,
    required String newPassword,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại.');
    }

    if (!hasPasswordProvider) {
      throw Exception(
        'Tài khoản này đăng nhập bằng Google nên chưa có mật khẩu cũ. Vui lòng dùng tính năng đặt lại mật khẩu qua Email.',
      );
    }

    try {
      final credential = EmailAuthProvider.credential(
        email: email.trim(),
        password: oldPassword,
      );

      // Xác thực lại mật khẩu cũ trước khi đổi
      await user.reauthenticateWithCredential(credential);

      // Cập nhật mật khẩu mới
      await user.updatePassword(newPassword);
    } on FirebaseAuthException catch (e) {
      switch (e.code) {
        case 'wrong-password':
        case 'invalid-credential':
          throw Exception('Mật khẩu cũ không chính xác.');
        case 'weak-password':
          throw Exception('Mật khẩu mới quá yếu (cần ít nhất 6 ký tự).');
        case 'requires-recent-login':
          throw Exception('Vui lòng đăng xuất và đăng nhập lại để đổi mật khẩu.');
        case 'too-many-requests':
          throw Exception('Bạn thao tác quá nhiều lần. Vui lòng thử lại sau.');
        default:
          throw Exception(e.message ?? 'Không thể đổi mật khẩu.');
      }
    }
  }

  // Đăng xuất
  Future<void> logout() async {
    await _auth.signOut();
  }

  // Gửi email xác minh lại
  Future<void> sendVerificationEmail() async {
    await _auth.currentUser?.sendEmailVerification();
  }

  // Tải lại trạng thái xác minh từ Firebase
  Future<void> reloadUser() async {
    await _auth.currentUser?.reload();
  }

  // Quên mật khẩu
  Future<void> resetPassword(String email) async {
    await _auth.sendPasswordResetEmail(email: email.trim());
  }
}