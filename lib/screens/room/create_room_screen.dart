import 'dart:core';
import 'dart:core' as core;
import 'dart:math';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:material_ui/material_ui.dart';

import '../../models/game_mode_model.dart';
import '../../services/quiz_service.dart';
import '../../services/supabase_service.dart';
import 'room_lobby_screen.dart';

class CreateRoomScreen extends StatefulWidget {
  final core.Map<String, dynamic>? initialExam;

  const CreateRoomScreen({
    super.key,
    this.initialExam,
  });

  @override
  State<CreateRoomScreen> createState() => _CreateRoomScreenState();
}

class _CreateRoomScreenState extends State<CreateRoomScreen> {
  static const Color primaryPurple = Color(0xFF565CEB);
  static const Color deepPurple = Color(0xFF3E44C6);
  static const Color cardLavender = Color(0xFFECEEFF);
  static const Color accentOrange = Color(0xFFF79E1B);
  static const Color darkText = Color(0xFF1E1E2C);
  static const Color disabledGrey = Color(0xFFBDBDBD);

  final TextEditingController _passwordController = TextEditingController();

  core.List<core.Map<String, dynamic>> _exams = [];
  core.Map<String, dynamic>? _selectedExam;

  core.List<GameModeModel> _gameModes = [];
  String? _selectedModeId;
  String _selectedModeLabel = 'Tùy chọn';

  int _maxPlayers = 2;
  final core.List<int> _playerOptions = [2, 4, 6, 8, 10, 15, 20];

  bool _isPrivate = false;
  bool _obscurePassword = true;
  bool _isLoadingData = true;
  bool _isCreatingRoom = false;

  @override
  void initState() {
    super.initState();
    _selectedExam = widget.initialExam;
    _loadInitialData();
  }

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  String get _currentCreatorName {
    final user = FirebaseAuth.instance.currentUser;
    if (user?.displayName != null && user!.displayName!.trim().isNotEmpty) {
      return user.displayName!.trim();
    }
    if (user?.email != null && user!.email!.contains('@')) {
      return user.email!.split('@').first;
    }
    final uid = user?.uid ?? '36063';
    final shortId = uid.length > 5 ? uid.substring(0, 5) : uid;
    return 'Player$shortId';
  }

  core.Future<void> _loadInitialData() async {
    try {
      final modes = await QuizService.getActiveGameModes();

      core.List<core.Map<String, dynamic>> examList = [];
      if (_selectedExam == null) {
        final res = await SupabaseService.client
            .from('de_thi')
            .select(
              'id, tieu_de, anh_bia_url, mon_hoc:mon_hoc_id(ten_mon), '
              'cau_hoi(id), nguoi_dung:nguoi_tao_id(ten_hien_thi, email)',
            )
            .order('id', ascending: false)
            .limit(30);
        examList =
            core.List<core.Map<String, dynamic>>.from(res as core.List);
      }

      if (!mounted) return;
      setState(() {
        _gameModes = modes;
        if (_gameModes.isNotEmpty) {
          _selectedModeId = _gameModes.first.id;
          _selectedModeLabel = _gameModes.first.tenCheDo;
        }
        if (_selectedExam == null && examList.isNotEmpty) {
          _exams = examList;
          _selectedExam = examList.first;
        }
        _isLoadingData = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoadingData = false);
      _showSnack(
        e.toString().replaceFirst('Exception: ', ''),
        isError: true,
      );
    }
  }

  core.Future<void> _openExamSearchSheet() async {
    if (_exams.isEmpty) {
      try {
        final res = await SupabaseService.client
            .from('de_thi')
            .select(
              'id, tieu_de, anh_bia_url, mon_hoc:mon_hoc_id(ten_mon), '
              'cau_hoi(id), nguoi_dung:nguoi_tao_id(ten_hien_thi, email)',
            )
            .order('id', ascending: false)
            .limit(50);
        _exams = core.List<core.Map<String, dynamic>>.from(res as core.List);
      } catch (e) {
        _showSnack('Không thể tải danh sách bộ đề: $e', isError: true);
        return;
      }
    }

    if (!mounted) return;
    String keyword = '';

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            final filtered = _exams.where((item) {
              if (keyword.trim().isEmpty) return true;
              final title =
                  (item['tieu_de']?.toString() ?? '').toLowerCase();
              return title.contains(keyword.trim().toLowerCase());
            }).toList();

            return SafeArea(
              child: SizedBox(
                height: MediaQuery.of(ctx).size.height * 0.72,
                child: Column(
                  children: [
                    const SizedBox(height: 10),
                    Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
                      child: TextField(
                        onChanged: (val) => setSheetState(() => keyword = val),
                        decoration: InputDecoration(
                          hintText: 'Tìm kiếm bộ đề...',
                          prefixIcon: const Icon(Icons.search_rounded),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: filtered.isEmpty
                          ? const Center(
                              child: Text(
                                'Không tìm thấy bộ đề phù hợp.',
                                style: TextStyle(color: Colors.grey),
                              ),
                            )
                          : ListView.separated(
                              padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                              itemCount: filtered.length,
                              separatorBuilder: (_, _) =>
                                  const SizedBox(height: 10),
                              itemBuilder: (_, idx) {
                                final exam = filtered[idx];
                                final subjectMap = exam['mon_hoc'] as core.Map?;
                                final subjectName =
                                    subjectMap?['ten_mon']?.toString() ??
                                        'Chung';
                                final qCount =
                                    (exam['cau_hoi'] as core.List?)?.length ??
                                        (exam['so_cau_hoi'] ?? 0);
                                final isCurrent = _selectedExam?['id']
                                        ?.toString() ==
                                    exam['id']?.toString();

                                return Material(
                                  color: isCurrent
                                      ? cardLavender
                                      : const Color(0xFFF7F8FC),
                                  clipBehavior: Clip.antiAlias,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                    side: BorderSide(
                                      color: isCurrent
                                          ? primaryPurple
                                          : const Color(0xFFE3E6FA),
                                      width: isCurrent ? 1.5 : 1,
                                    ),
                                  ),
                                  child: ListTile(
                                    title: Text(
                                      exam['tieu_de']?.toString() ?? 'Bộ đề',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        color: darkText,
                                      ),
                                    ),
                                    subtitle: Text(
                                      'Chủ đề: $subjectName • $qCount câu hỏi',
                                    ),
                                    trailing: Icon(
                                      isCurrent
                                          ? Icons.check_circle_rounded
                                          : Icons.chevron_right_rounded,
                                      color: primaryPurple,
                                    ),
                                    onTap: () {
                                      setState(() => _selectedExam = exam);
                                      Navigator.pop(ctx);
                                    },
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  String _generateRoomCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final rand = Random();
    return core.List.generate(6, (_) => chars[rand.nextInt(chars.length)])
        .join();
  }

  core.Future<void> _handleCreateRoom() async {
    if (_selectedExam == null) {
      _showSnack('Vui lòng chọn bộ đề trước khi tạo phòng!', isError: true);
      return;
    }

    if (_isPrivate && _passwordController.text.trim().isEmpty) {
      _showSnack('Vui lòng nhập mật khẩu cho phòng riêng tư!', isError: true);
      return;
    }

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      _showSnack('Bạn chưa đăng nhập!', isError: true);
      return;
    }

    setState(() => _isCreatingRoom = true);

    try {
      final roomCode = _generateRoomCode();

      final payload = <String, dynamic>{
        'ma_phong': roomCode,
        'de_thi_id': _selectedExam!['id'],
        'chu_phong_id': uid,
        'so_nguoi_toi_da': _maxPlayers,
        'rieng_tu': _isPrivate,
        'mat_khau': _isPrivate ? _passwordController.text.trim() : null,
        'trang_thai': 'dang_cho',
        if (_selectedModeId != null) 'che_do_choi_id': _selectedModeId,
      };

      final createdRoom = await SupabaseService.client
          .from('phong_thi')
          .insert(payload)
          .select()
          .single();

      if (!mounted) return;
      _showSnack('Tạo phòng thành công! Mã phòng: $roomCode');
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => RoomLobbyScreen(roomData: createdRoom),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      _showSnack(
        'Không thể tạo phòng: ${e.toString().replaceFirst('Exception: ', '')}',
        isError: true,
      );
    } finally {
      if (mounted) setState(() => _isCreatingRoom = false);
    }
  }

  void _showSnack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor:
            isError ? const Color(0xFFD32F2F) : const Color(0xFF2E7D32),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final examTitle =
        _selectedExam?['tieu_de']?.toString() ?? 'Chưa chọn bộ đề';

    final subjectObj = _selectedExam?['mon_hoc'];
    final subjectName = subjectObj is core.Map
        ? (subjectObj['ten_mon']?.toString() ?? 'Chung')
        : (_selectedExam?['ten_mon']?.toString() ?? 'Chung');

    final questionCount = _selectedExam?['cau_hoi'] is core.List
        ? (_selectedExam!['cau_hoi'] as core.List).length
        : (_selectedExam?['so_cau_hoi'] ?? 0);

    final creatorObj = _selectedExam?['nguoi_dung'];
    final creatorName = creatorObj is core.Map
        ? (creatorObj['ten_hien_thi']?.toString() ?? _currentCreatorName)
        : _currentCreatorName;

    final coverUrl = _selectedExam?['anh_bia_url']?.toString();
    final hasCover = coverUrl != null && coverUrl.isNotEmpty;

    return Scaffold(
      backgroundColor: primaryPurple,
      appBar: AppBar(
        backgroundColor: primaryPurple,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Tạo phòng',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
            fontSize: 19,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search_rounded, color: Colors.white),
            tooltip: 'Tìm kiếm bộ đề',
            onPressed: _openExamSearchSheet,
          ),
        ],
      ),
      body: _isLoadingData
          ? const Center(
              child: CircularProgressIndicator(color: Colors.white),
            )
          : Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(18, 12, 18, 28),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // 1. Banner ảnh bìa bộ đề
                      GestureDetector(
                        onTap: _openExamSearchSheet,
                        child: Container(
                          height: 168,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(24),
                            gradient: hasCover
                                ? null
                                : const LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [
                                      Color(0xFF6B72FF),
                                      deepPurple,
                                    ],
                                  ),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.28),
                              width: 1.5,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.16),
                                blurRadius: 14,
                                offset: const Offset(0, 6),
                              ),
                            ],
                            image: hasCover
                                ? DecorationImage(
                                    image: NetworkImage(coverUrl),
                                    fit: BoxFit.cover,
                                  )
                                : null,
                          ),
                          child: Stack(
                            children: [
                              if (!hasCover) ...[
                                Positioned(
                                  right: -24,
                                  top: -10,
                                  child: Transform.rotate(
                                    angle: 0.1,
                                    child: Icon(
                                      Icons.calculate_rounded,
                                      size: 140,
                                      color:
                                          Colors.white.withValues(alpha: 0.045),
                                    ),
                                  ),
                                ),
                                Positioned(
                                  left: -20,
                                  bottom: -20,
                                  child: Transform.rotate(
                                    angle: -0.15,
                                    child: Icon(
                                      Icons.architecture_rounded,
                                      size: 130,
                                      color:
                                          Colors.white.withValues(alpha: 0.045),
                                    ),
                                  ),
                                ),
                              ],
                              Positioned.fill(
                                child: Container(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(24),
                                    gradient: LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: [
                                        Colors.transparent,
                                        Colors.black.withValues(alpha: 0.35),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(14),
                                      decoration: BoxDecoration(
                                        color:
                                            Colors.white.withValues(alpha: 0.16),
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: Colors.white
                                              .withValues(alpha: 0.22),
                                          width: 1.5,
                                        ),
                                      ),
                                      child: Icon(
                                        hasCover
                                            ? Icons.play_circle_fill_rounded
                                            : (subjectName == 'Toán'
                                                ? Icons.calculate_rounded
                                                : Icons.school_rounded),
                                        size: 32,
                                        color: Colors.white,
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    Text(
                                      subjectName.toUpperCase(),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w900,
                                        fontSize: 16,
                                        letterSpacing: 0.8,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Positioned(
                                right: 14,
                                bottom: 14,
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(20),
                                  child: Material(
                                    color: Colors.black.withValues(alpha: 0.52),
                                    child: InkWell(
                                      onTap: _openExamSearchSheet,
                                      child: const Padding(
                                        padding: EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 5,
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              Icons.swap_horiz_rounded,
                                              color: Colors.white,
                                              size: 15,
                                            ),
                                            SizedBox(width: 4),
                                            Text(
                                              'Đổi bộ đề',
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontSize: 11.5,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // 2. Thẻ thông tin bộ đề
                      GestureDetector(
                        onTap: _openExamSearchSheet,
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.10),
                                blurRadius: 12,
                                offset: const Offset(0, 5),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      examTitle,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w800,
                                        color: darkText,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: cardLavender,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: const Text(
                                      'Chọn đề',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: primaryPurple,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const Padding(
                                padding: EdgeInsets.symmetric(vertical: 10),
                                child: Divider(
                                  height: 1,
                                  color: Color(0xFFECEEFF),
                                ),
                              ),
                              _buildIconInfoRow(
                                Icons.menu_book_rounded,
                                'Chủ đề:',
                                subjectName,
                              ),
                              const SizedBox(height: 7),
                              _buildIconInfoRow(
                                Icons.help_outline_rounded,
                                'Số câu hỏi:',
                                '$questionCount câu',
                              ),
                              const SizedBox(height: 7),
                              _buildIconInfoRow(
                                Icons.person_outline_rounded,
                                'Người tạo:',
                                creatorName,
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),

                      // 3. Hàng Chế độ & Số người chơi
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Chế độ chơi',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13.5,
                                  ),
                                ),
                                const SizedBox(height: 7),
                                _buildModeDropdown(),
                              ],
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Số người chơi',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13.5,
                                  ),
                                ),
                                const SizedBox(height: 7),
                                _buildPlayerCountDropdown(),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),

                      // 4. Hàng Riêng tư & Mật khẩu
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Riêng tư',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13.5,
                                ),
                              ),
                              const SizedBox(height: 7),
                              _buildCustomPrivacySwitch(),
                            ],
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Mật khẩu phòng',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13.5,
                                  ),
                                ),
                                const SizedBox(height: 7),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(14),
                                  child: SizedBox(
                                    height: 44,
                                    child: TextField(
                                      controller: _passwordController,
                                      enabled: _isPrivate,
                                      readOnly: !_isPrivate,
                                      obscureText: _obscurePassword,
                                      style: TextStyle(
                                        color: _isPrivate
                                            ? darkText
                                            : Colors.grey.shade700,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                      ),
                                      decoration: InputDecoration(
                                        filled: true,
                                        fillColor: _isPrivate
                                            ? Colors.white
                                            : disabledGrey,
                                        hintText: _isPrivate
                                            ? 'Nhập mật khẩu...'
                                            : 'Phòng công khai',
                                        hintStyle: TextStyle(
                                          color: _isPrivate
                                              ? Colors.grey.shade500
                                              : const Color(0xFF616161),
                                          fontSize: 13,
                                          fontWeight: FontWeight.w500,
                                        ),
                                        border: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(14),
                                          borderSide: BorderSide.none,
                                        ),
                                        enabledBorder: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(14),
                                          borderSide: BorderSide.none,
                                        ),
                                        disabledBorder: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(14),
                                          borderSide: BorderSide.none,
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(14),
                                          borderSide: const BorderSide(
                                            color: accentOrange,
                                            width: 1.5,
                                          ),
                                        ),
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                          horizontal: 14,
                                          vertical: 11,
                                        ),
                                        suffixIcon: _isPrivate
                                            ? IconButton(
                                                icon: Icon(
                                                  _obscurePassword
                                                      ? Icons
                                                          .visibility_off_rounded
                                                      : Icons
                                                          .visibility_rounded,
                                                  size: 19,
                                                  color: Colors.grey.shade600,
                                                ),
                                                onPressed: () => setState(() =>
                                                    _obscurePassword =
                                                        !_obscurePassword),
                                              )
                                            : const Icon(
                                                Icons.lock_open_rounded,
                                                size: 18,
                                                color: Color(0xFF616161),
                                              ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 30),

                      // 5. Nút Tạo phòng
                      SizedBox(
                        height: 50,
                        child: ElevatedButton.icon(
                          onPressed:
                              _isCreatingRoom ? null : _handleCreateRoom,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: accentOrange,
                            foregroundColor: darkText,
                            elevation: 3,
                            shadowColor: Colors.black.withValues(alpha: 0.25),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          icon: _isCreatingRoom
                              ? const SizedBox.shrink()
                              : const Icon(
                                  Icons.meeting_room_rounded,
                                  color: darkText,
                                  size: 21,
                                ),
                          label: _isCreatingRoom
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                    color: darkText,
                                  ),
                                )
                              : const Text(
                                  'Tạo phòng ngay',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                    color: darkText,
                                  ),
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

  Widget _buildIconInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 17, color: primaryPurple),
        const SizedBox(width: 8),
        Text(
          '$label ',
          style: const TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w600,
            color: Color(0xFF5D617A),
          ),
        ),
        Expanded(
          child: Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
              color: darkText,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildModeDropdown() {
    final items = _gameModes.isNotEmpty
        ? _gameModes
            .map(
              (m) => DropdownMenuItem<String>(
                value: m.id,
                child: Text(
                  m.tenCheDo,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: darkText,
                  ),
                ),
              ),
            )
            .toList()
        : [
            DropdownMenuItem<String>(
              value: 'default',
              child: Text(
                _selectedModeLabel,
                style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  color: darkText,
                ),
              ),
            ),
          ];

    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _gameModes.isNotEmpty ? _selectedModeId : 'default',
          isExpanded: true,
          icon: const Icon(
            Icons.keyboard_arrow_down_rounded,
            color: primaryPurple,
          ),
          items: items,
          onChanged: (val) {
            if (val == null) return;
            setState(() {
              _selectedModeId = val;
              if (_gameModes.isNotEmpty) {
                final found = _gameModes.firstWhere((e) => e.id == val);
                _selectedModeLabel = found.tenCheDo;
              }
            });
          },
        ),
      ),
    );
  }

  Widget _buildPlayerCountDropdown() {
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int>(
          value: _maxPlayers,
          isExpanded: true,
          icon: const Icon(
            Icons.keyboard_arrow_down_rounded,
            color: primaryPurple,
          ),
          items: _playerOptions.map((count) {
            return DropdownMenuItem<int>(
              value: count,
              child: Text(
                '$count người',
                style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  color: darkText,
                ),
              ),
            );
          }).toList(),
          onChanged: (val) {
            if (val != null) {
              setState(() => _maxPlayers = val);
            }
          },
        ),
      ),
    );
  }

  Widget _buildCustomPrivacySwitch() {
    return GestureDetector(
      onTap: () {
        setState(() {
          _isPrivate = !_isPrivate;
          if (!_isPrivate) {
            FocusScope.of(context).unfocus();
            _passwordController.clear();
          }
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 78,
        height: 44,
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: darkText,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.25),
          ),
        ),
        child: AnimatedAlign(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          alignment:
              _isPrivate ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            width: 34,
            height: 34,
            decoration: const BoxDecoration(
              color: accentOrange,
              shape: BoxShape.circle,
            ),
          ),
        ),
      ),
    );
  }
}