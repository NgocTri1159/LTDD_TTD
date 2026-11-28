/// Model ánh xạ bảng public.dap_an trong Supabase.
class AnswerModel {
  final String id;
  final String cauHoiId;
  final String noiDung;
  final bool laDapAnDung;
  final int thuTu;

  const AnswerModel({
    required this.id,
    required this.cauHoiId,
    required this.noiDung,
    this.laDapAnDung = false,
    this.thuTu = 1,
  });

  factory AnswerModel.fromJson(Map<String, dynamic> json) {
    return AnswerModel(
      id: json['id'] as String? ?? '',
      cauHoiId: json['cau_hoi_id'] as String? ?? '',
      noiDung: json['noi_dung'] as String? ?? '',
      laDapAnDung: json['la_dap_an_dung'] as bool? ?? false,
      thuTu: (json['thu_tu'] as num?)?.toInt() ?? 1,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id.isNotEmpty) 'id': id,
      'cau_hoi_id': cauHoiId,
      'noi_dung': noiDung,
      'la_dap_an_dung': laDapAnDung,
      'thu_tu': thuTu,
    };
  }
}