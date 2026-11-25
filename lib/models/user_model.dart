
/// Model ánh xạ bảng public.nguoi_dung trong Supabase.
class UserModel {
  final String id;
  final String email;
  final String hoTen;
  final String? anhDaiDienUrl;
  final String vaiTro;
  final int diemKinhNghiem;
  final double tongDiem;
  final bool trangThai;
  final DateTime ngayTao;
  final DateTime? capNhatLuc;

  const UserModel({
    required this.id,
    required this.email,
    required this.hoTen,
    this.anhDaiDienUrl,
    this.vaiTro = 'user',
    this.diemKinhNghiem = 0,
    this.tongDiem = 0.0,
    this.trangThai = true,
    required this.ngayTao,
    this.capNhatLuc,
  });

  bool get isAdmin => vaiTro == 'admin' || vaiTro == 'super_admin';
  bool get isActive => trangThai;

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] as String,
      email: json['email'] as String,
      hoTen: json['ho_ten'] as String,
      anhDaiDienUrl: json['anh_dai_dien_url'] as String?,
      vaiTro: json['vai_tro'] as String,
      diemKinhNghiem: (json['diem_kinh_nghiem'] as num).toInt(),
      tongDiem: (json['tong_diem'] as num).toDouble(),
      trangThai: json['trang_thai'] as bool,
      ngayTao: DateTime.parse(json['ngay_tao'] as String),
      capNhatLuc: json['cap_nhat_luc'] != null
          ? DateTime.parse(json['cap_nhat_luc'] as String)
          : null,
    );
  }

  /// Chuyển dữ liệu đầy đủ từ Model.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'ho_ten': hoTen,
      'anh_dai_dien_url': anhDaiDienUrl,
      'vai_tro': vaiTro,
      'diem_kinh_nghiem': diemKinhNghiem,
      'tong_diem': tongDiem,
      'trang_thai': trangThai,
      'ngay_tao': ngayTao.toIso8601String(),
      if (capNhatLuc != null)
        'cap_nhat_luc': capNhatLuc!.toIso8601String(),
    };
  }

  /// INSERT hồ sơ người dùng theo quyền cột hiện tại của Supabase.
  /// Không gửi vai_tro, điểm, trạng thái hoặc timestamp.
  Map<String, dynamic> toInsertJson() {
    return {
      'id': id,
      'email': email,
      'ho_ten': hoTen,
    };
  }

  /// UPDATE hồ sơ cá nhân theo quyền cột hiện tại của Supabase.
  Map<String, dynamic> toUpdateProfileJson() {
    return {
      'ho_ten': hoTen,
      'anh_dai_dien_url': anhDaiDienUrl,
    };
  }

  UserModel copyWith({
    String? hoTen,
    String? anhDaiDienUrl,
    String? vaiTro,
    int? diemKinhNghiem,
    double? tongDiem,
    bool? trangThai,
  }) {
    return UserModel(
      id: id,
      email: email,
      hoTen: hoTen ?? this.hoTen,
      anhDaiDienUrl: anhDaiDienUrl ?? this.anhDaiDienUrl,
      vaiTro: vaiTro ?? this.vaiTro,
      diemKinhNghiem: diemKinhNghiem ?? this.diemKinhNghiem,
      tongDiem: tongDiem ?? this.tongDiem,
      trangThai: trangThai ?? this.trangThai,
      ngayTao: ngayTao,
      capNhatLuc: capNhatLuc,
    );
  }
}
