import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/exam_model.dart';
import '../models/question_model.dart';
import '../models/subject_model.dart';
import 'supabase_service.dart';

/// Service quản lý truy vấn Môn học, Đề thi và Câu hỏi.
class ExamService {
  static SupabaseClient get _supabase => SupabaseService.client;

  /// Lấy danh sách môn học đang hoạt động
  static Future<List<SubjectModel>> getActiveSubjects() async {
    try {
      final response = await _supabase
          .from('mon_hoc')
          .select()
          .eq('trang_thai', true)
          .order('thu_tu_hien_thi', ascending: true);

      return (response as List)
          .map((item) => SubjectModel.fromJson(Map<String, dynamic>.from(item as Map)))
          .toList();
    } on PostgrestException catch (e) {
      throw Exception('Lỗi tải danh sách môn học: ${e.message}');
    } catch (e) {
      throw Exception('Không thể tải môn học: $e');
    }
  }

  /// Lấy danh sách đề thi đã xuất bản và công khai (hỗ trợ tìm kiếm & lọc)
  static Future<List<ExamModel>> getPublishedExams({
    String? subjectId,
    String? difficulty,
    String? searchQuery,
    int limit = 20,
    int offset = 0,
  }) async {
    try {
      var query = _supabase
          .from('de_thi')
          .select('*, mon_hoc:mon_hoc_id(ten_mon), cau_hoi:cau_hoi(id)')
          .eq('trang_thai', 'da_xuat_ban')
          .eq('cong_khai', true);

      if (subjectId != null && subjectId.isNotEmpty) {
        query = query.eq('mon_hoc_id', subjectId);
      }

      if (difficulty != null && difficulty.isNotEmpty) {
        query = query.eq('muc_do', difficulty);
      }

      if (searchQuery != null && searchQuery.trim().isNotEmpty) {
        query = query.ilike('tieu_de', '%${searchQuery.trim()}%');
      }

      final response = await query
          .order('ngay_tao', ascending: false)
          .range(offset, offset + limit - 1);

      return (response as List)
          .map((item) => ExamModel.fromJson(Map<String, dynamic>.from(item as Map)))
          .toList();
    } on PostgrestException catch (e) {
      throw Exception('Lỗi tải danh sách đề thi: ${e.message}');
    } catch (e) {
      throw Exception('Không thể tải đề thi: $e');
    }
  }

  /// Lấy danh sách đề thi nổi bật cho Trang chủ
  static Future<List<ExamModel>> getFeaturedExams({int limit = 5}) async {
    return getPublishedExams(limit: limit);
  }

  /// Lấy chi tiết một đề thi theo ID
  static Future<ExamModel> getExamDetail(String examId) async {
    try {
      final response = await _supabase
          .from('de_thi')
          .select('*, mon_hoc:mon_hoc_id(ten_mon), cau_hoi:cau_hoi(id)')
          .eq('id', examId)
          .single();

      return ExamModel.fromJson(Map<String, dynamic>.from(response));
    } on PostgrestException catch (e) {
      throw Exception('Lỗi tải chi tiết đề thi: ${e.message}');
    } catch (e) {
      throw Exception('Không tìm thấy đề thi: $e');
    }
  }

  /// Lấy danh sách câu hỏi và các đáp án của đề thi phục vụ làm bài
  static Future<List<QuestionModel>> getExamQuestions(String examId) async {
    try {
      final response = await _supabase
          .from('cau_hoi')
          .select('*, loai_cau_hoi:loai_cau_hoi_id(*), dap_an:dap_an(*)')
          .eq('de_thi_id', examId)
          .order('thu_tu', ascending: true);

      return (response as List)
          .map((item) => QuestionModel.fromJson(Map<String, dynamic>.from(item as Map)))
          .toList();
    } on PostgrestException catch (e) {
      throw Exception('Lỗi tải câu hỏi bài thi: ${e.message}');
    } catch (e) {
      throw Exception('Không thể tải câu hỏi: $e');
    }
  }
}
