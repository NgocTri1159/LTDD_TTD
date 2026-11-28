/// Model ánh xạ bảng public.loai_cau_hoi trong Supabase.
class QuestionTypeModel {
  final String id;
  final String maLoai; // VD: 'trac_nghiem', 'dung_sai', 'dien_khuyet'
  final String tenLoai; // VD: 'Trắc nghiệm 1 đáp án'
  final String? moTa;

  const QuestionTypeModel({
    required this.id,
    required this.maLoai,
    required this.tenLoai,
    this.moTa,
  });

  factory QuestionTypeModel.fromJson(Map<String, dynamic> json) {
    return QuestionTypeModel(
      id: json['id'] as String? ?? '',
      maLoai: json['ma_loai'] as String? ?? '',
      tenLoai: json['ten_loai'] as String? ?? '',
      moTa: json['mo_ta'] as String?,
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