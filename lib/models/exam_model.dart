/// Model ánh xạ bảng public.de_thi trong Supabase.
class ExamModel {
  final String id;
  final String monHocId;
  final String? nguoiTaoId;
  final String tieuDe;
  final String? moTa;
  final String? anhBiaUrl;
  final String mucDo; // 'de', 'trung_binh', 'kho'
  final int thoiGianLamBaiGiay;
  final int? soLanLamToiDa;
  final bool congKhai;
  final String trangThai; // 'nhap', 'da_xuat_ban', 'da_an'
  final DateTime? ngayTao;
  final DateTime? capNhatLuc;

  // Dữ liệu mở rộng từ join truy vấn
  final String? tenMonHoc;
  final int? soLuongCauHoi;

  const ExamModel({
    required this.id,
    required this.monHocId,
    this.nguoiTaoId,
    required this.tieuDe,
    this.moTa,
    this.anhBiaUrl,
    this.mucDo = 'trung_binh',
    this.thoiGianLamBaiGiay = 1800,
    this.soLanLamToiDa,
    this.congKhai = false,
    this.trangThai = 'nhap',
    this.ngayTao,
    this.capNhatLuc,
    this.tenMonHoc,
    this.soLuongCauHoi,
  });

  bool get isPublished => trangThai == 'da_xuat_ban';
  int get thoiGianPhut => (thoiGianLamBaiGiay / 60).round();

  String get mucDoDisplay {
    switch (mucDo) {
      case 'de':
        return 'Dễ';
      case 'kho':
        return 'Khó';
      case 'trung_binh':
      default:
        return 'Trung bình';
    }
  }

  factory ExamModel.fromJson(Map<String, dynamic> json) {
    // Xử lý join mon_hoc nếu có
    String? subjectName;
    if (json['mon_hoc'] is Map) {
      subjectName = json['mon_hoc']['ten_mon'] as String?;
    } else if (json['ten_mon'] != null) {
      subjectName = json['ten_mon'] as String?;
    }

    // Xử lý số lượng câu hỏi từ join hoặc count
    int? count;
    if (json['cau_hoi'] is List) {
      count = (json['cau_hoi'] as List).length;
    } else if (json['so_luong_cau_hoi'] != null) {
      count = (json['so_luong_cau_hoi'] as num?)?.toInt();
    }

    return ExamModel(
      id: json['id'] as String? ?? '',
      monHocId: json['mon_hoc_id'] as String? ?? '',
      nguoiTaoId: json['nguoi_tao_id'] as String?,
      tieuDe: json['tieu_de'] as String? ?? '',
      moTa: json['mo_ta'] as String?,
      anhBiaUrl: json['anh_bia_url'] as String?,
      mucDo: json['muc_do'] as String? ?? 'trung_binh',
      thoiGianLamBaiGiay:
          (json['thoi_gian_lam_bai_giay'] as num?)?.toInt() ?? 1800,
      soLanLamToiDa: (json['so_lan_lam_toi_da'] as num?)?.toInt(),
      congKhai: json['cong_khai'] as bool? ?? false,
      trangThai: json['trang_thai'] as String? ?? 'nhap',
      ngayTao: json['ngay_tao'] != null
          ? DateTime.tryParse(json['ngay_tao'].toString())
          : null,
      capNhatLuc: json['cap_nhat_luc'] != null
          ? DateTime.tryParse(json['cap_nhat_luc'].toString())
          : null,
      tenMonHoc: subjectName,
      soLuongCauHoi: count,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id.isNotEmpty) 'id': id,
      'mon_hoc_id': monHocId,
      if (nguoiTaoId != null) 'nguoi_tao_id': nguoiTaoId,
      'tieu_de': tieuDe,
      'mo_ta': moTa,
      'anh_bia_url': anhBiaUrl,
      'muc_do': mucDo,
      'thoi_gian_lam_bai_giay': thoiGianLamBaiGiay,
      'so_lan_lam_toi_da': soLanLamToiDa,
      'cong_khai': congKhai,
      'trang_thai': trangThai,
    };
  }
}
