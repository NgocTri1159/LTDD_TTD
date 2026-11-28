import 'dart:core';
import 'dart:core' as core;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:material_ui/material_ui.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'room_lobby_screen.dart';

class RoomListScreen extends StatefulWidget {
  const RoomListScreen({super.key});

  @override
  State<RoomListScreen> createState() => _RoomListScreenState();
}

class _RoomListScreenState extends State<RoomListScreen> {
  static const Color bgSoft = Color(0xFFF4F5FA);
  static const Color primaryPurple = Color(0xFF565CEB);
  static const Color accentOrange = Color(0xFFF79E1B);
  static const Color darkText = Color(0xFF1E1E2C);
  static const Color subText = Color(0xFF5A5E77);

  final SupabaseClient _supabase = Supabase.instance.client;
  final TextEditingController _searchController = TextEditingController();
  RealtimeChannel? _roomsChannel;

  core.List<core.Map<String, dynamic>> _allRooms = [];
  core.List<core.Map<String, dynamic>> _gameModes = [];

  String _searchQuery = '';
  String? _selectedModeId;
  String? _selectedModeName;
  String _privacyFilter = 'all'; // 'all' | 'public' | 'private'

  bool _isLoading = true;
  bool _isJoining = false;

  String get _currentUid => FirebaseAuth.instance.currentUser?.uid ?? '';

  @override
  void initState() {
    super.initState();
    _initData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    if (_roomsChannel != null) {
      _supabase.removeChannel(_roomsChannel!);
    }
    super.dispose();
  }

  core.Future<void> _initData() async {
    await core.Future.wait([
      _fetchGameModes(),
      _fetchWaitingRooms(),
    ]);
    _subscribeRealtime();
  }

  core.Future<void> _fetchGameModes() async {
    try {
      final res = await _supabase
          .from('che_do_choi')
          .select('id, ten_che_do')
          .order('ten_che_do', ascending: true);

      if (!mounted) return;
      setState(() {
        _gameModes =
            core.List<core.Map<String, dynamic>>.from(res as core.List);
      });
    } catch (e) {
      debugPrint('FETCH MODES ERROR: $e');
    }
  }

  core.Future<void> _fetchWaitingRooms() async {
    try {
      final res = await _supabase
          .from('phong_thi')
          .select(
            '*, '
            'che_do_choi:che_do_choi_id(id, ten_che_do), '
            'de_thi:de_thi_id(*, mon_hoc:mon_hoc_id(ten_mon)), '
            'chu_phong:chu_phong_id(*), '
            'thanh_vien_phong(id, nguoi_dung_id)',
          )
          .eq('trang_thai', 'dang_cho')
          .order('ngay_tao', ascending: false);

      if (!mounted) return;
      setState(() {
        _allRooms =
            core.List<core.Map<String, dynamic>>.from(res as core.List);
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      debugPrint('FETCH ROOMS ERROR: $e');
      _showSnack('Không thể tải danh sách phòng: $e', isError: true);
    }
  }

  void _subscribeRealtime() {
    _roomsChannel = _supabase
        .channel('public:phong_thi_list')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'phong_thi',
          callback: (_) => _fetchWaitingRooms(),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'thanh_vien_phong',
          callback: (_) => _fetchWaitingRooms(),
        )
        .subscribe();
  }

  core.List<core.Map<String, dynamic>> get _filteredRooms {
    return _allRooms.where((room) {
      // 0. Ẩn các phòng trống không có người chơi (tránh phòng ma khi tắt ngang trình duyệt)
      if (_getCurrentCount(room) <= 0) {
        return false;
      }

      // 1. Lọc theo chế độ chơi
      if (_selectedModeId != null &&
          room['che_do_choi_id']?.toString() != _selectedModeId) {
        return false;
      }

      // 2. Lọc theo công khai / riêng tư
      final isPrivate = _hasPassword(room);
      if (_privacyFilter == 'public' && isPrivate) return false;
      if (_privacyFilter == 'private' && !isPrivate) return false;

      // 3. Lọc theo từ khóa tìm kiếm (mã phòng, tên đề, tên chủ phòng)
      if (_searchQuery.trim().isNotEmpty) {
        final q = _searchQuery.trim().toLowerCase();
        final code = (room['ma_phong'] ?? '').toString().toLowerCase();
        final examTitle = _getExamTitle(room).toLowerCase();
        final subjectName = _getSubjectName(room).toLowerCase();
        final hostName = _getHostName(room).toLowerCase();

        final match = code.contains(q) ||
            examTitle.contains(q) ||
            subjectName.contains(q) ||
            hostName.contains(q);
        if (!match) return false;
      }

      return true;
    }).toList();
  }

  bool _hasPassword(core.Map<String, dynamic> room) {
    final pwd = room['mat_khau']?.toString().trim() ?? '';
    return pwd.isNotEmpty;
  }

  int _getCurrentCount(core.Map<String, dynamic> room) {
    final members = room['thanh_vien_phong'];
    if (members is core.List) return members.length;
    return 0;
  }

  int _getMaxPlayers(core.Map<String, dynamic> room) {
    return (room['so_nguoi_toi_da'] as num?)?.toInt() ?? 2;
  }

  String _getExamTitle(core.Map<String, dynamic> room) {
    final exam = room['de_thi'];
    if (exam is core.Map) {
      final title = (exam['tieu_de'] ?? exam['ten_de_thi'])?.toString().trim();
      if (title != null && title.isNotEmpty) return title;
    }
    return 'Bộ đề trực tuyến';
  }

  String _getSubjectName(core.Map<String, dynamic> room) {
    final exam = room['de_thi'];
    if (exam is core.Map && exam['mon_hoc'] is core.Map) {
      final sub = exam['mon_hoc']['ten_mon']?.toString().trim();
      if (sub != null && sub.isNotEmpty) return sub;
    }
    return 'Tổng hợp';
  }

  String _getModeName(core.Map<String, dynamic> room) {
    final mode = room['che_do_choi'];
    if (mode is core.Map && mode['ten_che_do'] != null) {
      return mode['ten_che_do'].toString();
    }
    return 'Quick Quiz';
  }

  String _getHostName(core.Map<String, dynamic> room) {
    final host = room['chu_phong'];
    if (host is core.Map) {
      final name =
          (host['ten_hien_thi'] ?? host['ho_ten'])?.toString().trim();
      if (name != null && name.isNotEmpty) return name;

      final email = host['email']?.toString().trim();
      if (email != null && email.contains('@')) return email.split('@').first;
    }
    final uid = room['chu_phong_id']?.toString() ?? 'Host';
    return 'Player${uid.length > 5 ? uid.substring(0, 5) : uid}';
  }

  core.Future<void> _handleJoinRoom(core.Map<String, dynamic> room) async {
    if (_isJoining) return;

    final currentCount = _getCurrentCount(room);
    final maxPlayers = _getMaxPlayers(room);
    final members = room['thanh_vien_phong'];
    final alreadyInRoom = members is core.List &&
        members.any((m) => m['nguoi_dung_id']?.toString() == _currentUid);

    if (!alreadyInRoom && currentCount >= maxPlayers) {
      _showSnack('Phòng này đã đủ số lượng người chơi!', isError: true);
      return;
    }

    // Kiểm tra mật khẩu nếu là phòng riêng tư (và user chưa ở trong phòng)
    if (!alreadyInRoom && _hasPassword(room)) {
      final expectedPwd = room['mat_khau'].toString().trim();
      final enteredPwd = await _showPasswordDialog(
        room['ma_phong']?.toString() ?? '',
      );
      if (enteredPwd == null) return; // Người dùng bấm Hủy
      if (enteredPwd.trim() != expectedPwd) {
        _showSnack('Mật khẩu phòng không chính xác!', isError: true);
        return;
      }
    }

    setState(() => _isJoining = true);
    try {
      // Kiểm tra lại trạng thái mới nhất trên DB trước khi vào
      final freshRoom = await _supabase
          .from('phong_thi')
          .select('*')
          .eq('id', room['id'])
          .maybeSingle();

      if (freshRoom == null || freshRoom['trang_thai'] != 'dang_cho') {
        _showSnack('Phòng đã bắt đầu hoặc không còn tồn tại.', isError: true);
        await _fetchWaitingRooms();
        return;
      }

      if (!mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => RoomLobbyScreen(
            roomData: core.Map<String, dynamic>.from(freshRoom),
          ),
        ),
      );

      // Làm mới danh sách sau khi rời phòng chờ
      await _fetchWaitingRooms();
    } catch (e) {
      _showSnack('Không thể tham gia phòng: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isJoining = false);
    }
  }

  core.Future<void> _joinByCodeDirectly(String rawCode) async {
    final code = rawCode.trim().toUpperCase();
    if (code.isEmpty) return;

    setState(() => _isJoining = true);
    try {
      final room = await _supabase
          .from('phong_thi')
          .select('*, thanh_vien_phong(id, nguoi_dung_id)')
          .eq('ma_phong', code)
          .eq('trang_thai', 'dang_cho')
          .maybeSingle();

      if (room == null) {
        _showSnack('Không tìm thấy phòng đang chờ với mã "$code".', isError: true);
        return;
      }

      setState(() => _isJoining = false);
      await _handleJoinRoom(core.Map<String, dynamic>.from(room));
    } catch (e) {
      _showSnack('Lỗi tìm mã phòng: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isJoining = false);
    }
  }

  core.Future<String?> _showPasswordDialog(String roomCode) {
    final pwdController = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text(
          'Phòng riêng tư ($roomCode)',
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Vui lòng nhập mật khẩu để tham gia phòng:',
              style: TextStyle(fontSize: 13.5, color: subText),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: pwdController,
              obscureText: true,
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'Nhập mật khẩu phòng...',
                filled: true,
                fillColor: bgSoft,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
              onSubmitted: (val) => Navigator.pop(ctx, val),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, null),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, pwdController.text),
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryPurple,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Vào phòng'),
          ),
        ],
      ),
    );
  }

  void _openFilterSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Lọc danh sách phòng',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: darkText,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Loại phòng',
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: subText,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [
                      _buildChoiceChip(
                        label: 'Tất cả',
                        selected: _privacyFilter == 'all',
                        onTap: () {
                          setModalState(() => _privacyFilter = 'all');
                          setState(() {});
                        },
                      ),
                      _buildChoiceChip(
                        label: 'Công khai',
                        selected: _privacyFilter == 'public',
                        onTap: () {
                          setModalState(() => _privacyFilter = 'public');
                          setState(() {});
                        },
                      ),
                      _buildChoiceChip(
                        label: 'Riêng tư (Có khóa)',
                        selected: _privacyFilter == 'private',
                        onTap: () {
                          setModalState(() => _privacyFilter = 'private');
                          setState(() {});
                        },
                      ),
                    ],
                  ),
                  if (_gameModes.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    const Text(
                      'Chế độ chơi',
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: subText,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _buildChoiceChip(
                          label: 'Tất cả chế độ',
                          selected: _selectedModeId == null,
                          onTap: () {
                            setModalState(() {
                              _selectedModeId = null;
                              _selectedModeName = null;
                            });
                            setState(() {});
                          },
                        ),
                        ..._gameModes.map((m) {
                          final id = m['id'].toString();
                          final name = m['ten_che_do'].toString();
                          return _buildChoiceChip(
                            label: name,
                            selected: _selectedModeId == id,
                            onTap: () {
                              setModalState(() {
                                _selectedModeId = id;
                                _selectedModeName = name;
                              });
                              setState(() {});
                            },
                          );
                        }),
                      ],
                    ),
                  ],
                  const SizedBox(height: 22),
                  SizedBox(
                    width: double.infinity,
                    height: 46,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(ctx),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryPurple,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Text(
                        'Áp dụng',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildChoiceChip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? primaryPurple : bgSoft,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : darkText,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  void _showSnack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? const Color(0xFFD32F2F) : darkText,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final rooms = _filteredRooms;
    final hasActiveFilter =
        _selectedModeId != null || _privacyFilter != 'all';

    return Scaffold(
      backgroundColor: bgSoft,
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 430),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Thanh tìm kiếm & nhập mã phòng giống thiết kế Figma
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
                  child: Container(
                    height: 48,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        IconButton(
                          icon: const Icon(
                            Icons.arrow_back_rounded,
                            color: darkText,
                            size: 22,
                          ),
                          onPressed: () => Navigator.pop(context),
                        ),
                        Expanded(
                          child: TextField(
                            controller: _searchController,
                            onChanged: (val) =>
                                setState(() => _searchQuery = val),
                            onSubmitted: (val) {
                              if (val.trim().length == 6) {
                                _joinByCodeDirectly(val);
                              }
                            },
                            style: const TextStyle(
                              fontSize: 14,
                              color: darkText,
                            ),
                            decoration: const InputDecoration(
                              hintText: 'Nhập mã phòng hoặc tên bộ đề...',
                              hintStyle: TextStyle(
                                color: Color(0xFF9EA2B8),
                                fontSize: 13.5,
                              ),
                              border: InputBorder.none,
                              isDense: true,
                            ),
                          ),
                        ),
                        if (_searchQuery.isNotEmpty)
                          IconButton(
                            icon: const Icon(
                              Icons.close_rounded,
                              size: 18,
                              color: subText,
                            ),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _searchQuery = '');
                            },
                          ),
                        IconButton(
                          icon: const Icon(
                            Icons.search_rounded,
                            color: darkText,
                            size: 22,
                          ),
                          tooltip: 'Tìm / Vào nhanh theo mã',
                          onPressed: () {
                            if (_searchQuery.trim().length == 6) {
                              _joinByCodeDirectly(_searchQuery);
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                ),

                // 2. Hàng nút Filter + Chip đang lọc (giống màn hình Figma bên phải)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        InkWell(
                          onTap: _openFilterSheet,
                          borderRadius: BorderRadius.circular(20),
                          child: Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.05),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Icon(
                              Icons.filter_alt_outlined,
                              size: 20,
                              color: hasActiveFilter ? primaryPurple : darkText,
                            ),
                          ),
                        ),
                        if (_selectedModeName != null) ...[
                          const SizedBox(width: 8),
                          _buildActiveFilterPill(
                            label: _selectedModeName!,
                            onRemove: () => setState(() {
                              _selectedModeId = null;
                              _selectedModeName = null;
                            }),
                          ),
                        ],
                        if (_privacyFilter != 'all') ...[
                          const SizedBox(width: 8),
                          _buildActiveFilterPill(
                            label: _privacyFilter == 'public'
                                ? 'Công khai'
                                : 'Riêng tư',
                            onRemove: () =>
                                setState(() => _privacyFilter = 'all'),
                          ),
                        ],
                        if (hasActiveFilter) ...[
                          const SizedBox(width: 8),
                          InkWell(
                            onTap: () => setState(() {
                              _selectedModeId = null;
                              _selectedModeName = null;
                              _privacyFilter = 'all';
                            }),
                            borderRadius: BorderRadius.circular(20),
                            child: Container(
                              width: 32,
                              height: 32,
                              decoration: const BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.close_rounded,
                                size: 16,
                                color: Color(0xFFE53935),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),

                // 3. Danh sách phòng đang chờ
                Expanded(
                  child: _isLoading
                      ? const Center(
                          child: CircularProgressIndicator(
                            color: primaryPurple,
                          ),
                        )
                      : RefreshIndicator(
                          color: primaryPurple,
                          onRefresh: _fetchWaitingRooms,
                          child: rooms.isEmpty
                              ? ListView(
                                  children: const [
                                    SizedBox(height: 120),
                                    Center(
                                      child: Column(
                                        children: [
                                          Icon(
                                            Icons.meeting_room_outlined,
                                            size: 54,
                                            color: Color(0xFFB0B4C8),
                                          ),
                                          SizedBox(height: 12),
                                          Text(
                                            'Chưa có phòng nào đang chờ',
                                            style: TextStyle(
                                              fontSize: 15,
                                              fontWeight: FontWeight.w700,
                                              color: subText,
                                            ),
                                          ),
                                          SizedBox(height: 4),
                                          Text(
                                            'Kéo xuống để làm mới hoặc tạo phòng mới',
                                            style: TextStyle(
                                              fontSize: 12.5,
                                              color: Color(0xFF8C90A6),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                )
                              : ListView.separated(
                                  padding:
                                      const EdgeInsets.fromLTRB(16, 2, 16, 24),
                                  itemCount: rooms.length,
                                  separatorBuilder: (_, _) =>
                                      const SizedBox(height: 12),
                                  itemBuilder: (_, index) =>
                                      _buildRoomCard(rooms[index]),
                                ),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActiveFilterPill({
    required String label,
    required VoidCallback onRemove,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: darkText,
            ),
          ),
          const SizedBox(width: 6),
          GestureDetector(
            onTap: onRemove,
            child: const Icon(Icons.close_rounded, size: 15, color: subText),
          ),
        ],
      ),
    );
  }

  Widget _buildRoomCard(core.Map<String, dynamic> room) {
    final code = room['ma_phong']?.toString() ?? '------';
    final title = _getExamTitle(room);
    final subject = _getSubjectName(room);
    final mode = _getModeName(room);
    final hostName = _getHostName(room);
    final current = _getCurrentCount(room);
    final max = _getMaxPlayers(room);
    final isPrivate = _hasPassword(room);
    final isFull = current >= max;

    return InkWell(
      onTap: () => _handleJoinRoom(room),
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.045),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            // Khối icon bên trái giống card Figma
            Container(
              width: 68,
              height: 68,
              decoration: BoxDecoration(
                color: const Color(0xFFECEEFF),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.sports_esports_rounded,
                    color: primaryPurple,
                    size: 26,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    code,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: darkText,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 14),

            // Thông tin chi tiết phòng
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w800,
                            color: darkText,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                      if (isPrivate)
                        const Padding(
                          padding: EdgeInsets.only(left: 6),
                          child: Icon(
                            Icons.lock_rounded,
                            size: 16,
                            color: accentOrange,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  _buildMetaLine('Chủ đề: ', '$subject • $mode'),
                  const SizedBox(height: 2),
                  _buildMetaLine('Chủ phòng: ', hostName),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: isFull
                              ? const Color(0xFFFFEBEE)
                              : const Color(0xFFE8F5E9),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          'Người chơi: $current/$max',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: isFull
                                ? const Color(0xFFD32F2F)
                                : const Color(0xFF2E7D32),
                          ),
                        ),
                      ),
                      const Spacer(),
                      Text(
                        isFull ? 'Đã đầy' : 'Tham gia →',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w800,
                          color: isFull ? Colors.grey : primaryPurple,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetaLine(String label, String value) {
    return RichText(
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      text: TextSpan(
        style: const TextStyle(fontSize: 12.5, color: darkText),
        children: [
          TextSpan(
            text: label,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          TextSpan(
            text: value,
            style: const TextStyle(
              fontWeight: FontWeight.w500,
              color: subText,
            ),
          ),
        ],
      ),
    );
  }
}