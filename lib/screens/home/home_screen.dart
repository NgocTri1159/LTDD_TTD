import 'dart:core';
import 'dart:core' as core;
import 'dart:math';
import 'package:material_ui/material_ui.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide User;
import '../../services/auth_service.dart';
import '../../services/backend_service.dart';
import '../../services/exam_service.dart';
import '../../services/role_service.dart';
import '../../services/session_guard_service.dart';
import '../../screens/subject/subject_detail_screen.dart';
import '../../screens/subject/subject_list_screen.dart';
import '../../screens/setting/change_password_screen.dart';
import '../../screens/profile/profile_screen.dart';
import '../../screens/quiz/create_quiz_screen.dart';
import '../../screens/quiz/quiz_taking_screen.dart';
import '../../screens/room/create_room_screen.dart';
import '../../screens/room/room_list_screen.dart';
import '../../screens/room/room_lobby_screen.dart';
import '../../screens/ranking/leaderboard_screen.dart';
import '../../screens/statistics/statistics_screen.dart';
import '../../models/subject_model.dart';
import '../../services/subject_service.dart';
import '../../screens/friends/friends_tab.dart';
import '../admin/admin_screen.dart';

class HomeScreen extends StatefulWidget {
  final bool fromAdmin;

  const HomeScreen({super.key, this.fromAdmin = false});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const Color primaryPurple = Color(0xFF565CEB);
  static const Color cardLavender = Color(0xFFECEEFF);
  static const Color accentOrange = Color(0xFFF79E1B);
  static const Color darkText = Color(0xFF1E1E2C);
  static const Color backgroundColor = Color(0xFFF9FAFF);

  final SupabaseClient _supabase = Supabase.instance.client;
  final Random _random = Random();
  RealtimeChannel? _notificationChannel;

  int _selectedIndex = 0;
  bool _isAdminUser = false;
  bool _isQuickMatching = false;

  core.List<core.Map<String, dynamic>> _notifications = [];
  int get _unreadCount =>
      _notifications.where((n) => n['da_doc'] != true).length;

  late Future<core.List<SubjectModel>> _subjectsFuture;

  final _quickActions = [
    {
      'label': 'Chơi ngay',
      'icon': Icons.play_arrow_rounded,
      'action': 'play_now',
    },
    {
      'label': 'Thách đấu',
      'icon': Icons.emoji_events_rounded,
      'action': 'challenge',
    },
    {
      'label': 'Xếp hạng',
      'icon': Icons.military_tech_rounded,
      'action': 'ranking',
    },
    {
      'label': 'Thống kê',
      'icon': Icons.bar_chart_rounded,
      'action': 'statistics',
    },
  ];

  final core.List<core.Map<String, dynamic>> _mainFeatures = [
    {
      'label': 'Tạo bộ đề',
      'icon': Icons.post_add_rounded,
      'action': 'create_quiz',
      'bgColor': const Color(0xFFFFF3E0),
      'iconColor': const Color(0xFFF79E1B), // Cam nổi bật
    },
    {
      'label': 'Tạo phòng',
      'icon': Icons.add_circle_outline_rounded,
      'action': 'create_room',
      'bgColor': const Color(0xFFE8F5E9),
      'iconColor': const Color(0xFF2E7D32), // Xanh lá
    },
    {
      'label': 'DS phòng',
      'icon': Icons.meeting_room_outlined,
      'action': 'room_list',
      'bgColor': const Color(0xFFE1F5FE),
      'iconColor': const Color(0xFF0288D1), // Xanh dương
    },
    {
      'label': 'Khác',
      'icon': Icons.apps_rounded,
      'action': 'more',
      'bgColor': const Color(0xFFF3E5F5),
      'iconColor': const Color(0xFF7B1FA2), // Tím violet
    },
  ];

  @override
  void initState() {
    super.initState();
    _isAdminUser = widget.fromAdmin;
    _subjectsFuture = SubjectService.getAllSubjects();
    _checkAdminRole();
    _loadNotifications();
    _subscribeRealtimeNotifications();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        try {
          await BackendService.checkCurrentUser();
        } catch (e) {
          debugPrint('CHECK CURRENT USER ERROR: $e');
        }
        if (mounted) {
          await SessionGuardService.instance.startSession(context);
        }
      }
    });
  }

  @override
  void dispose() {
    if (_notificationChannel != null) {
      _supabase.removeChannel(_notificationChannel!);
    }
    super.dispose();
  }

  // =========================
  // 4 CHỨC NĂNG NHANH TRÊN HEADER
  // =========================

  /// 1. Chơi ngay: Vào ngẫu nhiên 1 phòng công khai đang chờ
  Future<void> _handlePlayNowRandomRoom() async {
    if (_isQuickMatching) return;
    setState(() => _isQuickMatching = true);

    try {
      final res = await _supabase
          .from('phong_thi')
          .select('*, thanh_vien_phong(id, nguoi_dung_id)')
          .eq('trang_thai', 'dang_cho')
          .eq('rieng_tu', false);

      final allWaiting =
          core.List<core.Map<String, dynamic>>.from(res as core.List);

      // Lọc các phòng công khai (không mật khẩu), có ít nhất 1 người và chưa đầy
      final availableRooms = allWaiting.where((room) {
        final pwd = (room['mat_khau'] ?? '').toString().trim();
        if (pwd.isNotEmpty) return false;

        final members = room['thanh_vien_phong'];
        final currentCount = members is core.List ? members.length : 0;
        final maxPlayers = (room['so_nguoi_toi_da'] as num?)?.toInt() ?? 2;

        return currentCount > 0 && currentCount < maxPlayers;
      }).toList();

      if (!mounted) return;

      if (availableRooms.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'Hiện chưa có phòng công khai nào đang chờ. Bạn có thể tạo phòng mới!',
            ),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            action: SnackBarAction(
              label: 'Tạo phòng',
              textColor: const Color(0xFFFFD54F),
              onPressed: _openCreateRoomScreen,
            ),
          ),
        );
        return;
      }

      final chosenRoom = availableRooms[_random.nextInt(availableRooms.length)];

      // Lấy dữ liệu mới nhất của phòng trước khi vào sảnh
      final freshRoom = await _supabase
          .from('phong_thi')
          .select('*')
          .eq('id', chosenRoom['id'])
          .maybeSingle();

      if (!mounted) return;

      if (freshRoom == null || freshRoom['trang_thai'] != 'dang_cho') {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Phòng vừa bắt đầu, vui lòng bấm Chơi ngay lại.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }

      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => RoomLobbyScreen(
            roomData: core.Map<String, dynamic>.from(freshRoom),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Không thể tìm phòng ngẫu nhiên: $e'),
          backgroundColor: const Color(0xFFD32F2F),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _isQuickMatching = false);
    }
  }

  /// 2. Thách đấu: Làm ngẫu nhiên 1 đề kiểm tra công khai đã xuất bản
  Future<void> _handleRandomChallengeExam() async {
    if (_isQuickMatching) return;
    setState(() => _isQuickMatching = true);

    try {
      final exams = await ExamService.getPublishedExams(limit: 50);

      // Ưu tiên chọn trong các đề có ít nhất 1 câu hỏi
      final validExams =
          exams.where((e) => (e.soLuongCauHoi ?? 0) > 0).toList();
      final pool = validExams.isNotEmpty ? validExams : exams;

      if (!mounted) return;

      if (pool.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Hiện chưa có đề kiểm tra công khai nào trên hệ thống.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }

      final randomExam = pool[_random.nextInt(pool.length)];

      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => QuizTakingScreen(exam: randomExam),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e.toString().replaceFirst('Exception: ', ''),
          ),
          backgroundColor: const Color(0xFFD32F2F),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _isQuickMatching = false);
    }
  }

  /// 3. Xếp hạng: Top Rank & Top Cấp độ
  void _openLeaderboardScreen() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const LeaderboardScreen(),
      ),
    );
  }

  /// 4. Thống kê: Xếp hạng, số câu hỏi đã trả lời, tổng thời gian chơi, tỷ lệ đúng
  void _openStatisticsScreen() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const StatisticsScreen(),
      ),
    );
  }

  // =========================
  // HỆ THỐNG THÔNG BÁO
  // =========================

  Future<void> _loadNotifications() async {
    final email = currentUser?.email?.trim();
    if (email == null || email.isEmpty) return;

    try {
      final data = await _supabase
          .from('thong_bao')
          .select()
          .ilike('nguoi_nhan_email', email)
          .order('ngay_tao', ascending: false)
          .limit(30);

      if (!mounted) return;
      setState(() {
        _notifications = core.List<core.Map<String, dynamic>>.from(data);
      });
    } catch (e) {
      debugPrint('LOAD NOTIFICATIONS ERROR: $e');
    }
  }

  void _subscribeRealtimeNotifications() {
    final email = currentUser?.email?.trim().toLowerCase();
    if (email == null || email.isEmpty) return;

    _notificationChannel = _supabase
        .channel('public:thong_bao:$email')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'thong_bao',
          callback: (payload) {
            final newRecord = payload.newRecord;
            final targetEmail = (newRecord['nguoi_nhan_email'] ?? '')
                .toString()
                .trim()
                .toLowerCase();

            if (targetEmail == email && mounted) {
              setState(() {
                _notifications.insert(0, newRecord);
              });
              _showIncomingNotificationBanner(newRecord);
            }
          },
        )
        .subscribe();
  }

  void _showIncomingNotificationBanner(core.Map<String, dynamic> item) {
    if (!mounted) return;
    final title = (item['tieu_de'] ?? 'Thông báo mới').toString();
    final body = (item['noi_dung'] ?? '').toString();

    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(
              Icons.notifications_active_rounded,
              color: Color(0xFFFFD54F),
              size: 24,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13.5,
                      color: Colors.white,
                    ),
                  ),
                  if (body.isNotEmpty)
                    Text(
                      body,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: Colors.white70,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
        backgroundColor: darkText,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        duration: const Duration(seconds: 4),
        action: SnackBarAction(
          label: 'Xem',
          textColor: const Color(0xFFFFD54F),
          onPressed: _openNotificationsSheet,
        ),
      ),
    );
  }

  Future<void> _markNotificationAsRead(dynamic id, int index) async {
    if (_notifications[index]['da_doc'] == true) return;

    setState(() {
      _notifications[index]['da_doc'] = true;
    });

    try {
      await _supabase
          .from('thong_bao')
          .update({'da_doc': true}).eq('id', id);
    } catch (e) {
      debugPrint('MARK READ ERROR: $e');
    }
  }

  Future<void> _markAllNotificationsAsRead() async {
    final email = currentUser?.email?.trim();
    if (email == null || email.isEmpty || _unreadCount == 0) return;

    setState(() {
      for (final item in _notifications) {
        item['da_doc'] = true;
      }
    });

    try {
      await _supabase
          .from('thong_bao')
          .update({'da_doc': true})
          .ilike('nguoi_nhan_email', email)
          .eq('da_doc', false);
    } catch (e) {
      debugPrint('MARK ALL READ ERROR: $e');
    }
  }

  IconData _getNotificationIcon(String? type) {
    switch (type) {
      case 'rank':
        return Icons.military_tech_rounded;
      case 'friend':
        return Icons.person_add_alt_1_rounded;
      case 'room':
        return Icons.sports_esports_rounded;
      default:
        return Icons.notifications_rounded;
    }
  }

  String _formatTimeAgo(String? isoString) {
    if (isoString == null || isoString.isEmpty) return 'Vừa xong';
    final dt = DateTime.tryParse(isoString)?.toLocal();
    if (dt == null) return 'Vừa xong';

    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'Vừa xong';
    if (diff.inMinutes < 60) return '${diff.inMinutes} phút trước';
    if (diff.inHours < 24) return '${diff.inHours} giờ trước';
    return '${diff.inDays} ngày trước';
  }

  Future<void> _openNotificationsSheet() async {
    await _loadNotifications();
    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return DraggableScrollableSheet(
              expand: false,
              initialChildSize: 0.65,
              minChildSize: 0.4,
              maxChildSize: 0.9,
              builder: (_, scrollController) {
                return Column(
                  children: [
                    const SizedBox(height: 10),
                    Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 14, 12, 10),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Text(
                                'Thông báo',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: darkText,
                                ),
                              ),
                              if (_unreadCount > 0) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFE53935),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    '$_unreadCount mới',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          if (_unreadCount > 0)
                            TextButton(
                              onPressed: () async {
                                await _markAllNotificationsAsRead();
                                setModalState(() {});
                              },
                              child: const Text(
                                'Đọc tất cả',
                                style: TextStyle(
                                  color: primaryPurple,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    Expanded(
                      child: _notifications.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.notifications_off_outlined,
                                    size: 52,
                                    color: Colors.grey.shade400,
                                  ),
                                  const SizedBox(height: 12),
                                  const Text(
                                    'Bạn chưa có thông báo nào',
                                    style: TextStyle(
                                      color: Colors.grey,
                                      fontSize: 14.5,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : ListView.separated(
                              controller: scrollController,
                              padding: const EdgeInsets.all(16),
                              itemCount: _notifications.length,
                              separatorBuilder: (_, _) =>
                                  const SizedBox(height: 10),
                              itemBuilder: (context, index) {
                                final item = _notifications[index];
                                final isUnread = item['da_doc'] != true;
                                final title =
                                    (item['tieu_de'] ?? 'Thông báo').toString();
                                final content =
                                    (item['noi_dung'] ?? '').toString();
                                final type = item['loai']?.toString();
                                final timeText = _formatTimeAgo(
                                  item['ngay_tao']?.toString(),
                                );

                                return InkWell(
                                  onTap: () async {
                                    await _markNotificationAsRead(
                                      item['id'],
                                      index,
                                    );
                                    setModalState(() {});
                                  },
                                  borderRadius: BorderRadius.circular(14),
                                  child: Container(
                                    padding: const EdgeInsets.all(14),
                                    decoration: BoxDecoration(
                                      color: isUnread
                                          ? cardLavender
                                          : const Color(0xFFF7F8FC),
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(
                                        color: isUnread
                                            ? primaryPurple.withValues(
                                                alpha: 0.35,
                                              )
                                            : const Color(0xFFE8EAFA),
                                      ),
                                    ),
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Container(
                                          width: 40,
                                          height: 40,
                                          decoration: BoxDecoration(
                                            color: isUnread
                                                ? primaryPurple
                                                : Colors.white,
                                            shape: BoxShape.circle,
                                          ),
                                          child: Icon(
                                            _getNotificationIcon(type),
                                            color: isUnread
                                                ? Colors.white
                                                : primaryPurple,
                                            size: 20,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                children: [
                                                  Expanded(
                                                    child: Text(
                                                      title,
                                                      style: TextStyle(
                                                        fontSize: 14,
                                                        fontWeight: isUnread
                                                            ? FontWeight.bold
                                                            : FontWeight.w600,
                                                        color: darkText,
                                                      ),
                                                    ),
                                                  ),
                                                  if (isUnread)
                                                    Container(
                                                      width: 8,
                                                      height: 8,
                                                      decoration:
                                                          const BoxDecoration(
                                                        color:
                                                            Color(0xFFE53935),
                                                        shape: BoxShape.circle,
                                                      ),
                                                    ),
                                                ],
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                content,
                                                style: const TextStyle(
                                                  fontSize: 13,
                                                  color: Color(0xFF4F536B),
                                                  height: 1.4,
                                                ),
                                              ),
                                              const SizedBox(height: 6),
                                              Text(
                                                timeText,
                                                style: const TextStyle(
                                                  fontSize: 11.5,
                                                  color: Colors.grey,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }

  // =========================
  // CÁC HÀM CƠ BẢN CỦA HOME
  // =========================

  Future<void> _checkAdminRole() async {
    try {
      final role = (await RoleService.getCurrentRole()).trim().toLowerCase();
      debugPrint('HOME_SCREEN ROLE: $role');
      if (!mounted) return;
      if (role == 'admin' || role == 'super_admin') {
        setState(() => _isAdminUser = true);
      }
    } catch (e) {
      debugPrint('HOME_SCREEN ROLE ERROR: $e');
    }
  }

  void _backToAdminDashboard() {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const AdminScreen()),
      (route) => false,
    );
  }

  void _loadSubjects() {
    if (!mounted) return;
    setState(() {
      _subjectsFuture = SubjectService.getAllSubjects();
    });
  }

  User? get currentUser => FirebaseAuth.instance.currentUser;

  String get userName {
    final name = currentUser?.displayName;
    if (name != null && name.trim().isNotEmpty) {
      return name.trim();
    }
    final email = currentUser?.email ?? 'Player';
    return email.split('@').first;
  }

  String get userPhotoUrl => (currentUser?.photoURL ?? '').trim();

  Future<void> _openProfileScreen() async {
    final updated = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => const ProfileScreen(),
      ),
    );
    if (updated == true && mounted) {
      setState(() {});
    }
  }

  Future<void> _openCreateQuizScreen() async {
    final created = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => const CreateQuizScreen(),
      ),
    );
    if (created == true && mounted) {
      _loadSubjects();
    }
  }

  Future<void> _openCreateRoomScreen() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const CreateRoomScreen(),
      ),
    );
  }

  Future<void> _openRoomListScreen() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const RoomListScreen(),
      ),
    );
  }

  void _showComingSoon(String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$feature đang được phát triển.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _openAllSubjects() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const SubjectListScreen(),
      ),
    );
  }

  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Đăng xuất'),
        content: const Text(
          'Bạn có chắc chắn muốn đăng xuất khỏi QuizMaster?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryPurple,
              foregroundColor: Colors.white,
            ),
            child: const Text('Đăng xuất'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await SessionGuardService.instance.stopSession();
      await AuthService().logout();
    }
  }

  Widget _buildUserAvatar({
    required double size,
    required double fontSize,
    bool hasWhiteBorder = false,
  }) {
    final initial = userName.isNotEmpty ? userName[0].toUpperCase() : 'P';

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: const Color(0xFFFFD54F),
        shape: BoxShape.circle,
        border: hasWhiteBorder
            ? Border.all(color: Colors.white, width: 2)
            : null,
      ),
      child: ClipOval(
        child: userPhotoUrl.isNotEmpty
            ? Image.network(
                userPhotoUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => Center(
                  child: Text(
                    initial,
                    style: TextStyle(
                      fontSize: fontSize,
                      fontWeight: FontWeight.w900,
                      color: const Color(0xFF282B78),
                    ),
                  ),
                ),
              )
            : Center(
                child: Text(
                  initial,
                  style: TextStyle(
                    fontSize: fontSize,
                    fontWeight: FontWeight.w900,
                    color: const Color(0xFF282B78),
                  ),
                ),
              ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      body: Stack(
        children: [
          IndexedStack(
            index: _selectedIndex,
            children: [
              _buildHomePage(),
              _buildHistoryPage(),
              _buildFriendsPage(),
              _buildSettingsPage(),
            ],
          ),
          if (_isQuickMatching)
            Container(
              color: Colors.black26,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 18,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: primaryPurple,
                        ),
                      ),
                      SizedBox(width: 14),
                      Text(
                        'Đang ghép trận...',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: darkText,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
      bottomNavigationBar: _buildBottomNavigation(),
    );
  }

  // =========================
  // 1. TRANG CHỦ
  // =========================

  Widget _buildHomePage() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth > 700;

        return RefreshIndicator(
          color: primaryPurple,
          onRefresh: () async {
            _loadSubjects();
            await _loadNotifications();
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 960),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildTopPurpleHeader(isWide),
                    Padding(
                      padding: EdgeInsets.fromLTRB(
                        isWide ? 28 : 20,
                        22,
                        isWide ? 28 : 20,
                        28,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (_isAdminUser) ...[
                            Container(
                              margin: const EdgeInsets.only(bottom: 18),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                color: cardLavender,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: primaryPurple.withValues(alpha: 0.35),
                                ),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.admin_panel_settings_rounded,
                                    color: primaryPurple,
                                  ),
                                  const SizedBox(width: 12),
                                  const Expanded(
                                    child: Text(
                                      'Bạn đang xem dưới chế độ Người dùng',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13.5,
                                        color: darkText,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  ElevatedButton(
                                    onPressed: _backToAdminDashboard,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: primaryPurple,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 8,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                    ),
                                    child: const Text(
                                      'Về Quản trị',
                                      style: TextStyle(
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          const Text(
                            'Chức năng chính',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: darkText,
                            ),
                          ),
                          const SizedBox(height: 16),
                          _buildMainFeaturesGrid(isWide),
                          const SizedBox(height: 26),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Môn học',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: darkText,
                                ),
                              ),
                              InkWell(
                                onTap: _openAllSubjects,
                                borderRadius: BorderRadius.circular(8),
                                child: const Padding(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 4,
                                  ),
                                  child: Text(
                                    'Xem tất cả →',
                                    style: TextStyle(
                                      color: primaryPurple,
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          _buildSubjectGrid(isWide),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildTopPurpleHeader(bool isWide) {
    final topPadding = MediaQuery.of(context).padding.top;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
        isWide ? 28 : 20,
        topPadding + 16,
        isWide ? 28 : 20,
        22,
      ),
      decoration: const BoxDecoration(
        color: primaryPurple,
        borderRadius: BorderRadius.vertical(
          bottom: Radius.circular(28),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: _openProfileScreen,
                child: _buildUserAvatar(
                  size: 50,
                  fontSize: 22,
                  hasWhiteBorder: true,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: GestureDetector(
                  onTap: _openProfileScreen,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Xin chào,',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.white70,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '$userName!',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (_isAdminUser) ...[
                _buildCircleHeaderButton(
                  icon: Icons.admin_panel_settings_rounded,
                  tooltip: 'Quay lại trang Quản trị',
                  onTap: _backToAdminDashboard,
                ),
                const SizedBox(width: 10),
              ],
              _buildCircleHeaderButton(
                icon: Icons.search_rounded,
                tooltip: 'Tìm kiếm bộ đề',
                onTap: _openAllSubjects,
              ),
              const SizedBox(width: 10),
              _buildNotificationBellButton(),
            ],
          ),

          const SizedBox(height: 22),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: _quickActions.map((item) {
              return InkWell(
                onTap: () {
                  switch (item['action']) {
                    case 'play_now':
                      _handlePlayNowRandomRoom();
                      break;
                    case 'challenge':
                      _handleRandomChallengeExam();
                      break;
                    case 'ranking':
                      _openLeaderboardScreen();
                      break;
                    case 'statistics':
                      _openStatisticsScreen();
                      break;
                  }
                },
                borderRadius: BorderRadius.circular(14),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                  child: Column(
                    children: [
                      Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.08),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Icon(
                          item['icon'] as IconData,
                          color: primaryPurple,
                          size: 26,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        item['label'] as String,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationBellButton() {
    return Tooltip(
      message: 'Thông báo',
      child: InkWell(
        onTap: _openNotificationsSheet,
        customBorder: const CircleBorder(),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
              child: Icon(
                _unreadCount > 0
                    ? Icons.notifications_active_rounded
                    : Icons.notifications_none_rounded,
                color: primaryPurple,
                size: 21,
              ),
            ),
            if (_unreadCount > 0)
              Positioned(
                right: -2,
                top: -2,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 5,
                    vertical: 1.5,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE53935),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.white, width: 1.5),
                  ),
                  child: Text(
                    _unreadCount > 9 ? '9+' : '$_unreadCount',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCircleHeaderButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Container(
          width: 38,
          height: 38,
          decoration: const BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
          ),
          child: Icon(
            icon,
            color: primaryPurple,
            size: 21,
          ),
        ),
      ),
    );
  }

  Widget _buildMainFeaturesGrid(bool isWide) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _mainFeatures.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: isWide ? 6 : 4,
        crossAxisSpacing: 12,
        mainAxisSpacing: 14,
        childAspectRatio: 0.9,
      ),
      itemBuilder: (context, index) {
        final feature = _mainFeatures[index];
        final bgColor = (feature['bgColor'] as Color?) ?? cardLavender;
        final iconColor = (feature['iconColor'] as Color?) ?? darkText;

        return InkWell(
          onTap: () {
            if (feature['action'] == 'create_quiz') {
              _openCreateQuizScreen();
            } else if (feature['action'] == 'create_room') {
              _openCreateRoomScreen();
            } else if (feature['action'] == 'room_list') {
              _openRoomListScreen();
            } else {
              _showComingSoon(feature['label'] as String);
            }
          },
          borderRadius: BorderRadius.circular(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  feature['icon'] as IconData,
                  color: iconColor,
                  size: 26,
                ),
              ),
              const SizedBox(height: 7),
              Text(
                feature['label'] as String,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: darkText,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // =========================
  // LƯỚI MÔN HỌC (API THẬT)
  // =========================

  Color _getSubjectColor(String? colorValue) {
    if (colorValue == null || colorValue.trim().isEmpty) {
      return primaryPurple;
    }
    try {
      String hex = colorValue.trim().replaceAll('#', '');
      if (hex.length == 6) {
        hex = 'FF$hex';
      }
      if (hex.length != 8) {
        return primaryPurple;
      }
      return Color(int.parse(hex, radix: 16));
    } catch (_) {
      return primaryPurple;
    }
  }

  Widget _buildSubjectIcon(SubjectModel subject, Color color) {
    final symbol = subject.bieuTuong?.trim();
    if (symbol != null && symbol.isNotEmpty) {
      if (symbol.characters.length <= 2) {
        return Text(
          symbol,
          style: const TextStyle(fontSize: 25),
          textAlign: TextAlign.center,
        );
      }
    }
    return Icon(
      Icons.menu_book_rounded,
      color: color,
      size: 27,
    );
  }

  Widget _buildSubjectGrid(bool isWide) {
    return FutureBuilder<core.List<SubjectModel>>(
      future: _subjectsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox(
            height: 120,
            child: Center(
              child: CircularProgressIndicator(color: primaryPurple),
            ),
          );
        }

        if (snapshot.hasError) {
          return Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE3E6FA)),
            ),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'Không thể tải danh sách môn học',
                    style: TextStyle(
                      fontSize: 13,
                      color: Color(0xFFE53935),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                TextButton.icon(
                  onPressed: _loadSubjects,
                  icon: const Icon(Icons.refresh, size: 16),
                  label: const Text('Thử lại'),
                ),
              ],
            ),
          );
        }

        final subjects = snapshot.data ?? [];
        if (subjects.isEmpty) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 20),
            child: Center(
              child: Text(
                'Chưa có môn học nào',
                style: TextStyle(fontSize: 13, color: Colors.grey),
              ),
            ),
          );
        }

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: subjects.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: isWide ? 6 : 4,
            crossAxisSpacing: 12,
            mainAxisSpacing: 14,
            childAspectRatio: 0.88,
          ),
          itemBuilder: (context, index) {
            final subject = subjects[index];
            final color = _getSubjectColor(subject.mauSac);

            return InkWell(
              onTap: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => SubjectDetailScreen(subjectId: subject.id),
                  ),
                );
                if (mounted) {
                  _loadSubjects();
                }
              },
              borderRadius: BorderRadius.circular(16),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 58,
                    height: 58,
                    decoration: BoxDecoration(
                      color: cardLavender,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    alignment: Alignment.center,
                    child: _buildSubjectIcon(subject, color),
                  ),
                  const SizedBox(height: 7),
                  Text(
                    subject.tenMon,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                      color: darkText,
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

  // =========================
  // 2. TRANG LỊCH SỬ
  // =========================

  Widget _buildHistoryPage() {
    return SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 84,
                height: 84,
                decoration: const BoxDecoration(
                  color: cardLavender,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.history_rounded,
                  color: primaryPurple,
                  size: 44,
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                'Lịch sử làm bài',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: darkText,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Xem lại các bài kiểm tra bạn đã hoàn thành và theo dõi điểm số.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey, height: 1.5),
              ),
              const SizedBox(height: 22),
              ElevatedButton(
                onPressed: () => _showComingSoon('Lịch sử làm bài'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryPurple,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('Xem chi tiết lịch sử'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // =========================
  // 3. TRANG BẠN BÈ
  // =========================

  Widget _buildFriendsPage() {
    return const FriendsTab();
  }

  // =========================
  // 4. TRANG CÀI ĐẶT
  // =========================

  Widget _buildSettingsPage() {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Column(
              children: [
                const SizedBox(height: 8),
                const Text(
                  'Cài đặt',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: darkText,
                  ),
                ),
                const SizedBox(height: 20),

                InkWell(
                  onTap: _openProfileScreen,
                  borderRadius: BorderRadius.circular(18),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: cardLavender,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Row(
                      children: [
                        _buildUserAvatar(
                          size: 56,
                          fontSize: 24,
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                userName,
                                style: const TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.bold,
                                  color: darkText,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                currentUser?.email ?? '',
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: Color(0xFF5D617A),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(
                          Icons.chevron_right_rounded,
                          color: primaryPurple,
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 18),

                if (_isAdminUser)
                  _buildSettingTile(
                    icon: Icons.admin_panel_settings_rounded,
                    title: 'Quay lại trang Quản trị',
                    trailingText: 'Admin',
                    onTap: _backToAdminDashboard,
                  ),

                if (!_isAdminUser)
                  _buildSettingTile(
                    icon: Icons.lock_reset_rounded,
                    title: 'Đổi mật khẩu',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const ChangePasswordScreen(),
                        ),
                      );
                    },
                  ),

                _buildSettingTile(
                  icon: Icons.contrast_rounded,
                  title: 'Giao diện',
                  trailingText: 'Sáng',
                  onTap: () => _showComingSoon('Giao diện'),
                ),
                _buildSettingTile(
                  icon: Icons.notifications_none_rounded,
                  title: 'Thông báo',
                  trailingText: _unreadCount > 0 ? '$_unreadCount mới' : null,
                  onTap: _openNotificationsSheet,
                ),
                _buildSettingTile(
                  icon: Icons.headset_mic_outlined,
                  title: 'Hỗ trợ',
                  onTap: () => _showComingSoon('Hỗ trợ'),
                ),
                _buildSettingTile(
                  icon: Icons.logout_rounded,
                  title: 'Đăng xuất',
                  isDanger: true,
                  onTap: _logout,
                ),
                _buildSettingTile(
                  icon: Icons.info_outline_rounded,
                  title: 'Phiên bản ứng dụng',
                  trailingText: 'v1.0.0',
                  onTap: () {},
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSettingTile({
    required IconData icon,
    required String title,
    String? trailingText,
    bool isDanger = false,
    required VoidCallback onTap,
  }) {
    final Color itemColor = isDanger ? const Color(0xFFE53935) : darkText;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.white,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: Color(0xFFE8EAFA)),
        ),
        child: ListTile(
          leading: Icon(
            icon,
            color: isDanger ? const Color(0xFFE53935) : primaryPurple,
          ),
          title: Text(
            title,
            style: TextStyle(
              color: itemColor,
              fontWeight: FontWeight.w600,
              fontSize: 14.5,
            ),
          ),
          trailing: trailingText != null
              ? Text(
                  trailingText,
                  style: const TextStyle(
                    color: Colors.grey,
                    fontSize: 13,
                  ),
                )
              : Icon(
                  Icons.chevron_right_rounded,
                  color: isDanger ? const Color(0xFFE53935) : Colors.grey,
                ),
          onTap: onTap,
        ),
      ),
    );
  }

  // =========================
  // THANH ĐIỀU HƯỚNG DƯỚI CÙNG
  // =========================

  Widget _buildBottomNavigation() {
    final items = [
      {'icon': Icons.home_rounded, 'label': 'Trang chủ'},
      {'icon': Icons.history_rounded, 'label': 'Lịch sử'},
      {'icon': Icons.people_outline_rounded, 'label': 'Bạn bè'},
      {'icon': Icons.settings_outlined, 'label': 'Cài đặt'},
    ];

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: const Border(
          top: BorderSide(color: Color(0xFFE8EAFA)),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 64,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: core.List.generate(items.length, (index) {
              final isSelected = _selectedIndex == index;
              final Color color = isSelected ? accentOrange : darkText;

              return Expanded(
                child: InkWell(
                  onTap: () {
                    setState(() {
                      _selectedIndex = index;
                    });
                  },
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        items[index]['icon'] as IconData,
                        color: color,
                        size: 24,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        items[index]['label'] as String,
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight:
                              isSelected ? FontWeight.bold : FontWeight.w500,
                          color: color,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}