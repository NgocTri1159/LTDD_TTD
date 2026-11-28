import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../controllers/room_controller.dart';
import '../../models/room_model.dart';
import 'room_quiz_screen.dart';

class RoomLobbyScreen extends StatefulWidget {
  final RoomModel initialRoom;
  const RoomLobbyScreen({super.key, required this.initialRoom});

  @override
  State<RoomLobbyScreen> createState() => _RoomLobbyScreenState();
}

class _RoomLobbyScreenState extends State<RoomLobbyScreen> {
  static const Color _navy = Color(0xFF1E293B);

  late RoomModel _room;
  Map<String, String> _examMeta = {'tieu_de': 'Đang tải đề...', 'ten_mon': 'Tổng hợp'};
  StreamSubscription<RoomModel?>? _roomSub;
  bool _navigated = false;
  bool _isStarting = false;

  bool get _isHost => _room.chuPhongId == RoomController.instance.currentUserId;

  @override
  void initState() {
    super.initState();
    _room = widget.initialRoom;
    _loadExamMeta();
    _listenRoomStatus();
  }

  @override
  void dispose() {
    _roomSub?.cancel();
    super.dispose();
  }

  Future<void> _loadExamMeta() async {
    final meta = await RoomController.instance.fetchExamMeta(_room.deThiId);
    if (mounted) setState(() => _examMeta = meta);
  }

  void _listenRoomStatus() {
    _roomSub = RoomController.instance.watchRoom(_room.id).listen((updated) {
      if (!mounted || updated == null) return;
      setState(() => _room = updated);

      if (updated.trangThai == 'playing' && !_navigated) {
        _navigated = true;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => RoomQuizScreen(
              room: updated,
              tenDeThi: _examMeta['tieu_de'] ?? updated.tenPhong,
              monHoc: _examMeta['ten_mon'] ?? 'Tổng hợp',
            ),
          ),
        );
      } else if (updated.trangThai == 'cancelled' && !_navigated) {
        _navigated = true;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Chủ phòng đã hủy phòng thi này.')),
        );
        Navigator.pop(context);
      }
    });
  }

  Future<void> _handleStart() async {
    setState(() => _isStarting = true);
    try {
      await RoomController.instance.startRoom(_room.id);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Không thể bắt đầu: $e')),
      );
      setState(() => _isStarting = false);
    }
  }

  Future<void> _handleExit() async {
    if (_isHost) {
      await RoomController.instance.cancelRoom(_room.id);
    } else {
      await RoomController.instance.leaveRoom(_room.id);
    }
    if (mounted && !_navigated) {
      _navigated = true;
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          _room.tenPhong,
          style: const TextStyle(color: _navy, fontWeight: FontWeight.w700, fontSize: 17),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: _navy),
          onPressed: _handleExit,
        ),
      ),
      body: Column(
        children: [
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: _navy,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Column(
              children: [
                const Text(
                  'MÃ PHÒNG THI',
                  style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12, letterSpacing: 1.5),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      _room.maPhong,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 32,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 6,
                      ),
                    ),
                    const SizedBox(width: 10),
                    IconButton(
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: _room.maPhong));
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Đã sao chép mã phòng: ${_room.maPhong}')),
                        );
                      },
                      icon: const Icon(Icons.copy_rounded, color: Colors.white),
                      tooltip: 'Sao chép mã',
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  '${_examMeta['tieu_de']} • ${_room.thoiGianPhut} phút',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Color(0xFFCBD5E1), fontSize: 13.5),
                ),
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<List<RoomParticipantModel>>(
              stream: RoomController.instance.watchParticipants(_room.id),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final members = snapshot.data ?? [];
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      child: Text(
                        'Người tham gia (${members.length})',
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: _navy),
                      ),
                    ),
                    Expanded(
                      child: ListView.separated(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                        itemCount: members.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (_, index) {
                          final m = members[index];
                          final isMe = m.userId == RoomController.instance.currentUserId;
                          final firstChar =
                              m.tenHienThi.isNotEmpty ? m.tenHienThi[0].toUpperCase() : 'U';
                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isMe ? const Color(0xFF4F46E5) : const Color(0xFFE2E8F0),
                              ),
                            ),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  backgroundColor: const Color(0xFFEEF2FF),
                                  child: Text(
                                    firstChar,
                                    style: const TextStyle(
                                      color: Color(0xFF4F46E5),
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    '${m.tenHienThi}${isMe ? ' (Bạn)' : ''}',
                                    style: const TextStyle(fontWeight: FontWeight.w600, color: _navy),
                                  ),
                                ),
                                if (m.laChuPhong)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFFEF3C7),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: const Text(
                                      'Chủ phòng',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFFB45309),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: _isHost
                  ? SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton.icon(
                        onPressed: _isStarting ? null : _handleStart,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _navy,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        icon: _isStarting
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Icon(Icons.play_arrow_rounded),
                        label: Text(
                          _isStarting ? 'Đang bắt đầu...' : 'Bắt đầu thi ngay',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                        ),
                      ),
                    )
                  : Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEEF2FF),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                          SizedBox(width: 10),
                          Text(
                            'Đang chờ chủ phòng bắt đầu...',
                            style: TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF4F46E5)),
                          ),
                        ],
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}