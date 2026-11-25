import 'package:supabase_flutter/supabase_flutter.dart';

class UserManagementService {
  static final SupabaseClient _supabase = Supabase.instance.client;

  static Future<List<Map<String, dynamic>>> getAllUsers() async {
    try {
      final response = await _supabase
          .from('nguoi_dung')
          .select('id, email, ho_ten, vai_tro, trang_thai, ngay_tao')
          .order('ngay_tao', ascending: false);

      return List<Map<String, dynamic>>.from(response);
    } on PostgrestException catch (e) {
      throw Exception('Không thể tải danh sách người dùng: ${e.message}');
    } catch (e) {
      throw Exception('Đã xảy ra lỗi khi tải người dùng: $e');
    }
  }

  // Khóa hoặc mở khóa tài khoản.
  // Quyền thực tế được kiểm tra tại PostgreSQL RPC.
  static Future<void> setUserStatus({
    required String userId,
    required bool isActive,
  }) async {
    try {
      await _supabase.rpc(
        'admin_set_user_status',
        params: {'target_user_id': userId, 'new_status': isActive},
      );
    } on PostgrestException catch (e) {
      throw Exception(e.message);
    } catch (e) {
      throw Exception('Không thể cập nhật trạng thái tài khoản: $e');
    }
  }

  // Chỉ Super Admin có thể thay đổi vai trò.
  static Future<void> setUserRole({
    required String userId,
    required String role,
  }) async {
    try {
      if (role != 'admin' && role != 'user') {
        throw Exception('Vai trò không hợp lệ.');
      }

      await _supabase.rpc(
        'super_admin_set_user_role',
        params: {'target_user_id': userId, 'new_role': role},
      );
    } on PostgrestException catch (e) {
      throw Exception(e.message);
    } catch (e) {
      throw Exception('Không thể thay đổi vai trò: $e');
    }
  }
}
