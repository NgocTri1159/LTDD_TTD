
import 'dart:convert';

import '../models/subject_model.dart';
import 'backend_service.dart';

class SubjectService {
  static const String _endpoint = '/api/subjects';

  /// Kiểm tra phản hồi từ Backend.
  static Map<String, dynamic> _parseResponse(dynamic response) {
    final Map<String, dynamic> result =
        jsonDecode(response.body) as Map<String, dynamic>;

    if (response.statusCode < 200 ||
        response.statusCode >= 300 ||
        result['success'] != true) {
      throw Exception(
        result['message'] ?? 'Có lỗi xảy ra khi xử lý môn học.',
      );
    }

    return result;
  }

  /// Lấy danh sách môn học.
  /// User: chỉ nhận môn học đang hoạt động.
  /// Admin: nhận tất cả môn học.
  static Future<List<SubjectModel>> getAllSubjects() async {
    final response = await BackendService.get(_endpoint);
    final result = _parseResponse(response);

    final data = result['data'] as List<dynamic>? ?? [];

    return data
        .map(
          (item) => SubjectModel.fromJson(
            item as Map<String, dynamic>,
          ),
        )
        .toList();
  }

  /// Lấy chi tiết môn học theo ID.
  static Future<SubjectModel> getSubjectById(String id) async {
    final response = await BackendService.get('$_endpoint/$id');
    final result = _parseResponse(response);

    return SubjectModel.fromJson(
      result['data'] as Map<String, dynamic>,
    );
  }

  /// Tạo môn học mới (Admin).
  static Future<SubjectModel> createSubject({
    required String tenMon,
    String? moTa,
    String? bieuTuong,
    String? mauSac,
    int thuTuHienThi = 0,
    bool trangThai = true,
  }) async {
    final payload = {
      'ten_mon': tenMon.trim(),
      'mo_ta': moTa,
      'bieu_tuong': bieuTuong,
      'mau_sac': mauSac,
      'thu_tu_hien_thi': thuTuHienThi,
      'trang_thai': trangThai,
    };

    final response = await BackendService.post(
      _endpoint,
      body: jsonEncode(payload),
    );

    final result = _parseResponse(response);

    return SubjectModel.fromJson(
      result['data'] as Map<String, dynamic>,
    );
  }

  /// Cập nhật môn học (Admin).
  static Future<SubjectModel> updateSubject(
    String id, {
    required String tenMon,
    String? moTa,
    String? bieuTuong,
    String? mauSac,
    required int thuTuHienThi,
    required bool trangThai,
  }) async {
    final payload = {
      'ten_mon': tenMon.trim(),
      'mo_ta': moTa,
      'bieu_tuong': bieuTuong,
      'mau_sac': mauSac,
      'thu_tu_hien_thi': thuTuHienThi,
      'trang_thai': trangThai,
    };

    final response = await BackendService.put(
      '$_endpoint/$id',
      body: jsonEncode(payload),
    );

    final result = _parseResponse(response);

    return SubjectModel.fromJson(
      result['data'] as Map<String, dynamic>,
    );
  }

  /// Khóa hoặc mở môn học (Admin).
  static Future<SubjectModel> updateSubjectStatus(
    String id,
    bool trangThai,
  ) async {
    final payload = {
      'trang_thai': trangThai,
    };

    final response = await BackendService.patch(
      '$_endpoint/$id/status',
      body: jsonEncode(payload),
    );

    final result = _parseResponse(response);

    return SubjectModel.fromJson(
      result['data'] as Map<String, dynamic>,
    );
  }
}
