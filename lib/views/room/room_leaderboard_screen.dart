import 'package:flutter/material.dart';
import '../../controllers/room_controller.dart';
import '../../models/room_model.dart';

class RoomLeaderboardScreen extends StatelessWidget {
  final RoomModel room;
  const RoomLeaderboardScreen({super.key, required this.room});

  static const Color _navy = Color(0xFF1E293B);

  String _formatDuration(int sec) {
    final m = (sec ~/ 60).toString().padLeft(2, '0');
    final s = (sec % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final isHost = room.chuPhongId == RoomController.instance.currentUserId;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Bảng xếp hạng trực tiếp',
          style: TextStyle(color: _navy, fontWeight: FontWeight.w700, fontSize: 17),
        ),
        iconTheme: const IconThemeData(color: _navy),
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _navy,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                Text(
                  room.tenPhong,
                  style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(
                  'Mã phòng: ${room.maPhong} • Cập nhật tự động',
                  style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                ),
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<List<RoomParticipantModel>>(
              stream: RoomController.instance.watchParticipants(room.id),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final players = List<RoomParticipantModel>.from(snapshot.data ?? []);

                players.sort((a, b) {
                  final aDone = a.trangThai == 'finished' ? 0 : 1;
                  final bDone = b.trangThai == 'finished' ? 0 : 1;
                  if (aDone != bDone) return aDone.compareTo(bDone);

                  final scoreCmp = b.diemSo.compareTo(a.diemSo);
                  if (scoreCmp != 0) return scoreCmp;

                  return a.thoiGianGiay.compareTo(b.thoiGianGiay);
                });

                return ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: players.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (_, index) {
                    final p = players[index];
                    final finished = p.trangThai == 'finished';
                    final isMe = p.userId == RoomController.instance.currentUserId;

                    Color badgeBg = const Color(0xFFF1F5F9);
                    Color badgeText = _navy;
                    if (index == 0 && finished) {
                      badgeBg = const Color(0xFFFEF3C7);
                      badgeText = const Color(0xFFB45309);
                    } else if (index == 1 && finished) {
                      badgeBg = const Color(0xFFE2E8F0);
                      badgeText = const Color(0xFF334155);
                    } else if (index == 2 && finished) {
                      badgeBg = const Color(0xFFFFEDD5);
                      badgeText = const Color(0xFFC2410C);
                    }

                    return Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isMe ? const Color(0xFF4F46E5) : const Color(0xFFE2E8F0),
                          width: isMe ? 1.5 : 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(color: badgeBg, shape: BoxShape.circle),
                            child: Text(
                              '#${index + 1}',
                              style: TextStyle(fontWeight: FontWeight.w800, color: badgeText),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${p.tenHienThi}${isMe ? ' (Bạn)' : ''}',
                                  style: const TextStyle(fontWeight: FontWeight.w700, color: _navy),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  finished
                                      ? 'Đúng ${p.soCauDung}/${p.tongSoCau} • ${_formatDuration(p.thoiGianGiay)}'
                                      : 'Đang làm bài...',
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    color: finished ? const Color(0xFF64748B) : const Color(0xFF4F46E5),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            finished ? '${p.diemSo} đ' : '--',
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: _navy),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: () async {
                    if (isHost) {
                      await RoomController.instance.finishRoom(room.id);
                    }
                    if (context.mounted) Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _navy,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text(
                    isHost ? 'Kết thúc & đóng phòng' : 'Quay lại màn hình Phòng',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}