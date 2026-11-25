import 'package:material_ui/material_ui.dart';

import '../../services/auth_service.dart';
import '../../services/role_service.dart';
import 'admin_subject_screen.dart';
import 'admin_question_screen.dart';
import 'user_management_screen.dart';

class AdminScreen extends StatelessWidget {
  const AdminScreen({super.key});

  static const Color primaryColor = Color(0xFF6257E8);

  Future<void> _logout(BuildContext context) async {
    await AuthService().logout();
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

  Widget _buildDashboard(BuildContext context, String role) {
    final bool isSuperAdmin = role == 'super_admin';

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'QuizMaster - Quản trị',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            tooltip: 'Đăng xuất',
            onPressed: () => _logout(context),
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                isSuperAdmin
                    ? Icons.workspace_premium_rounded
                    : Icons.admin_panel_settings_rounded,
                size: 90,
                color: primaryColor,
              ),
              const SizedBox(height: 20),

              Text(
                isSuperAdmin
                    ? 'TRANG QUẢN TRỊ SUPER ADMIN'
                    : 'TRANG QUẢN TRỊ ADMIN',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: primaryColor,
                ),
              ),

              const SizedBox(height: 12),

              Text(
                isSuperAdmin
                    ? 'Bạn đang đăng nhập với quyền quản trị cao nhất.'
                    : 'Bạn đã đăng nhập với quyền quản trị viên.',
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 30),

              Card(
                child: ListTile(
                  leading: const Icon(
                    Icons.people_alt_rounded,
                    color: primaryColor,
                  ),
                  title: Text(
                    isSuperAdmin
                        ? 'Quản lý người dùng và Admin'
                        : 'Quản lý người dùng',
                  ),
                  subtitle: Text(
                    isSuperAdmin
                        ? 'Quản lý tài khoản và phân quyền Admin'
                        : 'Xem và quản lý tài khoản người dùng',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _openUserManagement(context),
                ),
              ),

              Card(
                child: ListTile(
                  leading: const Icon(
                    Icons.menu_book_rounded,
                    color: primaryColor,
                  ),
                  title: const Text('Quản lý môn học và đề thi'),
                  subtitle: const Text(
                    'Xem, thêm, sửa và quản lý trạng thái môn học',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _openSubjectManagement(context),
                ),
              ),

              Card(
                child: ListTile(
                  leading: const Icon(Icons.quiz_rounded, color: primaryColor),
                  title: const Text('Quản lý câu hỏi'),
                  subtitle: const Text('Xem, lọc và quản lý kho câu hỏi'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _openQuestionManagement(context),
                ),
              ),
            ],
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
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError) {
          return Scaffold(
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
