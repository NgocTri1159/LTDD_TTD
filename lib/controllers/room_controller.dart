import 'dart:async';
import 'dart:math';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/room_model.dart';

typedef JsonMap = Map<String, dynamic>;
typedef StringMap = Map<String, String>;

class RoomController {
  RoomController._();
  static final RoomController instance = RoomController._();

  final SupabaseClient _supabase = Supabase.instance.client;
  String? _guestId;

  String get currentUserId {
    final String? uid = _supabase.auth.currentUser?.id;
    if (uid != null && uid.isNotEmpty) return uid;
    _guestId ??= 'guest_${Random().nextInt(900000) + 100000}';
    return _guestId!;
  }

  Future<String> getCurrentDisplayName() async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      return 'Khách (${currentUserId.substring(currentUserId.length - 4)})';
    }

    try {
      final profile = await _supabase
          .from('profiles')
          .select('full_name, email')
          .eq('id', user.id)
          .maybeSingle();

      final String fullName = (profile?['full_name'] ?? '').toString().trim();
      if (fullName.isNotEmpty) return fullName;

      final String email = (profile?['email'] ?? user.email ?? '').toString();
      if (email.contains('@')) return email.split('@').first;
    } catch (_) {}

    final String? metaName = user.userMetadata?['full_name']?.toString().trim();
    if (metaName != null && metaName.isNotEmpty) return metaName;
    if (user.email != null && user.email!.contains('@')) {
      return user.email!.split('@').first;
    }
    return 'Người chơi';
  }

  String _generateRoomCode() {
    const String chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final Random rand = Random.secure();
    return List.generate(6, (_) => chars[rand.nextInt(chars.length)]).join();
  }

  Future<List<RoomExamOption>> fetchAvailableExams() async {
    final dynamic rawData = await _supabase
        .from('de_thi')
        .select('id, tieu_de, mon_hoc(ten_mon), de_thi_cau_hoi(cau_hoi_id)')
        .order('tieu_de', ascending: true);

    final List<RoomExamOption> result = [];
    if (rawData is List) {
      for (final dynamic rawItem in rawData) {
        if (rawItem is! JsonMap) continue;
        final dynamic links = rawItem['de_thi_cau_hoi'];
        final int soCau = links is List ? links.length : 0;
        if (soCau <= 0) continue;

        final dynamic mon = rawItem['mon_hoc'];
        final String tenMon =
            mon is Map ? (mon['ten_mon'] ?? 'Tổng hợp').toString() : 'Tổng hợp';

        result.add(
          RoomExamOption(
            id: rawItem['id'].toString(),
            tieuDe: (rawItem['tieu_de'] ?? 'Bộ đề trắc nghiệm').toString(),
            tenMon: tenMon,
            soCau: soCau,
          ),
        );
      }
    }
    return result;
  }

  Future<RoomModel> createRoom({
    required String tenPhong,
    required String deThiId,
    required int thoiGianPhut,
  }) async {
    final String userId = currentUserId;
    final String displayName = await getCurrentDisplayName();

    String code = _generateRoomCode();
    for (int i = 0; i < 5; i++) {
      final existed = await _supabase
          .from('phong_thi')
          .select('id')
          .eq('ma_phong', code)
          .maybeSingle();
      if (existed == null) break;
      code = _generateRoomCode();
    }

    final JsonMap roomRow = await _supabase
        .from('phong_thi')
        .insert({
          'ma_phong': code,
          'ten_phong':
              tenPhong.trim().isEmpty ? 'Phòng thi $code' : tenPhong.trim(),
          'de_thi_id': deThiId,
          'chu_phong_id': userId,
          'ten_chu_phong': displayName,
          'trang_thai': 'waiting',
          'thoi_gian_phut': thoiGianPhut,
        })
        .select()
        .single();

    final RoomModel room = RoomModel.fromMap(roomRow);

    await _supabase.from('phong_thi_thanh_vien').upsert(
      {
        'phong_thi_id': room.id,
        'user_id': userId,
        'ten_hien_thi': displayName,
        'la_chu_phong': true,
        'trang_thai': 'joined',
      },
      onConflict: 'phong_thi_id,user_id',
    );

    return room;
  }

  Future<RoomModel> joinRoomByCode(String rawCode) async {
    final String code = rawCode.trim().toUpperCase();
    if (code.length != 6) {
      throw Exception('Mã phòng phải gồm đúng 6 ký tự.');
    }

    final JsonMap? roomRow = await _supabase
        .from('phong_thi')
        .select()
        .eq('ma_phong', code)
        .maybeSingle();

    if (roomRow == null) {
      throw Exception('Không tìm thấy phòng với mã "$code".');
    }

    final RoomModel room = RoomModel.fromMap(roomRow);
    if (room.trangThai == 'cancelled') {
      throw Exception('Phòng thi này đã bị chủ phòng hủy.');
    }
    if (room.trangThai == 'finished') {
      throw Exception('Phòng thi này đã kết thúc.');
    }

    final String userId = currentUserId;
    final String displayName = await getCurrentDisplayName();

    final existingMember = await _supabase
        .from('phong_thi_thanh_vien')
        .select()
        .eq('phong_thi_id', room.id)
        .eq('user_id', userId)
        .maybeSingle();

    if (room.trangThai == 'playing' && existingMember == null) {
      throw Exception('Phòng thi đang diễn ra, không thể vào muộn.');
    }

    if (existingMember == null) {
      await _supabase.from('phong_thi_thanh_vien').insert({
        'phong_thi_id': room.id,
        'user_id': userId,
        'ten_hien_thi': displayName,
        'la_chu_phong': room.chuPhongId == userId,
        'trang_thai': room.trangThai == 'playing' ? 'playing' : 'joined',
      });
    }

    return room;
  }

  Future<StringMap> fetchExamMeta(String deThiId) async {
    final JsonMap? data = await _supabase
        .from('de_thi')
        .select('tieu_de, mon_hoc(ten_mon)')
        .eq('id', deThiId)
        .maybeSingle();

    if (data == null) {
      return {'tieu_de': 'Bộ đề thi', 'ten_mon': 'Tổng hợp'};
    }
    final dynamic mon = data['mon_hoc'];
    return {
      'tieu_de': (data['tieu_de'] ?? 'Bộ đề thi').toString(),
      'ten_mon':
          mon is Map ? (mon['ten_mon'] ?? 'Tổng hợp').toString() : 'Tổng hợp',
    };
  }

  Future<List<RoomQuestionModel>> fetchRoomQuestions(String deThiId) async {
    final dynamic rawRows = await _supabase
        .from('de_thi_cau_hoi')
        .select('thu_tu, diem, cau_hoi(id, noi_dung, muc_do, dap_an(*))')
        .eq('de_thi_id', deThiId)
        .order('thu_tu', ascending: true);

    final List<RoomQuestionModel> questions = [];
    if (rawRows is! List) return questions;

    for (final dynamic rawRow in rawRows) {
      if (rawRow is! JsonMap) continue;
      final dynamic cauHoi = rawRow['cau_hoi'];
      if (cauHoi is! JsonMap) continue;

      final List<JsonMap> rawAnswers = [];
      final dynamic rawAnsList = cauHoi['dap_an'];
      if (rawAnsList is List) {
        for (final dynamic item in rawAnsList) {
          if (item is JsonMap) {
            rawAnswers.add(item);
          }
        }
      }

      rawAnswers.sort(
        (a, b) =>
            ((a['thu_tu'] ?? 0) as num).compareTo((b['thu_tu'] ?? 0) as num),
      );

      final List<RoomAnswerModel> answers = [];
      for (final JsonMap ans in rawAnswers) {
        answers.add(
          RoomAnswerModel(
            id: ans['id'].toString(),
            noiDung: (ans['noi_dung'] ?? '').toString(),
            isCorrect: _extractIsCorrect(ans),
          ),
        );
      }

      if (answers.isEmpty) continue;

      questions.add(
        RoomQuestionModel(
          id: cauHoi['id'].toString(),
          noiDung: (cauHoi['noi_dung'] ?? '').toString(),
          mucDo: (cauHoi['muc_do'] ?? 'Trung bình').toString(),
          diem: (rawRow['diem'] as num?)?.toInt() ?? 1,
          dapAn: answers,
        ),
      );
    }
    return questions;
  }

  bool _extractIsCorrect(JsonMap ans) {
    if (ans['la_dap_an_dung'] is bool) return ans['la_dap_an_dung'] as bool;
    if (ans['dung'] is bool) return ans['dung'] as bool;
    if (ans['is_correct'] is bool) return ans['is_correct'] as bool;
    for (final dynamic v in ans.values) {
      if (v is bool) return v;
    }
    return false;
  }

  Future<void> startRoom(String roomId) async {
    await _supabase
        .from('phong_thi_thanh_vien')
        .update({'trang_thai': 'playing'})
        .eq('phong_thi_id', roomId);

    await _supabase.from('phong_thi').update({
      'trang_thai': 'playing',
      'bat_dau_luc': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', roomId);
  }

  Future<void> cancelRoom(String roomId) async {
    await _supabase
        .from('phong_thi')
        .update({'trang_thai': 'cancelled'})
        .eq('id', roomId);
  }

  Future<void> finishRoom(String roomId) async {
    await _supabase
        .from('phong_thi')
        .update({'trang_thai': 'finished'})
        .eq('id', roomId);
  }

  Future<void> leaveRoom(String roomId) async {
    await _supabase
        .from('phong_thi_thanh_vien')
        .delete()
        .eq('phong_thi_id', roomId)
        .eq('user_id', currentUserId);
  }

  Future<void> submitRoomResult({
    required String roomId,
    required String deThiId,
    required String tenDeThi,
    required String monHoc,
    required int diemSo,
    required int soCauDung,
    required int tongSoCau,
    required int thoiGianGiay,
    required List<RoomQuestionModel> questions,
    required StringMap dapAnDaChon,
  }) async {
    await _supabase
        .from('phong_thi_thanh_vien')
        .update({
          'diem_so': diemSo,
          'so_cau_dung': soCauDung,
          'tong_so_cau': tongSoCau,
          'thoi_gian_giay': thoiGianGiay,
          'trang_thai': 'finished',
          'nop_bai_luc': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('phong_thi_id', roomId)
        .eq('user_id', currentUserId);

    try {
      final String mm = (thoiGianGiay ~/ 60).toString().padLeft(2, '0');
      final String ss = (thoiGianGiay % 60).toString().padLeft(2, '0');
      await _supabase.from('lich_su_thi').insert({
        'user_id': currentUserId,
        'de_thi_id': deThiId,
        'ten_de_thi': '[Phòng thi] $tenDeThi',
        'mon_hoc': monHoc,
        'che_do': 'room',
        'diem_so': diemSo,
        'so_cau_dung': soCauDung,
        'tong_so_cau': tongSoCau,
        'thoi_gian_lam': '$mm:$ss',
        'chi_tiet_cau_hoi': questions.map((q) => q.toMap()).toList(),
        'dap_an_da_chon': dapAnDaChon,
      });
    } catch (_) {}
  }

  Stream<RoomModel?> watchRoom(String roomId) {
    return _supabase
        .from('phong_thi')
        .stream(primaryKey: ['id'])
        .eq('id', roomId)
        .map((rows) => rows.isEmpty ? null : RoomModel.fromMap(rows.first));
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
}