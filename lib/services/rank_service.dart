import 'package:material_ui/material_ui.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide User;

class RankUpdateResult {
  final String oldRank;
  final String newRank;
  final int oldPoints;
  final int newPoints;
  final int delta;

  const RankUpdateResult({
    required this.oldRank,
    required this.newRank,
    required this.oldPoints,
    required this.newPoints,
    required this.delta,
  });

  bool get isPromoted => _rankOrder(newRank) > _rankOrder(oldRank);
  bool get isDemoted => _rankOrder(newRank) < _rankOrder(oldRank);

  static int _rankOrder(String rank) {
    switch (rank.toUpperCase()) {
      case 'ĐỒNG':
        return 1;
      case 'BẠC':
        return 2;
      case 'VÀNG':
        return 3;
      case 'BẠCH KIM':
        return 4;
      case 'KIM CƯƠNG':
        return 5;
      default:
        return 0;
    }
  }
}

class RankService {
  static final SupabaseClient _supabase = Supabase.instance.client;

  /// Quy đổi điểm sang tên bậc hạng
  static String getRankFromPoints(int points) {
    if (points >= 700) return 'KIM CƯƠNG';
    if (points >= 450) return 'BẠCH KIM';
    if (points >= 250) return 'VÀNG';
    if (points >= 100) return 'BẠC';
    return 'ĐỒNG';
  }

  /// Màu sắc hiển thị theo từng bậc hạng
  static Color getRankColor(String rank) {
    switch (rank.trim().toUpperCase()) {
      case 'KIM CƯƠNG':
        return const Color(0xFF7C4DFF);
      case 'BẠCH KIM':
        return const Color(0xFF26A69A);
      case 'VÀNG':
        return const Color(0xFFFFCA28);
      case 'BẠC':
        return const Color(0xFF00C2FF);
      case 'ĐỒNG':
      default:
        return const Color(0xFFD98A4E);
    }
  }

  /// Cập nhật điểm sau trận đấu xếp hạng
  /// Mặc định: Thắng +25 điểm, Thua -15 điểm (tối thiểu 0 điểm)
  static Future<RankUpdateResult?> updateMatchResult({
    required bool isWin,
    int winPoints = 25,
    int losePoints = 15,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;

    // 1. Lấy điểm & hạng hiện tại trên Supabase
    Map<String, dynamic>? row = await _supabase
        .from('nguoi_dung')
        .select('uid, email, diem_rank, hang')
        .eq('uid', user.uid)
        .maybeSingle();

    if (row == null && user.email != null) {
      row = await _supabase
          .from('nguoi_dung')
          .select('uid, email, diem_rank, hang')
          .ilike('email', user.email!)
          .maybeSingle();
    }

    final int oldPoints =
        int.tryParse((row?['diem_rank'] ?? 0).toString()) ?? 0;
    final String oldRank =
        (row?['hang'] ?? getRankFromPoints(oldPoints)).toString().toUpperCase();

    // 2. Tính điểm mới (không để âm dưới 0)
    final int delta = isWin ? winPoints : -losePoints;
    final int newPoints = (oldPoints + delta).clamp(0, 999999);
    final String newRank = getRankFromPoints(newPoints);

    // 3. Lưu lại lên Supabase
    final payload = {
      'diem_rank': newPoints,
      'hang': newRank,
    };

    final updated = await _supabase
        .from('nguoi_dung')
        .update(payload)
        .eq('uid', user.uid)
        .select();

    if (updated.isEmpty && user.email != null) {
      await _supabase
          .from('nguoi_dung')
          .update(payload)
          .ilike('email', user.email!);
    }

    return RankUpdateResult(
      oldRank: oldRank,
      newRank: newRank,
      oldPoints: oldPoints,
      newPoints: newPoints,
      delta: newPoints - oldPoints,
    );
  }
}