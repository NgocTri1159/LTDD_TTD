/// Model ánh xạ bảng public.loai_cau_hoi trong Supabase.
class QuestionTypeModel {
  final String id;
  final String maLoai;
  final String tenLoai;
  final String? moTa;
  final DateTime? ngayTao;

  const QuestionTypeModel({
    required this.id,
    required this.maLoai,
    required this.tenLoai,
    this.moTa,
    this.ngayTao,
  });

  factory QuestionTypeModel.fromJson(Map<String, dynamic> json) {
    return QuestionTypeModel(
      id: json['id'] as String? ?? '',
      maLoai: json['ma_loai'] as String? ?? '',
      tenLoai: json['ten_loai'] as String? ?? '',
      moTa: json['mo_ta'] as String?,
      ngayTao: json['ngay_tao'] != null
          ? DateTime.tryParse(json['ngay_tao'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id.isNotEmpty) 'id': id,
      'ma_loai': maLoai,
      'ten_loai': tenLoai,
      'mo_ta': moTa,
    };
  }
}
