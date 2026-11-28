// Model ánh xạ dữ liệu từ bảng de_thi và mon_hoc trên Supabase
class ExamModel {
  final String id;
  final String monHocId;
  final String tenMon;
  final String tenDe;
  final String moTa;
  final int thoiGianPhut;
  final int soCauHoi;

  ExamModel({
    required this.id,
    required this.monHocId,
    required this.tenMon,
    required this.tenDe,
    required this.moTa,
    required this.thoiGianPhut,
    required this.soCauHoi,
  });

  // Chuyển đổi dữ liệu JSON từ Supabase sang đối tượng ExamModel
  factory ExamModel.fromJson(Map<String, dynamic> json) {
    final monHoc = json['mon_hoc'] as Map<String, dynamic>?;
    return ExamModel(
      id: (json['id'] ?? '').toString(),
      monHocId: (json['mon_hoc_id'] ?? '').toString(),
      tenMon: (monHoc?['ten_mon'] ?? 'Chưa phân loại').toString(),
      tenDe: (json['ten_de_thi'] ??
              json['tieu_de'] ??
              json['ten_de'] ??
              'Đề thi không tên')
          .toString(),
      moTa: (json['mo_ta'] ?? '').toString(),
      thoiGianPhut: _toInt(
        json['thoi_gian_lam_bai'] ?? json['thoi_gian'] ?? json['thoi_gian_phut'],
        15,
      ),
      soCauHoi: _toInt(
        json['so_cau_hoi'] ?? json['so_cau'] ?? json['so_luong_cau_hoi'],
        10,
      ),
    );
  }

  // Hàm phụ trợ ép kiểu số nguyên an toàn
  static int _toInt(dynamic value, int fallback) {
    if (value is int) return value;
    if (value is String) return int.tryParse(value) ?? fallback;
    return fallback;
  }
}