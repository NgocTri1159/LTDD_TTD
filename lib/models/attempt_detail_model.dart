import 'question_model.dart';

/// Model ánh xạ bảng public.dap_an_da_chon trong Supabase.
class SelectedAnswerModel {
  final String id;
  final String chiTietLamBaiId;
  final String? dapAnId;
  final String? noiDungTraLoi;
  final double? giaTriSo;
  final int thuTuLuaChon;
  final DateTime? ngayTao;

  const SelectedAnswerModel({
    required this.id,
    required this.chiTietLamBaiId,
    this.dapAnId,
    this.noiDungTraLoi,
    this.giaTriSo,
    this.thuTuLuaChon = 1,
    this.ngayTao,
  });

  factory SelectedAnswerModel.fromJson(Map<String, dynamic> json) {
    return SelectedAnswerModel(
      id: json['id'] as String? ?? '',
      chiTietLamBaiId: json['chi_tiet_lam_bai_id'] as String? ?? '',
      dapAnId: json['dap_an_id'] as String?,
      noiDungTraLoi: json['noi_dung_tra_loi'] as String?,
      giaTriSo: (json['gia_tri_so'] as num?)?.toDouble(),
      thuTuLuaChon: (json['thu_tu_lua_chon'] as num?)?.toInt() ?? 1,
      ngayTao: json['ngay_tao'] != null
          ? DateTime.tryParse(json['ngay_tao'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id.isNotEmpty) 'id': id,
      'chi_tiet_lam_bai_id': chiTietLamBaiId,
      if (dapAnId != null) 'dap_an_id': dapAnId,
      if (noiDungTraLoi != null) 'noi_dung_tra_loi': noiDungTraLoi,
      if (giaTriSo != null) 'gia_tri_so': giaTriSo,
      'thu_tu_lua_chon': thuTuLuaChon,
    };
  }
}

/// Model ánh xạ bảng public.chi_tiet_lam_bai trong Supabase.
class AttemptDetailModel {
  final String id;
  final String lanLamBaiId;
  final String cauHoiId;
  final double diemDatDuoc;
  final bool? laDung;
  final int thoiGianTraLoiGiay;
  final int thuTu;

  // Danh sách đáp án người dùng đã chọn cho câu này
  final List<SelectedAnswerModel> danhSachDapAnDaChon;

  // Câu hỏi liên kết phục vụ xem lại (Review)
  final QuestionModel? cauHoi;

  const AttemptDetailModel({
    required this.id,
    required this.lanLamBaiId,
    required this.cauHoiId,
    this.diemDatDuoc = 0.0,
    this.laDung,
    this.thoiGianTraLoiGiay = 0,
    required this.thuTu,
    this.danhSachDapAnDaChon = const [],
    this.cauHoi,
  });

  factory AttemptDetailModel.fromJson(Map<String, dynamic> json) {
    List<SelectedAnswerModel> selected = [];
    if (json['dap_an_da_chon'] is List) {
      selected = (json['dap_an_da_chon'] as List)
          .map((item) => SelectedAnswerModel.fromJson(
                Map<String, dynamic>.from(item as Map),
              ))
          .toList();
    }

    QuestionModel? question;
    if (json['cau_hoi'] is Map) {
      question = QuestionModel.fromJson(
        Map<String, dynamic>.from(json['cau_hoi'] as Map),
      );
    }

    return AttemptDetailModel(
      id: json['id'] as String? ?? '',
      lanLamBaiId: json['lan_lam_bai_id'] as String? ?? '',
      cauHoiId: json['cau_hoi_id'] as String? ?? '',
      diemDatDuoc: (json['diem_dat_duoc'] as num?)?.toDouble() ?? 0.0,
      laDung: json['la_dung'] as bool?,
      thoiGianTraLoiGiay:
          (json['thoi_gian_tra_loi_giay'] as num?)?.toInt() ?? 0,
      thuTu: (json['thu_tu'] as num?)?.toInt() ?? 1,
      danhSachDapAnDaChon: selected,
      cauHoi: question,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id.isNotEmpty) 'id': id,
      'lan_lam_bai_id': lanLamBaiId,
      'cau_hoi_id': cauHoiId,
      'diem_dat_duoc': diemDatDuoc,
      'la_dung': laDung,
      'thoi_gian_tra_loi_giay': thoiGianTraLoiGiay,
      'thu_tu': thuTu,
    };
  }
}
