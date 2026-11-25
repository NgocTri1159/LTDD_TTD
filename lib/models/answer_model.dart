/// Model ánh xạ bảng public.dap_an trong Supabase.
class AnswerModel {
  final String id;
  final String cauHoiId;
  final String noiDung;
  final String? hinhAnhUrl;
  final bool laDung; // Lưu ý: khi gửi câu hỏi cho thí sinh làm bài, trường này không được lộ.
  final int thuTu;
  final Map<String, dynamic> duLieuBoSung;
  final DateTime? ngayTao;

  const AnswerModel({
    required this.id,
    required this.cauHoiId,
    required this.noiDung,
    this.hinhAnhUrl,
    this.laDung = false,
    this.thuTu = 1,
    this.duLieuBoSung = const {},
    this.ngayTao,
  });

  factory AnswerModel.fromJson(Map<String, dynamic> json) {
    return AnswerModel(
      id: json['id'] as String? ?? '',
      cauHoiId: json['cau_hoi_id'] as String? ?? '',
      noiDung: json['noi_dung'] as String? ?? '',
      hinhAnhUrl: json['hinh_anh_url'] as String?,
      laDung: json['la_dung'] as bool? ?? false,
      thuTu: (json['thu_tu'] as num?)?.toInt() ?? 1,
      duLieuBoSung: json['du_lieu_bo_sung'] is Map<String, dynamic>
          ? Map<String, dynamic>.from(json['du_lieu_bo_sung'] as Map)
          : {},
      ngayTao: json['ngay_tao'] != null
          ? DateTime.tryParse(json['ngay_tao'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id.isNotEmpty) 'id': id,
      'cau_hoi_id': cauHoiId,
      'noi_dung': noiDung,
      'hinh_anh_url': hinhAnhUrl,
      'la_dung': laDung,
      'thu_tu': thuTu,
      'du_lieu_bo_sung': duLieuBoSung,
    };
  }
}
