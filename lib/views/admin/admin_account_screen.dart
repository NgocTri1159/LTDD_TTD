import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../controllers/admin_account_controller.dart';
import '../../core/theme.dart';
import '../../models/account_model.dart';
import '../auth/login_screen.dart';
import 'admin_account_detail_screen.dart';

class AdminAccountScreen extends StatefulWidget {
  const AdminAccountScreen({super.key});

  @override
  State<AdminAccountScreen> createState() => _AdminAccountScreenState();
}

class _AdminAccountScreenState extends State<AdminAccountScreen> {
  final _searchController = TextEditingController();

  static const Color _brandBlue = Color(0xFF3B5BFD);
  static const Color _brandPurple = Color(0xFF7C3AED);
  static const Color _brandEmerald = Color(0xFF10B981);
  static const Color _brandAmber = Color(0xFFF59E0B);

  List<AccountModel> _accounts = [];
  bool _loading = true;
  bool _hasLoadedOnce = false;
  String _searchQuery = '';
  String _roleFilter = 'Tất cả';

  static const List<String> _roles = ['Tất cả', 'User', 'Admin'];

  static const List<Color> _avatarPalette = [
    Color(0xFF3B82F6),
    Color(0xFF10B981),
    Color(0xFFF59E0B),
    Color(0xFF8B5CF6),
    Color(0xFFEC4899),
    Color(0xFF06B6D4),
  ];

  @override
  void initState() {
    super.initState();
    _loadAccounts();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadAccounts() async {
    if (mounted) setState(() => _loading = true);
    try {
      final list = await AdminAccountController.instance.fetchAccounts();
      if (!mounted) return;
      setState(() {
        _accounts = list;
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
          content: Text('Lỗi tải tài khoản: $e'),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  int _countByRole(String role) {
    if (role == 'Tất cả') return _accounts.length;
    return _accounts
        .where((a) => a.role.trim().toLowerCase() == role.toLowerCase())
        .length;
  }

  List<AccountModel> get _filteredAccounts {
    return _accounts.where((acc) {
      final matchRole = _roleFilter == 'Tất cả' ||
          acc.role.trim().toLowerCase() == _roleFilter.toLowerCase();
      final q = _searchQuery.trim().toLowerCase();
      final matchQuery = q.isEmpty ||
          acc.fullName.toLowerCase().contains(q) ||
          acc.rank.toLowerCase().contains(q) ||
          acc.role.toLowerCase().contains(q);
      return matchRole && matchQuery;
    }).toList();
  }

  bool get _hasActiveFilter =>
      _searchQuery.trim().isNotEmpty || _roleFilter != 'Tất cả';

  void _resetFilters() {
    setState(() {
      _searchQuery = '';
      _searchController.clear();
      _roleFilter = 'Tất cả';
    });
  }

  String _formatDate(DateTime? dt) {
    if (dt == null) return 'Chưa rõ';
    final d = dt.toLocal();
    final day = d.day.toString().padLeft(2, '0');
    final month = d.month.toString().padLeft(2, '0');
    return '$day/$month/${d.year}';
  }

  Color _colorForName(String name) {
    return _avatarPalette[name.hashCode.abs() % _avatarPalette.length];
  }

  Future<void> _openDetail([AccountModel? account]) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AdminAccountDetailScreen(account: account),
      ),
    );
    _loadAccounts();
  }

  Future<void> _confirmSignOut() async {
    final confirmed = await showDialog<bool>(
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
                Icons.logout_rounded,
                color: Color(0xFFEF4444),
                size: 20,
              ),
            ),
            const SizedBox(width: 10),
            const Text(
              'Đăng xuất',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
            ),
          ],
        ),
        content: Text(
          'Bạn có chắc muốn đăng xuất khỏi tài khoản quản trị hiện tại không?',
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
              'Đăng xuất',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await Supabase.instance.client.auth.signOut();
      } catch (_) {}
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = _filteredAccounts;

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5FB),
      body: !_hasLoadedOnce && _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.base),
            )
          : RefreshIndicator(
              color: AppColors.base,
              onRefresh: _loadAccounts,
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  // 1. HEADER GRADIENT + THỐNG KÊ MINI + THANH TÌM KIẾM
                  SliverToBoxAdapter(
                    child: _buildHeaderAndSearch(context),
                  ),

                  // 2. BỘ LỌC VAI TRÒ & TIÊU ĐỀ DANH SÁCH
                  SliverToBoxAdapter(
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 680),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // 3 tab lọc vai trò (Tất cả / User / Admin)
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 4, 16, 14),
                              child: Row(
                                children: [
                                  _buildRoleTab(
                                    role: 'Tất cả',
                                    label: 'Tất cả',
                                    color: AppColors.base,
                                  ),
                                  const SizedBox(width: 8),
                                  _buildRoleTab(
                                    role: 'User',
                                    label: 'Người chơi',
                                    color: const Color(0xFF0284C7),
                                  ),
                                  const SizedBox(width: 8),
                                  _buildRoleTab(
                                    role: 'Admin',
                                    label: 'Admin',
                                    color: _brandAmber,
                                  ),
                                ],
                              ),
                            ),

                            // Tiêu đề danh sách + số lượng kết quả
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 2, 16, 10),
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
                                    'Danh sách tài khoản',
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
                                      '${items.length}',
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

                  // 3. DANH SÁCH TÀI KHOẢN HOẶC EMPTY STATE
                  if (items.isEmpty)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 680),
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
                            child: _buildEmptyState(),
                          ),
                        ),
                      ),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                      sliver: SliverList.separated(
                        itemCount: items.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (_, index) {
                          return Center(
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 648),
                              child: _buildAccountCard(items[index]),
                            ),
                          );
                        },
                      ),
                    ),
                ],
              ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openDetail(),
        backgroundColor: AppColors.base,
        foregroundColor: Colors.white,
        elevation: 3,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        icon: const Icon(Icons.person_add_alt_1_rounded, size: 21),
        label: const Text(
          'Thêm tài khoản',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
        ),
      ),
    );
  }

  Widget _buildHeaderAndSearch(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;
    final adminCount = _countByRole('Admin');
    final userCount = _countByRole('User');

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
                                        Icons.admin_panel_settings_rounded,
                                        size: 13,
                                        color: Color(0xFFFDE68A),
                                      ),
                                      SizedBox(width: 5),
                                      Text(
                                        'PHÂN QUYỀN & THÀNH VIÊN',
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
                                  'Quản lí tài khoản',
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
                          const SizedBox(width: 8),

                          // Nút làm mới danh sách
                          _buildHeaderIconButton(
                            tooltip: 'Làm mới',
                            onTap: _loading ? null : _loadAccounts,
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
                                    size: 20,
                                  ),
                          ),
                          const SizedBox(width: 8),

                          // Nút Đăng xuất nhanh
                          _buildHeaderIconButton(
                            tooltip: 'Đăng xuất',
                            onTap: _confirmSignOut,
                            backgroundColor:
                                const Color(0xFFEF4444).withValues(alpha: 0.28),
                            borderColor:
                                const Color(0xFFFCA5A5).withValues(alpha: 0.45),
                            child: const Icon(
                              Icons.logout_rounded,
                              color: Colors.white,
                              size: 19,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // 3 ô tóm tắt mini trong Header
                      Row(
                        children: [
                          Expanded(
                            child: _buildHeaderStat(
                              icon: Icons.groups_rounded,
                              label: 'Tổng số',
                              value: '${_accounts.length}',
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _buildHeaderStat(
                              icon: Icons.sports_esports_rounded,
                              label: 'Người chơi',
                              value: '$userCount',
                              highlightColor: const Color(0xFF7DD3FC),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _buildHeaderStat(
                              icon: Icons.shield_rounded,
                              label: 'Quản trị',
                              value: '$adminCount',
                              highlightColor: const Color(0xFFFDE68A),
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
                    onChanged: (v) => setState(() => _searchQuery = v),
                    decoration: InputDecoration(
                      hintText: 'Tìm theo tên, cấp bậc hoặc vai trò...',
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

  Widget _buildHeaderIconButton({
    required String tooltip,
    required VoidCallback? onTap,
    required Widget child,
    Color? backgroundColor,
    Color? borderColor,
  }) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: backgroundColor ?? Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            width: 42,
            height: 42,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: borderColor ?? Colors.white.withValues(alpha: 0.28),
              ),
            ),
            child: child,
          ),
        ),
      ),
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

  Widget _buildRoleTab({
    required String role,
    required String label,
    required Color color,
  }) {
    final isSelected = _roleFilter == role;
    final count = _countByRole(role);

    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _roleFilter = role),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 8),
          alignment: Alignment.center,
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
          child: Text(
            '$label ($count)',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.text.copyWith(
              fontSize: 12.2,
              fontWeight: FontWeight.w700,
              color: isSelected ? Colors.white : const Color(0xFF334155),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAccountCard(AccountModel acc) {
    final isAdmin = acc.role.trim().toLowerCase() == 'admin';
    final accent = isAdmin ? _brandAmber : _colorForName(acc.fullName);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isAdmin
              ? _brandAmber.withValues(alpha: 0.42)
              : const Color(0xFFE2E8F0),
          width: isAdmin ? 1.3 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: 0.07),
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
            onTap: () => _openDetail(acc),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Thanh nhấn màu bên trái
                  Container(
                    width: 5,
                    color: isAdmin ? _brandAmber : accent,
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        children: [
                          // Avatar có viền nhấn + huy hiệu Admin nếu có
                          Stack(
                            clipBehavior: Clip.none,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(2.5),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: accent.withValues(alpha: 0.45),
                                    width: 1.5,
                                  ),
                                ),
                                child: CircleAvatar(
                                  radius: 26,
                                  backgroundColor:
                                      accent.withValues(alpha: 0.14),
                                  backgroundImage: acc.avatarUrl.isNotEmpty
                                      ? NetworkImage(acc.avatarUrl)
                                      : null,
                                  child: acc.avatarUrl.isEmpty
                                      ? Text(
                                          acc.fullName.isNotEmpty
                                              ? acc.fullName[0].toUpperCase()
                                              : 'P',
                                          style: TextStyle(
                                            fontSize: 19,
                                            fontWeight: FontWeight.w800,
                                            color: accent,
                                          ),
                                        )
                                      : null,
                                ),
                              ),
                              if (isAdmin)
                                Positioned(
                                  right: -2,
                                  bottom: -2,
                                  child: Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: BoxDecoration(
                                      color: _brandAmber,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: Colors.white,
                                        width: 1.8,
                                      ),
                                    ),
                                    child: const Icon(
                                      Icons.shield_rounded,
                                      size: 11,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(width: 13),

                          // Thông tin chi tiết tài khoản
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Flexible(
                                      child: Text(
                                        acc.fullName,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: AppTextStyles.question.copyWith(
                                          fontSize: 15.5,
                                          fontWeight: FontWeight.w800,
                                          color: AppColors.text,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 3,
                                      ),
                                      decoration: BoxDecoration(
                                        color: isAdmin
                                            ? const Color(0xFFFEF3C7)
                                            : const Color(0xFFE0F2FE),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            isAdmin
                                                ? Icons.verified_user_rounded
                                                : Icons.person_rounded,
                                            size: 11,
                                            color: isAdmin
                                                ? const Color(0xFFB45309)
                                                : const Color(0xFF0369A1),
                                          ),
                                          const SizedBox(width: 3),
                                          Text(
                                            isAdmin ? 'Admin' : 'User',
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w800,
                                              color: isAdmin
                                                  ? const Color(0xFFB45309)
                                                  : const Color(0xFF0369A1),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),

                                // Cấp độ & Hạng dạng pill tag
                                Wrap(
                                  spacing: 6,
                                  runSpacing: 4,
                                  children: [
                                    _buildMiniTag(
                                      icon: Icons.bolt_rounded,
                                      label: 'Lv.${acc.level}',
                                      color: _brandPurple,
                                    ),
                                    _buildMiniTag(
                                      icon: Icons.emoji_events_rounded,
                                      label: acc.rank,
                                      color: _brandEmerald,
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),

                                // Ngày tham gia
                                Row(
                                  children: [
                                    Icon(
                                      Icons.calendar_today_rounded,
                                      size: 12,
                                      color: Colors.grey.shade400,
                                    ),
                                    const SizedBox(width: 5),
                                    Text(
                                      'Ngày tạo: ${_formatDate(acc.createdAt)}',
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

                          const SizedBox(width: 8),

                          // Nút chỉnh sửa nhanh
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: AppColors.base.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.edit_outlined,
                              size: 18,
                              color: AppColors.base,
                            ),
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
    );
  }

  Widget _buildMiniTag({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 3),
          Text(
            label,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: color,
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
              Icons.manage_accounts_outlined,
              size: 34,
              color: AppColors.base,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            _hasActiveFilter
                ? 'Không tìm thấy tài khoản phù hợp'
                : 'Chưa có tài khoản nào',
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
                ? 'Thử đổi từ khóa tìm kiếm hoặc chọn lại nhóm vai trò khác.'
                : 'Nhấn nút "Thêm tài khoản" bên dưới để tạo thành viên đầu tiên.',
            textAlign: TextAlign.center,
            style: AppTextStyles.text.copyWith(
              fontSize: 13.2,
              color: Colors.grey.shade500,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 18),
          ElevatedButton.icon(
            onPressed: _hasActiveFilter ? _resetFilters : _loadAccounts,
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