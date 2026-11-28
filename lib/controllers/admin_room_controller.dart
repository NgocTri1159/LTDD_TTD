import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/room_model.dart';

class AdminRoomController {
  AdminRoomController._();
  static final AdminRoomController instance = AdminRoomController._();

  final SupabaseClient _supabase = Supabase.instance.client;

  Future<List<RoomModel>> fetchAllRooms() async {
    const selectQuery =
        '*, de_thi(tieu_de, mon_hoc(ten_mon)), phong_thi_thanh_vien(id)';

    dynamic data;
    try {
      data = await _supabase
          .from('phong_thi')
          .select(selectQuery)
          .order('created_at', ascending: false);
    } catch (_) {
      // Fallback nếu bảng phong_thi chưa có cột created_at
      data = await _supabase
          .from('phong_thi')
          .select(selectQuery)
          .order('id', ascending: false);
    }

    final List<RoomModel> result = [];
    if (data is List) {
      for (final dynamic item in data) {
        if (item is Map<String, dynamic>) {
          result.add(RoomModel.fromMap(item));
        }
      }
    }
    return result;
  }

  Future<RoomModel?> fetchRoomDetail(String roomId) async {
    final Map<String, dynamic>? row = await _supabase
        .from('phong_thi')
        .select(
          '*, de_thi(tieu_de, mon_hoc(ten_mon)), phong_thi_thanh_vien(id)',
        )
        .eq('id', roomId)
        .maybeSingle();

    if (row == null) return null;
    return RoomModel.fromMap(row);
  }

  Future<void> updateRoomConfig({
    required String roomId,
    String? tenPhong,
    String? deThiId,
    String? cheDo,
    bool? phongRieng,
    int? gioiHan,
  }) async {
    final Map<String, dynamic> payload = {};
    if (tenPhong != null) payload['ten_phong'] = tenPhong.trim();
    if (deThiId != null) payload['de_thi_id'] = deThiId;
    if (cheDo != null) payload['che_do'] = cheDo;
    if (phongRieng != null) payload['phong_rieng'] = phongRieng;
    if (gioiHan != null) payload['gioi_han'] = gioiHan;

    if (payload.isEmpty) return;
    await _supabase.from('phong_thi').update(payload).eq('id', roomId);
  }

  Future<void> toggleHideRoom(String roomId, bool hide) async {
    await _supabase
        .from('phong_thi')
        .update({'da_an': hide})
        .eq('id', roomId);
  }

  Future<void> deleteRoom(String roomId) async {
    await _supabase.from('phong_thi').delete().eq('id', roomId);
  }

  Stream<List<RoomParticipantModel>> watchParticipants(String roomId) {
    return _supabase
        .from('phong_thi_thanh_vien')
        .stream(primaryKey: ['id'])
        .eq('phong_thi_id', roomId)
        .map(
          (rows) => rows.map((e) => RoomParticipantModel.fromMap(e)).toList(),
        );
  }

  Future<void> toggleParticipantReady(String memberId, bool ready) async {
    await _supabase
        .from('phong_thi_thanh_vien')
        .update({'san_sang': ready})
        .eq('id', memberId);
  }

  Future<void> setRoomHost({
    required String roomId,
    required RoomParticipantModel newHost,
  }) async {
    await _supabase
        .from('phong_thi_thanh_vien')
        .update({'la_chu_phong': false})
        .eq('phong_thi_id', roomId);

    await _supabase
        .from('phong_thi_thanh_vien')
        .update({'la_chu_phong': true})
        .eq('id', newHost.id);

    await _supabase.from('phong_thi').update({
      'chu_phong_id': newHost.userId,
      'ten_chu_phong': newHost.tenHienThi,
    }).eq('id', roomId);
  }

  Future<void> kickParticipant(String memberId) async {
    await _supabase.from('phong_thi_thanh_vien').delete().eq('id', memberId);
  }

  Future<List<RoomExamOption>> fetchExamOptions() async {
    final dynamic data = await _supabase
        .from('de_thi')
        .select('id, tieu_de, mon_hoc(ten_mon), de_thi_cau_hoi(cau_hoi_id)')
        .order('tieu_de', ascending: true);

    final List<RoomExamOption> result = [];
    if (data is List) {
      for (final dynamic item in data) {
        if (item is Map<String, dynamic>) {
          final dynamic mon = item['mon_hoc'];
          final dynamic links = item['de_thi_cau_hoi'];
          result.add(
            RoomExamOption(
              id: item['id'].toString(),
              tieuDe: (item['tieu_de'] ?? 'Bộ đề trắc nghiệm').toString(),
              tenMon: mon is Map
                  ? (mon['ten_mon'] ?? 'Tổng hợp').toString()
                  : 'Tổng hợp',
              soCau: links is List ? links.length : 0,
            ),
          );
        }
      }
    }
    return result;
  }
}