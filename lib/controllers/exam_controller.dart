import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/exam_model.dart';

// Định nghĩa kiểu dữ liệu ngắn gọn để tránh lỗi ngoặc nhọn lồng nhau
typedef JsonMap = Map<String, dynamic>;

// Controller quản lý trạng thái tải dữ liệu, tìm kiếm và lọc bộ đề
class ExamController extends ChangeNotifier {
  final _supabase = Supabase.instance.client;

  List<JsonMap> subjects = []; // Danh sách môn học để tạo thanh lọc
  List<ExamModel> _allExams = []; // Toàn bộ đề thi tải từ Supabase

  bool isLoading = false;
  String? errorMessage;

  // Biến trạng thái bộ lọc hiện tại
  String searchQuery = '';
  String? selectedSubjectId; // null tương ứng với chọn "Tất cả"

  // Danh sách đề thi sau khi lọc kết hợp (Môn học + Từ khóa tìm kiếm)
  List<ExamModel> get filteredExams {
    final query = searchQuery.trim().toLowerCase();
    return _allExams.where((exam) {
      // 1. Kiểm tra điều kiện môn học
      final matchSubject =
          selectedSubjectId == null || exam.monHocId == selectedSubjectId;

      // 2. Kiểm tra điều kiện từ khóa (tìm theo tên đề hoặc tên môn)
      final matchSearch = query.isEmpty ||
          exam.tenDe.toLowerCase().contains(query) ||
          exam.tenMon.toLowerCase().contains(query);

      return matchSubject && matchSearch;
    }).toList();
  }

  // Tải song song danh sách môn học và đề thi từ Supabase
  Future<void> loadData() async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      final results = await Future.wait([
        _supabase.from('mon_hoc').select('id, ten_mon').order('ten_mon'),
        _supabase
            .from('de_thi')
            .select('*, mon_hoc(id, ten_mon)')
            .order('tieu_de'),
      ]);

      subjects = List<JsonMap>.from(results[0]);
      final rawExams = List<JsonMap>.from(results[1]);
      _allExams = rawExams.map((e) => ExamModel.fromJson(e)).toList();
    } catch (e) {
      errorMessage = 'Lỗi tải dữ liệu: $e';
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  // Cập nhật từ khóa tìm kiếm khi người dùng gõ
  void setSearchQuery(String value) {
    searchQuery = value;
    notifyListeners();
  }

  // Chọn hoặc bỏ chọn môn học trên thanh lọc
  void selectSubject(String? subjectId) {
    selectedSubjectId = (selectedSubjectId == subjectId) ? null : subjectId;
    notifyListeners();
  }

  // Xóa toàn bộ bộ lọc về mặc định
  void clearFilters() {
    searchQuery = '';
    selectedSubjectId = null;
    notifyListeners();
  }
}