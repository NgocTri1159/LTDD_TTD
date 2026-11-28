class RoomModel {
  final String id;
  final String maPhong;
  final String tenPhong;
  final String deThiId;
  final String chuPhongId;
  final String tenChuPhong;
  final String trangThai; // waiting | playing | finished | cancelled
  final int thoiGianPhut;
  final String cheDo;
  final bool phongRieng;
  final int gioiHan;
  final bool daAn;
  final String tenBoDe;
  final String chuDe;
  final int soNguoiHienTai;

  const RoomModel({
    required this.id,
    required this.maPhong,
    required this.tenPhong,
    required this.deThiId,
    required this.chuPhongId,
    required this.tenChuPhong,
    required this.trangThai,
    required this.thoiGianPhut,
    this.cheDo = 'Tùy chỉnh',
    this.phongRieng = false,
    this.gioiHan = 8,
    this.daAn = false,
    this.tenBoDe = 'Bộ đề trắc nghiệm',
    this.chuDe = 'Tổng hợp',
    this.soNguoiHienTai = 0,
  });

  factory RoomModel.fromMap(Map<String, dynamic> map) {
    final deThi = map['de_thi'];
    String tenBoDe = (map['ten_phong'] ?? 'Bộ đề trắc nghiệm').toString();
    String chuDe = 'Tổng hợp';

    if (deThi is Map) {
      tenBoDe = (deThi['tieu_de'] ?? tenBoDe).toString();
      final monHoc = deThi['mon_hoc'];
      if (monHoc is Map && monHoc['ten_mon'] != null) {
        chuDe = monHoc['ten_mon'].toString();
      }
    }

    final members = map['phong_thi_thanh_vien'];
    final int count = members is List ? members.length : 0;

    return RoomModel(
      id: map['id'].toString(),
      maPhong: (map['ma_phong'] ?? '').toString(),
      tenPhong: (map['ten_phong'] ?? tenBoDe).toString(),
      deThiId: map['de_thi_id'].toString(),
      chuPhongId: (map['chu_phong_id'] ?? '').toString(),
      tenChuPhong: (map['ten_chu_phong'] ?? 'Player').toString(),
      trangThai: (map['trang_thai'] ?? 'waiting').toString(),
      thoiGianPhut: (map['thoi_gian_phut'] as num?)?.toInt() ?? 15,
      cheDo: (map['che_do'] ?? 'Tùy chỉnh').toString(),
      phongRieng: map['phong_rieng'] == true,
      gioiHan: (map['gioi_han'] as num?)?.toInt() ?? 8,
      daAn: map['da_an'] == true,
      tenBoDe: tenBoDe,
      chuDe: chuDe,
      soNguoiHienTai: count,
    );
  }
}

class RoomParticipantModel {
  final String id;
  final String phongThiId;
  final String userId;
  final String tenHienThi;
  final bool laChuPhong;
  final bool sanSang;
  final int diemSo;
  final int soCauDung;
  final int tongSoCau;
  final int thoiGianGiay;
  final String trangThai;

  const RoomParticipantModel({
    required this.id,
    required this.phongThiId,
    required this.userId,
    required this.tenHienThi,
    required this.laChuPhong,
    this.sanSang = false,
    required this.diemSo,
    required this.soCauDung,
    required this.tongSoCau,
    required this.thoiGianGiay,
    required this.trangThai,
  });

  factory RoomParticipantModel.fromMap(Map<String, dynamic> map) {
    return RoomParticipantModel(
      id: map['id'].toString(),
      phongThiId: map['phong_thi_id'].toString(),
      userId: (map['user_id'] ?? '').toString(),
      tenHienThi: (map['ten_hien_thi'] ?? 'Người chơi').toString(),
      laChuPhong: map['la_chu_phong'] == true,
      sanSang: map['san_sang'] == true,
      diemSo: (map['diem_so'] as num?)?.toInt() ?? 0,
      soCauDung: (map['so_cau_dung'] as num?)?.toInt() ?? 0,
      tongSoCau: (map['tong_so_cau'] as num?)?.toInt() ?? 0,
      thoiGianGiay: (map['thoi_gian_giay'] as num?)?.toInt() ?? 0,
      trangThai: (map['trang_thai'] ?? 'joined').toString(),
    );
  }
}

class RoomExamOption {
  final String id;
  final String tieuDe;
  final String tenMon;
  final int soCau;
  final String nguoiTao;
  final int thoiGianPhut;

  const RoomExamOption({
    required this.id,
    required this.tieuDe,
    required this.tenMon,
    required this.soCau,
    this.nguoiTao = 'Admin',
    this.thoiGianPhut = 40,
  });
}

class RoomAnswerModel {
  final String id;
  final String noiDung;
  final bool isCorrect;

  const RoomAnswerModel({
    required this.id,
    required this.noiDung,
    required this.isCorrect,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'noi_dung': noiDung,
        'is_correct': isCorrect,
      };
}

class RoomQuestionModel {
  final String id;
  final String noiDung;
  final String mucDo;
  final int diem;
  final List<RoomAnswerModel> dapAn;

  const RoomQuestionModel({
    required this.id,
    required this.noiDung,
    required this.mucDo,
    required this.diem,
    required this.dapAn,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'noi_dung': noiDung,
        'muc_do': mucDo,
        'diem': diem,
        'dap_an': dapAn.map((e) => e.toMap()).toList(),
      };
}