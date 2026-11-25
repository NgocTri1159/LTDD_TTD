/// Model thành viên phòng thi (bảng public.thanh_vien_phong)
class RoomMemberModel {
  final String id;
  final String phongThiId;
  final String nguoiDungId;
  final String vaiTro; // 'host', 'participant'
  final String trangThai; // 'dang_tham_gia', 'da_roi', 'bi_loai'
  final double diem;
  final DateTime? thamGiaLuc;
  final DateTime? roiLuc;

  // Joined user info
  final String? hoTen;
  final String? anhDaiDienUrl;

  const RoomMemberModel({
    required this.id,
    required this.phongThiId,
    required this.nguoiDungId,
    this.vaiTro = 'participant',
    this.trangThai = 'dang_tham_gia',
    this.diem = 0.0,
    this.thamGiaLuc,
    this.roiLuc,
    this.hoTen,
    this.anhDaiDienUrl,
  });

  bool get isHost => vaiTro == 'host';

  factory RoomMemberModel.fromJson(Map<String, dynamic> json) {
    String? name;
    String? avatar;
    if (json['nguoi_dung'] is Map) {
      final user = json['nguoi_dung'] as Map;
      name = user['ho_ten'] as String?;
      avatar = user['anh_dai_dien_url'] as String?;
    }

    return RoomMemberModel(
      id: json['id'] as String? ?? '',
      phongThiId: json['phong_thi_id'] as String? ?? '',
      nguoiDungId: json['nguoi_dung_id'] as String? ?? '',
      vaiTro: json['vai_tro'] as String? ?? 'participant',
      trangThai: json['trang_thai'] as String? ?? 'dang_tham_gia',
      diem: (json['diem'] as num?)?.toDouble() ?? 0.0,
      thamGiaLuc: json['tham_gia_luc'] != null
          ? DateTime.tryParse(json['tham_gia_luc'].toString())
          : null,
      roiLuc: json['roi_luc'] != null
          ? DateTime.tryParse(json['roi_luc'].toString())
          : null,
      hoTen: name,
      anhDaiDienUrl: avatar,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id.isNotEmpty) 'id': id,
      'phong_thi_id': phongThiId,
      'nguoi_dung_id': nguoiDungId,
      'vai_tro': vaiTro,
      'trang_thai': trangThai,
      'diem': diem,
    };
  }
}

/// Model phòng thi trực tuyến (bảng public.phong_thi)
class ExamRoomModel {
  final String id;
  final String maPhong;
  final String? deThiId;
  final String cheDoChoiId;
  final String chuPhongId;
  final String? matKhauHash;
  final int soNguoiToiDa;
  final String trangThai; // 'cho', 'dang_choi', 'ket_thuc', 'da_huy'
  final Map<String, dynamic> cauHinh;
  final DateTime? batDauLuc;
  final DateTime? ketThucLuc;
  final DateTime? ngayTao;

  // Joined info
  final List<RoomMemberModel> danhSachThanhVien;
  final String? tenDeThi;
  final String? tenCheDoChoi;

  const ExamRoomModel({
    required this.id,
    required this.maPhong,
    this.deThiId,
    required this.cheDoChoiId,
    required this.chuPhongId,
    this.matKhauHash,
    this.soNguoiToiDa = 20,
    this.trangThai = 'cho',
    this.cauHinh = const {},
    this.batDauLuc,
    this.ketThucLuc,
    this.ngayTao,
    this.danhSachThanhVien = const [],
    this.tenDeThi,
    this.tenCheDoChoi,
  });

  bool get isWaiting => trangThai == 'cho';
  bool get isPlaying => trangThai == 'dang_choi';
  bool get hasPassword => matKhauHash != null && matKhauHash!.isNotEmpty;

  factory ExamRoomModel.fromJson(Map<String, dynamic> json) {
    List<RoomMemberModel> members = [];
    if (json['thanh_vien_phong'] is List) {
      members = (json['thanh_vien_phong'] as List)
          .map((m) => RoomMemberModel.fromJson(Map<String, dynamic>.from(m as Map)))
          .toList();
    }

    String? examName;
    if (json['de_thi'] is Map) {
      examName = json['de_thi']['tieu_de'] as String?;
    }

    String? modeName;
    if (json['che_do_choi'] is Map) {
      modeName = json['che_do_choi']['ten_che_do'] as String?;
    }

    return ExamRoomModel(
      id: json['id'] as String? ?? '',
      maPhong: json['ma_phong'] as String? ?? '',
      deThiId: json['de_thi_id'] as String?,
      cheDoChoiId: json['che_do_choi_id'] as String? ?? '',
      chuPhongId: json['chu_phong_id'] as String? ?? '',
      matKhauHash: json['mat_khau_hash'] as String?,
      soNguoiToiDa: (json['so_nguoi_toi_da'] as num?)?.toInt() ?? 20,
      trangThai: json['trang_thai'] as String? ?? 'cho',
      cauHinh: json['cau_hinh'] is Map<String, dynamic>
          ? Map<String, dynamic>.from(json['cau_hinh'] as Map)
          : {},
      batDauLuc: json['bat_dau_luc'] != null
          ? DateTime.tryParse(json['bat_dau_luc'].toString())
          : null,
      ketThucLuc: json['ket_thuc_luc'] != null
          ? DateTime.tryParse(json['ket_thuc_luc'].toString())
          : null,
      ngayTao: json['ngay_tao'] != null
          ? DateTime.tryParse(json['ngay_tao'].toString())
          : null,
      danhSachThanhVien: members,
      tenDeThi: examName,
      tenCheDoChoi: modeName,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id.isNotEmpty) 'id': id,
      'ma_phong': maPhong,
      if (deThiId != null) 'de_thi_id': deThiId,
      'che_do_choi_id': cheDoChoiId,
      'chu_phong_id': chuPhongId,
      if (matKhauHash != null) 'mat_khau_hash': matKhauHash,
      'so_nguoi_toi_da': soNguoiToiDa,
      'trang_thai': trangThai,
      'cau_hinh': cauHinh,
    };
  }
}
