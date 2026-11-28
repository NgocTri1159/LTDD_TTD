import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../controllers/admin_room_controller.dart';
import '../../core/theme.dart';
import '../../models/room_model.dart';
import 'admin_select_exam_screen.dart';

class AdminRoomDetailScreen extends StatefulWidget {
  final RoomModel room;
  const AdminRoomDetailScreen({super.key, required this.room});

  @override
  State<AdminRoomDetailScreen> createState() => _AdminRoomDetailScreenState();
}

class _AdminRoomDetailScreenState extends State<AdminRoomDetailScreen> {
  late RoomModel _room;
  bool _isUpdating = false;

  static const List<String> _defaultModes = [
    'Tùy chỉnh',
    'Thi đấu nhanh',
    'Kiểm tra 15p',
  ];

  static const List<int> _defaultLimits = [2, 4, 8, 12, 20, 30];

  @override
  void initState() {
    super.initState();
    _room = widget.room;
    _reloadRoom();
  }

  void _showSnack(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        behavior: SnackBarBehavior.floating,
        backgroundColor:
            isError ? const Color(0xFFEF4444) : const Color(0xFF0F172A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      ),
    );
  }

  Future<void> _reloadRoom() async {
    try {
      final fresh = await AdminRoomController.instance.fetchRoomDetail(_room.id);
      if (fresh != null && mounted) {
        setState(() => _room = fresh);
      }
    } catch (_) {
      _showSnack('Không thể tải lại thông tin phòng.', isError: true);
    }
  }

  Future<void> _runUpdate(Future<void> Function() action,
      {String? successMessage}) async {
    if (_isUpdating) return;
    setState(() => _isUpdating = true);
    try {
      await action();
      await _reloadRoom();
      if (successMessage != null) _showSnack(successMessage);
    } catch (_) {
      _showSnack('Cập nhật thất bại, vui lòng thử lại.', isError: true);
    } finally {
      if (mounted) setState(() => _isUpdating = false);
    }
  }

  Future<void> _copyRoomCode() async {
    if (_room.maPhong.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: _room.maPhong));
    _showSnack('Đã sao chép mã phòng #${_room.maPhong}');
  }

  Future<void> _selectExam() async {
    final selectedExamId = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (_) => AdminSelectExamScreen(currentExamId: _room.deThiId),
      ),
    );
    if (selectedExamId != null && selectedExamId.isNotEmpty) {
      await _runUpdate(
        () => AdminRoomController.instance.updateRoomConfig(
          roomId: _room.id,
          deThiId: selectedExamId,
        ),
        successMessage: 'Đã cập nhật bộ đề cho phòng.',
      );
    }
  }

  Future<void> _showRenameDialog() async {
    final controller = TextEditingController(text: _room.tenPhong);
    final newName = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Đổi tên phòng thi',
          style: AppTextStyles.question.copyWith(
            fontSize: 17,
            fontWeight: FontWeight.w800,
            color: AppColors.text,
          ),
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(
            hintText: 'Nhập tên phòng mới...',
            filled: true,
            fillColor: AppColors.background,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: AppColors.base, width: 1.5),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Hủy',
              style: TextStyle(
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.interact,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () {
              final value = controller.text.trim();
              if (value.isNotEmpty) Navigator.pop(ctx, value);
            },
            child: const Text(
              'Lưu tên',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
    controller.dispose();

    if (newName != null && newName.isNotEmpty && newName != _room.tenPhong) {
      await _runUpdate(
        () => AdminRoomController.instance.updateRoomConfig(
          roomId: _room.id,
          tenPhong: newName,
        ),
        successMessage: 'Đã đổi tên phòng thành công.',
      );
    }
  }

  Future<void> _confirmDeleteRoom() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Color(0xFFEF4444)),
            SizedBox(width: 8),
            Text(
              'Xóa phòng thi?',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
            ),
          ],
        ),
        content: Text(
          'Phòng "${_room.tenPhong}" (#${_room.maPhong}) và dữ liệu phiên thi hiện tại sẽ bị xóa vĩnh viễn. Bạn có chắc muốn tiếp tục?',
          style: TextStyle(
            fontSize: 13.5,
            height: 1.45,
            color: Colors.grey.shade700,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'Hủy',
              style: TextStyle(
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Xóa phòng',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await AdminRoomController.instance.deleteRoom(_room.id);
        if (mounted) Navigator.pop(context, true);
      } catch (_) {
        _showSnack('Không thể xóa phòng lúc này.', isError: true);
      }
    }
  }

  ({String label, Color bg, Color fg, Color dot}) _statusMeta(String status) {
    switch (status.toLowerCase()) {
      case 'playing':
        return (
          label: 'Đang thi đấu',
          bg: const Color(0xFFDCFCE7),
          fg: const Color(0xFF15803D),
          dot: const Color(0xFF22C55E),
        );
      case 'finished':
        return (
          label: 'Đã kết thúc',
          bg: const Color(0xFFE0E7FF),
          fg: const Color(0xFF4338CA),
          dot: const Color(0xFF6366F1),
        );
      case 'cancelled':
        return (
          label: 'Đã hủy',
          bg: const Color(0xFFFEE2E2),
          fg: const Color(0xFFB91C1C),
          dot: const Color(0xFFEF4444),
        );
      case 'waiting':
      default:
        return (
          label: 'Đang chờ',
          bg: const Color(0xFFFEF3C7),
          fg: const Color(0xFFB45309),
          dot: const Color(0xFFF59E0B),
        );
    }
  }

  void _showMemberProfileDialog(RoomParticipantModel member) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  CircleAvatar(
                    radius: 34,
                    backgroundColor: AppColors.base.withValues(alpha: 0.14),
                    child: Text(
                      member.tenHienThi.isNotEmpty
                          ? member.tenHienThi[0].toUpperCase()
                          : 'P',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: AppColors.base,
                      ),
                    ),
                  ),
                  if (member.laChuPhong)
                    Positioned(
                      right: -2,
                      bottom: -2,
                      child: Container(
                        padding: const EdgeInsets.all(5),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF59E0B),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                        child: const Icon(
                          Icons.workspace_premium_rounded,
                          size: 14,
                          color: Colors.white,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                member.tenHienThi,
                textAlign: TextAlign.center,
                style: AppTextStyles.question.copyWith(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppColors.text,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                member.laChuPhong ? 'Chủ phòng thi' : 'Thành viên tham gia',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    _buildDialogInfoRow(
                      'Trạng thái',
                      member.sanSang ? 'Đã sẵn sàng' : 'Đang chờ',
                      valueColor: member.sanSang
                          ? const Color(0xFF047857)
                          : const Color(0xFFB45309),
                    ),
                    const Divider(height: 18),
                    _buildDialogInfoRow('Điểm hiện tại', '${member.diemSo} đ'),
                    const Divider(height: 18),
                    _buildDialogInfoRow(
                      'Tiến độ làm bài',
                      member.tongSoCau > 0
                          ? '${member.soCauDung}/${member.tongSoCau} câu đúng'
                          : 'Chưa bắt đầu',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                height: 44,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.interact,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text(
                    'Đóng',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDialogInfoRow(String label, String value, {Color? valueColor}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12.5,
            color: Colors.grey.shade600,
            fontWeight: FontWeight.w600,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            color: valueColor ?? AppColors.text,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }

  void _showParticipantMenu(RoomParticipantModel member) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              Text(
                member.tenHienThi,
                style: AppTextStyles.question.copyWith(
                  fontSize: 16.5,
                  fontWeight: FontWeight.w800,
                  color: AppColors.text,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                member.laChuPhong ? 'Chủ phòng' : 'Người chơi',
                style: TextStyle(
                  fontSize: 12.5,
                  color: Colors.grey.shade500,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 10),
              const Divider(height: 1),
              ListTile(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                leading: const Icon(
                  Icons.person_outline_rounded,
                  color: AppColors.base,
                ),
                title: const Text(
                  'Xem hồ sơ & điểm số',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _showMemberProfileDialog(member);
                },
              ),
              ListTile(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                leading: Icon(
                  member.sanSang
                      ? Icons.pause_circle_outline_rounded
                      : Icons.check_circle_outline_rounded,
                  color: const Color(0xFF10B981),
                ),
                title: Text(
                  member.sanSang ? 'Hủy trạng thái sẵn sàng' : 'Đánh dấu sẵn sàng',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                onTap: () async {
                  Navigator.pop(ctx);
                  await AdminRoomController.instance
                      .toggleParticipantReady(member.id, !member.sanSang);
                },
              ),
              if (!member.laChuPhong)
                ListTile(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  leading: const Icon(
                    Icons.workspace_premium_outlined,
                    color: Color(0xFFF59E0B),
                  ),
                  title: const Text(
                    'Chuyển quyền chủ phòng',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  onTap: () async {
                    Navigator.pop(ctx);
                    await _runUpdate(
                      () => AdminRoomController.instance.setRoomHost(
                        roomId: _room.id,
                        newHost: member,
                      ),
                      successMessage:
                          'Đã chuyển chủ phòng cho ${member.tenHienThi}.',
                    );
                  },
                ),
              ListTile(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                leading: const Icon(
                  Icons.logout_rounded,
                  color: Color(0xFFEF4444),
                ),
                title: const Text(
                  'Đá khỏi phòng',
                  style: TextStyle(
                    color: Color(0xFFEF4444),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                onTap: () async {
                  Navigator.pop(ctx);
                  await AdminRoomController.instance.kickParticipant(member.id);
                  _showSnack('Đã mời ${member.tenHienThi} khỏi phòng.');
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final List<String> modes = _defaultModes.contains(_room.cheDo)
        ? _defaultModes
        : [_room.cheDo.isNotEmpty ? _room.cheDo : _defaultModes.first, ..._defaultModes];
    final String currentMode =
        _room.cheDo.isNotEmpty ? _room.cheDo : _defaultModes.first;

    final List<int> limits = {..._defaultLimits, _room.gioiHan}.toList()..sort();
    final int currentLimit = _room.gioiHan;

    final status = _statusMeta(_room.trangThai);
    final heroDeepColor =
        Color.lerp(AppColors.base, const Color(0xFF0F172A), 0.28) ??
            AppColors.base;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppColors.text),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Chi tiết phòng thi',
          style: AppTextStyles.question.copyWith(
            fontSize: 17.5,
            fontWeight: FontWeight.w800,
            color: AppColors.text,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Làm mới',
            icon: const Icon(Icons.refresh_rounded, color: AppColors.text),
            onPressed: _reloadRoom,
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded, color: AppColors.text),
            color: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            onSelected: (value) {
              if (value == 'rename') {
                _showRenameDialog();
              } else if (value == 'toggle_hide') {
                _runUpdate(
                  () => AdminRoomController.instance
                      .toggleHideRoom(_room.id, !_room.daAn),
                  successMessage: _room.daAn
                      ? 'Đã hiển thị lại phòng thi.'
                      : 'Đã ẩn phòng khỏi danh sách công khai.',
                );
              } else if (value == 'delete') {
                _confirmDeleteRoom();
              }
            },
            itemBuilder: (_) => [
              const PopupMenuItem(
                value: 'rename',
                child: Row(
                  children: [
                    Icon(Icons.edit_outlined, size: 18, color: AppColors.text),
                    SizedBox(width: 10),
                    Text('Đổi tên phòng'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'toggle_hide',
                child: Row(
                  children: [
                    Icon(
                      _room.daAn
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                      size: 18,
                      color: AppColors.text,
                    ),
                    const SizedBox(width: 10),
                    Text(_room.daAn ? 'Hiện phòng thi' : 'Ẩn phòng thi'),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(Icons.delete_outline_rounded,
                        size: 18, color: Color(0xFFEF4444)),
                    SizedBox(width: 10),
                    Text(
                      'Xóa phòng thi',
                      style: TextStyle(
                        color: Color(0xFFEF4444),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: StreamBuilder<List<RoomParticipantModel>>(
        stream: AdminRoomController.instance.watchParticipants(_room.id),
        builder: (context, snapshot) {
          final rawMembers = snapshot.data ?? [];
          final members = List<RoomParticipantModel>.from(rawMembers)
            ..sort((a, b) {
              if (a.laChuPhong != b.laChuPhong) {
                return a.laChuPhong ? -1 : 1;
              }
              if (a.sanSang != b.sanSang) {
                return a.sanSang ? -1 : 1;
              }
              return a.tenHienThi.compareTo(b.tenHienThi);
            });

          final readyCount = members.where((m) => m.sanSang).length;
          final double fillRatio = _room.gioiHan > 0
              ? (members.length / _room.gioiHan).clamp(0.0, 1.0)
              : 0.0;

          return RefreshIndicator(
            color: AppColors.base,
            onRefresh: _reloadRoom,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 36),
              children: [
                // 1. HERO SUMMARY CARD
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [AppColors.base, heroDeepColor],
                    ),
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.base.withValues(alpha: 0.28),
                        blurRadius: 18,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Hàng badge trạng thái + mã phòng
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: status.bg,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 7,
                                  height: 7,
                                  decoration: BoxDecoration(
                                    color: status.dot,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  status.label,
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w800,
                                    color: status.fg,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (_room.daAn) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 9,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.25),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.visibility_off_rounded,
                                    size: 12,
                                    color: Colors.white,
                                  ),
                                  SizedBox(width: 4),
                                  Text(
                                    'Đang ẩn',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          const Spacer(),
                          InkWell(
                            onTap: _copyRoomCode,
                            borderRadius: BorderRadius.circular(14),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.18),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.28),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    '#${_room.maPhong}',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white,
                                      letterSpacing: 0.4,
                                    ),
                                  ),
                                  const SizedBox(width: 5),
                                  const Icon(
                                    Icons.copy_rounded,
                                    size: 13,
                                    color: Colors.white,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 14),

                      // Tên phòng + nút sửa nhanh
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              _room.tenPhong.isNotEmpty
                                  ? _room.tenPhong
                                  : _room.tenBoDe,
                              style: AppTextStyles.question.copyWith(
                                fontSize: 19,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                                height: 1.25,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          InkWell(
                            onTap: _showRenameDialog,
                            borderRadius: BorderRadius.circular(10),
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.16),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(
                                Icons.edit_rounded,
                                size: 16,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 6),

                      // Thông tin chủ phòng
                      Row(
                        children: [
                          Icon(
                            Icons.person_pin_rounded,
                            size: 15,
                            color: Colors.white.withValues(alpha: 0.85),
                          ),
                          const SizedBox(width: 5),
                          Expanded(
                            child: Text(
                              'Chủ phòng: ${_room.tenChuPhong}  •  ${_room.phongRieng ? 'Phòng riêng' : 'Công khai'}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                                color: Colors.white.withValues(alpha: 0.88),
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 16),

                      // 3 chỉ số nhanh (Realtime)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.13),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.15),
                          ),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: _buildHeroMetric(
                                icon: Icons.groups_rounded,
                                value: '${members.length}/${_room.gioiHan}',
                                label: 'Người chơi',
                              ),
                            ),
                            Container(
                              width: 1,
                              height: 28,
                              color: Colors.white.withValues(alpha: 0.22),
                            ),
                            Expanded(
                              child: _buildHeroMetric(
                                icon: Icons.check_circle_rounded,
                                value: '$readyCount/${members.length}',
                                label: 'Sẵn sàng',
                              ),
                            ),
                            Container(
                              width: 1,
                              height: 28,
                              color: Colors.white.withValues(alpha: 0.22),
                            ),
                            Expanded(
                              child: _buildHeroMetric(
                                icon: Icons.timer_rounded,
                                value: '${_room.thoiGianPhut} phút',
                                label: 'Thời lượng',
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                if (_isUpdating) ...[
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: const LinearProgressIndicator(
                      minHeight: 3,
                      color: AppColors.interact,
                    ),
                  ),
                ],

                const SizedBox(height: 18),

                // 2. BỘ ĐỀ ĐANG SỬ DỤNG
                _buildSectionHeader(
                  icon: Icons.menu_book_rounded,
                  title: 'Bộ đề áp dụng',
                ),
                const SizedBox(height: 10),
                InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: _selectExam,
                  child: Container(
                    padding: const EdgeInsets.all(15),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: AppColors.interact.withValues(alpha: 0.35),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.03),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 46,
                          height: 46,
                          decoration: BoxDecoration(
                            color: AppColors.interact.withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Icon(
                            Icons.assignment_outlined,
                            size: 24,
                            color: AppColors.interact,
                          ),
                        ),
                        const SizedBox(width: 13),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _room.tenBoDe,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.text,
                                  height: 1.25,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Wrap(
                                spacing: 6,
                                runSpacing: 4,
                                children: [
                                  _buildMiniTag(
                                    Icons.book_outlined,
                                    _room.chuDe,
                                    const Color(0xFFE0F2FE),
                                    const Color(0xFF0369A1),
                                  ),
                                  _buildMiniTag(
                                    Icons.schedule_rounded,
                                    '${_room.thoiGianPhut} phút',
                                    const Color(0xFFF1F5F9),
                                    const Color(0xFF475569),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.interact,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.swap_horiz_rounded,
                                size: 15,
                                color: Colors.white,
                              ),
                              SizedBox(width: 4),
                              Text(
                                'Đổi đề',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // 3. CẤU HÌNH PHÒNG THI (Gom vào 1 thẻ thống nhất)
                _buildSectionHeader(
                  icon: Icons.tune_rounded,
                  title: 'Cấu hình phòng thi',
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.grey.shade200),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.03),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          // Môn học (Read-only theo bộ đề)
                          Expanded(
                            child: _buildConfigField(
                              label: 'Môn học',
                              child: Container(
                                height: 44,
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.circular(14),
                                  border:
                                      Border.all(color: Colors.grey.shade200),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.lock_outline_rounded,
                                      size: 15,
                                      color: Colors.grey.shade500,
                                    ),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        _room.chuDe,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700,
                                          color: Color(0xFF475569),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          // Chế độ
                          Expanded(
                            child: _buildConfigField(
                              label: 'Chế độ thi',
                              child: _buildDropdownContainer<String>(
                                value: currentMode,
                                items: modes
                                    .map(
                                      (m) => DropdownMenuItem<String>(
                                        value: m,
                                        child: Text(
                                          m,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w700,
                                            color: AppColors.text,
                                          ),
                                        ),
                                      ),
                                    )
                                    .toList(),
                                onChanged: (val) {
                                  if (val == null || val == _room.cheDo) return;
                                  _runUpdate(
                                    () => AdminRoomController.instance
                                        .updateRoomConfig(
                                      roomId: _room.id,
                                      cheDo: val,
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          // Phòng riêng
                          Expanded(
                            child: _buildConfigField(
                              label: 'Quyền truy cập',
                              child: _buildDropdownContainer<bool>(
                                value: _room.phongRieng,
                                items: const [
                                  DropdownMenuItem<bool>(
                                    value: false,
                                    child: Text(
                                      'Công khai',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.text,
                                      ),
                                    ),
                                  ),
                                  DropdownMenuItem<bool>(
                                    value: true,
                                    child: Text(
                                      'Phòng riêng',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.text,
                                      ),
                                    ),
                                  ),
                                ],
                                onChanged: (val) {
                                  if (val == null || val == _room.phongRieng) {
                                    return;
                                  }
                                  _runUpdate(
                                    () => AdminRoomController.instance
                                        .updateRoomConfig(
                                      roomId: _room.id,
                                      phongRieng: val,
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          // Giới hạn người chơi
                          Expanded(
                            child: _buildConfigField(
                              label: 'Giới hạn sĩ số',
                              child: _buildDropdownContainer<int>(
                                value: currentLimit,
                                items: limits
                                    .map(
                                      (n) => DropdownMenuItem<int>(
                                        value: n,
                                        child: Text(
                                          '$n người',
                                          style: const TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w700,
                                            color: AppColors.text,
                                          ),
                                        ),
                                      ),
                                    )
                                    .toList(),
                                onChanged: (val) {
                                  if (val == null || val == _room.gioiHan) {
                                    return;
                                  }
                                  _runUpdate(
                                    () => AdminRoomController.instance
                                        .updateRoomConfig(
                                      roomId: _room.id,
                                      gioiHan: val,
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                        ],
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 14),
                        child: Divider(height: 1),
                      ),
                      // Công tắc ẩn phòng
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: (_room.daAn
                                      ? const Color(0xFFF59E0B)
                                      : AppColors.base)
                                  .withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(11),
                            ),
                            child: Icon(
                              _room.daAn
                                  ? Icons.visibility_off_rounded
                                  : Icons.visibility_rounded,
                              size: 18,
                              color: _room.daAn
                                  ? const Color(0xFFD97706)
                                  : AppColors.base,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Ẩn phòng thi',
                                  style: TextStyle(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.text,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  _room.daAn
                                      ? 'Phòng đang bị ẩn khỏi người chơi'
                                      : 'Phòng đang hiển thị trong sảnh',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Switch.adaptive(
                            value: _room.daAn,
                            activeTrackColor: const Color(0xFFF59E0B),
                            onChanged: (val) {
                              _runUpdate(
                                () => AdminRoomController.instance
                                    .toggleHideRoom(_room.id, val),
                                successMessage: val
                                    ? 'Đã ẩn phòng thi.'
                                    : 'Đã hiển thị lại phòng thi.',
                              );
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 22),

                // 4. DANH SÁCH NGƯỜI CHƠI (Realtime)
                Row(
                  children: [
                    _buildSectionHeader(
                      icon: Icons.people_alt_rounded,
                      title: 'Người chơi (${members.length}/${_room.gioiHan})',
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '$readyCount sẵn sàng',
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF047857),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Thanh tiến độ sức chứa phòng
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: fillRatio,
                    minHeight: 6,
                    backgroundColor: Colors.grey.shade200,
                    color: fillRatio >= 1.0
                        ? const Color(0xFFEF4444)
                        : AppColors.base,
                  ),
                ),
                const SizedBox(height: 12),

                if (snapshot.connectionState == ConnectionState.waiting &&
                    members.isEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 28),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: const Center(
                      child: SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: AppColors.base,
                        ),
                      ),
                    ),
                  )
                else if (members.isEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(20, 26, 20, 24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Column(
                      children: [
                        Container(
                          width: 58,
                          height: 58,
                          decoration: BoxDecoration(
                            color: AppColors.base.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.groups_2_outlined,
                            size: 30,
                            color: AppColors.base,
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Phòng đang chờ người tham gia',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: AppColors.text,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Chia sẻ mã phòng #${_room.maPhong} để thí sinh tham gia vào phiên thi này.',
                          textAlign: TextAlign.center,
                          style: AppTextStyles.text.copyWith(
                            color: Colors.grey.shade600,
                            fontSize: 13,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 16),
                        OutlinedButton.icon(
                          onPressed: _copyRoomCode,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.base,
                            side: BorderSide(
                              color: AppColors.base.withValues(alpha: 0.45),
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 18,
                              vertical: 10,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          icon: const Icon(Icons.copy_rounded, size: 16),
                          label: Text(
                            'Sao chép mã #${_room.maPhong}',
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  ...members.map(_buildParticipantCard),

                const SizedBox(height: 22),

                // 5. THAO TÁC QUẢN TRỊ PHÒNG
                _buildSectionHeader(
                  icon: Icons.admin_panel_settings_outlined,
                  title: 'Thao tác quản trị',
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _showRenameDialog,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.text,
                          backgroundColor: Colors.white,
                          side: BorderSide(color: Colors.grey.shade300),
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        icon: const Icon(Icons.edit_outlined, size: 18),
                        label: const Text(
                          'Đổi tên phòng',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _confirmDeleteRoom,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFEE2E2),
                          foregroundColor: const Color(0xFFDC2626),
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        icon: const Icon(Icons.delete_outline_rounded, size: 18),
                        label: const Text(
                          'Xóa phòng thi',
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeroMetric({
    required IconData icon,
    required String value,
    required String label,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: Colors.white.withValues(alpha: 0.9)),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 3),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: Colors.white.withValues(alpha: 0.78),
          ),
        ),
      ],
    );
  }

  Widget _buildSectionHeader({required IconData icon, required String title}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18, color: AppColors.base),
        const SizedBox(width: 7),
        Text(
          title,
          style: AppTextStyles.question.copyWith(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            color: AppColors.text,
          ),
        ),
      ],
    );
  }

  Widget _buildMiniTag(IconData icon, String label, Color bg, Color fg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: fg),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConfigField({required String label, required Widget child}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: Colors.grey.shade600,
          ),
        ),
        const SizedBox(height: 6),
        child,
      ],
    );
  }

  Widget _buildDropdownContainer<T>({
    required T value,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
  }) {
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          isExpanded: true,
          value: value,
          dropdownColor: Colors.white,
          borderRadius: BorderRadius.circular(16),
          icon: Icon(
            Icons.keyboard_arrow_down_rounded,
            color: Colors.grey.shade600,
          ),
          items: items,
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _buildParticipantCard(RoomParticipantModel m) {
    final bool hasScore = m.diemSo > 0 || m.tongSoCau > 0;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => _showParticipantMenu(m),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: m.laChuPhong
                  ? const Color(0xFFF59E0B).withValues(alpha: 0.45)
                  : Colors.grey.shade200,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  CircleAvatar(
                    radius: 22,
                    backgroundColor: AppColors.base.withValues(alpha: 0.14),
                    child: Text(
                      m.tenHienThi.isNotEmpty
                          ? m.tenHienThi[0].toUpperCase()
                          : 'P',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: AppColors.base,
                      ),
                    ),
                  ),
                  if (m.laChuPhong)
                    Positioned(
                      right: -2,
                      bottom: -2,
                      child: Container(
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF59E0B),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 1.5),
                        ),
                        child: const Icon(
                          Icons.workspace_premium_rounded,
                          size: 11,
                          color: Colors.white,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            m.tenHienThi,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w800,
                              color: AppColors.text,
                            ),
                          ),
                        ),
                        if (m.laChuPhong) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFEF3C7),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text(
                              'Chủ phòng',
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFFB45309),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 5),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2.5,
                          ),
                          decoration: BoxDecoration(
                            color: m.sanSang
                                ? const Color(0xFF10B981)
                                    .withValues(alpha: 0.14)
                                : const Color(0xFFF59E0B)
                                    .withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 6,
                                height: 6,
                                decoration: BoxDecoration(
                                  color: m.sanSang
                                      ? const Color(0xFF10B981)
                                      : const Color(0xFFF59E0B),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 5),
                              Text(
                                m.sanSang ? 'Sẵn sàng' : 'Đang chờ',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: m.sanSang
                                      ? const Color(0xFF047857)
                                      : const Color(0xFFB45309),
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (hasScore)
                          Text(
                            '${m.diemSo} đ • ${m.soCauDung}/${m.tongSoCau} câu',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              color: Colors.grey.shade600,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.more_vert_rounded,
                size: 20,
                color: Colors.grey.shade500,
              ),
            ],
          ),
        ),
      ),
    );
  }
}