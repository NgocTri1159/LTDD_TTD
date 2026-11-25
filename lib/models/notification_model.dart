/// Model ánh xạ bảng public.thong_bao trong Supabase.
class NotificationModel {
  final String id;
  final String nguoiDungId;
  final String tieuDe;
  final String noiDung;
  final String loai;
  final String? duongDanDich;
  final bool daDoc;
  final DateTime? ngayTao;

  const NotificationModel({
    required this.id,
    required this.nguoiDungId,
    required this.tieuDe,
    required this.noiDung,
    this.loai = 'he_thong',
    this.duongDanDich,
    this.daDoc = false,
    this.ngayTao,
  });

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    return NotificationModel(
      id: json['id'] as String? ?? '',
      nguoiDungId: json['nguoi_dung_id'] as String? ?? '',
      tieuDe: json['tieu_de'] as String? ?? '',
      noiDung: json['noi_dung'] as String? ?? '',
      loai: json['loai'] as String? ?? 'he_thong',
      duongDanDich: json['duong_dan_dich'] as String?,
      daDoc: json['da_doc'] as bool? ?? false,
      ngayTao: json['ngay_tao'] != null
          ? DateTime.tryParse(json['ngay_tao'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id.isNotEmpty) 'id': id,
      'nguoi_dung_id': nguoiDungId,
      'tieu_de': tieuDe,
      'noi_dung': noiDung,
      'loai': loai,
      if (duongDanDich != null) 'duong_dan_dich': duongDanDich,
      'da_doc': daDoc,
    };
  }

  NotificationModel copyWith({
    bool? daDoc,
  }) {
    return NotificationModel(
      id: id,
      nguoiDungId: nguoiDungId,
      tieuDe: tieuDe,
      noiDung: noiDung,
      loai: loai,
      duongDanDich: duongDanDich,
      daDoc: daDoc ?? this.daDoc,
      ngayTao: ngayTao,
    );
  }
}
