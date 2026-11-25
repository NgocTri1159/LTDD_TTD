import 'package:firebase_auth/firebase_auth.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Lỗi khi tài khoản đã bị khóa
class AccountLockedException implements Exception {
  final String message;

  AccountLockedException([
    this.message =
        'Tài khoản của bạn đã bị khóa. Vui lòng liên hệ quản trị viên.',
  ]);

  @override
  String toString() => message;
}

// Lỗi khi không tìm thấy hồ sơ
class AccountProfileNotFoundException implements Exception {
  final String message;

  AccountProfileNotFoundException([
    this.message = 'Không tìm thấy hồ sơ người dùng trong hệ thống.',
  ]);

  @override
  String toString() => message;
}

class RoleService {
  static final SupabaseClient _supabase = Supabase.instance.client;

  // Kiểm tra trạng thái tài khoản và lấy vai trò hiện tại
  static Future<String> getCurrentRole() async {
    final firebaseUser = FirebaseAuth.instance.currentUser;

    if (firebaseUser == null) {
      throw Exception('Bạn chưa đăng nhập.');
    }

    // Đảm bảo Supabase sử dụng Firebase ID Token hiện tại
    await firebaseUser.getIdToken();

    // Gọi RPC kiểm tra trạng thái tài khoản
    final response = await _supabase.rpc('check_account_access');

    if (response is! List || response.isEmpty) {
      throw AccountProfileNotFoundException();
    }

    final result = Map<String, dynamic>.from(response.first as Map);

    final accountExists = result['account_exists'] == true;
    final accountActive = result['account_active'] == true;
    final role = result['account_role'] as String?;

    // Không tìm thấy hồ sơ
    if (!accountExists) {
      throw AccountProfileNotFoundException();
    }

    // Tài khoản đã bị khóa
    if (!accountActive) {
      throw AccountLockedException();
    }

    // Kiểm tra vai trò
    if (role != 'super_admin' && role != 'admin' && role != 'user') {
      throw Exception('Vai trò tài khoản không hợp lệ.');
    }

    return role!;
  }

  // Kiểm tra Super Admin
  static Future<bool> isSuperAdmin() async {
    return await getCurrentRole() == 'super_admin';
  }

  // Kiểm tra Admin hoặc Super Admin
  static Future<bool> isAdmin() async {
    final role = await getCurrentRole();
    return role == 'admin' || role == 'super_admin';
  }

  // Kiểm tra Admin thông thường
  static Future<bool> isNormalAdmin() async {
    return await getCurrentRole() == 'admin';
  }

  // Kiểm tra User thông thường
  static Future<bool> isUser() async {
    return await getCurrentRole() == 'user';
  }
}
