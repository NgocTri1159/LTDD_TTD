import 'package:firebase_auth/firebase_auth.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/user_model.dart';
import 'supabase_service.dart';

/// Model thứ hạng người dùng trên Bảng xếp hạng
class LeaderboardEntry {
  final int rank;
  final UserModel user;

  const LeaderboardEntry({
    required this.rank,
    required this.user,
  });
}

/// Service quản lý Bảng xếp hạng và Thứ hạng của người dùng.
class LeaderboardService {
  static SupabaseClient get _supabase => SupabaseService.client;
  static String? get _currentUserId => FirebaseAuth.instance.currentUser?.uid;

  /// Lấy danh sách bảng xếp hạng toàn cầu
  static Future<List<LeaderboardEntry>> getGlobalLeaderboard({int limit = 50}) async {
    try {
      final response = await _supabase
          .from('nguoi_dung')
          .select('id, email, ho_ten, anh_dai_dien_url, vai_tro, diem_kinh_nghiem, tong_diem, trang_thai, ngay_tao')
          .eq('trang_thai', true)
          .order('tong_diem', ascending: false)
          .order('diem_kinh_nghiem', ascending: false)
          .limit(limit);

      final users = (response as List)
          .map((item) => UserModel.fromJson(Map<String, dynamic>.from(item as Map)))
          .toList();

      return List.generate(
        users.length,
        (index) => LeaderboardEntry(rank: index + 1, user: users[index]),
      );
    } on PostgrestException catch (e) {
      throw Exception('Lỗi tải bảng xếp hạng: ${e.message}');
    } catch (e) {
      throw Exception('Không thể tải bảng xếp hạng: $e');
    }
  }

  /// Lấy vị trí thứ hạng của người dùng hiện tại
  static Future<LeaderboardEntry?> getCurrentUserRank() async {
    final uid = _currentUserId;
    if (uid == null) return null;

    try {
      // 1. Lấy thông tin user hiện tại
      final userResponse = await _supabase
          .from('nguoi_dung')
          .select()
          .eq('id', uid)
          .maybeSingle();

      if (userResponse == null) return null;
      final currentUser = UserModel.fromJson(Map<String, dynamic>.from(userResponse));

      // 2. Đếm số người có điểm cao hơn để xác định hạng
      final higherCount = await _supabase
          .from('nguoi_dung')
          .count(CountOption.exact)
          .eq('trang_thai', true)
          .gt('tong_diem', currentUser.tongDiem);

      return LeaderboardEntry(
        rank: higherCount + 1,
        user: currentUser,
      );
    } catch (e) {
      return null;
    }
  }
}
