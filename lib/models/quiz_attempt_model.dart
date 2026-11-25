/// Model ánh xạ bảng public.lan_lam_bai trong Supabase.
class QuizAttemptModel {
  final String id;
  final String nguoiDungId;
  final String deThiId;
  final String cheDoChoiId;
  final String? phongThiId;
  final double tongDiem;
  final int soCauDung;
  final int soCauSai;
  final int tongSoCau;
  final int thoiGianLamBaiGiay;
  final String trangThai; // 'dang_lam', 'hoan_thanh', 'qua_gio', 'da_huy'
  final DateTime? batDauLuc;
  final DateTime? ketThucLuc;

  // Dữ liệu mở rộng từ join truy vấn
  final String? tenDeThi;
  final String? tenMonHoc;
  final String? anhBiaUrl;
  final String? tenCheDoChoi;

  const QuizAttemptModel({
    required this.id,
    required this.nguoiDungId,
    required this.deThiId,
    required this.cheDoChoiId,
    this.phongThiId,
    this.tongDiem = 0.0,
    this.soCauDung = 0,
    this.soCauSai = 0,
    this.tongSoCau = 0,
    this.thoiGianLamBaiGiay = 0,
    this.trangThai = 'dang_lam',
    this.batDauLuc,
    this.ketThucLuc,
    this.tenDeThi,
    this.tenMonHoc,
    this.anhBiaUrl,
    this.tenCheDoChoi,
  });

  bool get isCompleted => trangThai == 'hoan_thanh';
  int get soCauChuaLam => (tongSoCau - (soCauDung + soCauSai)).clamp(0, tongSoCau);
  double get tyLeChinhXac =>
      tongSoCau > 0 ? ((soCauDung / tongSoCau) * 100).clamp(0.0, 100.0) : 0.0;

  String get formattedTimeSpent {
    final minutes = thoiGianLamBaiGiay ~/ 60;
    final seconds = thoiGianLamBaiGiay % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  factory QuizAttemptModel.fromJson(Map<String, dynamic> json) {
    String? examTitle;
    String? subjectTitle;
    String? coverUrl;

    if (json['de_thi'] is Map) {
      final exam = json['de_thi'] as Map;
      examTitle = exam['tieu_de'] as String?;
      coverUrl = exam['anh_bia_url'] as String?;
      if (exam['mon_hoc'] is Map) {
        subjectTitle = exam['mon_hoc']['ten_mon'] as String?;
      }
    }

    String? modeTitle;
    if (json['che_do_choi'] is Map) {
      modeTitle = json['che_do_choi']['ten_che_do'] as String?;
    }

    return QuizAttemptModel(
      id: json['id'] as String? ?? '',
      nguoiDungId: json['nguoi_dung_id'] as String? ?? '',
      deThiId: json['de_thi_id'] as String? ?? '',
      cheDoChoiId: json['che_do_choi_id'] as String? ?? '',
      phongThiId: json['phong_thi_id'] as String?,
      tongDiem: (json['tong_diem'] as num?)?.toDouble() ?? 0.0,
      soCauDung: (json['so_cau_dung'] as num?)?.toInt() ?? 0,
      soCauSai: (json['so_cau_sai'] as num?)?.toInt() ?? 0,
      tongSoCau: (json['tong_so_cau'] as num?)?.toInt() ?? 0,
      thoiGianLamBaiGiay:
          (json['thoi_gian_lam_bai_giay'] as num?)?.toInt() ?? 0,
      trangThai: json['trang_thai'] as String? ?? 'dang_lam',
      batDauLuc: json['bat_dau_luc'] != null
          ? DateTime.tryParse(json['bat_dau_luc'].toString())
          : null,
      ketThucLuc: json['ket_thuc_luc'] != null
          ? DateTime.tryParse(json['ket_thuc_luc'].toString())
          : null,
      tenDeThi: examTitle,
      tenMonHoc: subjectTitle,
      anhBiaUrl: coverUrl,
      tenCheDoChoi: modeTitle,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id.isNotEmpty) 'id': id,
      'nguoi_dung_id': nguoiDungId,
      'de_thi_id': deThiId,
      'che_do_choi_id': cheDoChoiId,
      if (phongThiId != null) 'phong_thi_id': phongThiId,
      'tong_diem': tongDiem,
      'so_cau_dung': soCauDung,
      'so_cau_sai': soCauSai,
      'tong_so_cau': tongSoCau,
      'thoi_gian_lam_bai_giay': thoiGianLamBaiGiay,
      'trang_thai': trangThai,
      if (batDauLuc != null) 'bat_dau_luc': batDauLuc!.toIso8601String(),
      if (ketThucLuc != null) 'ket_thuc_luc': ketThucLuc!.toIso8601String(),
    };
  }
}
