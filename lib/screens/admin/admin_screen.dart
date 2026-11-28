import 'package:material_ui/material_ui.dart';

import '../../services/auth_service.dart';
import '../../services/role_service.dart';
import '../../theme/app_theme.dart';
import '../home/home_screen.dart';
import 'admin_question_screen.dart';
import 'admin_subject_screen.dart';
import 'quiz_set_management_screen.dart';
import 'user_management_screen.dart';

class AdminScreen extends StatelessWidget {
  const AdminScreen({super.key});

  static const Color primaryPurple = Color(0xFF565CEB);
  static const Color darkPurple = Color(0xFF3E44C6);
  static const Color bgLight = Color(0xFFF6F7FC);
  static const Color darkText = Color(0xFF1E1E2C);

  Future<void> _logout(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('Đăng xuất?'),
        content: const Text('Bạn có chắc muốn đăng xuất khỏi tài khoản quản trị?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.error,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Đăng xuất'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await AuthService().logout();
    }
  }

  void _openUserMode(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const HomeScreen(fromAdmin: true),
      ),
    );
  }

  void _openUserManagement(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const UserManagementScreen()),
    );
  }

  void _openQuizSetManagement(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const QuizSetManagementScreen()),
    );
  }

  void _openSubjectManagement(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const AdminSubjectScreen()),
    );
  }

  void _openQuestionManagement(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const AdminQuestionScreen()),
    );
  }

  Widget _buildTopBanner(BuildContext context, bool isSuperAdmin) {
    final topPadding = MediaQuery.of(context).padding.top;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(18, topPadding + 12, 18, 24),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [primaryPurple, darkPurple],
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(30)),
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 860),
          child: Column(
            children: [
              // Thanh công cụ trên cùng
              Row(
                children: [
                  const Row(
                    children: [
                      Icon(
                        Icons.bolt_rounded,
                        color: Color(0xFFFFD54F),
                        size: 24,
                      ),
                      SizedBox(width: 6),
                      Text(
                        'QuizMaster',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  InkWell(
                    onTap: () => _openUserMode(context),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.22),
                        ),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.sports_esports_rounded,
                            color: Color(0xFFFFD54F),
                            size: 18,
                          ),
                          SizedBox(width: 6),
                          Text(
                            'Vào chơi / Thi',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  InkWell(
                    onTap: () => _logout(context),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.logout_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // Thẻ thông tin vai trò Admin
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.13),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.2),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 58,
                      height: 58,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(
                        isSuperAdmin
                            ? Icons.workspace_premium_rounded
                            : Icons.admin_panel_settings_rounded,
                        size: 32,
                        color: primaryPurple,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 9,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: isSuperAdmin
                                  ? const Color(0xFFFFB300)
                                  : Colors.white.withValues(alpha: 0.22),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              isSuperAdmin ? 'SUPER ADMIN' : 'ADMIN',
                              style: TextStyle(
                                color: isSuperAdmin ? darkText : Colors.white,
                                fontSize: 10.5,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.6,
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Bảng điều khiển quản trị',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            isSuperAdmin
                                ? 'Toàn quyền quản trị hệ thống, bộ đề & phân quyền'
                                : 'Quản lý bộ đề, môn học, kho câu hỏi & người dùng',
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
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 10),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w800,
          color: darkText,
        ),
      ),
    );
  }

  Widget _buildActionCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    String? badgeText,
    bool isHighlighted = false,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isHighlighted
            ? const Color(0xFFEDFBF3)
            : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isHighlighted
              ? const Color(0xFF00A86B).withValues(alpha: 0.35)
              : const Color(0xFFE6E8F8),
        ),
        boxShadow: [
          BoxShadow(
            color: primaryPurple.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Icon(icon, color: iconColor, size: 26),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            title,
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 15.5,
                              color: darkText,
                            ),
                          ),
                        ),
                        if (badgeText != null) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: iconColor.withValues(alpha: 0.14),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              badgeText,
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w800,
                                color: iconColor,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: Color(0xFF6B708D),
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 14,
                  color: iconColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDashboard(BuildContext context, String role) {
    final bool isSuperAdmin = role == 'super_admin';

    return Scaffold(
      backgroundColor: bgLight,
      body: Column(
        children: [
          _buildTopBanner(context, isSuperAdmin),
          Expanded(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 860),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 18, 16, 28),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSectionHeader('Chế độ Người dùng & Thi đấu'),
                      _buildActionCard(
                        icon: Icons.sports_esports_rounded,
                        iconColor: const Color(0xFF00A86B),
                        title: 'Tham gia phòng thi & Chơi game',
                        subtitle:
                            'Chuyển sang giao diện User để làm bài thi, vào phòng đấu và trải nghiệm trò chơi',
                        isHighlighted: true,
                        onTap: () => _openUserMode(context),
                      ),

                      const SizedBox(height: 14),
                      _buildSectionHeader('Quản lí học liệu & Đề thi'),

                      _buildActionCard(
                        icon: Icons.library_books_rounded,
                        iconColor: primaryPurple,
                        title: 'Quản lí bộ đề',
                        subtitle:
                            'Tạo mới, chỉnh sửa bộ đề, thiết lập thời gian, trạng thái và danh sách câu hỏi',
                        onTap: () => _openQuizSetManagement(context),
                      ),

                      _buildActionCard(
                        icon: Icons.menu_book_rounded,
                        iconColor: const Color(0xFF0288D1),
                        title: 'Quản lí môn học',
                        subtitle:
                            'Xem, thêm, chỉnh sửa và khóa/mở khóa các môn học & chủ đề',
                        onTap: () => _openSubjectManagement(context),
                      ),

                      _buildActionCard(
                        icon: Icons.quiz_rounded,
                        iconColor: const Color(0xFFF57C00),
                        title: 'Quản lí kho câu hỏi',
                        subtitle:
                            'Xem, lọc theo môn học/độ khó và quản lý ngân hàng câu hỏi chung',
                        onTap: () => _openQuestionManagement(context),
                      ),

                      const SizedBox(height: 14),
                      _buildSectionHeader('Quản lí tài khoản'),

                      _buildActionCard(
                        icon: Icons.people_alt_rounded,
                        iconColor: const Color(0xFF7B1FA2),
                        title: isSuperAdmin
                            ? 'Quản lí người dùng và Admin'
                            : 'Quản lí người dùng',
                        subtitle: isSuperAdmin
                            ? 'Quản lý hồ sơ, khóa/mở khóa tài khoản và phân quyền Admin'
                            : 'Xem thông tin hồ sơ và khóa/mở khóa tài khoản người dùng',
                        onTap: () => _openUserManagement(context),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String>(
      future: RoleService.getCurrentRole(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: bgLight,
            body: Center(
              child: CircularProgressIndicator(color: primaryPurple),
            ),
          );
        }

        if (snapshot.hasError) {
          return Scaffold(
            backgroundColor: bgLight,
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Không thể xác định quyền tài khoản:\n${snapshot.error}',
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          );
        }

        final role = snapshot.data;

        if (role != 'admin' && role != 'super_admin') {
          return const Scaffold(
            backgroundColor: bgLight,
            body: Center(
              child: Text('Bạn không có quyền truy cập trang quản trị.'),
            ),
          );
        }

        return _buildDashboard(context, role!);
      },
    );
  }
}