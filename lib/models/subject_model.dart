
/// Model ánh xạ bảng public.mon_hoc trong Supabase.
class SubjectModel {
  final String id;
  final String tenMon;
  final String? moTa;
  final String? bieuTuong;
  final String? mauSac;
  final int thuTuHienThi;
  final bool trangThai;
  final String? nguoiTaoId;
  final DateTime ngayTao;

  const SubjectModel({
    required this.id,
    required this.tenMon,
    this.moTa,
    this.bieuTuong,
    this.mauSac,
    this.thuTuHienThi = 0,
    this.trangThai = true,
    this.nguoiTaoId,
    required this.ngayTao,
  });

  factory SubjectModel.fromJson(Map<String, dynamic> json) {
    return SubjectModel(
      id: json['id'] as String,
      tenMon: json['ten_mon'] as String,
      moTa: json['mo_ta'] as String?,
      bieuTuong: json['bieu_tuong'] as String?,
      mauSac: json['mau_sac'] as String?,
      thuTuHienThi: (json['thu_tu_hien_thi'] as num).toInt(),
      trangThai: json['trang_thai'] as bool,
      nguoiTaoId: json['nguoi_tao_id'] as String?,
      ngayTao: DateTime.parse(json['ngay_tao'] as String),
    );
  }

  /// Chuyển Model thành dữ liệu đầy đủ.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'ten_mon': tenMon,
      'mo_ta': moTa,
      'bieu_tuong': bieuTuong,
      'mau_sac': mauSac,
      'thu_tu_hien_thi': thuTuHienThi,
      'trang_thai': trangThai,
      'nguoi_tao_id': nguoiTaoId,
      'ngay_tao': ngayTao.toIso8601String(),
    };
  }

  /// Dữ liệu INSERT, để Supabase tự sinh id và ngay_tao.
  Map<String, dynamic> toInsertJson() {
    return {
      'ten_mon': tenMon,
      'mo_ta': moTa,
      'bieu_tuong': bieuTuong,
      'mau_sac': mauSac,
      'thu_tu_hien_thi': thuTuHienThi,
      'trang_thai': trangThai,
      if (nguoiTaoId != null) 'nguoi_tao_id': nguoiTaoId,
    };
  }

  SubjectModel copyWith({
    String? tenMon,
    String? moTa,
    String? bieuTuong,
    String? mauSac,
    int? thuTuHienThi,
    bool? trangThai,
  }) {
    return SubjectModel(
      id: id,
      tenMon: tenMon ?? this.tenMon,
      moTa: moTa ?? this.moTa,
      bieuTuong: bieuTuong ?? this.bieuTuong,
      mauSac: mauSac ?? this.mauSac,
      thuTuHienThi: thuTuHienThi ?? this.thuTuHienThi,
      trangThai: trangThai ?? this.trangThai,
      nguoiTaoId: nguoiTaoId,
      ngayTao: ngayTao,
    );
  }
}
