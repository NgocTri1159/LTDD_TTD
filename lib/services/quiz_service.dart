
import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/attempt_detail_model.dart';
import '../models/game_mode_model.dart';
import '../models/quiz_attempt_model.dart';
import '../models/quiz_submission_result_model.dart';
import 'backend_service.dart';
import 'supabase_service.dart';

/// Service quản lý quá trình thi, nộp bài và lịch sử làm bài.
class QuizService {
  static SupabaseClient get _supabase => SupabaseService.client;

  static String? get _currentUserId =>
      FirebaseAuth.instance.currentUser?.uid;

  /// Đọc và kiểm tra phản hồi JSON từ Backend.
  static Map<String, dynamic> _parseBackendResponse(
    dynamic response,
    String defaultMessage,
  ) {
    Map<String, dynamic> result;

    try {
      final decoded = jsonDecode(response.body);

      if (decoded is! Map) {
        throw const FormatException('Invalid response');
      }

      result = Map<String, dynamic>.from(decoded);
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
  static Future<List<GameModeModel>> getActiveGameModes() async {
    try {
      final response = await _supabase
          .from('che_do_choi')
          .select()
          .eq('trang_thai', true);

      return (response as List)
          .map(
            (item) => GameModeModel.fromJson(
              Map<String, dynamic>.from(item as Map),
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
  static Future<QuizAttemptModel> startAttempt({
    required String examId,
    required String gameModeId,
    String? roomId,
  }) async {
    if (_currentUserId == null) {
      throw Exception('Bạn chưa đăng nhập.');
    }

    // Backend hiện chưa hỗ trợ phòng thi trong API start.
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

      if (data is! Map || data['attempt'] is! Map) {
        throw Exception(
          'Backend không trả về thông tin lượt thi hợp lệ.',
        );
      }

      final attemptJson = Map<String, dynamic>.from(
        data['attempt'] as Map,
      );

      // Backend không trả nguoi_dung_id trong attempt.
      // Lấy UID từ Firebase Auth hiện tại để hoàn thiện model.
      attemptJson['nguoi_dung_id'] = _currentUserId;

      return QuizAttemptModel.fromJson(attemptJson);
    } catch (e) {
      throw Exception('Không thể khởi tạo bài thi: $e');
    }
  }

  /// Nộp bài thông qua Backend.
  ///
  /// Backend tự chấm điểm và tự tính thời gian.
  /// questionDetails vẫn giữ cấu trúc cũ để thuận tiện tích hợp
  /// với màn hình làm bài hiện tại.
  static Future<QuizSubmissionResultModel> submitAttempt({
    required String attemptId,
    required int timeSpentSeconds,
    required double totalScore,
    required int correctCount,
    required int wrongCount,
    required int totalQuestions,
    required List<Map<String, dynamic>> questionDetails,
  }) async {
    if (_currentUserId == null) {
      throw Exception('Bạn chưa đăng nhập.');
    }

    try {
      // Chuyển dữ liệu chi tiết cũ thành định dạng API mới.
      final answers = questionDetails.map((detail) {
        final questionId = detail['cau_hoi_id'];

        if (questionId == null ||
            questionId.toString().isEmpty) {
          throw Exception('Thiếu mã câu hỏi khi nộp bài.');
        }

        final selectedAnswers =
            detail['dap_an_da_chon'] as List? ?? [];

        final selectedAnswerIds = <String>[];

        for (final answer in selectedAnswers) {
          if (answer is! Map) {
            throw Exception('Dữ liệu đáp án không hợp lệ.');
          }

          final answerId = answer['dap_an_id'];

          if (answerId != null &&
              answerId.toString().isNotEmpty) {
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

      if (data is! Map) {
        throw Exception(
          'Backend không trả về kết quả bài thi hợp lệ.',
        );
      }

      return QuizSubmissionResultModel.fromJson(
        Map<String, dynamic>.from(data),
      );
    } catch (e) {
      throw Exception('Không thể nộp bài thi: $e');
    }
  }

  /// Lấy lịch sử làm bài của thí sinh.
  static Future<List<QuizAttemptModel>> getUserAttempts({
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

      // Lọc theo môn học nếu được yêu cầu.
      if (subjectId != null && subjectId.isNotEmpty) {
        query = query.eq('de_thi.mon_hoc_id', subjectId);
      }

      final response = await query
          .order('bat_dau_luc', ascending: false)
          .range(offset, offset + limit - 1);

      return (response as List)
          .map(
            (item) => QuizAttemptModel.fromJson(
              Map<String, dynamic>.from(item as Map),
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
  static Future<List<AttemptDetailModel>> getAttemptReview(
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

      return (response as List)
          .map(
            (item) => AttemptDetailModel.fromJson(
              Map<String, dynamic>.from(item as Map),
            ),
          )
          .toList();
    } on PostgrestException catch (e) {
      throw Exception('Lỗi tải chi tiết bài làm: ${e.message}');
    } catch (e) {
      throw Exception('Không thể xem lại bài thi: $e');
    }
  }
}
