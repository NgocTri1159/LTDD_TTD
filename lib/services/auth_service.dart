
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

      // Debug
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

  // Đăng nhập
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
        // Kiểm tra claim hiện tại
        var tokenResult = await user.getIdTokenResult(true);

        // Nếu chưa có claim authenticated thì gọi Backend cấp quyền
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
