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
  String _statusFilter = 'all'; // 'all', 'active', 'locked'
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
          style: const TextStyle(fontSize: 26),
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
    return subjects.where((s) {
      if (_statusFilter == 'active' && !s.trangThai) return false;
      if (_statusFilter == 'locked' && s.trangThai) return false;

      if (_searchQuery.trim().isEmpty) return true;
      final query = _searchQuery.trim().toLowerCase();
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

  Widget _buildSummaryBar(List<SubjectModel> subjects) {
    final total = subjects.length;
    final activeCount = subjects.where((s) => s.trangThai).length;
    final lockedCount = total - activeCount;

    Widget statPill({
      required String label,
      required int count,
      required String filterKey,
      required Color color,
    }) {
      final isSelected = _statusFilter == filterKey;
      return Expanded(
        child: InkWell(
          onTap: () => setState(() => _statusFilter = filterKey),
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
            decoration: BoxDecoration(
              color: isSelected ? color : Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isSelected ? color : AppTheme.cardBorder,
              ),
              boxShadow: [
                if (isSelected)
                  BoxShadow(
                    color: color.withValues(alpha: 0.25),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
              ],
            ),
            child: Column(
              children: [
                Text(
                  '$count',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                    color: isSelected ? Colors.white : color,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: isSelected
                        ? Colors.white.withValues(alpha: 0.92)
                        : AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
      child: Row(
        children: [
          statPill(
            label: 'Tất cả môn',
            count: total,
            filterKey: 'all',
            color: AppTheme.primary,
          ),
          const SizedBox(width: 10),
          statPill(
            label: 'Đang hoạt động',
            count: activeCount,
            filterKey: 'active',
            color: AppTheme.success,
          ),
          const SizedBox(width: 10),
          statPill(
            label: 'Đã khóa',
            count: lockedCount,
            filterKey: 'locked',
            color: AppTheme.error,
          ),
        ],
      ),
    );
  }

  Widget _buildSubjectCard(SubjectModel subject) {
    final color = _getSubjectColor(subject.mauSac);

    return AppCard(
      margin: const EdgeInsets.only(bottom: 12),
      padding: EdgeInsets.zero,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            border: Border(
              left: BorderSide(color: color, width: 5),
            ),
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Icon môn học
                  Container(
                    width: 52,
                    height: 52,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: color.withAlpha(28),
                      borderRadius: BorderRadius.circular(15),
                      border: Border.all(color: color.withAlpha(60)),
                    ),
                    child: _buildSubjectIcon(subject, color),
                  ),
                  const SizedBox(width: 14),

                  // Thông tin môn học
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                subject.tenMon,
                                style: const TextStyle(
                                  fontSize: 16.5,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.textPrimary,
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 9,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: subject.trangThai
                                    ? AppTheme.successContainer
                                    : AppTheme.errorContainer,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    subject.trangThai
                                        ? Icons.check_circle_rounded
                                        : Icons.lock_rounded,
                                    size: 13,
                                    color: subject.trangThai
                                        ? AppTheme.success
                                        : AppTheme.error,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    subject.trangThai
                                        ? 'Hoạt động'
                                        : 'Đã khóa',
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w700,
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
                        const SizedBox(height: 5),
                        Text(
                          subject.moTa?.trim().isNotEmpty == true
                              ? subject.moTa!
                              : 'Chưa có mô tả cho môn học này.',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppTheme.textSecondary,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 9,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.background,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppTheme.cardBorder),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.sort_rounded,
                                size: 13,
                                color: AppTheme.primary,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Thứ tự hiển thị: ${subject.thuTuHienThi}',
                                style: const TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.textSecondary,
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

              const SizedBox(height: 14),
              const Divider(height: 1, color: AppTheme.cardBorder),
              const SizedBox(height: 10),

              // Nút hành động
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton.icon(
                    onPressed: _isProcessing
                        ? null
                        : () => _openEditSubject(subject),
                    icon: const Icon(Icons.edit_outlined, size: 16),
                    label: const Text('Chỉnh sửa'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.primary,
                      side: BorderSide(
                        color: AppTheme.primary.withValues(alpha: 0.4),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      textStyle: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
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
                      backgroundColor: (subject.trangThai
                              ? AppTheme.error
                              : AppTheme.success)
                          .withValues(alpha: 0.08),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
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
        ),
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
        elevation: 0,
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
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
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
                      borderSide: const BorderSide(color: AppTheme.cardBorder),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: AppTheme.cardBorder),
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

                    return Column(
                      children: [
                        if (subjects.isNotEmpty) _buildSummaryBar(subjects),
                        Expanded(
                          child: filtered.isEmpty
                              ? RefreshIndicator(
                                  onRefresh: () async => _loadSubjects(),
                                  color: AppTheme.primary,
                                  child: LayoutBuilder(
                                    builder: (context, constraints) {
                                      return SingleChildScrollView(
                                        physics:
                                            const AlwaysScrollableScrollPhysics(),
                                        child: ConstrainedBox(
                                          constraints: BoxConstraints(
                                            minHeight: constraints.maxHeight,
                                          ),
                                          child: EmptyStateWidget(
                                            icon: Icons.menu_book_rounded,
                                            title: _searchQuery.isEmpty &&
                                                    _statusFilter == 'all'
                                                ? 'Chưa có môn học nào'
                                                : 'Không tìm thấy môn học',
                                            message: _searchQuery.isEmpty &&
                                                    _statusFilter == 'all'
                                                ? 'Hãy nhấn "Thêm môn học" để tạo môn học đầu tiên cho hệ thống.'
                                                : 'Không có môn học nào khớp với điều kiện lọc hiện tại.',
                                            actionText: _searchQuery.isNotEmpty ||
                                                    _statusFilter != 'all'
                                                ? 'Xóa bộ lọc'
                                                : 'Thêm môn học ngay',
                                            onAction: _searchQuery.isNotEmpty ||
                                                    _statusFilter != 'all'
                                                ? () {
                                                    _searchController.clear();
                                                    setState(() {
                                                      _searchQuery = '';
                                                      _statusFilter = 'all';
                                                    });
                                                  }
                                                : _openAddSubject,
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                )
                              : RefreshIndicator(
                                  onRefresh: () async => _loadSubjects(),
                                  color: AppTheme.primary,
                                  child: ListView.builder(
                                    padding: const EdgeInsets.fromLTRB(
                                      16,
                                      8,
                                      16,
                                      84,
                                    ),
                                    physics:
                                        const AlwaysScrollableScrollPhysics(),
                                    itemCount: filtered.length,
                                    itemBuilder: (context, index) {
                                      return _buildSubjectCard(filtered[index]);
                                    },
                                  ),
                                ),
                        ),
                      ],
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