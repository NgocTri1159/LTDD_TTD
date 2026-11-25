/// Model ánh xạ bảng public.che_do_choi trong Supabase.
class GameModeModel {
  final String id;
  final String maCheDo;
  final String tenCheDo;
  final String? moTa;
  final String? bieuTuong;
  final bool choPhepNhieuNguoi;
  final bool trangThai;
  final DateTime? ngayTao;

  const GameModeModel({
    required this.id,
    required this.maCheDo,
    required this.tenCheDo,
    this.moTa,
    this.bieuTuong,
    this.choPhepNhieuNguoi = false,
    this.trangThai = true,
    this.ngayTao,
  });

  factory GameModeModel.fromJson(Map<String, dynamic> json) {
    return GameModeModel(
      id: json['id'] as String? ?? '',
      maCheDo: json['ma_che_do'] as String? ?? '',
      tenCheDo: json['ten_che_do'] as String? ?? '',
      moTa: json['mo_ta'] as String?,
      bieuTuong: json['bieu_tuong'] as String?,
      choPhepNhieuNguoi: json['cho_phep_nhieu_nguoi'] as bool? ?? false,
      trangThai: json['trang_thai'] as bool? ?? true,
      ngayTao: json['ngay_tao'] != null
          ? DateTime.tryParse(json['ngay_tao'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id.isNotEmpty) 'id': id,
      'ma_che_do': maCheDo,
      'ten_che_do': tenCheDo,
      'mo_ta': moTa,
      'bieu_tuong': bieuTuong,
      'cho_phep_nhieu_nguoi': choPhepNhieuNguoi,
      'trang_thai': trangThai,
    };
  }
}
