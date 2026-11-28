import 'dart:core';
import 'dart:core' as core;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:material_ui/material_ui.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen>
    with SingleTickerProviderStateMixin {
  static const Color primaryPurple = Color(0xFF565CEB);
  static const Color cardLavender = Color(0xFFECEEFF);
  static const Color accentOrange = Color(0xFFF79E1B);
  static const Color darkText = Color(0xFF1E1E2C);
  static const Color subText = Color(0xFF5A5E77);
  static const Color backgroundColor = Color(0xFFF9FAFF);

  final SupabaseClient _supabase = Supabase.instance.client;
  late TabController _tabController;

  core.List<core.Map<String, dynamic>> _topRankUsers = [];
  core.List<core.Map<String, dynamic>> _topLevelUsers = [];
  bool _isLoading = true;
  String? _errorMessage;

  String get _currentUid => FirebaseAuth.instance.currentUser?.uid ?? '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging && mounted) {
        setState(() {});
      }
    });
    _loadLeaderboards();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadLeaderboards() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final rankRes = await _supabase
          .from('nguoi_dung')
          .select(
            'id, email, ho_ten, ten_hien_thi, anh_dai_dien_url, anh_dai_dien, '
            'cap_do, diem_kinh_nghiem, diem_rank, hang',
          )
          .eq('trang_thai', true)
          .order('diem_rank', ascending: false)
          .order('cap_do', ascending: false)
          .limit(50);

      final levelRes = await _supabase
          .from('nguoi_dung')
          .select(
            'id, email, ho_ten, ten_hien_thi, anh_dai_dien_url, anh_dai_dien, '
            'cap_do, diem_kinh_nghiem, diem_rank, hang',
          )
          .eq('trang_thai', true)
          .order('cap_do', ascending: false)
          .order('diem_kinh_nghiem', ascending: false)
          .limit(50);

      if (!mounted) return;
      setState(() {
        _topRankUsers =
            core.List<core.Map<String, dynamic>>.from(rankRes as core.List);
        _topLevelUsers =
            core.List<core.Map<String, dynamic>>.from(levelRes as core.List);
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Không thể tải bảng xếp hạng: $e';
      });
    }
  }

  String _getDisplayName(core.Map<String, dynamic> user) {
    final display = (user['ten_hien_thi'] ?? '').toString().trim();
    if (display.isNotEmpty) return display;

    final fullName = (user['ho_ten'] ?? '').toString().trim();
    if (fullName.isNotEmpty) return fullName;

    final email = (user['email'] ?? '').toString().trim();
    if (email.contains('@')) return email.split('@').first;
    return 'Người chơi';
  }

  String _getAvatarUrl(core.Map<String, dynamic> user) {
    final url1 = (user['anh_dai_dien_url'] ?? '').toString().trim();
    if (url1.isNotEmpty) return url1;
    return (user['anh_dai_dien'] ?? '').toString().trim();
  }

  Color _getRankBadgeColor(String rankName) {
    final normalized = rankName.toUpperCase();
    if (normalized.contains('THÁCH ĐẤU') || normalized.contains('CAO THỦ')) {
      return const Color(0xFFE53935);
    }
    if (normalized.contains('KIM CƯƠNG')) {
      return const Color(0xFF00ACC1);
    }
    if (normalized.contains('BẠCH KIM')) {
      return const Color(0xFF26A69A);
    }
    if (normalized.contains('VÀNG')) {
      return const Color(0xFFF9A825);
    }
    if (normalized.contains('BẠC')) {
      return const Color(0xFF78909C);
    }
    return const Color(0xFF8D6E63);
  }

  @override
  Widget build(BuildContext context) {
    final isRankTab = _tabController.index == 0;
    final activeList = isRankTab ? _topRankUsers : _topLevelUsers;
    final myIndex = activeList.indexWhere(
      (u) => u['id']?.toString() == _currentUid,
    );

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: const Text(
          'Bảng xếp hạng',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: primaryPurple,
        foregroundColor: Colors.white,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFFFFD54F),
          indicatorWeight: 3,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          labelStyle: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
          tabs: const [
            Tab(
              icon: Icon(Icons.military_tech_rounded, size: 20),
              text: 'Top Rank',
            ),
            Tab(
              icon: Icon(Icons.trending_up_rounded, size: 20),
              text: 'Top Cấp độ',
            ),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: primaryPurple),
            )
          : _errorMessage != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _errorMessage!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Color(0xFFE53935)),
                        ),
                        const SizedBox(height: 12),
                        ElevatedButton(
                          onPressed: _loadLeaderboards,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryPurple,
                            foregroundColor: Colors.white,
                          ),
                          child: const Text('Thử lại'),
                        ),
                      ],
                    ),
                  ),
                )
              : Column(
                  children: [
                    Expanded(
                      child: RefreshIndicator(
                        color: primaryPurple,
                        onRefresh: _loadLeaderboards,
                        child: activeList.isEmpty
                            ? ListView(
                                children: const [
                                  SizedBox(height: 120),
                                  Center(
                                    child: Text(
                                      'Chưa có dữ liệu xếp hạng',
                                      style: TextStyle(color: subText),
                                    ),
                                  ),
                                ],
                              )
                            : Center(
                                child: ConstrainedBox(
                                  constraints:
                                      const BoxConstraints(maxWidth: 720),
                                  child: ListView.builder(
                                    padding: const EdgeInsets.fromLTRB(
                                      16,
                                      16,
                                      16,
                                      24,
                                    ),
                                    itemCount: activeList.length,
                                    itemBuilder: (context, index) {
                                      return _buildUserRankCard(
                                        user: activeList[index],
                                        position: index + 1,
                                        isRankTab: isRankTab,
                                      );
                                    },
                                  ),
                                ),
                              ),
                      ),
                    ),
                    if (myIndex != -1)
                      _buildMyPositionBar(
                        user: activeList[myIndex],
                        position: myIndex + 1,
                        isRankTab: isRankTab,
                      ),
                  ],
                ),
    );
  }

  Widget _buildUserRankCard({
    required core.Map<String, dynamic> user,
    required int position,
    required bool isRankTab,
  }) {
    final isMe = user['id']?.toString() == _currentUid;
    final name = _getDisplayName(user);
    final avatarUrl = _getAvatarUrl(user);
    final rankTier = (user['hang'] ?? 'ĐỒNG').toString();
    final rankPoints = (user['diem_rank'] as num?)?.toInt() ?? 0;
    final level = (user['cap_do'] as num?)?.toInt() ?? 1;
    final xp = (user['diem_kinh_nghiem'] as num?)?.toInt() ?? 0;

    Color medalColor = const Color(0xFF9EA2B8);
    if (position == 1) medalColor = const Color(0xFFFFB300);
    if (position == 2) medalColor = const Color(0xFF78909C);
    if (position == 3) medalColor = const Color(0xFFCD7F32);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isMe ? cardLavender : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isMe
              ? primaryPurple.withValues(alpha: 0.45)
              : const Color(0xFFE8EAFA),
          width: isMe ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          SizedBox(
            width: 34,
            child: position <= 3
                ? Icon(
                    Icons.workspace_premium_rounded,
                    color: medalColor,
                    size: 28,
                  )
                : Text(
                    '#$position',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 13.5,
                      color: subText,
                    ),
                  ),
          ),
          const SizedBox(width: 10),
          _buildAvatar(name: name, url: avatarUrl, size: 44),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14.5,
                          color: darkText,
                        ),
                      ),
                    ),
                    if (isMe) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: primaryPurple,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          'Bạn',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10.5,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: _getRankBadgeColor(rankTier)
                            .withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        rankTier,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: _getRankBadgeColor(rankTier),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Lv.$level',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: subText,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                isRankTab ? '$rankPoints RP' : 'Cấp $level',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                  color: primaryPurple,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                isRankTab ? 'Cấp $level' : '$xp XP',
                style: const TextStyle(
                  fontSize: 11.5,
                  color: subText,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMyPositionBar({
    required core.Map<String, dynamic> user,
    required int position,
    required bool isRankTab,
  }) {
    final rankTier = (user['hang'] ?? 'ĐỒNG').toString();
    final rankPoints = (user['diem_rank'] as num?)?.toInt() ?? 0;
    final level = (user['cap_do'] as num?)?.toInt() ?? 1;

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: const Border(top: BorderSide(color: Color(0xFFE0E3F8))),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: primaryPurple,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'Hạng #$position',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 13.5,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Mức rank: $rankTier • Cấp $level',
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  color: darkText,
                  fontSize: 13.5,
                ),
              ),
            ),
            Text(
              isRankTab ? '$rankPoints RP' : 'Lv.$level',
              style: const TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 15,
                color: accentOrange,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatar({
    required String name,
    required String url,
    required double size,
  }) {
    final initial = name.isNotEmpty ? name[0].toUpperCase() : 'P';
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        color: Color(0xFFFFD54F),
        shape: BoxShape.circle,
      ),
      child: ClipOval(
        child: url.isNotEmpty
            ? Image.network(
                url,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => Center(
                  child: Text(
                    initial,
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF282B78),
                      fontSize: 18,
                    ),
                  ),
                ),
              )
            : Center(
                child: Text(
                  initial,
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF282B78),
                    fontSize: 18,
                  ),
                ),
              ),
      ),
    );
  }
}