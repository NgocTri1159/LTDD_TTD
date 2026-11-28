import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/question_model.dart';
import '../models/answer_model.dart';

class QuestionController {
  // Khởi tạo client kết nối tới Supabase
  final SupabaseClient _supabase = Supabase.instance.client;

  // 1. LẤY DANH SÁCH CÂU HỎI (kèm danh sách đáp án và loại câu hỏi)
  Future<List<QuestionModel>> getQuestions({
    String? deThiId,
    String? searchQuery,
    String? mucDo,
  }) async {
    var query = _supabase
        .from('cau_hoi')
        .select('*, dap_an(*), loai_cau_hoi(*)')
        .eq('da_luu_tru', false);

    // Lọc theo bộ đề nếu có truyền vào
    if (deThiId != null && deThiId.isNotEmpty) {
      query = query.eq('de_thi_id', deThiId);
    }

    // Lọc theo mức độ nếu không phải 'all'
    if (mucDo != null && mucDo.isNotEmpty && mucDo != 'all') {
      query = query.eq('muc_do', mucDo);
    }

    final response = await query.order('ngay_tao', ascending: false);

    List<QuestionModel> questions = (response as List)
        .map((item) => QuestionModel.fromJson(Map<String, dynamic>.from(item)))
        .toList();

    // Lọc theo từ khóa tìm kiếm (nội dung câu hỏi hoặc thẻ tag)
    if (searchQuery != null && searchQuery.trim().isNotEmpty) {
      final keyword = searchQuery.toLowerCase().trim();
      questions = questions.where((q) {
        final matchContent = q.noiDung.toLowerCase().contains(keyword);
        final tags = (q.duLieuBoSung['tags'] as List?)
                ?.map((e) => e.toString().toLowerCase())
                .toList() ??
            [];
        final matchTag = tags.any((tag) => tag.contains(keyword));
        return matchContent || matchTag;
      }).toList();
    }

    return questions;
  }

  // 2. THÊM CÂU HỎI MỚI KÈM DANH SÁCH ĐÁP ÁN
  Future<void> createQuestion(
    QuestionModel question,
    List<AnswerModel> answers,
  ) async {
    // Bước 1: Lưu câu hỏi vào bảng public.cau_hoi và lấy lại id vừa tạo
    final insertedQuestion = await _supabase
        .from('cau_hoi')
        .insert(question.toJson())
        .select()
        .single();

    final String newQuestionId = insertedQuestion['id'] as String;

    // Bước 2: Gắn cau_hoi_id vào từng đáp án rồi lưu hàng loạt vào bảng public.dap_an
    if (answers.isNotEmpty) {
      final answerMaps = answers.asMap().entries.map((entry) {
        final index = entry.key;
        final ans = entry.value;
        return {
          'cau_hoi_id': newQuestionId,
          'noi_dung': ans.noiDung,
          'la_dap_an_dung': ans.laDapAnDung,
          'thu_tu': index + 1,
        };
      }).toList();

      await _supabase.from('dap_an').insert(answerMaps);
    }
  }

  // 3. CẬP NHẬT CÂU HỎI VÀ ĐÁP ÁN
  Future<void> updateQuestion(
    QuestionModel question,
    List<AnswerModel> answers,
  ) async {
    // Bước 1: Cập nhật thông tin câu hỏi
    await _supabase
        .from('cau_hoi')
        .update(question.toJson())
        .eq('id', question.id);

    // Bước 2: Xóa các đáp án cũ của câu hỏi này rồi thêm lại bộ đáp án mới
    await _supabase.from('dap_an').delete().eq('cau_hoi_id', question.id);

    if (answers.isNotEmpty) {
      final answerMaps = answers.asMap().entries.map((entry) {
        final index = entry.key;
        final ans = entry.value;
        return {
          'cau_hoi_id': question.id,
          'noi_dung': ans.noiDung,
          'la_dap_an_dung': ans.laDapAnDung,
          'thu_tu': index + 1,
        };
      }).toList();

      await _supabase.from('dap_an').insert(answerMaps);
    }
  }

  // 4. XÓA CÂU HỎI (Xóa đáp án trước để tránh lỗi khóa ngoại)
  Future<void> deleteQuestion(String questionId) async {
    await _supabase.from('dap_an').delete().eq('cau_hoi_id', questionId);
    await _supabase.from('cau_hoi').delete().eq('id', questionId);
  }
}