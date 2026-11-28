import 'dart:core';
import 'dart:core' as core;

import 'package:material_ui/material_ui.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../services/role_service.dart';

class UserManagementScreen extends StatefulWidget {
  const UserManagementScreen({super.key});

  @override
  State<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends State<UserManagementScreen> {
  static const Color primaryPurple = Color(0xFF565CEB);
  static const Color darkPurple = Color(0xFF3E44C6);
  static const Color bgLight = Color(0xFFF6F7FC);
  static const Color darkText = Color(0xFF1E1E2C);

  final SupabaseClient _supabase = Supabase.instance.client;
  final TextEditingController _searchController = TextEditingController();

  core.List<core.Map<core.String, dynamic>> _users = [];
  bool _isLoading = true;
  bool _showSearchBar = false;
  bool _isSuperAdmin = false;
  core.String? _errorMessage;
  core.String _searchQuery = '';
  core.String _roleFilter = 'all';

  @override
  void initState() {
    super.initState();
    _initAndLoad();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _initAndLoad() async {
    try {
      final currentRole = await RoleService.getCurrentRole();
      if (mounted) {
        setState(() => _isSuperAdmin = currentRole == 'super_admin');
      }
    } catch (_) {}
    await _loadUsers();
  }

  Future<void> _loadUsers() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final res = await _supabase
          .from('nguoi_dung')
          .select()
          .order('ngay_tao', ascending: false);

      if (!mounted) return;
      setState(() {
        _users = (res as core.List)
            .map((e) => core.Map<core.String, dynamic>.from(e as core.Map))
            .toList();
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  core.String _getDisplayName(core.Map<core.String, dynamic> user) {
    final name = (user['ho_ten'] ?? user['ten_hien_thi'] ?? '').toString().trim();
    if (name.isNotEmpty) return name;
    final email = (user['email'] ?? '').toString().trim();
    if (email.contains('@')) return email.split('@').first;
    return 'Người dùng';
  }

  core.String _getRole(core.Map<core.String, dynamic> user) {
    return (user['vai_tro'] ?? user['role'] ?? 'user').toString().toLowerCase();
  }

  bool _isLocked(core.Map<core.String, dynamic> user) {
    final status = (user['trang_thai'] ?? 'active').toString().toLowerCase();
    final biKhoa = user['bi_khoa'];
    return status == 'locked' || status == 'blocked' || biKhoa == true;
  }

  core.List<core.Map<core.String, dynamic>> get _filteredUsers {
    return _users.where((u) {
      final role = _getRole(u);
      if (_roleFilter != 'all' && role != _roleFilter) return false;

      if (_searchQuery.trim().isNotEmpty) {
        final q = _searchQuery.trim().toLowerCase();
        final name = _getDisplayName(u).toLowerCase();
        final email = (u['email'] ?? '').toString().toLowerCase();
        return name.contains(q) || email.contains(q);
      }
      return true;
    }).toList();
  }

  Future<void> _toggleLockUser(core.Map<core.String, dynamic> user) async {
    final id = user['id']?.toString() ?? '';
    if (id.isEmpty) return;
    final currentlyLocked = _isLocked(user);
    final newStatus = currentlyLocked ? 'active' : 'locked';

    try {
      await _supabase
          .from('nguoi_dung')
          .update({'trang_thai': newStatus})
          .eq('id', id);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            currentlyLocked
                ? 'Đã mở khóa tài khoản thành công.'
                : 'Đã khóa tài khoản thành công.',
          ),
          backgroundColor: Colors.green,
        ),
      );
      await _loadUsers();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Lỗi cập nhật trạng thái: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _changeUserRole(
    core.Map<core.String, dynamic> user,
    core.String newRole,
  ) async {
    final id = user['id']?.toString() ?? '';
    if (id.isEmpty) return;

    try {
      await _supabase
          .from('nguoi_dung')
          .update({'vai_tro': newRole})
          .eq('id', id);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Đã cập nhật quyền tài khoản.'),
          backgroundColor: Colors.green,
        ),
      );
      await _loadUsers();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Lỗi phân quyền: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Widget _buildRoleBadge(core.String role) {
    Color bg;
    Color fg;
    core.String label;

    switch (role) {
      case 'super_admin':
        bg = const Color(0xFFFFF3CD);
        fg = const Color(0xFFB26A00);
        label = 'SUPER ADMIN';
        break;
      case 'admin':
        bg = const Color(0xFFE8EAFF);
        fg = primaryPurple;
        label = 'ADMIN';
        break;
      default:
        bg = const Color(0xFFF1F3F9);
        fg = const Color(0xFF5C627D);
        label = 'USER';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w800,
          color: fg,
        ),
      ),
    );
  }

  Widget _buildUserCard(core.Map<core.String, dynamic> user) {
    final name = _getDisplayName(user);
    final email = (user['email'] ?? 'Chưa có email').toString();
    final role = _getRole(user);
    final locked = _isLocked(user);
    final avatarUrl = (user['anh_dai_dien'] ?? user['avatar_url'] ?? '')
        .toString()
        .trim();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: locked ? Colors.red.shade200 : const Color(0xFFE6E8F8),
        ),
        boxShadow: [
          BoxShadow(
            color: primaryPurple.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            CircleAvatar(
              radius: 25,
              backgroundColor: const Color(0xFFECEEFF),
              backgroundImage:
                  avatarUrl.isNotEmpty ? NetworkImage(avatarUrl) : null,
              child: avatarUrl.isEmpty
                  ? Text(
                      name.isNotEmpty ? name[0].toUpperCase() : 'U',
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 18,
                        color: primaryPurple,
                      ),
                    )
                  : null,
            ),
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
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: darkText,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      _buildRoleBadge(role),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    email,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12.5,
                      color: Color(0xFF6B708D),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        locked
                            ? Icons.lock_rounded
                            : Icons.check_circle_rounded,
                        size: 14,
                        color: locked ? Colors.red : const Color(0xFF2E9E5B),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        locked ? 'Đang bị khóa' : 'Đang hoạt động',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: locked ? Colors.red : const Color(0xFF2E9E5B),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (role != 'super_admin')
              PopupMenuButton<core.String>(
                icon: const Icon(
                  Icons.more_vert_rounded,
                  color: Color(0xFF4A4E69),
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                onSelected: (action) {
                  if (action == 'toggle_lock') {
                    _toggleLockUser(user);
                  } else if (action == 'make_admin') {
                    _changeUserRole(user, 'admin');
                  } else if (action == 'make_user') {
                    _changeUserRole(user, 'user');
                  }
                },
                itemBuilder: (_) => [
                  PopupMenuItem(
                    value: 'toggle_lock',
                    child: Row(
                      children: [
                        Icon(
                          locked
                              ? Icons.lock_open_rounded
                              : Icons.lock_outline_rounded,
                          size: 18,
                          color: locked ? Colors.green : Colors.red,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          locked ? 'Mở khóa tài khoản' : 'Khóa tài khoản',
                          style: TextStyle(
                            color: locked ? Colors.green : Colors.red,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_isSuperAdmin && role == 'user')
                    const PopupMenuItem(
                      value: 'make_admin',
                      child: Row(
                        children: [
                          Icon(
                            Icons.admin_panel_settings_outlined,
                            size: 18,
                            color: primaryPurple,
                          ),
                          SizedBox(width: 8),
                          Text(
                            'Cấp quyền Admin',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                  if (_isSuperAdmin && role == 'admin')
                    const PopupMenuItem(
                      value: 'make_user',
                      child: Row(
                        children: [
                          Icon(
                            Icons.person_outline_rounded,
                            size: 18,
                            color: Colors.orange,
                          ),
                          SizedBox(width: 8),
                          Text(
                            'Hạ xuống User',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;
    final filtered = _filteredUsers;

    return Scaffold(
      backgroundColor: bgLight,
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: EdgeInsets.fromLTRB(16, topPadding + 10, 16, 16),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [primaryPurple, darkPurple],
              ),
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(26)),
            ),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760),
                child: Column(
                  children: [
                    Row(
                      children: [
                        InkWell(
                          onTap: () => Navigator.pop(context),
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.16),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.arrow_back_rounded,
                              color: Colors.white,
                              size: 22,
                            ),
                          ),
                        ),
                        const Expanded(
                          child: Text(
                            'Quản lí người dùng',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 19,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        InkWell(
                          onTap: () {
                            setState(() {
                              _showSearchBar = !_showSearchBar;
                              if (!_showSearchBar) {
                                _searchController.clear();
                                _searchQuery = '';
                              }
                            });
                          },
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.16),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              _showSearchBar
                                  ? Icons.close_rounded
                                  : Icons.search_rounded,
                              color: Colors.white,
                              size: 22,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (_showSearchBar) ...[
                      const SizedBox(height: 12),
                      TextField(
                        controller: _searchController,
                        autofocus: true,
                        onChanged: (v) => setState(() => _searchQuery = v),
                        style: const TextStyle(fontSize: 14, color: darkText),
                        decoration: InputDecoration(
                          hintText: 'Tìm theo tên hoặc email...',
                          prefixIcon: const Icon(
                            Icons.search_rounded,
                            color: primaryPurple,
                          ),
                          filled: true,
                          fillColor: Colors.white,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),

          // Bộ lọc vai trò
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: Row(
                  children: [
                    Wrap(
                      spacing: 8,
                      children: [
                        {'key': 'all', 'label': 'Tất cả'},
                        {'key': 'user', 'label': 'User'},
                        {'key': 'admin', 'label': 'Admin'},
                      ].map((item) {
                        final key = item['key']!;
                        final selected = _roleFilter == key;
                        return ChoiceChip(
                          label: Text(item['label']!),
                          selected: selected,
                          selectedColor: primaryPurple,
                          labelStyle: TextStyle(
                            color: selected ? Colors.white : darkText,
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                          onSelected: (_) => setState(() => _roleFilter = key),
                        );
                      }).toList(),
                    ),
                    const Spacer(),
                    Text(
                      '${filtered.length} tài khoản',
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF6B708D),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          Expanded(
            child: _isLoading
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
                              const Icon(
                                Icons.error_outline_rounded,
                                color: Colors.red,
                                size: 48,
                              ),
                              const SizedBox(height: 10),
                              Text(
                                _errorMessage!,
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 14),
                              ElevatedButton(
                                onPressed: _loadUsers,
                                child: const Text('Thử lại'),
                              ),
                            ],
                          ),
                        ),
                      )
                    : Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 760),
                          child: filtered.isEmpty
                              ? const Center(
                                  child: Text(
                                    'Không tìm thấy người dùng nào.',
                                    style: TextStyle(color: Colors.grey),
                                  ),
                                )
                              : RefreshIndicator(
                                  onRefresh: _loadUsers,
                                  color: primaryPurple,
                                  child: ListView.builder(
                                    padding: const EdgeInsets.fromLTRB(
                                      16,
                                      8,
                                      16,
                                      24,
                                    ),
                                    itemCount: filtered.length,
                                    itemBuilder: (_, idx) =>
                                        _buildUserCard(filtered[idx]),
                                  ),
                                ),
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}