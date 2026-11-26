import 'package:material_ui/material_ui.dart';

import '../../services/auth_service.dart';
import '../../services/role_service.dart';
import '../../theme/app_theme.dart';
import '../home/home_screen.dart';
import 'admin_question_screen.dart';
import 'admin_subject_screen.dart';
import 'user_management_screen.dart';

class AdminScreen extends StatelessWidget {
  const AdminScreen({super.key});

  Future<void> _logout(BuildContext context) async {
    await AuthService().logout();
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

  Widget _buildHeaderBanner(bool isSuperAdmin) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.primary,
            AppTheme.primary.withValues(alpha: 0.82),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primary.withValues(alpha: 0.25),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(
              isSuperAdmin
                  ? Icons.workspace_premium_rounded
                  : Icons.admin_panel_settings_rounded,
              size: 36,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 16),
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
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    isSuperAdmin ? 'SUPER ADMIN' : 'ADMIN',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.6,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Bảng điều khiển QuizMaster',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  isSuperAdmin
                      ? 'Toàn quyền quản trị hệ thống & tham gia thi đấu'
                      : 'Quản lý nội dung, người dùng & tham gia thi đấu',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.white.withValues(alpha: 0.9),
                  ),
                ),
              ],
            ),
          ),
        ],
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
          fontWeight: FontWeight.bold,
          color: AppTheme.textPrimary,
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
    bool isHighlighted = false,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isHighlighted
            ? AppTheme.primary.withValues(alpha: 0.06)
            : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isHighlighted
              ? AppTheme.primary.withValues(alpha: 0.35)
              : AppTheme.cardBorder,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 10,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(icon, color: iconColor, size: 26),
        ),
        title: Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 15.5,
            color: AppTheme.textPrimary,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            subtitle,
            style: const TextStyle(
              fontSize: 12.5,
              color: AppTheme.textSecondary,
            ),
          ),
        ),
        trailing: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.arrow_forward_ios_rounded,
            size: 14,
            color: iconColor,
          ),
        ),
        onTap: onTap,
      ),
    );
  }

  Widget _buildDashboard(BuildContext context, String role) {
    final bool isSuperAdmin = role == 'super_admin';

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text(
          'QuizMaster - Quản trị',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          TextButton.icon(
            onPressed: () => _openUserMode(context),
            icon: const Icon(
              Icons.sports_esports_rounded,
              color: Colors.white,
              size: 20,
            ),
            label: const Text(
              'Vào chơi / Thi',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          IconButton(
            tooltip: 'Đăng xuất',
            onPressed: () => _logout(context),
            icon: const Icon(Icons.logout_rounded),
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeaderBanner(isSuperAdmin),
                const SizedBox(height: 24),

                _buildSectionHeader('Chế độ Người dùng & Thi đấu'),
                _buildActionCard(
                  icon: Icons.sports_esports_rounded,
                  iconColor: const Color(0xFF00A86B),
                  title: 'Tham gia phòng thi & Chơi game',
                  subtitle:
                      'Chuyển sang giao diện User để làm bài thi, vào phòng đấu và chơi các trò chơi',
                  isHighlighted: true,
                  onTap: () => _openUserMode(context),
                ),

                const SizedBox(height: 14),
                _buildSectionHeader('Quản trị hệ thống'),

                _buildActionCard(
                  icon: Icons.people_alt_rounded,
                  iconColor: AppTheme.primary,
                  title: isSuperAdmin
                      ? 'Quản lý người dùng và Admin'
                      : 'Quản lý người dùng',
                  subtitle: isSuperAdmin
                      ? 'Quản lý tài khoản, khóa/mở khóa và phân quyền Admin'
                      : 'Xem và quản lý trạng thái tài khoản người dùng',
                  onTap: () => _openUserManagement(context),
                ),

                _buildActionCard(
                  icon: Icons.menu_book_rounded,
                  iconColor: const Color(0xFF29B6F6),
                  title: 'Quản lý môn học và đề thi',
                  subtitle:
                      'Xem, thêm, chỉnh sửa và khóa/mở khóa các môn học',
                  onTap: () => _openSubjectManagement(context),
                ),

                _buildActionCard(
                  icon: Icons.quiz_rounded,
                  iconColor: const Color(0xFFFF9800),
                  title: 'Quản lý kho câu hỏi',
                  subtitle:
                      'Xem, lọc theo môn học/độ khó và thêm câu hỏi mới',
                  onTap: () => _openQuestionManagement(context),
                ),
              ],
            ),
          ),
        ),
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
            backgroundColor: AppTheme.background,
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError) {
          return Scaffold(
            backgroundColor: AppTheme.background,
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
            backgroundColor: AppTheme.background,
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