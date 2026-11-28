import 'dart:convert';
import 'dart:core';
import 'dart:core' as core;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/attempt_detail_model.dart';
import '../models/game_mode_model.dart';
import '../models/quiz_attempt_model.dart';
import '../models/quiz_submission_result_model.dart';
import 'backend_service.dart';
import 'supabase_service.dart';

/// Service quản lý quá trình thi, nộp bài, lịch sử làm bài và tạo bộ đề.
class QuizService {
  static SupabaseClient get _supabase => SupabaseService.client;

  static String? get _currentUserId =>
      FirebaseAuth.instance.currentUser?.uid;

  /// Đọc và kiểm tra phản hồi JSON từ Backend.
  static core.Map<String, dynamic> _parseBackendResponse(
    dynamic response,
    String defaultMessage,
  ) {
    core.Map<String, dynamic> result;

    try {
      final decoded = jsonDecode(response.body);

      if (decoded is! core.Map) {
        throw const FormatException('Invalid response');
      }

      result = core.Map<String, dynamic>.from(decoded);
    } catch (_) {
      throw Exception('Phản hồi từ Backend không hợp lệ.');
    }

    if (response.statusCode < 200 ||
        response.statusCode >= 300 ||
        result['success'] != true) {
      throw Exception(
        result['message']?.toString() ?? defaultMessage,
      );
    }

    return result;
  }

  /// Lấy danh sách các chế độ chơi đang mở.
  static core.Future<core.List<GameModeModel>> getActiveGameModes() async {
    try {
      final response = await _supabase
          .from('che_do_choi')
          .select()
          .eq('trang_thai', true);

      return (response as core.List)
          .map(
            (item) => GameModeModel.fromJson(
              core.Map<String, dynamic>.from(item as core.Map),
            ),
          )
          .toList();
    } on PostgrestException catch (e) {
      throw Exception('Lỗi tải chế độ chơi: ${e.message}');
    } catch (e) {
      throw Exception('Không thể tải chế độ chơi: $e');
    }
  }

  /// Khởi tạo lượt làm bài thông qua Backend.
  static core.Future<QuizAttemptModel> startAttempt({
    required String examId,
    required String gameModeId,
    String? roomId,
  }) async {
    if (_currentUserId == null) {
      throw Exception('Bạn chưa đăng nhập.');
    }

    if (roomId != null && roomId.isNotEmpty) {
      throw Exception(
        'API bắt đầu thi hiện chưa hỗ trợ tham số roomId.',
      );
    }

    try {
      final response = await BackendService.post(
        '/api/quiz/attempts/start',
        body: jsonEncode({
          'examId': examId,
          'gameModeId': gameModeId,
        }),
      );

      final result = _parseBackendResponse(
        response,
        'Không thể bắt đầu bài thi.',
      );

      final data = result['data'];

      if (data is! core.Map || data['attempt'] is! core.Map) {
        throw Exception(
          'Backend không trả về thông tin lượt thi hợp lệ.',
        );
      }

      final attemptJson = core.Map<String, dynamic>.from(
        data['attempt'] as core.Map,
      );

      attemptJson['nguoi_dung_id'] = _currentUserId;

      return QuizAttemptModel.fromJson(attemptJson);
    } catch (e) {
      throw Exception('Không thể khởi tạo bài thi: $e');
    }
  }

  /// Nộp bài thông qua Backend.
  static core.Future<QuizSubmissionResultModel> submitAttempt({
    required String attemptId,
    required int timeSpentSeconds,
    required double totalScore,
    required int correctCount,
    required int wrongCount,
    required int totalQuestions,
    required core.List<core.Map<String, dynamic>> questionDetails,
  }) async {
    if (_currentUserId == null) {
      throw Exception('Bạn chưa đăng nhập.');
    }

    try {
      final answers = questionDetails.map((detail) {
        final questionId = detail['cau_hoi_id'];

        if (questionId == null || questionId.toString().isEmpty) {
          throw Exception('Thiếu mã câu hỏi khi nộp bài.');
        }

        final selectedAnswers =
            detail['dap_an_da_chon'] as core.List? ?? [];

        final selectedAnswerIds = <String>[];

        for (final answer in selectedAnswers) {
          if (answer is! core.Map) {
            throw Exception('Dữ liệu đáp án không hợp lệ.');
          }

          final answerId = answer['dap_an_id'];

          if (answerId != null && answerId.toString().isNotEmpty) {
            selectedAnswerIds.add(answerId.toString());
          }
        }

        return {
          'questionId': questionId.toString(),
          'selectedAnswerIds': selectedAnswerIds,
        };
      }).toList();

      final response = await BackendService.post(
        '/api/quiz/attempts/$attemptId/submit',
        body: jsonEncode({
          'answers': answers,
        }),
      );

      final result = _parseBackendResponse(
        response,
        'Không thể nộp bài thi.',
      );

      final data = result['data'];

      if (data is! core.Map) {
        throw Exception(
          'Backend không trả về kết quả bài thi hợp lệ.',
        );
      }

      return QuizSubmissionResultModel.fromJson(
        core.Map<String, dynamic>.from(data),
      );
    } catch (e) {
      throw Exception('Không thể nộp bài thi: $e');
    }
  }

  /// Lấy lịch sử làm bài của thí sinh.
  static core.Future<core.List<QuizAttemptModel>> getUserAttempts({
    int limit = 20,
    int offset = 0,
    String? subjectId,
  }) async {
    final uid = _currentUserId;

    if (uid == null) return [];

    try {
      var query = _supabase
          .from('lan_lam_bai')
          .select(
            '*, de_thi:de_thi_id('
            'tieu_de, anh_bia_url, mon_hoc_id, '
            'mon_hoc:mon_hoc_id(ten_mon)'
            '), che_do_choi:che_do_choi_id(ten_che_do)',
          )
          .eq('nguoi_dung_id', uid)
          .eq('trang_thai', 'hoan_thanh');

      if (subjectId != null && subjectId.isNotEmpty) {
        query = query.eq('de_thi.mon_hoc_id', subjectId);
      }

      final response = await query
          .order('bat_dau_luc', ascending: false)
          .range(offset, offset + limit - 1);

      return (response as core.List)
          .map(
            (item) => QuizAttemptModel.fromJson(
              core.Map<String, dynamic>.from(item as core.Map),
            ),
          )
          .toList();
    } on PostgrestException catch (e) {
      throw Exception('Lỗi tải lịch sử thi: ${e.message}');
    } catch (e) {
      throw Exception('Không thể tải lịch sử làm bài: $e');
    }
  }

  /// Lấy chi tiết bài thi để xem lại.
  static core.Future<core.List<AttemptDetailModel>> getAttemptReview(
    String attemptId,
  ) async {
    try {
      final response = await _supabase
          .from('chi_tiet_lam_bai')
          .select(
            '*, cau_hoi:cau_hoi_id('
            '*, loai_cau_hoi:loai_cau_hoi_id(*), '
            'dap_an:dap_an(*)'
            '), dap_an_da_chon:dap_an_da_chon(*)',
          )
          .eq('lan_lam_bai_id', attemptId)
          .order('thu_tu', ascending: true);

      return (response as core.List)
          .map(
            (item) => AttemptDetailModel.fromJson(
              core.Map<String, dynamic>.from(item as core.Map),
            ),
          )
          .toList();
    } on PostgrestException catch (e) {
      throw Exception('Lỗi tải chi tiết bài làm: ${e.message}');
    } catch (e) {
      throw Exception('Không thể xem lại bài thi: $e');
    }
  }

  /// Lấy danh sách môn học từ bảng mon_hoc (luôn có "Khác" ở cuối danh sách).
  static core.Future<core.List<core.Map<String, dynamic>>> getSubjects() async {
    try {
      final response = await _supabase
          .from('mon_hoc')
          .select('id, ten_mon')
          .order('ten_mon', ascending: true);

      final list =
          core.List<core.Map<String, dynamic>>.from(response as core.List);

      // Tách mục "Khác" (nếu đã có trong DB) để đưa xuống cuối cùng
      final otherItems = list
          .where((e) =>
              (e['ten_mon']?.toString().trim().toLowerCase() ?? '') == 'khác')
          .toList();
      list.removeWhere((e) =>
          (e['ten_mon']?.toString().trim().toLowerCase() ?? '') == 'khác');

      if (otherItems.isNotEmpty) {
        list.addAll(otherItems);
      } else {
        // Nếu DB chưa có hàng "Khác", tự bổ sung lựa chọn tạm thời ở cuối
        list.add({'id': 'khac', 'ten_mon': 'Khác'});
      }

      return list;
    } catch (e) {
      throw Exception('Không thể tải danh sách môn học: $e');
    }
  }

  /// Lấy danh sách câu hỏi có sẵn trong kho theo môn học.
  static core.Future<core.List<core.Map<String, dynamic>>>
      getQuestionsBySubject(String monHocId) async {
    try {
      final response = await _supabase
          .from('cau_hoi')
          .select('*, dap_an(*)')
          .eq('mon_hoc_id', monHocId)
          .order('id', ascending: true);

      return core.List<core.Map<String, dynamic>>.from(response as core.List);
    } on PostgrestException catch (e) {
      throw Exception('Lỗi tải kho câu hỏi: ${e.message}');
    } catch (e) {
      throw Exception('Không thể tải kho câu hỏi: $e');
    }
  }

  /// Tạo bộ đề mới vào các bảng de_thi -> cau_hoi -> dap_an.
  static core.Future<String> createExam({
    required String tieuDe,
    required String moTa,
    required String monHocId,
    required core.List<core.Map<String, dynamic>> questions,
  }) async {
    final uid = _currentUserId;
    if (uid == null) {
      throw Exception('Bạn chưa đăng nhập.');
    }

    try {
      String resolvedMonHocId = monHocId;

      // Nếu người dùng chọn "Khác" khi DB chưa có dòng này, tự động tìm hoặc tạo mới trong mon_hoc
      if (resolvedMonHocId == 'khac') {
        final existingOther = await _supabase
            .from('mon_hoc')
            .select('id')
            .ilike('ten_mon', 'Khác')
            .limit(1)
            .maybeSingle();

        if (existingOther != null && existingOther['id'] != null) {
          resolvedMonHocId = existingOther['id'].toString();
        } else {
          final insertedOther = await _supabase
              .from('mon_hoc')
              .insert({'ten_mon': 'Khác'})
              .select('id')
              .single();
          resolvedMonHocId = insertedOther['id'].toString();
        }
      }

      // 1. Lấy mã loại câu hỏi mặc định từ bảng loai_cau_hoi
      final questionType = await _supabase
          .from('loai_cau_hoi')
          .select('id')
          .limit(1)
          .single();
      final String loaiCauHoiId = questionType['id'].toString();

      // 2. Tạo bản ghi trong bảng de_thi
      final examRes = await _supabase
          .from('de_thi')
          .insert({
            'tieu_de': tieuDe,
            'mo_ta': moTa,
            'mon_hoc_id': resolvedMonHocId,
            'nguoi_tao_id': uid,
          })
          .select('id')
          .single();

      final String deThiId = examRes['id'].toString();

      // 3. Tạo từng câu hỏi và 4 đáp án tương ứng
      for (int i = 0; i < questions.length; i++) {
        final q = questions[i];

        final questionRes = await _supabase
            .from('cau_hoi')
            .insert({
              'de_thi_id': deThiId,
              'loai_cau_hoi_id': loaiCauHoiId,
              'noi_dung': q['noi_dung'],
              'thu_tu': i + 1,
            })
            .select('id')
            .single();

        final String cauHoiId = questionRes['id'].toString();
        final core.List<core.Map<String, dynamic>> options =
            core.List<core.Map<String, dynamic>>.from(q['options'] as core.List);

        final answersPayload = options.map((opt) {
          return {
            'cau_hoi_id': cauHoiId,
            'noi_dung': opt['noi_dung'],
            'la_dap_an_dung': opt['is_correct'] == true,
          };
        }).toList();

        await _supabase.from('dap_an').insert(answersPayload);
      }

      return deThiId;
    } on PostgrestException catch (e) {
      throw Exception('Lỗi cơ sở dữ liệu (${e.code}): ${e.message}');
    } catch (e) {
      throw Exception('Không thể tạo bộ đề: $e');
    }
  }
}