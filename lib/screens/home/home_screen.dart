
import 'package:material_ui/material_ui.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../services/auth_service.dart';
import '../../services/backend_service.dart';
import '../../screens/subject/subject_detail_screen.dart';
import '../../screens/subject/subject_list_screen.dart';
import '../../models/subject_model.dart';
import '../../services/subject_service.dart';

  class HomeScreen extends StatefulWidget {
    const HomeScreen({super.key});

    @override
    State<HomeScreen> createState() => _HomeScreenState();
  }

  class _HomeScreenState extends State<HomeScreen> {
    static const Color primaryColor = Color(0xFF6257E8);
    static const Color backgroundColor = Color(0xFFF5F6FF);

    int _selectedIndex = 0;

    final TextEditingController _searchController =
        TextEditingController();

    late Future<List<SubjectModel>> _subjectsFuture;

    // =========================
    // KIỂM TRA FIREBASE TOKEN & TẢI DỮ LIỆU
    // =========================

    @override
    void initState() {
      super.initState();
      _subjectsFuture = SubjectService.getAllSubjects();

      WidgetsBinding.instance.addPostFrameCallback((_) async {
        final user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          try {
            await BackendService.checkCurrentUser();
          } catch (e) {
            debugPrint('CHECK CURRENT USER ERROR: $e');
          }
        }
      });
    }

    void _loadSubjects() {
      if (!mounted) return;
      setState(() {
        _subjectsFuture = SubjectService.getAllSubjects();
      });
    }



    // =========================
    // DỮ LIỆU TRANG CHỦ
    // =========================

    final List<Map<String, dynamic>> _gameModes = [
      {
        'name': 'Quick Quiz',
        'description': 'Kiểm tra kiến thức nhanh',
        'icon': Icons.bolt_rounded,
        'color': Color(0xFFFFA726),
      },
      {
        'name': 'Ai là triệu phú',
        'description': 'Chinh phục từng câu hỏi',
        'icon': Icons.monetization_on_rounded,
        'color': Color(0xFF6257E8),
      },
      {
        'name': 'Đấu 1vs1',
        'description': 'Thách đấu bạn bè',
        'icon': Icons.people_alt_rounded,
        'color': Color(0xFF29B6F6),
      },
      {
        'name': 'Sinh tồn',
        'description': 'Trả lời để sống sót',
        'icon': Icons.local_fire_department_rounded,
        'color': Color(0xFFEF5350),
      },
      {
        'name': 'Team Battle',
        'description': 'Cùng đồng đội chiến đấu',
        'icon': Icons.groups_rounded,
        'color': Color(0xFF66BB6A),
      },
      {
        'name': 'Luyện tập',
        'description': 'Ôn luyện kiến thức mỗi ngày',
        'icon': Icons.menu_book_rounded,
        'color': Color(0xFFAB47BC),
      },
    ];



    User? get currentUser => FirebaseAuth.instance.currentUser;

    String get userName {
      final name = currentUser?.displayName;

      if (name != null && name.trim().isNotEmpty) {
        return name;
      }

      final email = currentUser?.email ?? 'Bạn';
      return email.split('@').first;
    }

    @override
    void dispose() {
      _searchController.dispose();
      super.dispose();
    }

    void _showComingSoon(String feature) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$feature đang được phát triển.'),
          behavior: SnackBarBehavior.floating,
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
                backgroundColor: primaryColor,
                foregroundColor: Colors.white,
              ),
              child: const Text('Đăng xuất'),
            ),
          ],
        ),
      );

      if (confirm == true) {
        await AuthService().logout();
      }
    }

    @override
    Widget build(BuildContext context) {
      return Scaffold(
        backgroundColor: backgroundColor,
        body: SafeArea(
          child: IndexedStack(
            index: _selectedIndex,
            children: [
              _buildHomePage(),
              _buildExplorePage(),
              _buildRankingPage(),
              _buildProfilePage(),
            ],
          ),
        ),
        bottomNavigationBar: _buildBottomNavigation(),
      );
    }

    // =========================
    // TRANG CHỦ
    // =========================

    Widget _buildHomePage() {
      return LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth > 700;

          return SingleChildScrollView(
            padding: EdgeInsets.symmetric(
              horizontal: isWide ? 32 : 20,
              vertical: 20,
            ),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1000),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeader(),
                    const SizedBox(height: 25),
                    _buildWelcomeBanner(),
                    const SizedBox(height: 25),
                    _buildSearchBar(),
                    const SizedBox(height: 30),
                    _buildSectionTitle(
                      'Chế độ chơi',
                      'Khám phá các thử thách thú vị',
                      onSeeAll: () {
                        setState(() => _selectedIndex = 1);
                      },
                    ),
                    const SizedBox(height: 16),
                    _buildGameModeGrid(isWide),
                    const SizedBox(height: 30),
                    _buildSectionTitle(
                      'Môn học',
                      'Chọn lĩnh vực bạn yêu thích',
                      onSeeAll: () {
                        setState(() => _selectedIndex = 1);
                      },
                    ),
                    const SizedBox(height: 16),
                    _buildSubjectList(),
                    const SizedBox(height: 30),
                    _buildSectionTitle(
                      'Bài kiểm tra nổi bật',
                      'Những thử thách dành cho bạn',
                      onSeeAll: () {
                        setState(() => _selectedIndex = 1);
                      },
                    ),
                    const SizedBox(height: 16),
                    _buildFeaturedExam(),
                    const SizedBox(height: 25),
                    _buildDailyChallenge(),
                    const SizedBox(height: 25),
                  ],
                ),
              ),
            ),
          );
        },
      );
    }

    // Header
    Widget _buildHeader() {
      return Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: primaryColor,
              borderRadius: BorderRadius.circular(15),
            ),
            child: const Icon(
              Icons.quiz_rounded,
              color: Colors.white,
              size: 29,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'QuizMaster',
                  style: TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF29245C),
                  ),
                ),
                Text(
                  'Học tập và thử thách bản thân',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () {
              _showComingSoon('Thông báo');
            },
            icon: const Icon(
              Icons.notifications_none_rounded,
              color: Color(0xFF29245C),
              size: 27,
            ),
          ),
          CircleAvatar(
            radius: 21,
            backgroundColor: const Color(0xFFE6E3FF),
            child: Text(
              userName.isNotEmpty
                  ? userName[0].toUpperCase()
                  : 'U',
              style: const TextStyle(
                color: primaryColor,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ),
        ],
      );
    }

    // Banner chào mừng
    Widget _buildWelcomeBanner() {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [
              Color(0xFF6257E8),
              Color(0xFF9187F5),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(22),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Xin chào, $userName!',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 21,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Sẵn sàng chinh phục những thử thách kiến thức hôm nay chưa?',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      _showComingSoon('Thử thách hôm nay');
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: primaryColor,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Bắt đầu ngay',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            const Icon(
              Icons.emoji_events_rounded,
              size: 75,
              color: Color(0xFFFFD166),
            ),
          ],
        ),
      );
    }

    // Thanh tìm kiếm
    Widget _buildSearchBar() {
      return TextField(
        controller: _searchController,
        onSubmitted: (value) {
          if (value.trim().isNotEmpty) {
            _showComingSoon('Tìm kiếm: ${value.trim()}');
          }
        },
        decoration: InputDecoration(
          hintText: 'Tìm kiếm môn học, bài kiểm tra...',
          prefixIcon: const Icon(
            Icons.search,
            color: primaryColor,
          ),
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(vertical: 16),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: BorderSide.none,
          ),
        ),
      );
    }

    // Tiêu đề từng phần
    Widget _buildSectionTitle(
      String title,
      String subtitle, {
      VoidCallback? onSeeAll,
    }) {
      return Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF29245C),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
          ),
          if (onSeeAll != null)
            TextButton(
              onPressed: onSeeAll,
              child: const Text(
                'Xem tất cả',
                style: TextStyle(
                  color: primaryColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      );
    }

    // Danh sách chế độ chơi
    Widget _buildGameModeGrid(bool isWide) {
      return GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: _gameModes.length,
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: isWide ? 3 : 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: isWide ? 2.1 : 1.45,
        ),
        itemBuilder: (context, index) {
          final mode = _gameModes[index];
          return _buildGameModeCard(mode);
        },
      );
    }

    Widget _buildGameModeCard(Map<String, dynamic> mode) {
      final Color color = mode['color'];

      return InkWell(
        onTap: () {
          _showComingSoon(mode['name']);
        },
        borderRadius: BorderRadius.circular(17),
        child: Container(
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(17),
            border: Border.all(
              color: const Color(0xFFEDEBFA),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: color.withAlpha(30),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  mode['icon'],
                  color: color,
                  size: 23,
                ),
              ),
              const SizedBox(height: 9),
              Text(
                mode['name'],
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF29245C),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                mode['description'],
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 10,
                  color: Colors.grey,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // =========================
    // DANH SÁCH MÔN HỌC (API)
    // =========================

    Color _getSubjectColor(String? colorValue) {
      if (colorValue == null || colorValue.trim().isEmpty) {
        return primaryColor;
      }
      try {
        String hex = colorValue.trim().replaceAll('#', '');
        if (hex.length == 6) {
          hex = 'FF$hex';
        }
        if (hex.length != 8) {
          return primaryColor;
        }
        return Color(int.parse(hex, radix: 16));
      } catch (_) {
        return primaryColor;
      }
    }

    Widget _buildSubjectIcon(SubjectModel subject, Color color) {
      final symbol = subject.bieuTuong?.trim();
      if (symbol != null && symbol.isNotEmpty) {
        if (symbol.characters.length <= 2) {
          return Text(
            symbol,
            style: const TextStyle(fontSize: 26),
            textAlign: TextAlign.center,
          );
        }
      }
      return Icon(
        Icons.menu_book_rounded,
        color: color,
        size: 32,
      );
    }

    Widget _buildSubjectList() {
      return FutureBuilder<List<SubjectModel>>(
        future: _subjectsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const SizedBox(
              height: 112,
              child: Center(
                child: CircularProgressIndicator(),
              ),
            );
          }

          if (snapshot.hasError) {
            return SizedBox(
              height: 112,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Không thể tải danh sách môn học',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.red,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextButton.icon(
                      onPressed: _loadSubjects,
                      icon: const Icon(Icons.refresh, size: 16),
                      label: const Text(
                        'Thử lại',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          final subjects = snapshot.data ?? [];
          if (subjects.isEmpty) {
            return const SizedBox(
              height: 112,
              child: Center(
                child: Text(
                  'Chưa có môn học nào',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey,
                  ),
                ),
              ),
            );
          }

          return SizedBox(
            height: 112,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: subjects.length,
              separatorBuilder: (context, index) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                final subject = subjects[index];
                final Color color = _getSubjectColor(subject.mauSac);

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
                  child: Container(
                    width: 105,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: const Color(0xFFEDEBFA),
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _buildSubjectIcon(subject, color),
                        const SizedBox(height: 9),
                        Text(
                          subject.tenMon,
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                            color: Color(0xFF29245C),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          );
        },
      );
    }

    // Bài kiểm tra nổi bật
    Widget _buildFeaturedExam() {
      return InkWell(
        onTap: () {
          _showComingSoon('Bài kiểm tra nổi bật');
        },
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(17),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: const Color(0xFFEDEBFA),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 65,
                height: 65,
                decoration: BoxDecoration(
                  color: const Color(0xFFE9E6FF),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: const Icon(
                  Icons.menu_book_rounded,
                  color: primaryColor,
                  size: 35,
                ),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Kiến thức tổng hợp',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: Color(0xFF29245C),
                      ),
                    ),
                    SizedBox(height: 7),
                    Text(
                      'Ôn tập nhiều lĩnh vực kiến thức',
                      style: TextStyle(
                        color: Colors.grey,
                        fontSize: 11,
                      ),
                    ),
                    SizedBox(height: 7),
                    Row(
                      children: [
                        Icon(
                          Icons.help_outline,
                          size: 14,
                          color: primaryColor,
                        ),
                        SizedBox(width: 4),
                        Text(
                          '10 câu hỏi',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.arrow_forward_ios,
                color: primaryColor,
                size: 17,
              ),
            ],
          ),
        ),
      );
    }

    // Thử thách mỗi ngày
    Widget _buildDailyChallenge() {
      return Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF3DF),
          borderRadius: BorderRadius.circular(18),
        ),
        child: const Row(
          children: [
            Icon(
              Icons.local_fire_department_rounded,
              color: Color(0xFFFF9800),
              size: 40,
            ),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Thử thách mỗi ngày',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF754600),
                    ),
                  ),
                  SizedBox(height: 5),
                  Text(
                    'Duy trì luyện tập để nâng cao kiến thức!',
                    style: TextStyle(
                      fontSize: 11,
                      color: Color(0xFF98713D),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    // =========================
    // TRANG KHÁM PHÁ (MÔN HỌC)
    // =========================

    Widget _buildExplorePage() {
      return const SubjectListScreen(isEmbedded: true);
    }

    // =========================
    // TRANG XẾP HẠNG
    // =========================

    Widget _buildRankingPage() {
      return _buildSimplePage(
        icon: Icons.emoji_events_rounded,
        title: 'Bảng xếp hạng',
        subtitle: 'Theo dõi thành tích và so tài với người chơi khác.',
        buttonText: 'Xem bảng xếp hạng',
        onPressed: () => _showComingSoon('Bảng xếp hạng'),
      );
    }

    // =========================
    // TRANG CÁ NHÂN
    // =========================

    Widget _buildProfilePage() {
      return SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Column(
              children: [
                const SizedBox(height: 30),
                CircleAvatar(
                  radius: 48,
                  backgroundColor: const Color(0xFFE6E3FF),
                  child: Text(
                    userName.isNotEmpty
                        ? userName[0].toUpperCase()
                        : 'U',
                    style: const TextStyle(
                      fontSize: 38,
                      color: primaryColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 15),
                Text(
                  userName,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF29245C),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  currentUser?.email ?? '',
                  style: const TextStyle(
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 30),
                _buildProfileOption(
                  Icons.person_outline,
                  'Thông tin cá nhân',
                  () => _showComingSoon('Thông tin cá nhân'),
                ),
                _buildProfileOption(
                  Icons.history_rounded,
                  'Lịch sử làm bài',
                  () => _showComingSoon('Lịch sử làm bài'),
                ),
                _buildProfileOption(
                  Icons.settings_outlined,
                  'Cài đặt',
                  () => _showComingSoon('Cài đặt'),
                ),
                _buildProfileOption(
                  Icons.help_outline,
                  'Trợ giúp',
                  () => _showComingSoon('Trợ giúp'),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: OutlinedButton.icon(
                    onPressed: _logout,
                    icon: const Icon(Icons.logout),
                    label: const Text('Đăng xuất'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.red),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
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

    Widget _buildProfileOption(
      IconData icon,
      String title,
      VoidCallback onTap,
    ) {
      return Card(
        color: Colors.white,
        elevation: 0,
        margin: const EdgeInsets.only(bottom: 10),
        child: ListTile(
          leading: Icon(icon, color: primaryColor),
          title: Text(title),
          trailing: const Icon(
            Icons.arrow_forward_ios,
            size: 15,
          ),
          onTap: onTap,
        ),
      );
    }

    // Trang thông tin đơn giản
    Widget _buildSimplePage({
      required IconData icon,
      required String title,
      required String subtitle,
      required String buttonText,
      required VoidCallback onPressed,
    }) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                color: primaryColor,
                size: 85,
              ),
              const SizedBox(height: 20),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF29245C),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.grey,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 25),
              ElevatedButton(
                onPressed: onPressed,
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  foregroundColor: Colors.white,
                ),
                child: Text(buttonText),
              ),
            ],
          ),
        ),
      );
    }

    // =========================
    // THANH ĐIỀU HƯỚNG
    // =========================

    Widget _buildBottomNavigation() {
      return NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        backgroundColor: Colors.white,
        indicatorColor: const Color(0xFFE9E6FF),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded),
            label: 'Trang chủ',
          ),
          NavigationDestination(
            icon: Icon(Icons.explore_outlined),
            selectedIcon: Icon(Icons.explore_rounded),
            label: 'Khám phá',
          ),
          NavigationDestination(
            icon: Icon(Icons.emoji_events_outlined),
            selectedIcon: Icon(Icons.emoji_events_rounded),
            label: 'Xếp hạng',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person_rounded),
            label: 'Cá nhân',
          ),
        ],
      );
    }
  }
