import 'dart:core';
import 'dart:core' as core;
import 'package:material_ui/material_ui.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide User;
import '../../services/notification_service.dart';
import '../../services/rank_service.dart';

class FriendsTab extends StatefulWidget {
  const FriendsTab({super.key});

  @override
  State<FriendsTab> createState() => _FriendsTabState();
}

class _FriendsTabState extends State<FriendsTab>
    with SingleTickerProviderStateMixin {
  static const Color primaryPurple = Color(0xFF565CEB);
  static const Color cardLavender = Color(0xFFECEEFF);
  static const Color darkText = Color(0xFF1E1E2C);

  final SupabaseClient _supabase = Supabase.instance.client;
  final TextEditingController _searchController = TextEditingController();
  late TabController _tabController;
  RealtimeChannel? _friendChannel;

  bool _isLoading = true;
  bool _isSearching = false;

  // Dữ liệu quan hệ bạn bè & thông tin user tương ứng
  core.List<core.Map<String, dynamic>> _relations = [];
  core.Map<String, core.Map<String, dynamic>> _userProfiles = {};
  core.List<core.Map<String, dynamic>> _searchResults = [];

  User? get _currentUser => FirebaseAuth.instance.currentUser;
  String get _myEmail => (_currentUser?.email ?? '').trim().toLowerCase();

  String get _myName {
    final name = _currentUser?.displayName;
    if (name != null && name.trim().isNotEmpty) return name.trim();
    final dbName = (_userProfiles[_myEmail]?['ten_hien_thi'] ?? '').toString();
    if (dbName.trim().isNotEmpty) return dbName.trim();
    return _myEmail.split('@').first;
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadFriendData();
    _subscribeRealtimeFriends();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _tabController.dispose();
    if (_friendChannel != null) {
      _supabase.removeChannel(_friendChannel!);
    }
    super.dispose();
  }

  void _showSnack(String msg, {bool isError = false}) {
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor:
            isError ? const Color(0xFFD32F2F) : const Color(0xFF2E7D32),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _subscribeRealtimeFriends() {
    if (_myEmail.isEmpty) return;

    _friendChannel = _supabase
        .channel('public:ket_ban:$_myEmail')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'ket_ban',
          callback: (_) {
            if (mounted) _loadFriendData(silent: true);
          },
        )
        .subscribe();
  }

  Future<void> _loadFriendData({bool silent = false}) async {
    if (_myEmail.isEmpty) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    if (!silent && mounted) setState(() => _isLoading = true);

    try {
      // Lấy tất cả quan hệ có liên quan đến email hiện tại
      final rows = await _supabase
          .from('ket_ban')
          .select()
          .or('nguoi_gui_email.ilike.$_myEmail,nguoi_nhan_email.ilike.$_myEmail')
          .order('ngay_tao', ascending: false);

      final relList = core.List<core.Map<String, dynamic>>.from(rows);

      // Gom tất cả email liên quan để tải hồ sơ (tên, avatar, hạng)
      final emails = <String>{_myEmail};
      for (final r in relList) {
        emails.add((r['nguoi_gui_email'] ?? '').toString().trim().toLowerCase());
        emails.add((r['nguoi_nhan_email'] ?? '').toString().trim().toLowerCase());
      }
      emails.removeWhere((e) => e.isEmpty);

      final profileMap = <String, core.Map<String, dynamic>>{};
      if (emails.isNotEmpty) {
        final usersData = await _supabase
            .from('nguoi_dung')
            .select('id, email, ten_hien_thi, anh_dai_dien, hang, diem_rank');

        for (final u in usersData) {
          final e = (u['email'] ?? '').toString().trim().toLowerCase();
          if (emails.contains(e)) {
            profileMap[e] = core.Map<String, dynamic>.from(u);
          }
        }
      }

      if (!mounted) return;
      setState(() {
        _relations = relList;
        _userProfiles = profileMap;
      });
    } catch (e) {
      debugPrint('LOAD FRIENDS ERROR: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // Danh sách bạn bè đã chấp nhận
  core.List<core.Map<String, dynamic>> get _acceptedFriends =>
      _relations.where((r) => r['trang_thai'] == 'accepted').toList();

  // Danh sách lời mời gửi đến mình đang chờ duyệt
  core.List<core.Map<String, dynamic>> get _incomingRequests =>
      _relations.where((r) {
        final receiver =
            (r['nguoi_nhan_email'] ?? '').toString().trim().toLowerCase();
        return r['trang_thai'] == 'pending' && receiver == _myEmail;
      }).toList();

  // Kiểm tra trạng thái quan hệ với 1 email bất kỳ
  core.Map<String, dynamic>? _getRelationWith(String targetEmail) {
    final target = targetEmail.trim().toLowerCase();
    for (final r in _relations) {
      final s = (r['nguoi_gui_email'] ?? '').toString().trim().toLowerCase();
      final rec = (r['nguoi_nhan_email'] ?? '').toString().trim().toLowerCase();
      if ((s == _myEmail && rec == target) ||
          (s == target && rec == _myEmail)) {
        return r;
      }
    }
    return null;
  }

  Future<void> _searchUsers(String query) async {
    final keyword = query.trim();
    if (keyword.isEmpty) {
      setState(() => _searchResults = []);
      return;
    }

    setState(() => _isSearching = true);
    try {
      final data = await _supabase
          .from('nguoi_dung')
          .select('id, email, ten_hien_thi, anh_dai_dien, hang, diem_rank')
          .or('ten_hien_thi.ilike.%$keyword%,email.ilike.%$keyword%')
          .limit(20);

      final filtered = core.List<core.Map<String, dynamic>>.from(data)
          .where((u) =>
              (u['email'] ?? '').toString().trim().toLowerCase() != _myEmail)
          .toList();

      if (!mounted) return;
      setState(() => _searchResults = filtered);
    } catch (e) {
      debugPrint('SEARCH USERS ERROR: $e');
      _showSnack('Lỗi tìm kiếm người chơi.', isError: true);
    } finally {
      if (mounted) setState(() => _isSearching = false);
    }
  }

  Future<void> _sendFriendRequest(String targetEmail, String targetName) async {
    if (_myEmail.isEmpty) return;

    try {
      await _supabase.from('ket_ban').insert({
        'nguoi_gui_email': _myEmail,
        'nguoi_nhan_email': targetEmail.trim().toLowerCase(),
        'trang_thai': 'pending',
      });

      // Gửi thông báo Realtime cho đối phương
      await NotificationService.sendFriendRequest(
        receiverEmail: targetEmail,
        senderName: _myName,
      );

      await _loadFriendData(silent: true);
      _showSnack('Đã gửi lời mời kết bạn tới $targetName!');
    } catch (e) {
      debugPrint('SEND FRIEND REQUEST ERROR: $e');
      _showSnack('Không thể gửi lời mời kết bạn.', isError: true);
    }
  }

  Future<void> _acceptFriendRequest(core.Map<String, dynamic> relation) async {
    final senderEmail =
        (relation['nguoi_gui_email'] ?? '').toString().trim().toLowerCase();

    try {
      await _supabase
          .from('ket_ban')
          .update({'trang_thai': 'accepted'}).eq('id', relation['id']);

      // Báo lại cho người gửi biết lời mời đã được chấp nhận
      await NotificationService.sendFriendAccepted(
        receiverEmail: senderEmail,
        accepterName: _myName,
      );

      await _loadFriendData(silent: true);
      _showSnack('Đã chấp nhận lời mời kết bạn!');
    } catch (e) {
      debugPrint('ACCEPT FRIEND ERROR: $e');
      _showSnack('Lỗi khi chấp nhận lời mời.', isError: true);
    }
  }

  Future<void> _removeRelation(dynamic relationId, String message) async {
    try {
      await _supabase.from('ket_ban').delete().eq('id', relationId);
      await _loadFriendData(silent: true);
      _showSnack(message);
    } catch (e) {
      debugPrint('REMOVE RELATION ERROR: $e');
      _showSnack('Thao tác thất bại.', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final incomingCount = _incomingRequests.length;

    return SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: Column(
            children: [
              const SizedBox(height: 14),
              const Text(
                'Bạn bè',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: darkText,
                ),
              ),
              const SizedBox(height: 14),
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 20),
                decoration: BoxDecoration(
                  color: cardLavender,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: TabBar(
                  controller: _tabController,
                  indicatorSize: TabBarIndicatorSize.tab,
                  dividerColor: Colors.transparent,
                  indicator: BoxDecoration(
                    color: primaryPurple,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  labelColor: Colors.white,
                  unselectedLabelColor: darkText,
                  labelStyle: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                  tabs: [
                    Tab(text: 'Bạn bè (${_acceptedFriends.length})'),
                    Tab(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text('Lời mời'),
                          if (incomingCount > 0) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 1.5,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFE53935),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                '$incomingCount',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const Tab(text: 'Tìm bạn'),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: _isLoading
                    ? const Center(
                        child: CircularProgressIndicator(color: primaryPurple),
                      )
                    : TabBarView(
                        controller: _tabController,
                        children: [
                          _buildFriendsListTab(),
                          _buildRequestsTab(),
                          _buildSearchTab(),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // TAB 1: DANH SÁCH BẠN BÈ
  Widget _buildFriendsListTab() {
    final friends = _acceptedFriends;

    if (friends.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.people_outline_rounded,
                size: 54,
                color: Colors.grey,
              ),
              const SizedBox(height: 12),
              const Text(
                'Bạn chưa có người bạn nào',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: darkText,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Chuyển sang mục "Tìm bạn" để kết nối với người chơi khác.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey, fontSize: 13.5),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => _tabController.animateTo(2),
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryPurple,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('Tìm bạn ngay'),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      color: primaryPurple,
      onRefresh: () => _loadFriendData(),
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        itemCount: friends.length,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          final rel = friends[index];
          final sender =
              (rel['nguoi_gui_email'] ?? '').toString().trim().toLowerCase();
          final receiver =
              (rel['nguoi_nhan_email'] ?? '').toString().trim().toLowerCase();
          final friendEmail = sender == _myEmail ? receiver : sender;
          final profile = _userProfiles[friendEmail];

          return _buildUserCard(
            email: friendEmail,
            profile: profile,
            trailing: IconButton(
              tooltip: 'Hủy kết bạn',
              icon: const Icon(
                Icons.person_remove_outlined,
                color: Color(0xFFE53935),
                size: 21,
              ),
              onPressed: () =>
                  _removeRelation(rel['id'], 'Đã hủy kết bạn.'),
            ),
          );
        },
      ),
    );
  }

  // TAB 2: LỜI MỜI KẾT BẠN
  Widget _buildRequestsTab() {
    final requests = _incomingRequests;

    if (requests.isEmpty) {
      return const Center(
        child: Text(
          'Không có lời mời kết bạn nào đang chờ.',
          style: TextStyle(color: Colors.grey, fontSize: 14),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      itemCount: requests.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final rel = requests[index];
        final senderEmail =
            (rel['nguoi_gui_email'] ?? '').toString().trim().toLowerCase();
        final profile = _userProfiles[senderEmail];

        return _buildUserCard(
          email: senderEmail,
          profile: profile,
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                tooltip: 'Từ chối',
                onPressed: () =>
                    _removeRelation(rel['id'], 'Đã từ chối lời mời.'),
                icon: const Icon(Icons.close_rounded, color: Colors.grey),
              ),
              ElevatedButton(
                onPressed: () => _acceptFriendRequest(rel),
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryPurple,
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: const Text(
                  'Chấp nhận',
                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // TAB 3: TÌM KIẾM NGƯỜI CHƠI
  Widget _buildSearchTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 6, 20, 12),
          child: TextField(
            controller: _searchController,
            onChanged: _searchUsers,
            decoration: InputDecoration(
              hintText: 'Nhập tên hiển thị hoặc email người chơi...',
              prefixIcon: const Icon(Icons.search_rounded, color: primaryPurple),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear_rounded, size: 20),
                      onPressed: () {
                        _searchController.clear();
                        _searchUsers('');
                      },
                    )
                  : null,
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: Color(0xFFE3E6FA)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: Color(0xFFE3E6FA)),
              ),
            ),
          ),
        ),
        Expanded(
          child: _isSearching
              ? const Center(
                  child: CircularProgressIndicator(color: primaryPurple),
                )
              : _searchResults.isEmpty
                  ? Center(
                      child: Text(
                        _searchController.text.trim().isEmpty
                            ? 'Nhập tên hoặc email để tìm bạn bè'
                            : 'Không tìm thấy người chơi phù hợp',
                        style: const TextStyle(color: Colors.grey),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                      itemCount: _searchResults.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final user = _searchResults[index];
                        final email =
                            (user['email'] ?? '').toString().trim().toLowerCase();
                        final name = (user['ten_hien_thi'] ?? email.split('@').first)
                            .toString();
                        final relation = _getRelationWith(email);

                        Widget actionWidget;
                        if (relation == null) {
                          actionWidget = ElevatedButton.icon(
                            onPressed: () => _sendFriendRequest(email, name),
                            icon: const Icon(Icons.person_add_alt_1_rounded,
                                size: 16),
                            label: const Text('Kết bạn'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: primaryPurple,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 8),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          );
                        } else if (relation['trang_thai'] == 'accepted') {
                          actionWidget = Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: cardLavender,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Text(
                              'Bạn bè',
                              style: TextStyle(
                                color: primaryPurple,
                                fontWeight: FontWeight.bold,
                                fontSize: 12.5,
                              ),
                            ),
                          );
                        } else {
                          final isSentByMe = (relation['nguoi_gui_email'] ?? '')
                                  .toString()
                                  .trim()
                                  .toLowerCase() ==
                              _myEmail;
                          actionWidget = isSentByMe
                              ? OutlinedButton(
                                  onPressed: () => _removeRelation(
                                    relation['id'],
                                    'Đã hủy lời mời kết bạn.',
                                  ),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: Colors.grey.shade700,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                  child: const Text('Đã gửi',
                                      style: TextStyle(fontSize: 12.5)),
                                )
                              : ElevatedButton(
                                  onPressed: () =>
                                      _acceptFriendRequest(relation),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF2E7D32),
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                  child: const Text('Chấp nhận',
                                      style: TextStyle(fontSize: 12.5)),
                                );
                        }

                        return _buildUserCard(
                          email: email,
                          profile: user,
                          trailing: actionWidget,
                        );
                      },
                    ),
        ),
      ],
    );
  }

  Widget _buildUserCard({
    required String email,
    required core.Map<String, dynamic>? profile,
    required Widget trailing,
  }) {
    final name = (profile?['ten_hien_thi'] ?? '').toString().trim().isNotEmpty
        ? profile!['ten_hien_thi'].toString().trim()
        : email.split('@').first;
    final avatarUrl = (profile?['anh_dai_dien'] ?? '').toString().trim();
    final rank = (profile?['hang'] ?? 'ĐỒNG').toString().toUpperCase();
    final rankColor = RankService.getRankColor(rank);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE8EAFA)),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: const BoxDecoration(
              color: Color(0xFFFFD54F),
              shape: BoxShape.circle,
            ),
            child: ClipOval(
              child: avatarUrl.isNotEmpty
                  ? Image.network(
                      avatarUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => Center(
                        child: Text(
                          name.isNotEmpty ? name[0].toUpperCase() : 'P',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF282B78),
                          ),
                        ),
                      ),
                    )
                  : Center(
                      child: Text(
                        name.isNotEmpty ? name[0].toUpperCase() : 'P',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF282B78),
                        ),
                      ),
                    ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: darkText,
                  ),
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: rankColor,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        rank,
                        style: const TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                          color: darkText,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        email,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          trailing,
        ],
      ),
    );
  }
}