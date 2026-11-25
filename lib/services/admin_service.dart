import 'package:firebase_auth/firebase_auth.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/answer_model.dart';
import '../models/exam_model.dart';
import '../models/question_model.dart';
import '../models/subject_model.dart';
import 'supabase_service.dart';

/// Model thống kê tổng quan hệ thống cho Admin Dashboard.
class AdminDashboardStats {
  final int totalUsers;
  final int totalSubjects;
  final int totalExams;
  final int totalQuestions;
  final int totalAttempts;

  const AdminDashboardStats({
    this.totalUsers = 0,
    this.totalSubjects = 0,
    this.totalExams = 0,
    this.totalQuestions = 0,
    this.totalAttempts = 0,
  });
}

/// Service quản lý các nghiệp vụ Quản trị viên (Admin & Super Admin).
class AdminService {
  static SupabaseClient get _supabase => SupabaseService.client;

  static String? get _currentUserId => FirebaseAuth.instance.currentUser?.uid;

  // ===========================================================================
  // THỐNG KÊ DASHBOARD
  // ===========================================================================

  /// Lấy số liệu thống kê Dashboard.
  static Future<AdminDashboardStats> getDashboardStats() async {
    try {
      final usersCount = await _supabase
          .from('nguoi_dung')
          .count(CountOption.exact);

      final subjectsCount = await _supabase
          .from('mon_hoc')
          .count(CountOption.exact);

      final examsCount = await _supabase
          .from('de_thi')
          .count(CountOption.exact);

      final questionsCount = await _supabase
          .from('cau_hoi')
          .count(CountOption.exact);

      final attemptsCount = await _supabase
          .from('lan_lam_bai')
          .count(CountOption.exact);

      return AdminDashboardStats(
        totalUsers: usersCount,
        totalSubjects: subjectsCount,
        totalExams: examsCount,
        totalQuestions: questionsCount,
        totalAttempts: attemptsCount,
      );
    } catch (e) {
      throw Exception('Không thể tải thống kê quản trị: $e');
    }
  }

  // ===========================================================================
  // QUẢN LÝ MÔN HỌC (SUBJECT CRUD)
  // ===========================================================================

  static Future<List<SubjectModel>> getAllSubjectsAdmin() async {
    try {
      final response = await _supabase
          .from('mon_hoc')
          .select()
          .order('thu_tu_hien_thi', ascending: true);

      return (response as List)
          .map(
            (item) =>
                SubjectModel.fromJson(Map<String, dynamic>.from(item as Map)),
          )
          .toList();
    } on PostgrestException catch (e) {
      throw Exception('Lỗi tải môn học: ${e.message}');
    }
  }

  static Future<void> saveSubject(SubjectModel subject) async {
    try {
      final data = subject.toJson();

      if (subject.id.isEmpty) {
        data['nguoi_tao_id'] = _currentUserId;
        await _supabase.from('mon_hoc').insert(data);
      } else {
        await _supabase.from('mon_hoc').update(data).eq('id', subject.id);
      }
    } on PostgrestException catch (e) {
      throw Exception('Lỗi lưu môn học: ${e.message}');
    }
  }

  static Future<void> deleteSubject(String subjectId) async {
    try {
      await _supabase.from('mon_hoc').delete().eq('id', subjectId);
    } on PostgrestException catch (e) {
      throw Exception(
        'Lỗi xóa môn học (có thể do đã có đề thi tham chiếu): ${e.message}',
      );
    }
  }

  // ===========================================================================
  // QUẢN LÝ ĐỀ THI (EXAM CRUD)
  // ===========================================================================

  static Future<List<ExamModel>> getAllExamsAdmin({String? subjectId}) async {
    try {
      var query = _supabase
          .from('de_thi')
          .select('*, mon_hoc:mon_hoc_id(ten_mon), cau_hoi:cau_hoi(id)');

      if (subjectId != null && subjectId.isNotEmpty) {
        query = query.eq('mon_hoc_id', subjectId);
      }

      final response = await query.order('ngay_tao', ascending: false);

      return (response as List)
          .map(
            (item) =>
                ExamModel.fromJson(Map<String, dynamic>.from(item as Map)),
          )
          .toList();
    } on PostgrestException catch (e) {
      throw Exception('Lỗi tải danh sách đề thi: ${e.message}');
    }
  }

  static Future<void> saveExam(ExamModel exam) async {
    try {
      final data = exam.toJson();

      if (exam.id.isEmpty) {
        data['nguoi_tao_id'] = _currentUserId;
        await _supabase.from('de_thi').insert(data);
      } else {
        await _supabase.from('de_thi').update(data).eq('id', exam.id);
      }
    } on PostgrestException catch (e) {
      throw Exception('Lỗi lưu đề thi: ${e.message}');
    }
  }

  static Future<void> deleteExam(String examId) async {
    try {
      await _supabase.from('de_thi').delete().eq('id', examId);
    } on PostgrestException catch (e) {
      throw Exception('Lỗi xóa đề thi: ${e.message}');
    }
  }

  // ===========================================================================
  // QUẢN LÝ KHO CÂU HỎI
  // ===========================================================================

  /// Lấy câu hỏi thuộc một đề thi.
  static Future<List<QuestionModel>> getQuestionsAdmin(String examId) async {
    try {
      final response = await _supabase
          .from('cau_hoi')
          .select('*, loai_cau_hoi:loai_cau_hoi_id(*), dap_an:dap_an(*)')
          .eq('de_thi_id', examId)
          .order('thu_tu', ascending: true);

      return (response as List)
          .map(
            (item) =>
                QuestionModel.fromJson(Map<String, dynamic>.from(item as Map)),
          )
          .toList();
    } on PostgrestException catch (e) {
      throw Exception('Lỗi tải câu hỏi: ${e.message}');
    }
  }

  /// Lấy kho câu hỏi.
  ///
  /// Có thể lọc theo môn học và độ khó.
  /// Không bắt buộc câu hỏi phải thuộc một đề thi.
  static Future<List<QuestionModel>> getQuestionBank({
    String? subjectId,
    String? difficulty,
  }) async {
    try {
      var query = _supabase
          .from('cau_hoi')
          .select('*, loai_cau_hoi:loai_cau_hoi_id(*), dap_an:dap_an(*)')
          .eq('da_luu_tru', false);

      // Lọc theo môn học.
      if (subjectId != null && subjectId.isNotEmpty) {
        query = query.eq('mon_hoc_id', subjectId);
      }

      // Lọc theo độ khó: de, trung_binh, kho.
      if (difficulty != null && difficulty.isNotEmpty) {
        query = query.eq('muc_do', difficulty);
      }

      final response = await query.order('ngay_tao', ascending: false);

      return (response as List)
          .map(
            (item) =>
                QuestionModel.fromJson(Map<String, dynamic>.from(item as Map)),
          )
          .toList();
    } on PostgrestException catch (e) {
      throw Exception('Lỗi tải kho câu hỏi: ${e.message}');
    }
  }

  /// Lưu câu hỏi và danh sách đáp án.
  static Future<void> saveQuestionWithAnswers({
    required QuestionModel question,
    required List<AnswerModel> answers,
  }) async {
    try {
      String questionId = question.id;

      final questionData = question.toJson();

      if (questionId.isEmpty) {
        final inserted = await _supabase
            .from('cau_hoi')
            .insert(questionData)
            .select('id')
            .single();

        questionId = inserted['id'] as String;
      } else {
        await _supabase
            .from('cau_hoi')
            .update(questionData)
            .eq('id', questionId);

        // Xóa đáp án cũ để cập nhật bộ đáp án mới.
        await _supabase.from('dap_an').delete().eq('cau_hoi_id', questionId);
      }

      // Thêm danh sách đáp án mới.
      if (answers.isNotEmpty) {
        final answerInserts = answers.asMap().entries.map((entry) {
          final index = entry.key;
          final answer = entry.value;

          return {
            'cau_hoi_id': questionId,
            'noi_dung': answer.noiDung,
            'hinh_anh_url': answer.hinhAnhUrl,
            'la_dung': answer.laDung,
            'thu_tu': index + 1,
            'du_lieu_bo_sung': answer.duLieuBoSung,
          };
        }).toList();

        await _supabase.from('dap_an').insert(answerInserts);
      }
    } on PostgrestException catch (e) {
      throw Exception('Lỗi lưu câu hỏi và đáp án: ${e.message}');
    }
  }

  /// Xóa câu hỏi.
  static Future<void> deleteQuestion(String questionId) async {
    try {
      await _supabase.from('cau_hoi').delete().eq('id', questionId);
    } on PostgrestException catch (e) {
      throw Exception('Lỗi xóa câu hỏi: ${e.message}');
    }
  }

  // ===========================================================================
  // QUẢN LÝ THÔNG BÁO (ADMIN NOTIFICATIONS)
  // ===========================================================================

  static Future<void> sendNotification({
    required String targetUserId,
    required String title,
    required String content,
    String type = 'he_thong',
    String? destinationRoute,
  }) async {
    try {
      await _supabase.from('thong_bao').insert({
        'nguoi_dung_id': targetUserId,
        'tieu_de': title,
        'noi_dung': content,
        'loai': type,
        if (destinationRoute != null) ...{'duong_dan_dich': destinationRoute},
        'da_doc': false,
      });
    } on PostgrestException catch (e) {
      throw Exception('Lỗi gửi thông báo: ${e.message}');
    }
  }
}
