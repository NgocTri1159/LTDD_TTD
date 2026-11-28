import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../controllers/admin_room_controller.dart';
import '../../core/theme.dart';
import '../../models/room_model.dart';
import 'admin_room_detail_screen.dart';

class AdminRoomScreen extends StatefulWidget {
  const AdminRoomScreen({super.key});

  @override
  State<AdminRoomScreen> createState() => _AdminRoomScreenState();
}

class _AdminRoomScreenState extends State<AdminRoomScreen> {
  final _searchController = TextEditingController();

  static const Color _brandBlue = Color(0xFF3B5BFD);
  static const Color _brandPurple = Color(0xFF7C3AED);
  static const Color _brandEmerald = Color(0xFF10B981);
  static const Color _brandAmber = Color(0xFFF59E0B);

  List<RoomModel> _rooms = [];
  bool _loading = true;
  bool _hasLoadedOnce = false;
  String _searchQuery = '';
  String _selectedSubject = 'Tất cả';
  String _selectedStatus = 'all'; // 'all' | 'live' | 'hidden'

  static const List<Color> _palette = [
    Color(0xFF3B82F6),
    Color(0xFF8B5CF6),
    Color(0xFF10B981),
    Color(0xFFF59E0B),
    Color(0xFF06B6D4),
    Color(0xFFEC4899),
  ];

  @override
  void initState() {
    super.initState();
    _loadRooms();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadRooms() async {
    if (mounted) setState(() => _loading = true);
    try {
      final list = await AdminRoomController.instance.fetchAllRooms();
      if (!mounted) return;
      setState(() {
        _rooms = list;
        _loading = false;
        _hasLoadedOnce = true;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _hasLoadedOnce = true;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Lỗi tải danh sách phòng: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  int get _liveCount => _rooms.where((r) => r.trangThai == 'playing').length;

  int get _hiddenCount => _rooms.where((r) => r.daAn).length;

  int get _totalPlayers =>
      _rooms.fold<int>(0, (sum, r) => sum + r.soNguoiHienTai);

  List<String> get _subjectFilters {
    final set = <String>{'Tất cả'};
    for (final r in _rooms) {
      if (r.chuDe.trim().isNotEmpty) {
        set.add(r.chuDe.trim());
      }
    }
    return set.toList();
  }

  List<RoomModel> get _filteredRooms {
    return _rooms.where((room) {
      final matchSubject =
          _selectedSubject == 'Tất cả' || room.chuDe.trim() == _selectedSubject;

      final matchStatus = switch (_selectedStatus) {
        'live' => room.trangThai == 'playing',
        'hidden' => room.daAn,
        _ => true,
      };

      final q = _searchQuery.trim().toLowerCase();
      final matchQuery = q.isEmpty ||
          room.maPhong.toLowerCase().contains(q) ||
          room.tenPhong.toLowerCase().contains(q) ||
          room.tenBoDe.toLowerCase().contains(q) ||
          room.tenChuPhong.toLowerCase().contains(q);

      return matchSubject && matchStatus && matchQuery;
    }).toList();
  }

  bool get _hasActiveFilter =>
      _searchQuery.trim().isNotEmpty ||
      _selectedSubject != 'Tất cả' ||
      _selectedStatus != 'all';

  void _resetFilters() {
    setState(() {
      _searchQuery = '';
      _searchController.clear();
      _selectedSubject = 'Tất cả';
      _selectedStatus = 'all';
    });
  }

  Color _colorForSubject(String subject) {
    return _palette[subject.hashCode.abs() % _palette.length];
  }

  IconData _iconForSubject(String subject) {
    final lower = subject.toLowerCase();
    if (lower.contains('toán')) return Icons.calculate_rounded;
    if (lower.contains('văn')) return Icons.auto_stories_rounded;
    if (lower.contains('anh') || lower.contains('ngoại ngữ')) {
      return Icons.language_rounded;
    }
    if (lower.contains('địa')) return Icons.terrain_rounded;
    if (lower.contains('sử')) return Icons.account_balance_rounded;
    if (lower.contains('lập trình') || lower.contains('tin')) {
      return Icons.code_rounded;
    }
    return Icons.meeting_room_rounded;
  }

  Future<void> _confirmDeleteRoom(RoomModel room) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFEF4444).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.delete_outline_rounded,
                color: Color(0xFFEF4444),
                size: 20,
              ),
            ),
            const SizedBox(width: 10),
            const Text(
              'Xóa phòng thi',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
            ),
          ],
        ),
        content: Text(
          'Bạn có chắc muốn xóa vĩnh viễn phòng #${room.maPhong} không? Hành động này không thể hoàn tác.',
          style: TextStyle(color: Colors.grey.shade700, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Hủy', style: TextStyle(color: Colors.grey.shade700)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Xóa phòng',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
    if (ok == true) {
      await AdminRoomController.instance.deleteRoom(room.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Đã xóa phòng #${room.maPhong}'),
          backgroundColor: Colors.green.shade700,
          behavior: SnackBarBehavior.floating,
        ),
      );
      _loadRooms();
    }
  }

  Future<void> _openRoomDetail(RoomModel room) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AdminRoomDetailScreen(room: room),
      ),
    );
    _loadRooms();
  }

  @override
  Widget build(BuildContext context) {
    final rooms = _filteredRooms;
    final subjects = _subjectFilters;

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5FB),
      body: !_hasLoadedOnce && _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.base),
            )
          : RefreshIndicator(
              color: AppColors.base,
              onRefresh: _loadRooms,
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  // 1. HEADER GRADIENT + THỐNG KÊ MINI + THANH TÌM KIẾM
                  SliverToBoxAdapter(
                    child: _buildHeaderAndSearch(context),
                  ),

                  // 2. BỘ LỌC TRẠNG THÁI & CHỦ ĐỀ
                  SliverToBoxAdapter(
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 680),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Bộ lọc trạng thái (Tất cả / Đang LIVE / Đang ẩn)
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
                              child: Row(
                                children: [
                                  _buildStatusTab(
                                    keyVal: 'all',
                                    label: 'Tất cả',
                                    count: _rooms.length,
                                    color: AppColors.base,
                                  ),
                                  const SizedBox(width: 8),
                                  _buildStatusTab(
                                    keyVal: 'live',
                                    label: 'Đang LIVE',
                                    count: _liveCount,
                                    color: _brandEmerald,
                                    showDot: _liveCount > 0,
                                  ),
                                  const SizedBox(width: 8),
                                  _buildStatusTab(
                                    keyVal: 'hidden',
                                    label: 'Đang ẩn',
                                    count: _hiddenCount,
                                    color: _brandAmber,
                                  ),
                                ],
                              ),
                            ),

                            // Dải chip lọc theo chủ đề / môn học
                            if (subjects.length > 1)
                              SizedBox(
                                height: 38,
                                child: ListView.separated(
                                  scrollDirection: Axis.horizontal,
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16),
                                  itemCount: subjects.length,
                                  separatorBuilder: (_, __) =>
                                      const SizedBox(width: 8),
                                  itemBuilder: (_, index) {
                                    final sub = subjects[index];
                                    final isSelected = _selectedSubject == sub;
                                    final accent = sub == 'Tất cả'
                                        ? AppColors.interact
                                        : _colorForSubject(sub);

                                    return GestureDetector(
                                      onTap: () => setState(
                                          () => _selectedSubject = sub),
                                      child: AnimatedContainer(
                                        duration:
                                            const Duration(milliseconds: 180),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 13,
                                          vertical: 6,
                                        ),
                                        alignment: Alignment.center,
                                        decoration: BoxDecoration(
                                          color: isSelected
                                              ? accent
                                              : Colors.white,
                                          borderRadius:
                                              BorderRadius.circular(20),
                                          border: Border.all(
                                            color: isSelected
                                                ? accent
                                                : const Color(0xFFE2E8F0),
                                          ),
                                          boxShadow: isSelected
                                              ? [
                                                  BoxShadow(
                                                    color: accent.withValues(
                                                        alpha: 0.25),
                                                    blurRadius: 8,
                                                    offset: const Offset(0, 2),
                                                  ),
                                                ]
                                              : null,
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            if (sub != 'Tất cả') ...[
                                              Container(
                                                width: 7,
                                                height: 7,
                                                decoration: BoxDecoration(
                                                  color: isSelected
                                                      ? Colors.white
                                                      : accent,
                                                  shape: BoxShape.circle,
                                                ),
                                              ),
                                              const SizedBox(width: 6),
                                            ],
                                            Text(
                                              sub == 'Tất cả'
                                                  ? 'Mọi chủ đề'
                                                  : sub,
                                              style:
                                                  AppTextStyles.text.copyWith(
                                                fontSize: 12.3,
                                                fontWeight: FontWeight.w700,
                                                color: isSelected
                                                    ? Colors.white
                                                    : const Color(0xFF334155),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),

                            // Tiêu đề danh sách + số lượng kết quả
                            Padding(
                              padding:
                                  const EdgeInsets.fromLTRB(16, 16, 16, 10),
                              child: Row(
                                children: [
                                  Container(
                                    width: 4,
                                    height: 17,
                                    decoration: BoxDecoration(
                                      color: AppColors.base,
                                      borderRadius: BorderRadius.circular(99),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Danh sách phòng thi',
                                    style: AppTextStyles.question.copyWith(
                                      fontSize: 15.5,
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.text,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppColors.base
                                          .withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(99),
                                    ),
                                    child: Text(
                                      '${rooms.length}',
                                      style: AppTextStyles.text.copyWith(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w800,
                                        color: AppColors.base,
                                      ),
                                    ),
                                  ),
                                  const Spacer(),
                                  if (_hasActiveFilter)
                                    GestureDetector(
                                      onTap: _resetFilters,
                                      child: Text(
                                        'Xóa bộ lọc',
                                        style: AppTextStyles.text.copyWith(
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.w700,
                                          color: AppColors.base,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // 3. DANH SÁCH PHÒNG THI HOẶC EMPTY STATE
                  if (rooms.isEmpty)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 680),
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
                            child: _buildEmptyState(),
                          ),
                        ),
                      ),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                      sliver: SliverList.separated(
                        itemCount: rooms.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (_, index) {
                          return Center(
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 648),
                              child: _buildRoomCard(rooms[index]),
                            ),
                          );
                        },
                      ),
                    ),
                ],
              ),
            ),
    );
  }

  Widget _buildHeaderAndSearch(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;

    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: EdgeInsets.fromLTRB(20, topPadding + 16, 20, 44),
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [_brandBlue, AppColors.base, _brandPurple],
            ),
            borderRadius: BorderRadius.vertical(
              bottom: Radius.circular(30),
            ),
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 648),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned(
                    right: -24,
                    top: -26,
                    child: Container(
                      width: 130,
                      height: 130,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: 0.08),
                      ),
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.16),
                                    borderRadius: BorderRadius.circular(99),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.sensors_rounded,
                                        size: 13,
                                        color: Color(0xFF6EE7B7),
                                      ),
                                      SizedBox(width: 5),
                                      Text(
                                        'PHÒNG THI TRỰC TUYẾN',
                                        style: TextStyle(
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.w800,
                                          letterSpacing: 0.8,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  'Quản lí phòng thi',
                                  style: AppTextStyles.question.copyWith(
                                    fontSize: 23,
                                    fontWeight: FontWeight.w900,
                                    color: Colors.white,
                                    letterSpacing: -0.3,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Material(
                            color: Colors.white.withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(15),
                            child: InkWell(
                              onTap: _loading ? null : _loadRooms,
                              borderRadius: BorderRadius.circular(15),
                              child: Container(
                                width: 44,
                                height: 44,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(15),
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.28),
                                  ),
                                ),
                                child: _loading
                                    ? const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2.2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : const Icon(
                                        Icons.refresh_rounded,
                                        color: Colors.white,
                                        size: 21,
                                      ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // 3 ô tóm tắt mini giúp header sinh động, đầy đặn
                      Row(
                        children: [
                          Expanded(
                            child: _buildHeaderStat(
                              icon: Icons.meeting_room_rounded,
                              label: 'Tổng phòng',
                              value: '${_rooms.length}',
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _buildHeaderStat(
                              icon: Icons.podcasts_rounded,
                              label: 'Đang LIVE',
                              value: '$_liveCount',
                              highlightColor: const Color(0xFF6EE7B7),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _buildHeaderStat(
                              icon: Icons.groups_rounded,
                              label: 'Người chơi',
                              value: '$_totalPlayers',
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),

        // Thanh tìm kiếm nổi chồng nhẹ lên mép dưới Header
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: Transform.translate(
              offset: const Offset(0, -24),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF0F172A).withValues(alpha: 0.06),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: TextField(
                    controller: _searchController,
                    style: AppTextStyles.text.copyWith(
                      color: AppColors.text,
                      fontSize: 14,
                    ),
                    onChanged: (val) => setState(() => _searchQuery = val),
                    decoration: InputDecoration(
                      hintText: 'Tìm mã phòng, tên bộ đề, chủ phòng...',
                      hintStyle: TextStyle(
                        color: Colors.grey.shade400,
                        fontSize: 13.8,
                      ),
                      prefixIcon: Icon(
                        Icons.search_rounded,
                        color: AppColors.base.withValues(alpha: 0.8),
                        size: 21,
                      ),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: Icon(
                                Icons.close_rounded,
                                size: 19,
                                color: Colors.grey.shade500,
                              ),
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _searchQuery = '');
                              },
                            )
                          : null,
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 14,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHeaderStat({
    required IconData icon,
    required String label,
    required String value,
    Color? highlightColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                icon,
                size: 15,
                color: highlightColor ?? Colors.white.withValues(alpha: 0.88),
              ),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Colors.white.withValues(alpha: 0.85),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              height: 1.1,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusTab({
    required String keyVal,
    required String label,
    required int count,
    required Color color,
    bool showDot = false,
  }) {
    final isSelected = _selectedStatus == keyVal;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedStatus = keyVal),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 8),
          decoration: BoxDecoration(
            color: isSelected ? color : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isSelected ? color : const Color(0xFFE2E8F0),
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: color.withValues(alpha: 0.24),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (showDot) ...[
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: isSelected ? Colors.white : color,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 5),
              ],
              Flexible(
                child: Text(
                  '$label ($count)',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.text.copyWith(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: isSelected ? Colors.white : const Color(0xFF334155),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRoomCard(RoomModel room) {
    final accent = _colorForSubject(room.chuDe);
    final isLive = room.trangThai == 'playing';
    final isWaiting = room.trangThai == 'waiting';
    final double ratio = room.gioiHan > 0
        ? (room.soNguoiHienTai / room.gioiHan).clamp(0.0, 1.0)
        : 0.0;
    final Color progressColor = ratio >= 0.9
        ? const Color(0xFFEF4444)
        : ratio >= 0.6
            ? _brandAmber
            : _brandEmerald;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isLive
              ? _brandEmerald.withValues(alpha: 0.45)
              : const Color(0xFFE2E8F0),
          width: isLive ? 1.4 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: (isLive ? _brandEmerald : accent).withValues(alpha: 0.07),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(21),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => _openRoomDetail(room),
            child: Opacity(
              opacity: room.daAn ? 0.68 : 1.0,
              child: IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Thanh nhấn màu dọc bên trái
                    Container(
                      width: 5,
                      color: isLive ? _brandEmerald : accent,
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Icon chủ đề nền gradient pastel
                                Container(
                                  width: 54,
                                  height: 54,
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: [
                                        accent.withValues(alpha: 0.18),
                                        accent.withValues(alpha: 0.08),
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: Icon(
                                    _iconForSubject(room.chuDe),
                                    size: 26,
                                    color: accent,
                                  ),
                                ),
                                const SizedBox(width: 12),

                                // Tên phòng, trạng thái, chủ phòng
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Expanded(
                                            child: Text(
                                              room.tenBoDe.isNotEmpty
                                                  ? room.tenBoDe
                                                  : room.tenPhong,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: AppTextStyles.question
                                                  .copyWith(
                                                fontSize: 15.5,
                                                fontWeight: FontWeight.w800,
                                                color: AppColors.text,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 4),
                                          _buildRoomPopupMenu(room),
                                        ],
                                      ),
                                      const SizedBox(height: 5),

                                      // Hàng nhãn Chủ đề + Trạng thái
                                      Wrap(
                                        spacing: 6,
                                        runSpacing: 4,
                                        children: [
                                          if (room.chuDe.trim().isNotEmpty)
                                            _buildBadge(
                                              text: room.chuDe,
                                              bgColor: accent.withValues(
                                                  alpha: 0.11),
                                              textColor: accent,
                                            ),
                                          if (isLive)
                                            _buildBadge(
                                              text: 'LIVE',
                                              bgColor: _brandEmerald.withValues(
                                                  alpha: 0.14),
                                              textColor:
                                                  const Color(0xFF047857),
                                              dotColor: _brandEmerald,
                                            )
                                          else if (isWaiting)
                                            _buildBadge(
                                              text: 'Đang chờ',
                                              bgColor: const Color(0xFF3B82F6)
                                                  .withValues(alpha: 0.12),
                                              textColor:
                                                  const Color(0xFF1D4ED8),
                                            ),
                                          if (room.daAn)
                                            _buildBadge(
                                              text: 'Đã ẩn',
                                              bgColor: Colors.grey.shade200,
                                              textColor: Colors.grey.shade700,
                                            ),
                                        ],
                                      ),
                                      const SizedBox(height: 7),

                                      // Chủ phòng
                                      Row(
                                        children: [
                                          Icon(
                                            Icons.person_outline_rounded,
                                            size: 14,
                                            color: Colors.grey.shade500,
                                          ),
                                          const SizedBox(width: 4),
                                          Expanded(
                                            child: Text(
                                              'Chủ phòng: ${room.tenChuPhong}',
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style:
                                                  AppTextStyles.text.copyWith(
                                                fontSize: 12.5,
                                                color: Colors.grey.shade600,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 12),
                            Divider(height: 1, color: Colors.grey.shade100),
                            const SizedBox(height: 10),

                            // Hàng dưới: Mã phòng (copy) + Sức chứa & thanh tiến độ
                            Row(
                              children: [
                                InkWell(
                                  borderRadius: BorderRadius.circular(10),
                                  onTap: () {
                                    Clipboard.setData(
                                      ClipboardData(text: room.maPhong),
                                    );
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          'Đã sao chép mã phòng ${room.maPhong}',
                                        ),
                                        behavior: SnackBarBehavior.floating,
                                        duration: const Duration(seconds: 1),
                                      ),
                                    );
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 5,
                                    ),
                                    decoration: BoxDecoration(
                                      color: accent.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                        color: accent.withValues(alpha: 0.22),
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.tag_rounded,
                                          size: 13,
                                          color: accent,
                                        ),
                                        const SizedBox(width: 3),
                                        Text(
                                          room.maPhong,
                                          style: TextStyle(
                                            fontSize: 12.5,
                                            fontWeight: FontWeight.w800,
                                            letterSpacing: 0.4,
                                            color: accent,
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        Icon(
                                          Icons.copy_rounded,
                                          size: 13,
                                          color: accent,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.end,
                                        children: [
                                          Icon(
                                            Icons.groups_2_rounded,
                                            size: 14,
                                            color: Colors.grey.shade500,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            '${room.soNguoiHienTai}/${room.gioiHan} thí sinh',
                                            style: const TextStyle(
                                              fontSize: 12.2,
                                              fontWeight: FontWeight.w800,
                                              color: AppColors.text,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 5),
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(99),
                                        child: LinearProgressIndicator(
                                          value: ratio,
                                          minHeight: 5,
                                          backgroundColor:
                                              const Color(0xFFE2E8F0),
                                          valueColor:
                                              AlwaysStoppedAnimation<Color>(
                                            progressColor,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRoomPopupMenu(RoomModel room) {
    return SizedBox(
      width: 28,
      height: 24,
      child: PopupMenuButton<String>(
        padding: EdgeInsets.zero,
        color: Colors.white,
        icon: Icon(
          Icons.more_vert_rounded,
          size: 20,
          color: Colors.grey.shade600,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        onSelected: (val) async {
          if (val == 'watch' || val == 'edit') {
            _openRoomDetail(room);
          } else if (val == 'hide') {
            await AdminRoomController.instance.toggleHideRoom(
              room.id,
              !room.daAn,
            );
            _loadRooms();
          } else if (val == 'delete') {
            _confirmDeleteRoom(room);
          }
        },
        itemBuilder: (_) => [
          const PopupMenuItem(
            value: 'watch',
            child: Row(
              children: [
                Icon(Icons.visibility_outlined, size: 18),
                SizedBox(width: 10),
                Text('Theo dõi'),
              ],
            ),
          ),
          const PopupMenuItem(
            value: 'edit',
            child: Row(
              children: [
                Icon(Icons.edit_outlined, size: 18),
                SizedBox(width: 10),
                Text('Chỉnh sửa'),
              ],
            ),
          ),
          PopupMenuItem(
            value: 'hide',
            child: Row(
              children: [
                Icon(
                  room.daAn
                      ? Icons.visibility_rounded
                      : Icons.visibility_off_outlined,
                  size: 18,
                ),
                const SizedBox(width: 10),
                Text(room.daAn ? 'Hiện phòng' : 'Ẩn phòng'),
              ],
            ),
          ),
          const PopupMenuDivider(),
          const PopupMenuItem(
            value: 'delete',
            child: Row(
              children: [
                Icon(
                  Icons.delete_outline_rounded,
                  size: 18,
                  color: Color(0xFFEF4444),
                ),
                SizedBox(width: 10),
                Text(
                  'Xóa phòng',
                  style: TextStyle(
                    color: Color(0xFFEF4444),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBadge({
    required String text,
    required Color bgColor,
    required Color textColor,
    Color? dotColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (dotColor != null) ...[
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: dotColor,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 4),
          ],
          Text(
            text,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 38),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  _brandBlue.withValues(alpha: 0.14),
                  _brandPurple.withValues(alpha: 0.14),
                ],
              ),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.meeting_room_outlined,
              size: 34,
              color: AppColors.base,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            _hasActiveFilter
                ? 'Không tìm thấy phòng phù hợp'
                : 'Chưa có phòng thi trực tuyến nào',
            textAlign: TextAlign.center,
            style: AppTextStyles.question.copyWith(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: AppColors.text,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _hasActiveFilter
                ? 'Thử thay đổi từ khóa tìm kiếm hoặc chọn lại chủ đề khác.'
                : 'Khi người dùng tạo phòng thi mới, danh sách phòng sẽ tự động hiển thị tại đây.',
            textAlign: TextAlign.center,
            style: AppTextStyles.text.copyWith(
              fontSize: 13.2,
              color: Colors.grey.shade500,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 18),
          ElevatedButton.icon(
            onPressed: _hasActiveFilter ? _resetFilters : _loadRooms,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.base,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            icon: Icon(
              _hasActiveFilter
                  ? Icons.filter_alt_off_rounded
                  : Icons.refresh_rounded,
              size: 18,
            ),
            label: Text(
              _hasActiveFilter ? 'Đặt lại bộ lọc' : 'Làm mới danh sách',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}