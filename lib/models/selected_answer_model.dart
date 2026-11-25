


class SelectedAnswerModel {
  final String id;
  final String chiTietLamBaiId;
  final String? dapAnId;
  final String? noiDungTraLoi;
  final double? giaTriSo;
  final int thuTuLuaChon; // NOT NULL, default 1 in DB
  final DateTime ngayTao;

  const SelectedAnswerModel({
    required this.id,
    required this.chiTietLamBaiId,
    this.dapAnId,
    this.noiDungTraLoi,
    this.giaTriSo,
    required this.thuTuLuaChon,
    required this.ngayTao,
  });

  factory SelectedAnswerModel.fromJson(Map<String, dynamic> json) {
    return SelectedAnswerModel(
      id: json['id'] as String,
      chiTietLamBaiId: json['chi_tiet_lam_bai_id'] as String,
      dapAnId: json['dap_an_id'] as String?,
      noiDungTraLoi: json['noi_dung_tra_loi'] as String?,
      giaTriSo: (json['gia_tri_so'] as num?)?.toDouble(),
      thuTuLuaChon: (json['thu_tu_lua_chon'] as num).toInt(),
      ngayTao: DateTime.parse(json['ngay_tao'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'chi_tiet_lam_bai_id': chiTietLamBaiId,
      if (dapAnId != null) 'dap_an_id': dapAnId,
      if (noiDungTraLoi != null) 'noi_dung_tra_loi': noiDungTraLoi,
      if (giaTriSo != null) 'gia_tri_so': giaTriSo,
      'thu_tu_lua_chon': thuTuLuaChon,
      'ngay_tao': ngayTao.toIso8601String(),
    };
  }

  /// JSON for INSERT – excludes fields with DB defaults (id, ngay_tao, thu_tu_lua_chon).
  Map<String, dynamic> toInsertJson() {
    return {
      'chi_tiet_lam_bai_id': chiTietLamBaiId,
      if (dapAnId != null) 'dap_an_id': dapAnId,
      if (noiDungTraLoi != null) 'noi_dung_tra_loi': noiDungTraLoi,
      if (giaTriSo != null) 'gia_tri_so': giaTriSo,
    };
  }
}
