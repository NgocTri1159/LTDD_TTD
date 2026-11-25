import 'answer_model.dart';
import 'question_type_model.dart';

/// Model ánh xạ bảng public.cau_hoi trong Supabase.
class QuestionModel {
  final String id;
  final String? deThiId;
  final String? monHocId;
  final String loaiCauHoiId;
  final String noiDung;
  final String? giaiThich;
  final String? hinhAnhUrl;
  final String? amThanhUrl;
  final double diem;
  final int? thoiGianGiay;
  final int thuTu;
  final String mucDo;
  final bool daLuuTru;
  final Map<String, dynamic> duLieuBoSung;
  final DateTime? ngayTao;

  final List<AnswerModel> danhSachDapAn;
  final QuestionTypeModel? loaiCauHoi;

  const QuestionModel({
    required this.id,
    this.deThiId,
    this.monHocId,
    required this.loaiCauHoiId,
    required this.noiDung,
    this.giaiThich,
    this.hinhAnhUrl,
    this.amThanhUrl,
    this.diem = 1.0,
    this.thoiGianGiay,
    this.thuTu = 1,
    this.mucDo = 'trung_binh',
    this.daLuuTru = false,
    this.duLieuBoSung = const {},
    this.ngayTao,
    this.danhSachDapAn = const [],
    this.loaiCauHoi,
  });

  factory QuestionModel.fromJson(Map<String, dynamic> json) {
    List<AnswerModel> answers = [];

    if (json['dap_an'] is List) {
      answers =
          (json['dap_an'] as List)
              .map(
                (item) => AnswerModel.fromJson(
                  Map<String, dynamic>.from(item as Map),
                ),
              )
              .toList()
            ..sort((a, b) => a.thuTu.compareTo(b.thuTu));
    }

    QuestionTypeModel? type;
    if (json['loai_cau_hoi'] is Map) {
      type = QuestionTypeModel.fromJson(
        Map<String, dynamic>.from(json['loai_cau_hoi'] as Map),
      );
    }

    return QuestionModel(
      id: json['id'] as String? ?? '',
      deThiId: json['de_thi_id'] as String?,
      monHocId: json['mon_hoc_id'] as String?,
      loaiCauHoiId: json['loai_cau_hoi_id'] as String? ?? '',
      noiDung: json['noi_dung'] as String? ?? '',
      giaiThich: json['giai_thich'] as String?,
      hinhAnhUrl: json['hinh_anh_url'] as String?,
      amThanhUrl: json['am_thanh_url'] as String?,
      diem: (json['diem'] as num?)?.toDouble() ?? 1.0,
      thoiGianGiay: (json['thoi_gian_giay'] as num?)?.toInt(),
      thuTu: (json['thu_tu'] as num?)?.toInt() ?? 1,
      mucDo: json['muc_do'] as String? ?? 'trung_binh',
      daLuuTru: json['da_luu_tru'] as bool? ?? false,
      duLieuBoSung: json['du_lieu_bo_sung'] is Map
          ? Map<String, dynamic>.from(json['du_lieu_bo_sung'] as Map)
          : {},
      ngayTao: json['ngay_tao'] != null
          ? DateTime.tryParse(json['ngay_tao'].toString())
          : null,
      danhSachDapAn: answers,
      loaiCauHoi: type,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id.isNotEmpty) 'id': id,
      'de_thi_id': deThiId,
      'mon_hoc_id': monHocId,
      'loai_cau_hoi_id': loaiCauHoiId,
      'noi_dung': noiDung,
      'giai_thich': giaiThich,
      'hinh_anh_url': hinhAnhUrl,
      'am_thanh_url': amThanhUrl,
      'diem': diem,
      'thoi_gian_giay': thoiGianGiay,
      'thu_tu': thuTu,
      'muc_do': mucDo,
      'da_luu_tru': daLuuTru,
      'du_lieu_bo_sung': duLieuBoSung,
    };
  }

  QuestionModel copyWith({
    String? noiDung,
    String? giaiThich,
    String? hinhAnhUrl,
    String? amThanhUrl,
    double? diem,
    int? thoiGianGiay,
    int? thuTu,
    String? mucDo,
    String? monHocId,
    bool? daLuuTru,
    List<AnswerModel>? danhSachDapAn,
  }) {
    return QuestionModel(
      id: id,
      deThiId: deThiId,
      monHocId: monHocId ?? this.monHocId,
      loaiCauHoiId: loaiCauHoiId,
      noiDung: noiDung ?? this.noiDung,
      giaiThich: giaiThich ?? this.giaiThich,
      hinhAnhUrl: hinhAnhUrl ?? this.hinhAnhUrl,
      amThanhUrl: amThanhUrl ?? this.amThanhUrl,
      diem: diem ?? this.diem,
      thoiGianGiay: thoiGianGiay ?? this.thoiGianGiay,
      thuTu: thuTu ?? this.thuTu,
      mucDo: mucDo ?? this.mucDo,
      daLuuTru: daLuuTru ?? this.daLuuTru,
      duLieuBoSung: duLieuBoSung,
      ngayTao: ngayTao,
      danhSachDapAn: danhSachDapAn ?? this.danhSachDapAn,
      loaiCauHoi: loaiCauHoi,
    );
  }
}
