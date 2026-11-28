import 'dart:core';
import 'dart:core' as core;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/exam_model.dart';
import '../quiz/quiz_taking_screen.dart';

class RoomLobbyScreen extends StatefulWidget {
  final core.Map<String, dynamic> roomData;

  const RoomLobbyScreen({
    super.key,
    required this.roomData,
  });

  @override
  State<RoomLobbyScreen> createState() => _RoomLobbyScreenState();
}

class _RoomLobbyScreenState extends State<RoomLobbyScreen> {
  static const Color primaryPurple = Color(0xFF565CEB);
  static const Color accentOrange = Color(0xFFF79E1B);
  static const Color readyGreen = Color(0xFF34C759);
  static const Color notReadyYellow = Color(0xFFF5B82E);
  static const Color disabledGrey = Color(0xFFBDBDBD);
  static const Color darkText = Color(0xFF1E1E2C);

  final SupabaseClient _supabase = Supabase.instance.client;
  RealtimeChannel? _roomChannel;

  late core.Map<String, dynamic> _room;
  core.List<core.Map<String, dynamic>> _participants = [];
  String _modeName = 'Đấu đơn trực tuyến';

  bool _isLoading = true;
  bool _isSubmitting = false;
  bool _isNavigating = false;

  String get _currentUid => FirebaseAuth.instance.currentUser?.uid ?? '';
  String get _roomId => _room['id']?.toString() ?? '';
  String get _roomCode => _room['ma_phong']?.toString() ?? '000000';
  int get _maxPlayers => (_room['so_nguoi_toi_da'] as num?)?.toInt() ?? 8;
  bool get _isHost => _room['chu_phong_id']?.toString() == _currentUid;

  @override
  void initState() {
    super.initState();
    _room = core.Map<String, dynamic>.from(widget.roomData);
    _initLobby();
  }

  @override
  void dispose() {
    if (_roomChannel != null) {
      _supabase.removeChannel(_roomChannel!);
    }
    super.dispose();
  }

  core.Future<void> _initLobby() async {
    await _ensureCurrentUserInRoom();
    await _fetchRoomDetailsAndPlayers();
    _subscribeRealtime();
  }

  core.Future<void> _ensureCurrentUserInRoom() async {
    if (_currentUid.isEmpty || _roomId.isEmpty) return;
    try {
      // Đồng bộ ảnh đại diện từ Firebase Auth sang bảng nguoi_dung nếu có
      final firebasePhoto =
          (FirebaseAuth.instance.currentUser?.photoURL ?? '').trim();
      if (firebasePhoto.isNotEmpty) {
        try {
          await _supabase
              .from('nguoi_dung')
              .update({'anh_dai_dien_url': firebasePhoto})
              .eq('id', _currentUid);
        } catch (_) {
          // Bỏ qua nếu tên cột khác, tránh chặn luồng vào phòng
        }
      }

      await _supabase.from('thanh_vien_phong').upsert(
        {
          'phong_id': _roomId,
          'nguoi_dung_id': _currentUid,
          'san_sang': _isHost,
        },
        onConflict: 'phong_id,nguoi_dung_id',
      );
    } catch (e) {
      debugPrint('ENSURE PARTICIPANT ERROR: $e');
      if (mounted) {
        _showSnack('Lỗi thêm người chơi vào phòng: $e', isError: true);
      }
    }
  }

  core.Future<void> _fetchRoomDetailsAndPlayers() async {
    try {
      final roomRes = await _supabase
          .from('phong_thi')
          .select(
            '*, che_do_choi:che_do_choi_id(ten_che_do), '
            'de_thi:de_thi_id(*, mon_hoc:mon_hoc_id(ten_mon))',
          )
          .eq('id', _roomId)
          .maybeSingle();

      if (roomRes != null) {
        _room = core.Map<String, dynamic>.from(roomRes);
        final modeObj = _room['che_do_choi'];
        if (modeObj is core.Map && modeObj['ten_che_do'] != null) {
          _modeName = modeObj['ten_che_do'].toString();
        }
      }

      final membersRes = await _supabase
          .from('thanh_vien_phong')
          .select(
            'id, phong_id, nguoi_dung_id, san_sang, '
            'nguoi_dung:nguoi_dung_id(*)',
          )
          .eq('phong_id', _roomId)
          .order('ngay_tham_gia', ascending: true);

      final list =
          core.List<core.Map<String, dynamic>>.from(membersRes as core.List);

      list.sort((a, b) {
        final aHost = a['nguoi_dung_id']?.toString() == _room['chu_phong_id'];
        final bHost = b['nguoi_dung_id']?.toString() == _room['chu_phong_id'];
        if (aHost && !bHost) return -1;
        if (!aHost && bHost) return 1;
        return 0;
      });

      if (!mounted) return;
      setState(() {
        _participants = list;
        _isLoading = false;
      });

      if (_room['trang_thai'] == 'dang_thi') {
        await _navigateToQuizScreen();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      debugPrint('FETCH LOBBY ERROR: $e');
      _showSnack('Lỗi tải danh sách người chơi: $e', isError: true);
    }
  }

  void _subscribeRealtime() {
    if (_roomId.isEmpty) return;

    _roomChannel = _supabase
        .channel('lobby:$_roomId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'thanh_vien_phong',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'phong_id',
            value: _roomId,
          ),
          callback: (_) => _fetchRoomDetailsAndPlayers(),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'phong_thi',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'id',
            value: _roomId,
          ),
          callback: (payload) async {
            final updated = payload.newRecord;
            if (!mounted) return;
            setState(() => _room.addAll(updated));

            if (updated['trang_thai'] == 'dang_thi') {
              await _navigateToQuizScreen();
            } else if (updated['trang_thai'] == 'da_huy') {
              _showSnack('Chủ phòng đã giải tán phòng.', isError: true);
              Navigator.pop(context);
            }
          },
        )
        .subscribe();
  }

  bool get _myReadyStatus {
    final me = _participants.where(
      (p) => p['nguoi_dung_id']?.toString() == _currentUid,
    );
    if (me.isEmpty) return false;
    return me.first['san_sang'] == true;
  }

  bool get _canHostStart {
    if (_participants.length < 2) return false;
    return _participants.every((p) => p['san_sang'] == true);
  }

  core.Future<void> _toggleReady() async {
    if (_isSubmitting) return;
    setState(() => _isSubmitting = true);

    try {
      final nextState = !_myReadyStatus;
      await _supabase
          .from('thanh_vien_phong')
          .update({'san_sang': nextState})
          .eq('phong_id', _roomId)
          .eq('nguoi_dung_id', _currentUid);

      await _fetchRoomDetailsAndPlayers();
    } catch (e) {
      _showSnack('Không thể cập nhật trạng thái: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  core.Future<void> _startMatch() async {
    if (!_isHost || !_canHostStart || _isSubmitting) return;
    setState(() => _isSubmitting = true);

    try {
      await _supabase
          .from('phong_thi')
          .update({'trang_thai': 'dang_thi'}).eq('id', _roomId);
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        _showSnack('Lỗi khi bắt đầu cuộc thi: $e', isError: true);
      }
    }
  }

  core.Future<void> _navigateToQuizScreen() async {
    if (_isNavigating) return;
    _isNavigating = true;

    try {
      core.Map<String, dynamic>? examData;

      if (_room['de_thi'] is core.Map) {
        examData = core.Map<String, dynamic>.from(_room['de_thi'] as core.Map);
      } else {
        final examId = _room['de_thi_id']?.toString();
        if (examId != null && examId.isNotEmpty) {
          final res = await _supabase
              .from('de_thi')
              .select('*, mon_hoc:mon_hoc_id(ten_mon)')
              .eq('id', examId)
              .maybeSingle();
          if (res != null) {
            examData = core.Map<String, dynamic>.from(res);
          }
        }
      }

      if (!mounted || examData == null) {
        _isNavigating = false;
        return;
      }

      final examModel = ExamModel.fromJson(examData);

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => QuizTakingScreen(exam: examModel),
        ),
      );
    } catch (e) {
      _isNavigating = false;
      debugPrint('NAVIGATE TO QUIZ ERROR: $e');
    }
  }

  core.Future<void> _handleLeaveRoom() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text(_isHost ? 'Giải tán phòng?' : 'Rời khỏi phòng?'),
        content: Text(
          _isHost
              ? 'Bạn là chủ phòng. Nếu thoát, phòng chờ này sẽ bị đóng.'
              : 'Bạn có chắc muốn rời khỏi phòng thi này không?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Ở lại'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE53935),
              foregroundColor: Colors.white,
            ),
            child: Text(_isHost ? 'Giải tán' : 'Rời phòng'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      if (_isHost) {
        // 1. Xóa toàn bộ thành viên trong phòng để DS phòng lập tức ẩn phòng này
        await _supabase
            .from('thanh_vien_phong')
            .delete()
            .eq('phong_id', _roomId);

        // 2. Cập nhật trạng thái phòng thành đã hủy
        await _supabase
            .from('phong_thi')
            .update({'trang_thai': 'da_huy'})
            .eq('id', _roomId);
      } else {
        await _supabase
            .from('thanh_vien_phong')
            .delete()
            .eq('phong_id', _roomId)
            .eq('nguoi_dung_id', _currentUid);
      }

      if (mounted) Navigator.pop(context);
    } catch (e) {
      debugPrint('LEAVE ROOM ERROR: $e');
      if (mounted) {
        _showSnack('Không thể giải tán/rời phòng: $e', isError: true);
      }
    }
  }

  void _copyRoomCode() {
    Clipboard.setData(ClipboardData(text: _roomCode));
    _showSnack('Đã sao chép mã phòng: $_roomCode');
  }

  void _showSnack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? const Color(0xFFD32F2F) : darkText,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  String _formatPlayerName(core.Map<String, dynamic> member) {
    final userObj = member['nguoi_dung'];
    if (userObj is core.Map) {
      final display = (userObj['ten_hien_thi'] ?? userObj['ho_ten'])
          ?.toString()
          .trim();
      if (display != null && display.isNotEmpty) return display;

      final email = userObj['email']?.toString().trim();
      if (email != null && email.contains('@')) return email.split('@').first;
    }
    final uid = member['nguoi_dung_id']?.toString() ?? 'Player';
    return 'Player${uid.length > 5 ? uid.substring(0, 5) : uid}';
  }

  @override
  Widget build(BuildContext context) {
    final statusText =
        _room['trang_thai'] == 'dang_thi' ? 'Đang thi...' : 'Đang chờ...';
    final emptySlots = (_maxPlayers - _participants.length).clamp(0, 3);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _handleLeaveRoom();
      },
      child: Scaffold(
        backgroundColor: primaryPurple,
        appBar: AppBar(
          backgroundColor: primaryPurple,
          elevation: 0,
          centerTitle: true,
          leading: IconButton(
            icon: const Icon(
              Icons.arrow_back_rounded,
              color: Colors.white,
              size: 23,
            ),
            onPressed: _handleLeaveRoom,
          ),
          title: const Text(
            'Phòng thi trực tuyến',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 18,
              letterSpacing: 0.2,
            ),
          ),
          actions: [
            IconButton(
              icon: const Icon(
                Icons.share_rounded,
                color: Colors.white,
                size: 21,
              ),
              tooltip: 'Chia sẻ mã phòng',
              onPressed: _copyRoomCode,
            ),
          ],
        ),
        body: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: Colors.white),
              )
            : Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 412),
                  child: Column(
                    children: [
                      // 1. Thẻ thông tin phòng giống thiết kế Figma
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                        child: _buildRoomInfoCard(statusText),
                      ),
                      const SizedBox(height: 22),

                      // 2. Tiêu đề danh sách người chơi
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 22),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'Danh sách người chơi (${_participants.length}/$_maxPlayers)',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),

                      // 3. Danh sách người chơi + slot trống
                      Expanded(
                        child: ListView.separated(
                          padding: const EdgeInsets.fromLTRB(22, 0, 22, 16),
                          itemCount: _participants.length + emptySlots,
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: 14),
                          itemBuilder: (_, index) {
                            if (index < _participants.length) {
                              return _buildPlayerRow(_participants[index]);
                            }
                            return _buildEmptySlotRow();
                          },
                        ),
                      ),

                      // 4. Nút hành động dạng viên thuốc căn giữa
                      SafeArea(
                        top: false,
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(24, 6, 24, 28),
                          child: _buildBottomActionArea(),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildRoomInfoCard(String statusText) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.14),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          const Icon(
            Icons.sports_esports_rounded,
            color: darkText,
            size: 32,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'Mã phòng: $_roomCode',
                      style: const TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w800,
                        color: darkText,
                      ),
                    ),
                    const SizedBox(width: 6),
                    InkWell(
                      onTap: _copyRoomCode,
                      borderRadius: BorderRadius.circular(6),
                      child: const Padding(
                        padding: EdgeInsets.all(3),
                        child: Icon(
                          Icons.copy_rounded,
                          size: 16,
                          color: Color(0xFF4B506D),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                RichText(
                  text: TextSpan(
                    style: const TextStyle(
                      fontSize: 12.5,
                      color: Color(0xFF4B506D),
                    ),
                    children: [
                      const TextSpan(text: 'Chế độ: '),
                      TextSpan(
                        text: _modeName,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          color: darkText,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 2),
                RichText(
                  text: TextSpan(
                    style: const TextStyle(
                      fontSize: 12.5,
                      color: Color(0xFF4B506D),
                    ),
                    children: [
                      const TextSpan(text: 'Trạng thái: '),
                      TextSpan(
                        text: statusText,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          color: darkText,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlayerRow(core.Map<String, dynamic> member) {
    final uid = member['nguoi_dung_id']?.toString() ?? '';
    final isRoomHost = uid == _room['chu_phong_id']?.toString();
    final isReady = member['san_sang'] == true;
    final name = _formatPlayerName(member);

    final userObj = member['nguoi_dung'];
    String avatarUrl = '';

    if (userObj is core.Map) {
      avatarUrl = (userObj['anh_dai_dien_url'] ??
              userObj['anh_dai_dien'] ??
              userObj['avatar_url'] ??
              userObj['photo_url'] ??
              userObj['hinh_anh'] ??
              '')
          .toString()
          .trim();
    }

    // Fallback lấy trực tiếp từ FirebaseAuth nếu là chính mình
    if (avatarUrl.isEmpty && uid == _currentUid) {
      avatarUrl = (FirebaseAuth.instance.currentUser?.photoURL ?? '').trim();
    }

    return Row(
      children: [
        Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFFFFE082), Color(0xFFFFB300)],
            ),
            border: Border.all(color: Colors.white, width: 2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.14),
                blurRadius: 6,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: ClipOval(
            child: avatarUrl.isNotEmpty
                ? Image.network(
                    avatarUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => _buildInitialAvatar(name),
                  )
                : _buildInitialAvatar(name),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (isRoomHost) ...[
                const SizedBox(height: 2),
                Text(
                  '(Chủ phòng)',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.8),
                    fontSize: 11.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(width: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: isReady ? readyGreen : notReadyYellow,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.10),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Text(
            isReady ? 'Sẵn sàng' : 'Chưa sẵn sàng',
            style: TextStyle(
              color: isReady ? Colors.white : darkText,
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInitialAvatar(String name) {
    return Center(
      child: Text(
        name.isNotEmpty ? name[0].toUpperCase() : 'P',
        style: const TextStyle(
          fontWeight: FontWeight.w900,
          fontSize: 19,
          color: darkText,
        ),
      ),
    );
  }

  Widget _buildEmptySlotRow() {
    return Row(
      children: [
        Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withValues(alpha: 0.10),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.28),
              width: 1.5,
            ),
          ),
          child: Icon(
            Icons.person_add_alt_1_rounded,
            color: Colors.white.withValues(alpha: 0.55),
            size: 20,
          ),
        ),
        const SizedBox(width: 14),
        Text(
          'Đang chờ người chơi...',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.6),
            fontSize: 13.5,
            fontStyle: FontStyle.italic,
          ),
        ),
      ],
    );
  }

  Widget _buildBottomActionArea() {
    if (_isHost) {
      final enabled = _canHostStart && !_isSubmitting;
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!_canHostStart) ...[
            Text(
              _participants.length < 2
                  ? 'Cần ít nhất 2 người chơi để bắt đầu'
                  : 'Đang chờ tất cả người chơi sẵn sàng...',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.8),
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 10),
          ],
          SizedBox(
            width: 220,
            height: 46,
            child: ElevatedButton(
              onPressed: enabled ? _startMatch : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: accentOrange,
                disabledBackgroundColor: disabledGrey,
                foregroundColor: darkText,
                disabledForegroundColor: const Color(0xFF4A4A4A),
                elevation: enabled ? 4 : 0,
                shadowColor: Colors.black.withValues(alpha: 0.25),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
              ),
              child: _isSubmitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: darkText,
                      ),
                    )
                  : const Text(
                      'Bắt đầu cuộc thi',
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
            ),
          ),
        ],
      );
    }

    final isReady = _myReadyStatus;
    return SizedBox(
      width: 220,
      height: 46,
      child: ElevatedButton(
        onPressed: _isSubmitting ? null : _toggleReady,
        style: ElevatedButton.styleFrom(
          backgroundColor: isReady ? accentOrange : readyGreen,
          foregroundColor: isReady ? darkText : Colors.white,
          elevation: 4,
          shadowColor: Colors.black.withValues(alpha: 0.25),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
        ),
        child: _isSubmitting
            ? SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: isReady ? darkText : Colors.white,
                ),
              )
            : Text(
                isReady ? 'Hủy sẵn sàng' : 'Sẵn sàng',
                style: const TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
      ),
    );
  }
}