import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/theme.dart';

typedef SystemLogItem = Map<String, String>;

class AdminOverviewScreen extends StatefulWidget {
  final ValueChanged<int>? onSwitchTab;

  const AdminOverviewScreen({
    super.key,
    this.onSwitchTab,
  });

  @override
  State<AdminOverviewScreen> createState() => _AdminOverviewScreenState();
}

class _AdminOverviewScreenState extends State<AdminOverviewScreen> {
  final _supabase = Supabase.instance.client;

  static const Color _brandBlue = Color(0xFF3B5BFD);
  static const Color _brandPurple = Color(0xFF7C3AED);
  static const Color _brandAmber = Color(0xFFF59E0B);
  static const Color _brandEmerald = Color(0xFF10B981);

  bool _isLoading = true;
  bool _hasLoadedOnce = false;
  int _totalUsers = 0;
  int _dailyAttempts = 0;
  int _totalQuizzes = 0;
  int _liveRooms = 0;
  List<SystemLogItem> _logs = [];

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    if (mounted) {
      setState(() => _isLoading = true);
    }

    int usersCount = 0;
    int todayAttemptsCount = 0;
    int quizzesCount = 0;
    int liveRoomsCount = 0;
    final List<SystemLogItem> fetchedLogs = [];

    // 1. Tổng User (bảng nguoi_dung)
    try {
      final dynamic userRows =
          await _supabase.from('nguoi_dung').select('id');
      if (userRows is Iterable) {
        usersCount = userRows.length;
      }
    } catch (e) {
      debugPrint('Lỗi đếm nguoi_dung: $e');
    }

    // 2. Số bộ đề (bảng de_thi)
    try {
      final dynamic quizRows = await _supabase
          .from('de_thi')
          .select('id, tieu_de, created_at')
          .order('created_at', ascending: false);

      if (quizRows is Iterable) {
        int addedQuizLogs = 0;
        for (final item in quizRows) {
          if (item is Map) {
            quizzesCount++;
            if (addedQuizLogs < 3) {
              final title = (item['tieu_de'] ?? 'Bộ đề mới').toString();
              fetchedLogs.add({
                'time': _formatShortTime(item['created_at']),
                'message': 'Bộ đề "$title" đã được tạo trên hệ thống.',
                'type': 'quiz',
              });
              addedQuizLogs++;
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Lỗi đếm de_thi: $e');
    }

    // 3. Lượt thi trong ngày & Log làm bài (bảng lich_su_thi)
    try {
      final now = DateTime.now();
      final startOfDay = DateTime(now.year, now.month, now.day).toUtc();

      final dynamic historyRows = await _supabase
          .from('lich_su_thi')
          .select('id, user_id, ten_de_thi, diem_so, created_at')
          .order('created_at', ascending: false)
          .limit(20);

      if (historyRows is Iterable) {
        for (final row in historyRows) {
          if (row is Map) {
            final createdAt =
                DateTime.tryParse((row['created_at'] ?? '').toString());
            if (createdAt != null && !createdAt.isBefore(startOfDay)) {
              todayAttemptsCount++;
            }

            if (fetchedLogs.length < 15) {
              final examName =
                  (row['ten_de_thi'] ?? 'Bộ đề trắc nghiệm').toString();
              final score = (row['diem_so'] ?? 0).toString();
              fetchedLogs.add({
                'time': _formatShortTime(row['created_at']),
                'message':
                    'Người chơi hoàn thành "$examName" đạt $score điểm.',
                'type': 'attempt',
              });
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Lỗi đọc lich_su_thi: $e');
    }

    // 4. Phòng thi đang LIVE (bảng phong_thi)
    try {
      final dynamic roomRows = await _supabase.from('phong_thi').select('*');
      if (roomRows is Iterable) {
        for (final row in roomRows) {
          if (row is Map) {
            final status = (row['trang_thai'] ?? row['status'] ?? '')
                .toString()
                .toLowerCase();
            final bool isActive =
                row['dang_hoat_dong'] == true || row['is_active'] == true;
            if (isActive ||
                status == 'live' ||
                status == 'dang_thi' ||
                status == 'waiting' ||
                status == 'open') {
              liveRoomsCount++;
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Lỗi đọc phong_thi: $e');
    }

    if (!mounted) return;
    setState(() {
      _totalUsers = usersCount;
      _dailyAttempts = todayAttemptsCount;
      _totalQuizzes = quizzesCount;
      _liveRooms = liveRoomsCount;
      _logs = fetchedLogs;
      _isLoading = false;
      _hasLoadedOnce = true;
    });
  }

  String _formatShortTime(dynamic rawDate) {
    if (rawDate == null) return 'Mới cập nhật';
    final dt = DateTime.tryParse(rawDate.toString())?.toLocal();
    if (dt == null) return 'Mới cập nhật';
    final hh = dt.hour.toString().padLeft(2, '0');
    final mm = dt.minute.toString().padLeft(2, '0');
    final dd = dt.day.toString().padLeft(2, '0');
    final mo = dt.month.toString().padLeft(2, '0');
    return '$dd/$mo • $hh:$mm';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5FB),
      body: !_hasLoadedOnce && _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.base),
            )
          : RefreshIndicator(
              color: AppColors.base,
              onRefresh: _loadDashboardData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // 1. HEADER GRADIENT XANH - TÍM
                    _buildHeader(context),

                    // 2. NỘI DUNG CHÍNH (ĐẨY LÊN CHỒNG NHẸ HEADER)
                    Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 680),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                          child: Transform.translate(
                            offset: const Offset(0, -28),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                // Lưới 4 thẻ chỉ số (2x2)
                                Row(
                                  children: [
                                    Expanded(
                                      child: _buildStatCard(
                                        title: 'Tổng User',
                                        subtitle: 'Tài khoản hệ thống',
                                        value: '$_totalUsers',
                                        icon: Icons.people_alt_rounded,
                                        accentColor: const Color(0xFF3B82F6),
                                        onTap: () =>
                                            widget.onSwitchTab?.call(3),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: _buildStatCard(
                                        title: 'Lượt thi ngày',
                                        subtitle: 'Tính trong hôm nay',
                                        value: '$_dailyAttempts',
                                        icon: Icons.bolt_rounded,
                                        accentColor: _brandAmber,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    Expanded(
                                      child: _buildStatCard(
                                        title: 'Số bộ đề',
                                        subtitle: 'Kho học liệu sẵn sàng',
                                        value: '$_totalQuizzes',
                                        icon: Icons.library_books_rounded,
                                        accentColor: _brandPurple,
                                        onTap: () =>
                                            widget.onSwitchTab?.call(1),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: _buildStatCard(
                                        title: 'Phòng thi',
                                        subtitle: _liveRooms > 0
                                            ? 'Đang diễn ra'
                                            : 'Chưa có phòng mở',
                                        value: '$_liveRooms',
                                        icon: Icons.sensors_rounded,
                                        accentColor: _brandEmerald,
                                        isLive: _liveRooms > 0,
                                        onTap: () =>
                                            widget.onSwitchTab?.call(2),
                                      ),
                                    ),
                                  ],
                                ),

                                const SizedBox(height: 18),

                                // Thanh Thao tác nhanh
                                _buildQuickActions(),

                                const SizedBox(height: 22),

                                // Nhật ký hoạt động (Log)
                                _buildLogSection(),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;

    return Container(
      padding: EdgeInsets.fromLTRB(20, topPadding + 16, 20, 48),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            _brandBlue,
            AppColors.base,
            _brandPurple,
          ],
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
                top: -28,
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
                      if (Navigator.canPop(context))
                        Padding(
                          padding: const EdgeInsets.only(right: 10, top: 2),
                          child: Material(
                            color: Colors.white.withValues(alpha: 0.16),
                            borderRadius: BorderRadius.circular(14),
                            child: InkWell(
                              onTap: () => Navigator.pop(context),
                              borderRadius: BorderRadius.circular(14),
                              child: const SizedBox(
                                width: 42,
                                height: 42,
                                child: Icon(
                                  Icons.arrow_back_rounded,
                                  color: Colors.white,
                                  size: 20,
                                ),
                              ),
                            ),
                          ),
                        ),
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
                                    Icons.verified_user_rounded,
                                    size: 13,
                                    color: Color(0xFFFDE047),
                                  ),
                                  SizedBox(width: 5),
                                  Text(
                                    'QUẢN TRỊ VIÊN',
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
                              'Tổng quan hệ thống',
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
                          onTap: _isLoading ? null : _loadDashboardData,
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
                            child: _isLoading
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
                  const SizedBox(height: 10),
                  Text(
                    'Theo dõi nhanh người dùng, kho bộ đề và hoạt động mới nhất',
                    style: AppTextStyles.text.copyWith(
                      fontSize: 13,
                      color: Colors.white.withValues(alpha: 0.86),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuickActions() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 10),
            child: Text(
              'Thao tác nhanh',
              style: AppTextStyles.question.copyWith(
                fontSize: 13.5,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF334155),
              ),
            ),
          ),
          Row(
            children: [
              Expanded(
                child: _buildQuickActionButton(
                  icon: Icons.menu_book_rounded,
                  label: 'Học liệu',
                  color: _brandPurple,
                  onTap: () => widget.onSwitchTab?.call(1),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildQuickActionButton(
                  icon: Icons.sensors_rounded,
                  label: 'Phòng thi',
                  color: _brandEmerald,
                  onTap: () => widget.onSwitchTab?.call(2),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildQuickActionButton(
                  icon: Icons.manage_accounts_rounded,
                  label: 'Tài khoản',
                  color: const Color(0xFF3B82F6),
                  onTap: () => widget.onSwitchTab?.call(3),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: color.withValues(alpha: 0.09),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 17, color: color),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.text.copyWith(
                    fontSize: 12.8,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLogSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Container(
              width: 4,
              height: 18,
              decoration: BoxDecoration(
                color: AppColors.base,
                borderRadius: BorderRadius.circular(99),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'Hoạt động gần đây',
              style: AppTextStyles.question.copyWith(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: AppColors.text,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 2.5),
              decoration: BoxDecoration(
                color: AppColors.base.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(99),
              ),
              child: Text(
                '${_logs.length}',
                style: AppTextStyles.text.copyWith(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: AppColors.base,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Divider(
                color: Colors.grey.shade300,
                thickness: 1,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0F172A).withValues(alpha: 0.04),
                blurRadius: 18,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: _logs.isEmpty
              ? Padding(
                  padding:
                      const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.history_toggle_off_rounded,
                        size: 40,
                        color: Colors.grey.shade300,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Chưa có hoạt động hệ thống nào được ghi nhận.',
                        textAlign: TextAlign.center,
                        style: AppTextStyles.text.copyWith(
                          color: Colors.grey.shade500,
                          fontSize: 13.5,
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  itemCount: _logs.length,
                  separatorBuilder: (context, index) => const Divider(
                    height: 1,
                    indent: 64,
                    endIndent: 16,
                    color: Color(0xFFF1F5F9),
                  ),
                  itemBuilder: (context, index) {
                    final log = _logs[index];
                    final isAttempt = log['type'] == 'attempt';
                    final itemColor =
                        isAttempt ? _brandEmerald : _brandPurple;

                    return Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: itemColor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              isAttempt
                                  ? Icons.check_circle_rounded
                                  : Icons.post_add_rounded,
                              size: 19,
                              color: itemColor,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  log['message'] ?? '',
                                  style: AppTextStyles.text.copyWith(
                                    fontSize: 13.5,
                                    color: AppColors.text,
                                    fontWeight: FontWeight.w600,
                                    height: 1.38,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Icon(
                                      Icons.access_time_rounded,
                                      size: 12.5,
                                      color: Colors.grey.shade400,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      log['time'] ?? 'Mới cập nhật',
                                      style: AppTextStyles.text.copyWith(
                                        fontSize: 11.8,
                                        color: Colors.grey.shade500,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required String title,
    required String subtitle,
    required String value,
    required IconData icon,
    required Color accentColor,
    bool isLive = false,
    VoidCallback? onTap,
  }) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Container(
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: isLive
                  ? accentColor.withValues(alpha: 0.45)
                  : accentColor.withValues(alpha: 0.2),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: accentColor.withValues(alpha: 0.08),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // Icon chìm trang trí ở góc phải dưới
              Positioned(
                right: -6,
                bottom: -6,
                child: Icon(
                  icon,
                  size: 58,
                  color: accentColor.withValues(alpha: 0.08),
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: accentColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(icon, color: accentColor, size: 20),
                      ),
                      if (isLive)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: _brandEmerald.withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 6,
                                height: 6,
                                decoration: const BoxDecoration(
                                  color: _brandEmerald,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'LIVE',
                                style: AppTextStyles.text.copyWith(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  color: const Color(0xFF047857),
                                ),
                              ),
                            ],
                          ),
                        )
                      else if (onTap != null)
                        Icon(
                          Icons.arrow_outward_rounded,
                          size: 16,
                          color: Colors.grey.shade400,
                        ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Text(
                    value,
                    style: AppTextStyles.question.copyWith(
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                      color: AppColors.text,
                      height: 1.1,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    title,
                    style: AppTextStyles.text.copyWith(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF334155),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.text.copyWith(
                      fontSize: 11.5,
                      color: Colors.grey.shade500,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}