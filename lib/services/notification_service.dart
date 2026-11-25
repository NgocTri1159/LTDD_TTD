import 'package:firebase_auth/firebase_auth.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/notification_model.dart';
import 'supabase_service.dart';

/// Service quản lý Thông báo cá nhân và hệ thống.
class NotificationService {
  static SupabaseClient get _supabase => SupabaseService.client;
  static String? get _currentUserId => FirebaseAuth.instance.currentUser?.uid;

  /// Lấy danh sách thông báo của người dùng hiện tại
  static Future<List<NotificationModel>> getUserNotifications({int limit = 30}) async {
    final uid = _currentUserId;
    if (uid == null) return [];

    try {
      final response = await _supabase
          .from('thong_bao')
          .select()
          .eq('nguoi_dung_id', uid)
          .order('ngay_tao', ascending: false)
          .limit(limit);

      return (response as List)
          .map((item) => NotificationModel.fromJson(Map<String, dynamic>.from(item as Map)))
          .toList();
    } on PostgrestException catch (e) {
      throw Exception('Lỗi tải thông báo: ${e.message}');
    } catch (e) {
      throw Exception('Không thể tải thông báo: $e');
    }
  }

  /// Đánh dấu một thông báo là đã đọc
  static Future<void> markAsRead(String notificationId) async {
    try {
      await _supabase
          .from('thong_bao')
          .update({'da_doc': true})
          .eq('id', notificationId);
    } catch (e) {
      // Bỏ qua lỗi ngầm để không ngắt trải nghiệm người dùng
    }
  }

  /// Đánh dấu tất cả thông báo của người dùng là đã đọc
  static Future<void> markAllAsRead() async {
    final uid = _currentUserId;
    if (uid == null) return;

    try {
      await _supabase
          .from('thong_bao')
          .update({'da_doc': true})
          .eq('nguoi_dung_id', uid)
          .eq('da_doc', false);
    } catch (e) {
      throw Exception('Không thể cập nhật trạng thái thông báo: $e');
    }
  }

  /// Đếm số thông báo chưa đọc
  static Future<int> getUnreadCount() async {
    final uid = _currentUserId;
    if (uid == null) return 0;

    try {
      final count = await _supabase
          .from('thong_bao')
          .count(CountOption.exact)
          .eq('nguoi_dung_id', uid)
          .eq('da_doc', false);

      return count;
    } catch (e) {
      return 0;
    }
  }
}
