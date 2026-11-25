import 'package:material_ui/material_ui.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../services/user_management_service.dart';
import '../../services/role_service.dart';

class UserManagementScreen extends StatefulWidget {
  const UserManagementScreen({super.key});

  @override
  State<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends State<UserManagementScreen> {
  static const Color primaryColor = Color(0xFF6257E8);

  final TextEditingController _searchController = TextEditingController();

  List<Map<String, dynamic>> _users = [];
  bool _isLoading = true;
  String? _errorMessage;
  String _searchQuery = '';
  String? _currentRole;

  bool get _isSuperAdmin => _currentRole == 'super_admin';

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // Tải vai trò và danh sách người dùng.
  Future<void> _loadUsers() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final role = await RoleService.getCurrentRole();

      if (role != 'admin' && role != 'super_admin') {
        throw Exception('Bạn không có quyền quản lý người dùng.');
      }

      final users = await UserManagementService.getAllUsers();

      if (!mounted) return;

      setState(() {
        _currentRole = role;
        _users = users;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  // Lọc theo họ tên hoặc email.
  List<Map<String, dynamic>> get _filteredUsers {
    if (_searchQuery.trim().isEmpty) {
      return _users;
    }

    final query = _searchQuery.trim().toLowerCase();

    return _users.where((user) {
      final name = (user['ho_ten'] ?? '').toString().toLowerCase();
      final email = (user['email'] ?? '').toString().toLowerCase();

      return name.contains(query) || email.contains(query);
    }).toList();
  }

  // Kiểm tra quyền khóa/mở khóa tài khoản.
  bool _canChangeStatus(Map<String, dynamic> user) {
    final role = user['vai_tro']?.toString() ?? 'user';
    final userId = user['id']?.toString();
    final currentUid = FirebaseAuth.instance.currentUser?.uid;

    // Không ai được khóa Super Admin.
    if (role == 'super_admin') return false;

    // Không được tự khóa tài khoản.
    if (userId == currentUid) return false;

    // Admin chỉ được quản lý User.
    if (!_isSuperAdmin && role != 'user') return false;

    return true;
  }

  // Kiểm tra quyền thay đổi vai trò.
  bool _canChangeRole(Map<String, dynamic> user) {
    if (!_isSuperAdmin) return false;

    final role = user['vai_tro']?.toString() ?? 'user';
    final userId = user['id']?.toString();
    final currentUid = FirebaseAuth.instance.currentUser?.uid;

    // Không thay đổi Super Admin hoặc chính tài khoản hiện tại.
    if (role == 'super_admin' || userId == currentUid) {
      return false;
    }

    return role == 'user' || role == 'admin';
  }

  // Khóa hoặc mở khóa tài khoản.
  Future<void> _changeUserStatus(Map<String, dynamic> user) async {
    if (!_canChangeStatus(user)) {
      _showMessage('Bạn không có quyền thực hiện thao tác này.');
      return;
    }

    final userId = user['id']?.toString();

    if (userId == null || userId.isEmpty) {
      _showMessage('Không tìm thấy UID của tài khoản.');
      return;
    }

    final currentStatus = user['trang_thai'] == true;
    final newStatus = !currentStatus;
    final name = user['ho_ten']?.toString() ?? userId;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(newStatus ? 'Mở khóa tài khoản?' : 'Khóa tài khoản?'),
          content: Text(
            newStatus
                ? 'Bạn có chắc muốn mở khóa tài khoản "$name"?'
                : 'Bạn có chắc muốn khóa tài khoản "$name"?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Hủy'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: newStatus ? Colors.green : Colors.red,
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(newStatus ? 'Mở khóa' : 'Khóa tài khoản'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) return;

    try {
      await UserManagementService.setUserStatus(
        userId: userId,
        isActive: newStatus,
      );

      await _loadUsers();

      if (!mounted) return;

      _showMessage(
        newStatus
            ? 'Đã mở khóa tài khoản thành công.'
            : 'Đã khóa tài khoản thành công.',
        isError: false,
      );
    } catch (e) {
      if (!mounted) return;

      _showMessage(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  // Thăng cấp User thành Admin hoặc hạ Admin xuống User.
  Future<void> _changeUserRole(Map<String, dynamic> user) async {
    if (!_canChangeRole(user)) {
      _showMessage('Bạn không có quyền thay đổi vai trò tài khoản.');
      return;
    }

    final userId = user['id']?.toString();

    if (userId == null || userId.isEmpty) {
      _showMessage('Không tìm thấy UID của tài khoản.');
      return;
    }

    final currentRole = user['vai_tro']?.toString() ?? 'user';
    final newRole = currentRole == 'user' ? 'admin' : 'user';

    final name = user['ho_ten']?.toString() ?? userId;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(
            newRole == 'admin' ? 'Nâng cấp lên Admin?' : 'Hạ cấp xuống User?',
          ),
          content: Text(
            newRole == 'admin'
                ? 'Bạn có chắc muốn cấp quyền Admin cho "$name"? '
                      'Tài khoản này sẽ có quyền quản lý người dùng thông thường.'
                : 'Bạn có chắc muốn chuyển "$name" về quyền User? '
                      'Tài khoản sẽ không còn quyền quản trị.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Hủy'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Xác nhận'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) return;

    try {
      await UserManagementService.setUserRole(userId: userId, role: newRole);

      await _loadUsers();

      if (!mounted) return;

      _showMessage(
        newRole == 'admin'
            ? 'Đã nâng cấp tài khoản thành Admin.'
            : 'Đã hạ cấp tài khoản xuống User.',
        isError: false,
      );
    } catch (e) {
      if (!mounted) return;

      _showMessage(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  void _showMessage(String message, {bool isError = true}) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
      ),
    );
  }

  // Hiển thị chi tiết tài khoản.
  void _showUserDetails(Map<String, dynamic> user) {
    final role = user['vai_tro']?.toString() ?? 'user';
    final isActive = user['trang_thai'] == true;

    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    final isCurrentUser = user['id']?.toString() == currentUid;

    final canChangeStatus = _canChangeStatus(user);
    final canChangeRole = _canChangeRole(user);

    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Thông tin tài khoản'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _detailRow('Họ tên', user['ho_ten']),
                _detailRow('Email', user['email']),
                _detailRow('UID', user['id']),
                _detailRow('Vai trò', _roleLabel(role)),
                _detailRow(
                  'Trạng thái',
                  isActive ? 'Đang hoạt động' : 'Đã bị khóa',
                ),
                _detailRow('Ngày tạo', _formatDate(user['ngay_tao'])),

                if (role == 'super_admin') ...[
                  const SizedBox(height: 8),
                  const Text(
                    'Đây là tài khoản Super Admin. '
                    'Tài khoản này được bảo vệ và không thể bị khóa '
                    'hoặc thay đổi vai trò.',
                    style: TextStyle(color: Colors.orange, fontSize: 12),
                  ),
                ],

                if (isCurrentUser) ...[
                  const SizedBox(height: 8),
                  const Text(
                    'Đây là tài khoản đang đăng nhập. '
                    'Không thể tự khóa hoặc tự thay đổi vai trò.',
                    style: TextStyle(color: Colors.orange, fontSize: 12),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Đóng'),
            ),

            if (canChangeRole)
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  foregroundColor: Colors.white,
                ),
                icon: const Icon(Icons.admin_panel_settings),
                label: Text(
                  role == 'user' ? 'Cấp quyền Admin' : 'Hạ xuống User',
                ),
                onPressed: () {
                  Navigator.pop(dialogContext);
                  _changeUserRole(user);
                },
              ),

            if (canChangeStatus)
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: isActive ? Colors.red : Colors.green,
                  foregroundColor: Colors.white,
                ),
                icon: Icon(isActive ? Icons.lock : Icons.lock_open),
                label: Text(isActive ? 'Khóa tài khoản' : 'Mở khóa'),
                onPressed: () {
                  Navigator.pop(dialogContext);
                  _changeUserStatus(user);
                },
              ),
          ],
        );
      },
    );
  }

  Widget _detailRow(String label, dynamic value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 3),
          SelectableText(value?.toString() ?? 'Chưa có thông tin'),
        ],
      ),
    );
  }

  String _roleLabel(String role) {
    switch (role) {
      case 'super_admin':
        return 'SUPER ADMIN';
      case 'admin':
        return 'ADMIN';
      default:
        return 'USER';
    }
  }

  String _formatDate(dynamic value) {
    if (value == null) return 'Không xác định';

    final date = DateTime.tryParse(value.toString());

    if (date == null) return value.toString();

    final localDate = date.toLocal();

    return '${localDate.day.toString().padLeft(2, '0')}/'
        '${localDate.month.toString().padLeft(2, '0')}/'
        '${localDate.year}';
  }

  Widget _buildStatusChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildUserCard(Map<String, dynamic> user) {
    final name = user['ho_ten']?.toString() ?? 'Chưa có tên';
    final email = user['email']?.toString() ?? '';
    final role = user['vai_tro']?.toString() ?? 'user';
    final isActive = user['trang_thai'] == true;

    final roleColor = switch (role) {
      'super_admin' => Colors.deepOrange,
      'admin' => primaryColor,
      _ => Colors.blue,
    };

    final roleIcon = switch (role) {
      'super_admin' => Icons.workspace_premium_rounded,
      'admin' => Icons.admin_panel_settings,
      _ => Icons.person,
    };

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 10,
        ),
        leading: CircleAvatar(
          backgroundColor: roleColor.withValues(alpha: 0.12),
          child: Icon(roleIcon, color: roleColor),
        ),
        title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 5),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(email),
              const SizedBox(height: 7),
              Wrap(
                spacing: 8,
                runSpacing: 5,
                children: [
                  _buildStatusChip(_roleLabel(role), roleColor),
                  _buildStatusChip(
                    isActive ? 'Hoạt động' : 'Đã khóa',
                    isActive ? Colors.green : Colors.red,
                  ),
                ],
              ),
            ],
          ),
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => _showUserDetails(user),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: primaryColor),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 55),
              const SizedBox(height: 12),
              const Text(
                'Không thể tải danh sách người dùng',
                textAlign: TextAlign.center,
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
              ),
              const SizedBox(height: 8),
              Text(_errorMessage!, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _loadUsers,
                icon: const Icon(Icons.refresh),
                label: const Text('Thử lại'),
              ),
            ],
          ),
        ),
      );
    }

    final filteredUsers = _filteredUsers;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Tìm theo họ tên hoặc email...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      onPressed: () {
                        _searchController.clear();
                        setState(() {
                          _searchQuery = '';
                        });
                      },
                      icon: const Icon(Icons.clear),
                    )
                  : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onChanged: (value) {
              setState(() {
                _searchQuery = value;
              });
            },
          ),
        ),

        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              const Icon(Icons.people_alt, color: primaryColor),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Tổng số tài khoản: ${_users.length}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              IconButton(
                tooltip: 'Làm mới',
                onPressed: _loadUsers,
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
        ),

        if (_isSuperAdmin)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Bạn có quyền quản lý User và Admin. '
                'Tài khoản Super Admin được bảo vệ.',
                style: TextStyle(fontSize: 12, color: Colors.deepOrange),
              ),
            ),
          ),

        const SizedBox(height: 8),

        Expanded(
          child: filteredUsers.isEmpty
              ? Center(
                  child: Text(
                    _users.isEmpty
                        ? 'Chưa có người dùng nào.'
                        : 'Không tìm thấy người dùng phù hợp.',
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadUsers,
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 4,
                    ),
                    itemCount: filteredUsers.length,
                    itemBuilder: (context, index) {
                      return _buildUserCard(filteredUsers[index]);
                    },
                  ),
                ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _isSuperAdmin ? 'Quản lý người dùng và Admin' : 'Quản lý người dùng',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
      ),
      body: _buildBody(),
    );
  }
}
