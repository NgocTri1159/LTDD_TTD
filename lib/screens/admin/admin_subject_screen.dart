import 'package:material_ui/material_ui.dart';

import '../../models/subject_model.dart';
import '../../services/role_service.dart';
import '../../services/subject_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common/app_card.dart';
import '../../widgets/common/app_confirm_dialog.dart';
import '../../widgets/common/empty_state_widget.dart';
import '../../widgets/common/error_state_widget.dart';
import '../../widgets/common/loading_widget.dart';
import 'subject_form_screen.dart';

class AdminSubjectScreen extends StatefulWidget {
  const AdminSubjectScreen({super.key});

  @override
  State<AdminSubjectScreen> createState() => _AdminSubjectScreenState();
}

class _AdminSubjectScreenState extends State<AdminSubjectScreen> {
  final TextEditingController _searchController = TextEditingController();

  late Future<List<SubjectModel>> _subjectsFuture;
  String _searchQuery = '';
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _subjectsFuture = SubjectService.getAllSubjects();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _loadSubjects() {
    if (!mounted) return;
    setState(() {
      _subjectsFuture = SubjectService.getAllSubjects();
    });
  }

  Color _getSubjectColor(String? colorValue) {
    if (colorValue == null || colorValue.trim().isEmpty) {
      return AppTheme.primary;
    }
    try {
      String hex = colorValue.trim().replaceAll('#', '');
      if (hex.length == 6) {
        hex = 'FF$hex';
      }
      if (hex.length != 8) {
        return AppTheme.primary;
      }
      return Color(int.parse(hex, radix: 16));
    } catch (_) {
      return AppTheme.primary;
    }
  }

  Widget _buildSubjectIcon(SubjectModel subject, Color color) {
    final symbol = subject.bieuTuong?.trim();
    if (symbol != null && symbol.isNotEmpty) {
      if (symbol.characters.length <= 2) {
        return Text(
          symbol,
          style: const TextStyle(fontSize: 24),
          textAlign: TextAlign.center,
        );
      }
    }
    return Icon(
      Icons.menu_book_rounded,
      color: color,
      size: 26,
    );
  }

  List<SubjectModel> _filterSubjects(List<SubjectModel> subjects) {
    if (_searchQuery.trim().isEmpty) {
      return subjects;
    }
    final query = _searchQuery.trim().toLowerCase();
    return subjects.where((s) {
      final name = s.tenMon.toLowerCase();
      final desc = (s.moTa ?? '').toLowerCase();
      return name.contains(query) || desc.contains(query);
    }).toList();
  }

  Future<void> _openAddSubject() async {
    final role = await RoleService.getCurrentRole();
    if (role != 'admin' && role != 'super_admin') {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Bạn không có quyền quản lý môn học.'),
          backgroundColor: AppTheme.error,
        ),
      );
      return;
    }

    if (!mounted) return;
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const SubjectFormScreen()),
    );

    if (result == true && mounted) {
      _loadSubjects();
    }
  }

  Future<void> _openEditSubject(SubjectModel subject) async {
    final role = await RoleService.getCurrentRole();
    if (role != 'admin' && role != 'super_admin') {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Bạn không có quyền quản lý môn học.'),
          backgroundColor: AppTheme.error,
        ),
      );
      return;
    }

    if (!mounted) return;
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => SubjectFormScreen(subject: subject)),
    );

    if (result == true && mounted) {
      _loadSubjects();
    }
  }

  Future<void> _toggleSubjectStatus(SubjectModel subject) async {
    if (_isProcessing) return;

    final willLock = subject.trangThai;
    final confirmed = await AppConfirmDialog.show(
      context,
      title: willLock ? 'Khóa môn học' : 'Mở khóa môn học',
      message: willLock
          ? 'Bạn có chắc chắn muốn khóa môn học "${subject.tenMon}"? Môn học này sẽ bị ẩn đối với toàn bộ học viên.'
          : 'Bạn có chắc chắn muốn mở khóa môn học "${subject.tenMon}"? Học viên sẽ nhìn thấy và làm bài kiểm tra.',
      confirmText: willLock ? 'Khóa môn học' : 'Mở khóa',
      isDanger: willLock,
      icon: willLock ? Icons.lock_outline_rounded : Icons.lock_open_rounded,
    );

    if (confirmed != true || !mounted) return;

    setState(() => _isProcessing = true);

    try {
      await SubjectService.updateSubjectStatus(subject.id, !subject.trangThai);
      if (!mounted) return;
      _loadSubjects();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            willLock
                ? 'Đã khóa môn học "${subject.tenMon}".'
                : 'Đã mở khóa môn học "${subject.tenMon}".',
          ),
          backgroundColor: AppTheme.success,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Lỗi cập nhật: $e'),
          backgroundColor: AppTheme.error,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  Widget _buildSubjectCard(SubjectModel subject) {
    final color = _getSubjectColor(subject.mauSac);

    return AppCard(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Icon môn học
              Container(
                width: 48,
                height: 48,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: color.withAlpha(28),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: color.withAlpha(50)),
                ),
                child: _buildSubjectIcon(subject, color),
              ),
              const SizedBox(width: 14),

              // Thông tin môn học
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      subject.tenMon,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subject.moTa?.trim().isNotEmpty == true
                          ? subject.moTa!
                          : 'Chưa có mô tả cho môn học này.',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppTheme.textSecondary,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Badges: Thứ tự và Trạng thái
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        // Badge Thứ tự
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryContainer,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.sort_rounded,
                                size: 12,
                                color: AppTheme.primary,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Thứ tự: ${subject.thuTuHienThi}',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.primary,
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Badge Trạng thái
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: subject.trangThai
                                ? AppTheme.successContainer
                                : AppTheme.errorContainer,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                subject.trangThai
                                    ? Icons.check_circle_rounded
                                    : Icons.lock_rounded,
                                size: 12,
                                color: subject.trangThai
                                    ? AppTheme.success
                                    : AppTheme.error,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                subject.trangThai
                                    ? 'Đang hoạt động'
                                    : 'Đã khóa',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: subject.trangThai
                                      ? AppTheme.success
                                      : AppTheme.error,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),
          const Divider(height: 1, color: AppTheme.cardBorder),
          const SizedBox(height: 8),

          // Nút hành động
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              // Nút chỉnh sửa
              TextButton.icon(
                onPressed: _isProcessing
                    ? null
                    : () => _openEditSubject(subject),
                icon: const Icon(Icons.edit_outlined, size: 16),
                label: const Text('Chỉnh sửa'),
                style: TextButton.styleFrom(
                  foregroundColor: AppTheme.primary,
                  textStyle: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // Nút khóa / mở khóa
              TextButton.icon(
                onPressed: _isProcessing
                    ? null
                    : () => _toggleSubjectStatus(subject),
                icon: Icon(
                  subject.trangThai
                      ? Icons.lock_outline_rounded
                      : Icons.lock_open_rounded,
                  size: 16,
                ),
                label: Text(subject.trangThai ? 'Khóa môn' : 'Mở khóa'),
                style: TextButton.styleFrom(
                  foregroundColor:
                      subject.trangThai ? AppTheme.error : AppTheme.success,
                  textStyle: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text(
          'Quản lý môn học',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            tooltip: 'Tải lại',
            onPressed: _loadSubjects,
            icon: const Icon(Icons.refresh_rounded),
          ),
          IconButton(
            tooltip: 'Thêm môn học',
            onPressed: _openAddSubject,
            icon: const Icon(Icons.add_circle_outline_rounded),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openAddSubject,
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text(
          'Thêm môn học',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1000),
          child: Column(
            children: [
              // Thanh tìm kiếm
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: TextField(
                  controller: _searchController,
                  onChanged: (val) {
                    setState(() => _searchQuery = val);
                  },
                  decoration: InputDecoration(
                    hintText: 'Tìm kiếm theo tên môn học hoặc mô tả...',
                    prefixIcon: const Icon(
                      Icons.search_rounded,
                      color: AppTheme.primary,
                    ),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.close_rounded),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _searchQuery = '');
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(
                      vertical: 14,
                      horizontal: 16,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),

              // Danh sách môn học
              Expanded(
                child: FutureBuilder<List<SubjectModel>>(
                  future: _subjectsFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const LoadingWidget(
                        message: 'Đang tải danh sách môn học...',
                      );
                    }

                    if (snapshot.hasError) {
                      return RefreshIndicator(
                        onRefresh: () async => _loadSubjects(),
                        color: AppTheme.primary,
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            return SingleChildScrollView(
                              physics: const AlwaysScrollableScrollPhysics(),
                              child: ConstrainedBox(
                                constraints: BoxConstraints(
                                  minHeight: constraints.maxHeight,
                                ),
                                child: ErrorStateWidget(
                                  errorMessage: snapshot.error.toString(),
                                  onRetry: _loadSubjects,
                                ),
                              ),
                            );
                          },
                        ),
                      );
                    }

                    final subjects = snapshot.data ?? [];
                    final filtered = _filterSubjects(subjects);

                    if (filtered.isEmpty) {
                      return RefreshIndicator(
                        onRefresh: () async => _loadSubjects(),
                        color: AppTheme.primary,
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            return SingleChildScrollView(
                              physics: const AlwaysScrollableScrollPhysics(),
                              child: ConstrainedBox(
                                constraints: BoxConstraints(
                                  minHeight: constraints.maxHeight,
                                ),
                                child: EmptyStateWidget(
                                  icon: Icons.menu_book_rounded,
                                  title: _searchQuery.isEmpty
                                      ? 'Chưa có môn học nào'
                                      : 'Không tìm thấy môn học',
                                  message: _searchQuery.isEmpty
                                      ? 'Hãy nhấn "Thêm môn học" để tạo môn học đầu tiên cho hệ thống.'
                                      : 'Không tìm thấy môn học khớp với từ khóa "$_searchQuery".',
                                  actionText: _searchQuery.isNotEmpty
                                      ? 'Xóa tìm kiếm'
                                      : 'Thêm môn học ngay',
                                  onAction: _searchQuery.isNotEmpty
                                      ? () {
                                          _searchController.clear();
                                          setState(() => _searchQuery = '');
                                        }
                                      : _openAddSubject,
                                ),
                              ),
                            );
                          },
                        ),
                      );
                    }

                    return RefreshIndicator(
                      onRefresh: () async => _loadSubjects(),
                      color: AppTheme.primary,
                      child: ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
                        physics: const AlwaysScrollableScrollPhysics(),
                        itemCount: filtered.length,
                        itemBuilder: (context, index) {
                          return _buildSubjectCard(filtered[index]);
                        },
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
