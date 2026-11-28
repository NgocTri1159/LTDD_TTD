import 'dart:math';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:material_ui/material_ui.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SessionGuardService {
  SessionGuardService._();
  static final SessionGuardService instance = SessionGuardService._();

  final SupabaseClient _supabase = Supabase.instance.client;
  RealtimeChannel? _channel;
  String? _currentToken;
  String? _listeningUid;
  bool _isKickingOut = false;

  String _generateToken() {
    final rand = Random.secure();
    final bytes = List<int>.generate(16, (_) => rand.nextInt(256));
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${DateTime.now().millisecondsSinceEpoch}_$hex';
  }

  /// Gọi hàm này ngay sau khi đăng nhập thành công hoặc trong initState của HomeScreen
  Future<void> startSession(BuildContext context) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || uid.isEmpty) return;

    // Nếu đã đăng ký phiên cho đúng user này trên tab/thiết bị hiện tại rồi thì giữ nguyên
    if (_listeningUid == uid && _currentToken != null && _channel != null) {
      return;
    }

    await stopSession();

    final newToken = _generateToken();
    _currentToken = newToken;
    _listeningUid = uid;
    _isKickingOut = false;

    try {
      // 1. Ghi đè mã phiên mới lên Supabase (vô hiệu hóa các thiết bị cũ)
      await _supabase
          .from('nguoi_dung')
          .update({'active_session_token': newToken})
          .eq('id', uid);

      // 2. Lắng nghe thay đổi trên dòng của chính user này
      _channel = _supabase
          .channel('session_guard:$uid')
          .onPostgresChanges(
            event: PostgresChangeEvent.update,
            schema: 'public',
            table: 'nguoi_dung',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'id',
              value: uid,
            ),
            callback: (payload) {
              final latestToken =
                  payload.newRecord['active_session_token']?.toString();

              if (latestToken != null &&
                  latestToken.isNotEmpty &&
                  latestToken != _currentToken &&
                  !_isKickingOut) {
                if (context.mounted) {
                  _forceLogout(context);
                }
              }
            },
          )
          .subscribe();
    } catch (e) {
      debugPrint('SESSION GUARD ERROR: $e');
    }
  }

  Future<void> _forceLogout(BuildContext context) async {
    _isKickingOut = true;
    await stopSession();
    await FirebaseAuth.instance.signOut();

    if (!context.mounted) return;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text(
          'Phiên đăng nhập hết hạn',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
        ),
        content: const Text(
          'Tài khoản của bạn vừa được đăng nhập trên một thiết bị hoặc trình duyệt khác.',
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF565CEB),
              foregroundColor: Colors.white,
            ),
            child: const Text('Đã hiểu'),
          ),
        ],
      ),
    );

    if (context.mounted) {
      // Quay về màn hình gốc (AuthWrapper / LoginScreen)
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
  }

  /// Gọi hàm này khi người dùng chủ động bấm Đăng xuất
  Future<void> stopSession() async {
    if (_channel != null) {
      await _supabase.removeChannel(_channel!);
      _channel = null;
    }
    _currentToken = null;
    _listeningUid = null;
  }
}