import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class NotificationService {
  static final SupabaseClient _supabase = Supabase.instance.client;

  /// Hàm gửi thông báo tổng quát tới một người dùng qua email
  static Future<void> sendNotification({
    required String receiverEmail,
    required String title,
    required String content,
    String type = 'system', // 'rank', 'friend', 'room', 'system'
  }) async {
    final cleanEmail = receiverEmail.trim();
    if (cleanEmail.isEmpty) return;

    try {
      // Tìm nguoi_dung_id tương ứng (nếu có) để lưu đồng bộ
      final userRow = await _supabase
          .from('nguoi_dung')
          .select('id')
          .ilike('email', cleanEmail)
          .maybeSingle();

      await _supabase.from('thong_bao').insert({
        'nguoi_dung_id': userRow?['id'],
        'nguoi_nhan_email': cleanEmail,
        'tieu_de': title,
        'noi_dung': content,
        'loai': type,
        'da_doc': false,
      });
    } catch (e) {
      debugPrint('SEND NOTIFICATION ERROR: $e');
    }
  }

  /// Gửi thông báo khi có lời mời kết bạn mới
  static Future<void> sendFriendRequest({
    required String receiverEmail,
    required String senderName,
  }) async {
    await sendNotification(
      receiverEmail: receiverEmail,
      title: 'Lời mời kết bạn mới',
      content: '$senderName muốn kết bạn với bạn trên QuizMaster.',
      type: 'friend',
    );
  }

  /// Gửi thông báo khi đối phương chấp nhận lời mời kết bạn
  static Future<void> sendFriendAccepted({
    required String receiverEmail,
    required String accepterName,
  }) async {
    await sendNotification(
      receiverEmail: receiverEmail,
      title: 'Đã trở thành bạn bè',
      content: '$accepterName đã chấp nhận lời mời kết bạn của bạn.',
      type: 'friend',
    );
  }
}