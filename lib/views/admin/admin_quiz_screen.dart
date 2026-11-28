import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/theme.dart';

typedef AdminRow = Map<String, dynamic>;

/// ============================================================================
/// 1. MÀN HÌNH QUẢN LÍ BỘ ĐỀ
/// ============================================================================
class AdminQuizScreen extends StatefulWidget {
  const AdminQuizScreen({super.key});

  @override
  State<AdminQuizScreen> createState() => _AdminQuizScreenState();
}

class _AdminQuizScreenState extends State<AdminQuizScreen> {
  final _supabase = Supabase.instance.client;
  final _searchController = TextEditingController();

  static const Color _brandBlue = Color(0xFF3B5BFD);
  static const Color _brandPurple = Color(0xFF7C3AED);

  List<AdminRow> _quizzes = [];
  List<AdminRow> _subjects = [];
  Map<String, String> _subjectNames = {};
  Map<String, int> _questionCounts = {};
  Map<String, int> _quizCountBySubject = {};

  bool _isLoading = true;
  bool _hasLoadedOnce = false;
  String _searchQuery = '';
  String? _selectedSubjectFilter;

  static const List<(Color, Color)> _subjectPalettes = [
    (Color(0xFF3B5BFD), Color(0xFF60A5FA)), // Xanh dương
    (Color(0xFF7C3AED), Color(0xFFA78BFA)), // Tím
    (Color(0xFF059669), Color(0xFF34D399)), // Xanh ngọc
    (Color(0xFFD97706), Color(0xFFFBBF24)), // Vàng cam
    (Color(0xFF0891B2), Color(0xFF22D3EE)), // Cyan
    (Color(0xFFDB2777), Color(0xFFF472B6)), // Hồng
    (Color(0xFF4F46E5), Color(0xFF818CF8)), // Chàm
    (Color(0xFF0D9488), Color(0xFF2DD4BF)), // Teal
  ];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    if (mounted) setState(() => _isLoading = true);
    try {
      final dynamic subRows =
          await _supabase.from('mon_hoc').select('*').order('ten_mon');
      final subjects = <AdminRow>[];
      final nameMap = <String, String>{};
      if (subRows is Iterable) {
        for (final s in subRows) {
          if (s is Map) {
            final row = Map<String, dynamic>.from(s);
            subjects.add(row);
            nameMap[row['id'].toString()] =
                (row['ten_mon'] ?? 'Tổng hợp').toString();
          }
        }
      }

      dynamic quizRows;
      try {
        quizRows = await _supabase
            .from('de_thi')
            .select('*')
            .order('created_at', ascending: false);
      } catch (_) {
        quizRows = await _supabase.from('de_thi').select('*');
      }

      final quizzes = <AdminRow>[];
      final bySubject = <String, int>{};
      if (quizRows is Iterable) {
        for (final q in quizRows) {
          if (q is Map) {
            final row = Map<String, dynamic>.from(q);
            quizzes.add(row);
            final subId = (row['mon_hoc_id'] ?? '').toString();
            if (subId.isNotEmpty) {
              bySubject[subId] = (bySubject[subId] ?? 0) + 1;
            }
          }
        }
      }

      final counts = <String, int>{};
      try {
        final dynamic linkRows =
            await _supabase.from('de_thi_cau_hoi').select('de_thi_id');
        if (linkRows is Iterable) {
          for (final l in linkRows) {
            if (l is Map && l['de_thi_id'] != null) {
              final id = l['de_thi_id'].toString();
              counts[id] = (counts[id] ?? 0) + 1;
            }
          }
        }
      } catch (_) {}

      if (counts.isEmpty) {
        try {
          final dynamic directRows =
              await _supabase.from('cau_hoi').select('de_thi_id');
          if (directRows is Iterable) {
            for (final c in directRows) {
              if (c is Map && c['de_thi_id'] != null) {
                final id = c['de_thi_id'].toString();
                counts[id] = (counts[id] ?? 0) + 1;
              }
            }
          }
        } catch (_) {}
      }

      if (!mounted) return;
      setState(() {
        _subjects = subjects;
        _subjectNames = nameMap;
        _quizzes = quizzes;
        _questionCounts = counts;
        _quizCountBySubject = bySubject;
        _isLoading = false;
        _hasLoadedOnce = true;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _hasLoadedOnce = true;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Lỗi tải bộ đề: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  List<AdminRow> get _filteredQuizzes {
    return _quizzes.where((q) {
      final title = (q['tieu_de'] ?? '').toString().toLowerCase();
      final subId = (q['mon_hoc_id'] ?? '').toString();
      final matchQuery = _searchQuery.trim().isEmpty ||
          title.contains(_searchQuery.trim().toLowerCase());
      final matchSubject =
          _selectedSubjectFilter == null || subId == _selectedSubjectFilter;
      return matchQuery && matchSubject;
    }).toList();
  }

  int get _totalQuestions {
    int total = 0;
    for (final q in _quizzes) {
      total += _questionCounts[q['id'].toString()] ?? 0;
    }
    return total;
  }

  (Color, Color) _paletteForSubject(String subjectId, String subjectName) {
    final idx = _subjects.indexWhere((s) => s['id'].toString() == subjectId);
    if (idx >= 0) {
      return _subjectPalettes[idx % _subjectPalettes.length];
    }
    return _subjectPalettes[
        subjectName.hashCode.abs() % _subjectPalettes.length];
  }

  IconData _iconForSubject(String subjectName) {
    final lower = subjectName.toLowerCase();
    if (lower.contains('toán')) return Icons.calculate_rounded;
    if (lower.contains('văn')) return Icons.auto_stories_rounded;
    if (lower.contains('anh') || lower.contains('ngoại ngữ')) {
      return Icons.language_rounded;
    }
    if (lower.contains('địa')) return Icons.public_rounded;
    if (lower.contains('lý')) return Icons.bolt_rounded;
    if (lower.contains('hóa')) return Icons.science_rounded;
    if (lower.contains('sinh')) return Icons.biotech_rounded;
    if (lower.contains('sử')) return Icons.account_balance_rounded;
    if (lower.contains('tin')) return Icons.computer_rounded;
    return Icons.quiz_rounded;
  }

  Widget _buildQuizThumbnail({
    required String imageUrl,
    required String subjectName,
    required Color primaryColor,
    required Color secondaryColor,
    double size = 66,
  }) {
    if (imageUrl.startsWith('data:image')) {
      try {
        final bytes = base64Decode(imageUrl.split(',').last);
        return ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Image.memory(
            bytes,
            width: size,
            height: size,
            fit: BoxFit.cover,
          ),
        );
      } catch (_) {}
    } else if (imageUrl.startsWith('http')) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Image.network(
          imageUrl,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => _buildGradientIcon(
            subjectName: subjectName,
            primaryColor: primaryColor,
            secondaryColor: secondaryColor,
            size: size,
          ),
        ),
      );
    }

    return _buildGradientIcon(
      subjectName: subjectName,
      primaryColor: primaryColor,
      secondaryColor: secondaryColor,
      size: size,
    );
  }

  Widget _buildGradientIcon({
    required String subjectName,
    required Color primaryColor,
    required Color secondaryColor,
    required double size,
  }) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [primaryColor, secondaryColor],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withValues(alpha: 0.28),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Icon(
        _iconForSubject(subjectName),
        color: Colors.white,
        size: 28,
      ),
    );
  }

  Future<void> _deleteQuiz(AdminRow quiz) async {
    final title = (quiz['tieu_de'] ?? 'bộ đề này').toString();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Xác nhận xóa',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        content: Text('Bạn có chắc muốn xóa bộ đề "$title"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'Hủy',
              style: TextStyle(color: Colors.grey.shade700),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Xóa',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await _supabase.from('de_thi').delete().eq('id', quiz['id']);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Đã xóa bộ đề "$title"'),
          backgroundColor: const Color(0xFF059669),
        ),
      );
      _loadData();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Không thể xóa bộ đề: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  Future<void> _openQuizDetail([AdminRow? quiz]) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AdminQuizDetailScreen(
          quiz: quiz,
          subjects: _subjects,
        ),
      ),
    );
    _loadData();
  }

  Widget _buildHeaderAndSearch(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;

    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: EdgeInsets.fromLTRB(16, topPadding + 14, 16, 44),
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [_brandBlue, AppColors.base, _brandPurple],
            ),
            borderRadius: BorderRadius.vertical(
              bottom: Radius.circular(30),
            ),
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 648),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned(
                    right: -20,
                    top: -24,
                    child: Container(
                      width: 126,
                      height: 126,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: 0.08),
                      ),
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          _buildHeaderIconButton(
                            tooltip: 'Quay lại',
                            onTap: () => Navigator.pop(context),
                            child: const Icon(
                              Icons.arrow_back_rounded,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'KHO HỌC LIỆU',
                                  style: TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.9,
                                    color: Colors.white.withValues(alpha: 0.8),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Quản lí bộ đề',
                                  style: AppTextStyles.question.copyWith(
                                    fontSize: 21,
                                    fontWeight: FontWeight.w900,
                                    color: Colors.white,
                                    letterSpacing: -0.3,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          _buildHeaderIconButton(
                            tooltip: 'Làm mới',
                            onTap: _isLoading ? null : _loadData,
                            child: _isLoading
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(
                                    Icons.refresh_rounded,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: _buildHeaderStat(
                              icon: Icons.layers_rounded,
                              label: 'Bộ đề',
                              value: '${_quizzes.length}',
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _buildHeaderStat(
                              icon: Icons.help_outline_rounded,
                              label: 'Câu hỏi',
                              value: '$_totalQuestions',
                              highlightColor: const Color(0xFFFDE68A),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _buildHeaderStat(
                              icon: Icons.bookmarks_rounded,
                              label: 'Môn học',
                              value: '${_subjects.length}',
                              highlightColor: const Color(0xFF6EE7B7),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),

        // Thanh tìm kiếm nổi chồng nhẹ lên mép dưới Header
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: Transform.translate(
              offset: const Offset(0, -24),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF0F172A).withValues(alpha: 0.06),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: TextField(
                    controller: _searchController,
                    onChanged: (v) => setState(() => _searchQuery = v),
                    style: AppTextStyles.text.copyWith(
                      color: AppColors.text,
                      fontSize: 14,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Tìm kiếm theo tên bộ đề...',
                      hintStyle: TextStyle(
                        color: Colors.grey.shade400,
                        fontSize: 13.8,
                      ),
                      prefixIcon: Icon(
                        Icons.search_rounded,
                        color: AppColors.base.withValues(alpha: 0.8),
                        size: 21,
                      ),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: Icon(
                                Icons.close_rounded,
                                size: 19,
                                color: Colors.grey.shade500,
                              ),
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _searchQuery = '');
                              },
                            )
                          : null,
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 14,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHeaderIconButton({
    required String tooltip,
    required VoidCallback? onTap,
    required Widget child,
  }) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            width: 42,
            height: 42,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.28),
              ),
            ),
            child: child,
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderStat({
    required IconData icon,
    required String label,
    required String value,
    Color? highlightColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              icon,
              size: 16,
              color: highlightColor ?? Colors.white,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                    color: Colors.white.withValues(alpha: 0.85),
                  ),
                ),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 16.5,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    height: 1.15,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    final hasFilter =
        _searchQuery.trim().isNotEmpty || _selectedSubjectFilter != null;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 34),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 66,
            height: 66,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  _brandBlue.withValues(alpha: 0.14),
                  _brandPurple.withValues(alpha: 0.14),
                ],
              ),
              shape: BoxShape.circle,
            ),
            child: Icon(
              hasFilter ? Icons.search_off_rounded : Icons.assignment_outlined,
              size: 32,
              color: AppColors.base,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            hasFilter ? 'Không tìm thấy bộ đề phù hợp' : 'Chưa có bộ đề nào',
            style: AppTextStyles.question.copyWith(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: AppColors.text,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            hasFilter
                ? 'Thử đổi từ khóa tìm kiếm hoặc chọn môn học khác.'
                : 'Tạo bộ đề đầu tiên để bắt đầu thêm câu hỏi trắc nghiệm.',
            textAlign: TextAlign.center,
            style: AppTextStyles.text.copyWith(
              color: Colors.grey.shade600,
              fontSize: 13.5,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.base,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            onPressed: () {
              if (hasFilter) {
                _searchController.clear();
                setState(() {
                  _searchQuery = '';
                  _selectedSubjectFilter = null;
                });
              } else {
                _openQuizDetail();
              }
            },
            icon: Icon(
              hasFilter ? Icons.restart_alt_rounded : Icons.add_rounded,
              size: 18,
            ),
            label: Text(
              hasFilter ? 'Xóa bộ lọc' : 'Tạo bộ đề mới',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final quizzes = _filteredQuizzes;

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5FB),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.base,
        foregroundColor: Colors.white,
        elevation: 3,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        onPressed: () => _openQuizDetail(),
        icon: const Icon(Icons.add_rounded, size: 22),
        label: const Text(
          'Tạo bộ đề',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
        ),
      ),
      body: !_hasLoadedOnce && _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.base),
            )
          : RefreshIndicator(
              color: AppColors.base,
              onRefresh: _loadData,
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverToBoxAdapter(
                    child: _buildHeaderAndSearch(context),
                  ),

                  // Thanh chip lọc nhanh theo môn học
                  SliverToBoxAdapter(
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 680),
                        child: SizedBox(
                          height: 42,
                          child: ListView(
                            scrollDirection: Axis.horizontal,
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            children: [
                              _buildSubjectFilterChip(
                                label: 'Tất cả',
                                count: _quizzes.length,
                                isSelected: _selectedSubjectFilter == null,
                                primaryColor: AppColors.base,
                                secondaryColor: _brandPurple,
                                onTap: () => setState(
                                    () => _selectedSubjectFilter = null),
                              ),
                              ..._subjects.asMap().entries.map((entry) {
                                final idx = entry.key;
                                final sub = entry.value;
                                final id = sub['id'].toString();
                                final name = (sub['ten_mon'] ?? '').toString();
                                final (c1, c2) = _subjectPalettes[
                                    idx % _subjectPalettes.length];
                                final count = _quizCountBySubject[id] ?? 0;

                                return Padding(
                                  padding: const EdgeInsets.only(left: 8),
                                  child: _buildSubjectFilterChip(
                                    label: name,
                                    count: count,
                                    isSelected: _selectedSubjectFilter == id,
                                    primaryColor: c1,
                                    secondaryColor: c2,
                                    onTap: () => setState(() {
                                      _selectedSubjectFilter =
                                          _selectedSubjectFilter == id
                                              ? null
                                              : id;
                                    }),
                                  ),
                                );
                              }),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),

                  // Tiêu đề danh sách
                  SliverToBoxAdapter(
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 680),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
                          child: Row(
                            children: [
                              Container(
                                width: 4,
                                height: 17,
                                decoration: BoxDecoration(
                                  color: AppColors.base,
                                  borderRadius: BorderRadius.circular(99),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Danh sách bộ đề',
                                style: AppTextStyles.question.copyWith(
                                  fontSize: 15.5,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.text,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.base.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(99),
                                ),
                                child: Text(
                                  '${quizzes.length}',
                                  style: AppTextStyles.text.copyWith(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.base,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),

                  // Danh sách bộ đề
                  if (quizzes.isEmpty)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 680),
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
                            child: _buildEmptyState(),
                          ),
                        ),
                      ),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 2, 16, 100),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) => Center(
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 648),
                              child: _buildQuizCard(quizzes[index]),
                            ),
                          ),
                          childCount: quizzes.length,
                        ),
                      ),
                    ),
                ],
              ),
            ),
    );
  }

  Widget _buildQuizCard(AdminRow quiz) {
    final id = quiz['id'].toString();
    final subjectId = (quiz['mon_hoc_id'] ?? '').toString();
    final title = (quiz['tieu_de'] ?? 'Bộ đề trắc nghiệm').toString();
    final subjectName = _subjectNames[subjectId] ?? 'Tổng hợp';
    final count = _questionCounts[id] ?? 0;
    final creator = (quiz['nguoi_tao'] ?? 'Admin').toString();
    final minutes = (quiz['thoi_gian_phut'] as num?)?.toInt() ?? 15;
    final imageUrl = (quiz['hinh_anh_url'] ?? '').toString();
    final (primaryColor, secondaryColor) =
        _paletteForSubject(subjectId, subjectName);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: primaryColor.withValues(alpha: 0.2),
          width: 1.1,
        ),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withValues(alpha: 0.08),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(19),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => _openQuizDetail(quiz),
            splashColor: primaryColor.withValues(alpha: 0.1),
            highlightColor: primaryColor.withValues(alpha: 0.04),
            child: Stack(
              children: [
                // Dải màu gradient nhấn trên đỉnh thẻ
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    height: 3.5,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [primaryColor, secondaryColor],
                      ),
                    ),
                  ),
                ),

                // Họa tiết icon chìm góc phải
                Positioned(
                  right: -10,
                  bottom: 24,
                  child: Icon(
                    _iconForSubject(subjectName),
                    size: 68,
                    color: primaryColor.withValues(alpha: 0.045),
                  ),
                ),

                Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(14, 16, 14, 12),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildQuizThumbnail(
                            imageUrl: imageUrl,
                            subjectName: subjectName,
                            primaryColor: primaryColor,
                            secondaryColor: secondaryColor,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        title,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: AppTextStyles.question.copyWith(
                                          fontSize: 15.5,
                                          fontWeight: FontWeight.w800,
                                          color: AppColors.text,
                                          height: 1.25,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    SizedBox(
                                      width: 28,
                                      height: 28,
                                      child: PopupMenuButton<String>(
                                        padding: EdgeInsets.zero,
                                        icon: Icon(
                                          Icons.more_horiz_rounded,
                                          size: 20,
                                          color: Colors.grey.shade600,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(14),
                                        ),
                                        onSelected: (value) {
                                          if (value == 'edit') {
                                            _openQuizDetail(quiz);
                                          } else if (value == 'delete') {
                                            _deleteQuiz(quiz);
                                          }
                                        },
                                        itemBuilder: (context) => [
                                          const PopupMenuItem(
                                            value: 'edit',
                                            child: Row(
                                              children: [
                                                Icon(
                                                  Icons.edit_outlined,
                                                  size: 18,
                                                ),
                                                SizedBox(width: 8),
                                                Text('Chỉnh sửa'),
                                              ],
                                            ),
                                          ),
                                          const PopupMenuItem(
                                            value: 'delete',
                                            child: Row(
                                              children: [
                                                Icon(
                                                  Icons.delete_outline_rounded,
                                                  size: 18,
                                                  color: Colors.redAccent,
                                                ),
                                                SizedBox(width: 8),
                                                Text(
                                                  'Xóa',
                                                  style: TextStyle(
                                                    color: Colors.redAccent,
                                                    fontWeight: FontWeight.w600,
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
                                const SizedBox(height: 8),
                                Wrap(
                                  spacing: 6,
                                  runSpacing: 6,
                                  children: [
                                    _buildMetaBadge(
                                      label: subjectName,
                                      color: primaryColor,
                                    ),
                                    _buildMetaBadge(
                                      icon: Icons.help_outline_rounded,
                                      label: '$count câu',
                                      color: const Color(0xFF475569),
                                    ),
                                    _buildMetaBadge(
                                      icon: Icons.timer_outlined,
                                      label: '$minutes phút',
                                      color: const Color(0xFF475569),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 9,
                      ),
                      decoration: BoxDecoration(
                        color: primaryColor.withValues(alpha: 0.04),
                        border: Border(
                          top: BorderSide(
                            color: primaryColor.withValues(alpha: 0.1),
                          ),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.person_outline_rounded,
                            size: 14,
                            color: Colors.grey.shade500,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              'Tạo bởi $creator',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTextStyles.text.copyWith(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ),
                          Text(
                            'Quản lí câu hỏi',
                            style: AppTextStyles.text.copyWith(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: primaryColor,
                            ),
                          ),
                          const SizedBox(width: 2),
                          Icon(
                            Icons.chevron_right_rounded,
                            size: 16,
                            color: primaryColor,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSubjectFilterChip({
    required String label,
    required int count,
    required bool isSelected,
    required Color primaryColor,
    required Color secondaryColor,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          gradient: isSelected
              ? LinearGradient(colors: [primaryColor, secondaryColor])
              : null,
          color: isSelected ? null : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? Colors.transparent : const Color(0xFFE2E8F0),
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: primaryColor.withValues(alpha: 0.25),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: AppTextStyles.text.copyWith(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: isSelected ? Colors.white : AppColors.text,
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: isSelected
                    ? Colors.white.withValues(alpha: 0.24)
                    : primaryColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(99),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: isSelected ? Colors.white : primaryColor,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetaBadge({
    IconData? icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12.5, color: color),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: AppTextStyles.text.copyWith(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

/// ============================================================================
/// 2. MÀN HÌNH CHI TIẾT BỘ ĐỀ & DANH SÁCH CÂU HỎI
/// ============================================================================
class AdminQuizDetailScreen extends StatefulWidget {
  final AdminRow? quiz;
  final List<AdminRow> subjects;

  const AdminQuizDetailScreen({
    super.key,
    this.quiz,
    required this.subjects,
  });

  @override
  State<AdminQuizDetailScreen> createState() => _AdminQuizDetailScreenState();
}

class _AdminQuizDetailScreenState extends State<AdminQuizDetailScreen> {
  final _supabase = Supabase.instance.client;
  final _picker = ImagePicker();
  late TextEditingController _titleController;

  static const Color _brandBlue = Color(0xFF3B5BFD);
  static const Color _brandPurple = Color(0xFF7C3AED);

  String? _quizId;
  String? _selectedSubjectId;
  int _selectedMinutes = 15;
  String _selectedStatus = 'Đã xuất bản';
  String _creatorName = 'Admin';

  Uint8List? _pickedCoverBytes;
  String? _existingCoverUrl;

  List<AdminRow> _questions = [];
  bool _isLoading = false;
  bool _isSaving = false;

  static const List<int> _minuteOptions = [10, 15, 20, 30, 40, 45, 50, 60];
  static const List<String> _statusOptions = ['Đã xuất bản', 'Bản nháp'];

  @override
  void initState() {
    super.initState();
    final q = widget.quiz;
    _quizId = q?['id']?.toString();
    _titleController = TextEditingController(
      text: (q?['tieu_de'] ?? '').toString(),
    );
    _selectedSubjectId = q?['mon_hoc_id']?.toString() ??
        (widget.subjects.isNotEmpty
            ? widget.subjects.first['id'].toString()
            : null);

    final rawMin = (q?['thoi_gian_phut'] as num?)?.toInt() ?? 15;
    _selectedMinutes = _minuteOptions.contains(rawMin) ? rawMin : 15;
    _creatorName = (q?['nguoi_tao'] ?? 'Admin').toString();

    final rawCover = (q?['hinh_anh_url'] ?? '').toString().trim();
    if (rawCover.isNotEmpty) {
      _existingCoverUrl = rawCover;
    }

    if (_quizId != null) {
      _loadQuestions();
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  Future<void> _pickCoverImage() async {
    try {
      final XFile? file = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 600,
        maxHeight: 600,
        imageQuality: 85,
      );
      if (file == null) return;
      final bytes = await file.readAsBytes();
      if (!mounted) return;
      setState(() => _pickedCoverBytes = bytes);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Không thể chọn ảnh bìa: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  Future<String?> _uploadOrEncodeCover(Uint8List bytes) async {
    try {
      final fileName = 'quiz_${DateTime.now().millisecondsSinceEpoch}.png';
      await _supabase.storage.from('quiz_covers').uploadBinary(
            fileName,
            bytes,
            fileOptions: const FileOptions(contentType: 'image/png'),
          );
      return _supabase.storage.from('quiz_covers').getPublicUrl(fileName);
    } catch (_) {
      return 'data:image/png;base64,${base64Encode(bytes)}';
    }
  }

  Future<void> _loadQuestions() async {
    if (_quizId == null) return;
    setState(() => _isLoading = true);

    try {
      final loaded = <AdminRow>[];

      try {
        final dynamic linkRows = await _supabase
            .from('de_thi_cau_hoi')
            .select('thu_tu, cau_hoi(*, dap_an(*))')
            .eq('de_thi_id', _quizId!)
            .order('thu_tu', ascending: true);

        if (linkRows is Iterable) {
          for (final row in linkRows) {
            if (row is Map && row['cau_hoi'] is Map) {
              loaded.add(Map<String, dynamic>.from(row['cau_hoi'] as Map));
            }
          }
        }
      } catch (_) {}

      if (loaded.isEmpty) {
        final dynamic directRows = await _supabase
            .from('cau_hoi')
            .select('*, dap_an(*)')
            .eq('de_thi_id', _quizId!)
            .order('thu_tu', ascending: true);

        if (directRows is Iterable) {
          for (final row in directRows) {
            if (row is Map) {
              loaded.add(Map<String, dynamic>.from(row));
            }
          }
        }
      }

      if (!mounted) return;
      setState(() {
        _questions = loaded;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  String _extractCorrectAnswer(AdminRow question) {
    final dynamic rawList = question['dap_an'];
    if (rawList is Iterable) {
      for (final ans in rawList) {
        if (ans is Map && ans.values.any((v) => v == true)) {
          return (ans['noi_dung'] ?? '').toString();
        }
      }
    }
    return 'Chưa có đáp án đúng';
  }

  int _countAnswers(AdminRow question) {
    final dynamic rawList = question['dap_an'];
    if (rawList is Iterable) {
      return rawList.length;
    }
    return 0;
  }

  bool _hasQuestionImage(AdminRow question) {
    final raw =
        (question['hinh_anh_url'] ?? question['hinh_anh'] ?? '')
            .toString()
            .trim();
    return raw.isNotEmpty;
  }

  Future<String?> _saveQuizInfo({bool showToast = true}) async {
    final title = _titleController.text.trim().isEmpty
        ? 'Bộ đề trắc nghiệm mới'
        : _titleController.text.trim();

    setState(() => _isSaving = true);
    try {
      String? coverUrl = _existingCoverUrl;
      if (_pickedCoverBytes != null) {
        coverUrl = await _uploadOrEncodeCover(_pickedCoverBytes!);
      }

      final fullPayload = <String, dynamic>{
        'tieu_de': title,
        if (_selectedSubjectId != null) 'mon_hoc_id': _selectedSubjectId,
        'thoi_gian_phut': _selectedMinutes,
        if (coverUrl != null) 'hinh_anh_url': coverUrl,
      };

      final minimalPayload = <String, dynamic>{
        'tieu_de': title,
        if (_selectedSubjectId != null) 'mon_hoc_id': _selectedSubjectId,
      };

      if (_quizId == null) {
        dynamic inserted;
        try {
          inserted = await _supabase
              .from('de_thi')
              .insert(fullPayload)
              .select('*')
              .single();
        } catch (_) {
          inserted = await _supabase
              .from('de_thi')
              .insert(minimalPayload)
              .select('*')
              .single();
        }
        if (inserted is Map) {
          _quizId = inserted['id'].toString();
        }
      } else {
        try {
          await _supabase.from('de_thi').update(fullPayload).eq('id', _quizId!);
        } catch (_) {
          await _supabase
              .from('de_thi')
              .update(minimalPayload)
              .eq('id', _quizId!);
        }
      }

      if (!mounted) return _quizId;
      setState(() => _isSaving = false);
      if (showToast) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Đã lưu thông tin bộ đề'),
            backgroundColor: const Color(0xFF059669),
          ),
        );
      }
      return _quizId;
    } catch (e) {
      if (!mounted) return null;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Lỗi lưu bộ đề: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return null;
    }
  }

  Future<void> _openQuestionEditor([AdminRow? question]) async {
    final savedQuizId = _quizId ?? await _saveQuizInfo(showToast: false);
    if (savedQuizId == null || !mounted) return;

    final quizTitle = _titleController.text.trim().isEmpty
        ? 'Bộ đề trắc nghiệm'
        : _titleController.text.trim();

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AdminQuestionFormScreen(
          quizId: savedQuizId,
          quizTitle: quizTitle,
          creatorName: _creatorName,
          question: question,
          nextOrder: _questions.length + 1,
        ),
      ),
    );
    _loadQuestions();
  }

  Future<void> _deleteQuestion(AdminRow question) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Xóa câu hỏi',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        content: const Text('Bạn có chắc muốn xóa câu hỏi này khỏi bộ đề?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Hủy', style: TextStyle(color: Colors.grey.shade700)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Xóa',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final qId = question['id'];
      if (_quizId != null) {
        try {
          await _supabase
              .from('de_thi_cau_hoi')
              .delete()
              .eq('de_thi_id', _quizId!)
              .eq('cau_hoi_id', qId);
        } catch (_) {}
      }
      await _supabase.from('dap_an').delete().eq('cau_hoi_id', qId);
      await _supabase.from('cau_hoi').delete().eq('id', qId);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Đã xóa câu hỏi'),
          backgroundColor: Color(0xFF059669),
        ),
      );
      _loadQuestions();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Lỗi xóa câu hỏi: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  Widget _buildCoverRow() {
    Widget? coverContent;

    if (_pickedCoverBytes != null) {
      coverContent = Image.memory(
        _pickedCoverBytes!,
        width: 84,
        height: 84,
        fit: BoxFit.cover,
      );
    } else if (_existingCoverUrl != null && _existingCoverUrl!.isNotEmpty) {
      if (_existingCoverUrl!.startsWith('data:image')) {
        try {
          final bytes = base64Decode(_existingCoverUrl!.split(',').last);
          coverContent = Image.memory(
            bytes,
            width: 84,
            height: 84,
            fit: BoxFit.cover,
          );
        } catch (_) {}
      } else {
        coverContent = Image.network(
          _existingCoverUrl!,
          width: 84,
          height: 84,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => const SizedBox.shrink(),
        );
      }
    }

    final hasCover = coverContent != null;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          InkWell(
            onTap: _isSaving ? null : _pickCoverImage,
            borderRadius: BorderRadius.circular(14),
            child: Container(
              width: 84,
              height: 84,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: hasCover
                      ? AppColors.base.withValues(alpha: 0.4)
                      : Colors.grey.shade300,
                ),
              ),
              child: hasCover
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(13),
                      child: coverContent,
                    )
                  : Icon(
                      Icons.add_photo_alternate_outlined,
                      size: 30,
                      color: AppColors.base.withValues(alpha: 0.8),
                    ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Ảnh bìa bộ đề',
                  style: AppTextStyles.question.copyWith(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w800,
                    color: AppColors.text,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  hasCover
                      ? 'Ảnh bìa sẽ hiển thị ở danh sách bộ đề.'
                      : 'Chưa có ảnh bìa (tự dùng biểu tượng môn học).',
                  style: AppTextStyles.text.copyWith(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.base,
                        side: BorderSide(
                          color: AppColors.base.withValues(alpha: 0.4),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      onPressed: _isSaving ? null : _pickCoverImage,
                      icon: const Icon(Icons.photo_library_outlined, size: 15),
                      label: Text(
                        hasCover ? 'Đổi ảnh' : 'Chọn ảnh',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    if (hasCover) ...[
                      const SizedBox(width: 8),
                      TextButton(
                        style: TextButton.styleFrom(
                          foregroundColor: const Color(0xFFEF4444),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        onPressed: () => setState(() {
                          _pickedCoverBytes = null;
                          _existingCoverUrl = null;
                        }),
                        child: const Text(
                          'Gỡ ảnh',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;
    final headerTitle = _titleController.text.trim().isEmpty
        ? 'Tạo bộ đề mới'
        : _titleController.text.trim();

    final safeSubjectId =
        widget.subjects.any((s) => s['id'].toString() == _selectedSubjectId)
            ? _selectedSubjectId
            : null;

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5FB),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.base,
        foregroundColor: Colors.white,
        elevation: 3,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        onPressed: () => _openQuestionEditor(),
        icon: const Icon(Icons.add_rounded, size: 22),
        label: const Text(
          'Thêm câu hỏi',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      body: Column(
        children: [
          // Header Gradient xanh-tím
          Container(
            width: double.infinity,
            padding: EdgeInsets.fromLTRB(16, topPadding + 14, 16, 22),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [_brandBlue, AppColors.base, _brandPurple],
              ),
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
            ),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 648),
                child: Row(
                  children: [
                    Material(
                      color: Colors.white.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(14),
                      child: InkWell(
                        onTap: () => Navigator.pop(context),
                        borderRadius: BorderRadius.circular(14),
                        child: Container(
                          width: 42,
                          height: 42,
                          alignment: Alignment.center,
                          child: const Icon(
                            Icons.arrow_back_rounded,
                            color: Colors.white,
                            size: 20,
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
                            'Người tạo: $_creatorName',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: Colors.white.withValues(alpha: 0.82),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            headerTitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.question.copyWith(
                              fontSize: 19,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: AppColors.base,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      onPressed: _isSaving ? null : () => _saveQuizInfo(),
                      icon: _isSaving
                          ? const SizedBox(
                              width: 15,
                              height: 15,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.base,
                              ),
                            )
                          : const Icon(Icons.save_rounded, size: 18),
                      label: const Text(
                        'Lưu đề',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Nội dung chi tiết
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 648),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // 1. Thẻ cấu hình bộ đề
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF0F172A)
                                  .withValues(alpha: 0.04),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _buildCoverRow(),
                            const SizedBox(height: 14),
                            Text(
                              'Tên bộ đề',
                              style: AppTextStyles.text.copyWith(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700,
                                color: Colors.grey.shade700,
                              ),
                            ),
                            const SizedBox(height: 6),
                            TextField(
                              controller: _titleController,
                              onChanged: (_) => setState(() {}),
                              style: AppTextStyles.text.copyWith(
                                fontWeight: FontWeight.w700,
                                color: AppColors.text,
                              ),
                              decoration: InputDecoration(
                                hintText: 'Nhập tên bộ đề...',
                                hintStyle:
                                    TextStyle(color: Colors.grey.shade400),
                                filled: true,
                                fillColor: const Color(0xFFF8FAFC),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 13,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: BorderSide.none,
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: const BorderSide(
                                    color: AppColors.base,
                                    width: 1.5,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Môn học',
                                        style: AppTextStyles.text.copyWith(
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.w700,
                                          color: Colors.grey.shade700,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                        ),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFF8FAFC),
                                          borderRadius:
                                              BorderRadius.circular(14),
                                        ),
                                        child: DropdownButtonHideUnderline(
                                          child: DropdownButton<String>(
                                            isExpanded: true,
                                            value: safeSubjectId,
                                            hint: Text(
                                              'Chọn môn',
                                              style: TextStyle(
                                                fontSize: 13.5,
                                                color: Colors.grey.shade500,
                                              ),
                                            ),
                                            items: widget.subjects.map((s) {
                                              return DropdownMenuItem<String>(
                                                value: s['id'].toString(),
                                                child: Text(
                                                  (s['ten_mon'] ?? '')
                                                      .toString(),
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: const TextStyle(
                                                    fontSize: 13.5,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                              );
                                            }).toList(),
                                            onChanged: (val) => setState(
                                                () => _selectedSubjectId = val),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Thời gian',
                                        style: AppTextStyles.text.copyWith(
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.w700,
                                          color: Colors.grey.shade700,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                        ),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFF8FAFC),
                                          borderRadius:
                                              BorderRadius.circular(14),
                                        ),
                                        child: DropdownButtonHideUnderline(
                                          child: DropdownButton<int>(
                                            isExpanded: true,
                                            value: _selectedMinutes,
                                            items: _minuteOptions.map((m) {
                                              return DropdownMenuItem<int>(
                                                value: m,
                                                child: Text(
                                                  '$m phút',
                                                  style: const TextStyle(
                                                    fontSize: 13.5,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                              );
                                            }).toList(),
                                            onChanged: (val) {
                                              if (val != null) {
                                                setState(() =>
                                                    _selectedMinutes = val);
                                              }
                                            },
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Trạng thái',
                              style: AppTextStyles.text.copyWith(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700,
                                color: Colors.grey.shade700,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: _statusOptions.map((st) {
                                final isSelected = _selectedStatus == st;
                                final isPublished = st == 'Đã xuất bản';
                                final activeColor = isPublished
                                    ? const Color(0xFF059669)
                                    : _brandPurple;

                                return Expanded(
                                  child: Padding(
                                    padding: EdgeInsets.only(
                                      right: isPublished ? 6 : 0,
                                      left: isPublished ? 0 : 6,
                                    ),
                                    child: InkWell(
                                      borderRadius: BorderRadius.circular(12),
                                      onTap: () =>
                                          setState(() => _selectedStatus = st),
                                      child: AnimatedContainer(
                                        duration:
                                            const Duration(milliseconds: 160),
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 10,
                                        ),
                                        decoration: BoxDecoration(
                                          color: isSelected
                                              ? activeColor.withValues(
                                                  alpha: 0.12)
                                              : const Color(0xFFF8FAFC),
                                          borderRadius:
                                              BorderRadius.circular(12),
                                          border: Border.all(
                                            color: isSelected
                                                ? activeColor
                                                : Colors.transparent,
                                            width: 1.4,
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Icon(
                                              isPublished
                                                  ? Icons
                                                      .check_circle_outline_rounded
                                                  : Icons.edit_note_rounded,
                                              size: 16,
                                              color: isSelected
                                                  ? activeColor
                                                  : Colors.grey.shade600,
                                            ),
                                            const SizedBox(width: 6),
                                            Text(
                                              st,
                                              style:
                                                  AppTextStyles.text.copyWith(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w700,
                                                color: isSelected
                                                    ? activeColor
                                                    : Colors.grey.shade700,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 20),

                      // 2. Tiêu đề danh sách câu hỏi
                      Row(
                        children: [
                          Container(
                            width: 4,
                            height: 17,
                            decoration: BoxDecoration(
                              color: AppColors.base,
                              borderRadius: BorderRadius.circular(99),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Danh sách câu hỏi',
                            style: AppTextStyles.question.copyWith(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: AppColors.text,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 9,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.base.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '${_questions.length} câu',
                              style: AppTextStyles.text.copyWith(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: AppColors.base,
                              ),
                            ),
                          ),
                          const Spacer(),
                          Text(
                            '$_selectedMinutes phút',
                            style: AppTextStyles.text.copyWith(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 12),

                      // 3. Danh sách câu hỏi
                      if (_isLoading)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 32),
                          child: Center(
                            child: CircularProgressIndicator(
                              color: AppColors.base,
                            ),
                          ),
                        )
                      else if (_questions.isEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 28,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Column(
                            children: [
                              Container(
                                width: 54,
                                height: 54,
                                decoration: BoxDecoration(
                                  color: AppColors.base.withValues(alpha: 0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.quiz_outlined,
                                  size: 28,
                                  color: AppColors.base,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'Chưa có câu hỏi nào',
                                style: AppTextStyles.question.copyWith(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.text,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Thêm câu hỏi để hoàn thiện bộ đề trắc nghiệm này.',
                                textAlign: TextAlign.center,
                                style: AppTextStyles.text.copyWith(
                                  fontSize: 13,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                              const SizedBox(height: 14),
                              OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: AppColors.base,
                                  side: BorderSide(
                                    color:
                                        AppColors.base.withValues(alpha: 0.45),
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                onPressed: () => _openQuestionEditor(),
                                icon: const Icon(Icons.add_rounded, size: 18),
                                label: const Text(
                                  'Tạo câu hỏi đầu tiên',
                                  style: TextStyle(fontWeight: FontWeight.w700),
                                ),
                              ),
                            ],
                          ),
                        )
                      else
                        ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _questions.length,
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: 10),
                          itemBuilder: (context, index) {
                            final question = _questions[index];
                            final content = (question['noi_dung'] ??
                                    'Nội dung câu hỏi')
                                .toString();
                            final correctAns = _extractCorrectAnswer(question);
                            final answerCount = _countAnswers(question);
                            final hasImage = _hasQuestionImage(question);

                            return Container(
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(18),
                                border:
                                    Border.all(color: const Color(0xFFE2E8F0)),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.03),
                                    blurRadius: 10,
                                    offset: const Offset(0, 3),
                                  ),
                                ],
                              ),
                              child: Material(
                                color: Colors.transparent,
                                borderRadius: BorderRadius.circular(18),
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(18),
                                  onTap: () => _openQuestionEditor(question),
                                  child: Padding(
                                    padding: const EdgeInsets.all(14),
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Container(
                                          width: 34,
                                          height: 34,
                                          alignment: Alignment.center,
                                          decoration: BoxDecoration(
                                            gradient: const LinearGradient(
                                              colors: [
                                                _brandBlue,
                                                _brandPurple,
                                              ],
                                            ),
                                            borderRadius:
                                                BorderRadius.circular(10),
                                          ),
                                          child: Text(
                                            '${index + 1}',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w800,
                                              fontSize: 13.5,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                content,
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                                style:
                                                    AppTextStyles.text.copyWith(
                                                  fontSize: 14.5,
                                                  fontWeight: FontWeight.w700,
                                                  color: AppColors.text,
                                                  height: 1.35,
                                                ),
                                              ),
                                              const SizedBox(height: 8),
                                              Wrap(
                                                spacing: 6,
                                                runSpacing: 6,
                                                children: [
                                                  Container(
                                                    padding: const EdgeInsets
                                                        .symmetric(
                                                      horizontal: 8,
                                                      vertical: 3,
                                                    ),
                                                    decoration: BoxDecoration(
                                                      color: const Color(
                                                              0xFF10B981)
                                                          .withValues(
                                                              alpha: 0.12),
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              8),
                                                    ),
                                                    child: Row(
                                                      mainAxisSize:
                                                          MainAxisSize.min,
                                                      children: [
                                                        const Icon(
                                                          Icons
                                                              .check_circle_rounded,
                                                          size: 13,
                                                          color:
                                                              Color(0xFF047857),
                                                        ),
                                                        const SizedBox(
                                                            width: 4),
                                                        ConstrainedBox(
                                                          constraints:
                                                              const BoxConstraints(
                                                            maxWidth: 180,
                                                          ),
                                                          child: Text(
                                                            correctAns,
                                                            maxLines: 1,
                                                            overflow:
                                                                TextOverflow
                                                                    .ellipsis,
                                                            style: AppTextStyles
                                                                .text
                                                                .copyWith(
                                                              fontSize: 12,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w700,
                                                              color:
                                                                  const Color(
                                                                0xFF047857,
                                                              ),
                                                            ),
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                  if (answerCount > 0)
                                                    Container(
                                                      padding: const EdgeInsets
                                                          .symmetric(
                                                        horizontal: 8,
                                                        vertical: 3,
                                                      ),
                                                      decoration: BoxDecoration(
                                                        color: const Color(
                                                                0xFF64748B)
                                                            .withValues(
                                                                alpha: 0.1),
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(8),
                                                      ),
                                                      child: Text(
                                                        '$answerCount phương án',
                                                        style: AppTextStyles
                                                            .text
                                                            .copyWith(
                                                          fontSize: 11.5,
                                                          fontWeight:
                                                              FontWeight.w700,
                                                          color: const Color(
                                                              0xFF475569),
                                                        ),
                                                      ),
                                                    ),
                                                  if (hasImage)
                                                    Container(
                                                      padding: const EdgeInsets
                                                          .symmetric(
                                                        horizontal: 7,
                                                        vertical: 3,
                                                      ),
                                                      decoration: BoxDecoration(
                                                        color: AppColors.base
                                                            .withValues(
                                                                alpha: 0.1),
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(8),
                                                      ),
                                                      child: Row(
                                                        mainAxisSize:
                                                            MainAxisSize.min,
                                                        children: [
                                                          const Icon(
                                                            Icons
                                                                .image_outlined,
                                                            size: 12.5,
                                                            color:
                                                                AppColors.base,
                                                          ),
                                                          const SizedBox(
                                                              width: 3),
                                                          Text(
                                                            'Ảnh',
                                                            style: AppTextStyles
                                                                .text
                                                                .copyWith(
                                                              fontSize: 11.5,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w700,
                                                              color: AppColors
                                                                  .base,
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
                                        IconButton(
                                          tooltip: 'Xóa câu hỏi',
                                          icon: Icon(
                                            Icons.delete_outline_rounded,
                                            size: 20,
                                            color: Colors.red.shade400,
                                          ),
                                          onPressed: () =>
                                              _deleteQuestion(question),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
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
}

/// ============================================================================
/// 3. MÀN HÌNH TẠO / SỬA CÂU HỎI
/// ============================================================================
class AdminQuestionFormScreen extends StatefulWidget {
  final String quizId;
  final String quizTitle;
  final String creatorName;
  final AdminRow? question;
  final int nextOrder;

  const AdminQuestionFormScreen({
    super.key,
    required this.quizId,
    required this.quizTitle,
    required this.creatorName,
    this.question,
    required this.nextOrder,
  });

  @override
  State<AdminQuestionFormScreen> createState() =>
      _AdminQuestionFormScreenState();
}

class _AdminQuestionFormScreenState extends State<AdminQuestionFormScreen> {
  final _supabase = Supabase.instance.client;
  final _picker = ImagePicker();

  static const Color _brandBlue = Color(0xFF3B5BFD);
  static const Color _brandPurple = Color(0xFF7C3AED);

  late TextEditingController _questionController;
  late TextEditingController _correctController;
  late List<TextEditingController> _wrongControllers;

  Uint8List? _pickedImageBytes;
  String? _existingImageUrl;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final q = widget.question;
    _questionController = TextEditingController(
      text: (q?['noi_dung'] ?? '').toString(),
    );

    final rawImg =
        (q?['hinh_anh_url'] ?? q?['hinh_anh'] ?? '').toString().trim();
    if (rawImg.isNotEmpty) {
      _existingImageUrl = rawImg;
    }

    String correctText = '';
    final wrongTexts = <String>[];

    final dynamic rawAnswers = q?['dap_an'];
    if (rawAnswers is Iterable) {
      for (final ans in rawAnswers) {
        if (ans is Map) {
          final text = (ans['noi_dung'] ?? '').toString();
          final isCorrect = ans.values.any((v) => v == true);
          if (isCorrect && correctText.isEmpty) {
            correctText = text;
          } else {
            wrongTexts.add(text);
          }
        }
      }
    }

    _correctController = TextEditingController(text: correctText);
    _wrongControllers = List.generate(
      3,
      (i) => TextEditingController(
        text: i < wrongTexts.length ? wrongTexts[i] : '',
      ),
    );
  }

  @override
  void dispose() {
    _questionController.dispose();
    _correctController.dispose();
    for (final c in _wrongControllers) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pickQuestionImage() async {
    try {
      final XFile? file = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );
      if (file == null) return;
      final bytes = await file.readAsBytes();
      if (!mounted) return;
      setState(() => _pickedImageBytes = bytes);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Không thể chọn ảnh: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  Future<String?> _uploadOrEncodeImage(Uint8List bytes) async {
    try {
      final fileName = 'question_${DateTime.now().millisecondsSinceEpoch}.png';
      await _supabase.storage.from('question_images').uploadBinary(
            fileName,
            bytes,
            fileOptions: const FileOptions(contentType: 'image/png'),
          );
      return _supabase.storage.from('question_images').getPublicUrl(fileName);
    } catch (_) {
      return 'data:image/png;base64,${base64Encode(bytes)}';
    }
  }

  Future<String> _detectCorrectBoolColumn() async {
    try {
      final dynamic sample =
          await _supabase.from('dap_an').select('*').limit(1).maybeSingle();
      if (sample is Map) {
        for (final entry in sample.entries) {
          if (entry.value is bool) {
            return entry.key.toString();
          }
        }
      }
    } catch (_) {}
    return 'la_dap_an_dung';
  }

  Future<void> _saveQuestion() async {
    final content = _questionController.text.trim();
    final correct = _correctController.text.trim();
    final wrongs = _wrongControllers
        .map((c) => c.text.trim())
        .where((t) => t.isNotEmpty)
        .toList();

    if (content.isEmpty || correct.isEmpty || wrongs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Vui lòng nhập nội dung câu hỏi, đáp án đúng và ít nhất 1 đáp án sai.',
          ),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final boolCol = await _detectCorrectBoolColumn();
      dynamic questionId = widget.question?['id'];

      String? imageUrl = _existingImageUrl;
      if (_pickedImageBytes != null) {
        imageUrl = await _uploadOrEncodeImage(_pickedImageBytes!);
      }

      if (questionId == null) {
        dynamic insertedQ;
        try {
          insertedQ = await _supabase
              .from('cau_hoi')
              .insert({
                'noi_dung': content,
                'loai_cau_hoi_id': '11111111-1111-1111-1111-111111111111',
                if (imageUrl != null) 'hinh_anh_url': imageUrl,
              })
              .select('*')
              .single();
        } catch (_) {
          insertedQ = await _supabase
              .from('cau_hoi')
              .insert({
                'noi_dung': content,
                'loai_cau_hoi_id': '11111111-1111-1111-1111-111111111111',
              })
              .select('*')
              .single();
        }

        questionId = insertedQ['id'];

        try {
          await _supabase.from('de_thi_cau_hoi').insert({
            'de_thi_id': widget.quizId,
            'cau_hoi_id': questionId,
            'thu_tu': widget.nextOrder,
          });
        } catch (_) {
          await _supabase
              .from('cau_hoi')
              .update({'de_thi_id': widget.quizId}).eq('id', questionId);
        }
      } else {
        try {
          await _supabase.from('cau_hoi').update({
            'noi_dung': content,
            'hinh_anh_url': imageUrl,
          }).eq('id', questionId);
        } catch (_) {
          await _supabase
              .from('cau_hoi')
              .update({'noi_dung': content}).eq('id', questionId);
        }
        await _supabase.from('dap_an').delete().eq('cau_hoi_id', questionId);
      }

      final answersPayload = <AdminRow>[
        {
          'cau_hoi_id': questionId,
          'noi_dung': correct,
          'thu_tu': 1,
          boolCol: true,
        },
        for (int i = 0; i < wrongs.length; i++)
          {
            'cau_hoi_id': questionId,
            'noi_dung': wrongs[i],
            'thu_tu': i + 2,
            boolCol: false,
          },
      ];

      await _supabase.from('dap_an').insert(answersPayload);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Đã lưu câu hỏi thành công'),
          backgroundColor: Color(0xFF059669),
        ),
      );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Lỗi lưu câu hỏi: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  Widget _buildQuestionImageArea() {
    Widget? imageContent;

    if (_pickedImageBytes != null) {
      imageContent = Image.memory(
        _pickedImageBytes!,
        width: double.infinity,
        height: 170,
        fit: BoxFit.cover,
      );
    } else if (_existingImageUrl != null && _existingImageUrl!.isNotEmpty) {
      if (_existingImageUrl!.startsWith('data:image')) {
        try {
          final bytes = base64Decode(_existingImageUrl!.split(',').last);
          imageContent = Image.memory(
            bytes,
            width: double.infinity,
            height: 170,
            fit: BoxFit.cover,
          );
        } catch (_) {}
      } else {
        imageContent = Image.network(
          _existingImageUrl!,
          width: double.infinity,
          height: 170,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => const SizedBox.shrink(),
        );
      }
    }

    if (imageContent == null) {
      return InkWell(
        onTap: _isSaving ? null : _pickQuestionImage,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.base.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.add_photo_alternate_outlined,
                  size: 20,
                  color: AppColors.base,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Thêm ảnh minh họa',
                      style: AppTextStyles.text.copyWith(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.text,
                      ),
                    ),
                    Text(
                      'Không bắt buộc • Chọn ảnh từ thiết bị',
                      style: AppTextStyles.text.copyWith(
                        fontSize: 11.5,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: Colors.grey.shade500,
              ),
            ],
          ),
        ),
      );
    }

    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Container(
            width: double.infinity,
            height: 170,
            color: const Color(0xFFF8FAFC),
            child: imageContent,
          ),
        ),
        Positioned(
          top: 10,
          right: 10,
          child: Row(
            children: [
              Material(
                color: Colors.black.withValues(alpha: 0.65),
                borderRadius: BorderRadius.circular(10),
                child: InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: _isSaving ? null : _pickQuestionImage,
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.photo_library_outlined,
                          size: 14,
                          color: Colors.white,
                        ),
                        SizedBox(width: 4),
                        Text(
                          'Đổi ảnh',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Material(
                color: const Color(0xFFEF4444),
                borderRadius: BorderRadius.circular(10),
                child: InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: () => setState(() {
                    _pickedImageBytes = null;
                    _existingImageUrl = null;
                  }),
                  child: const Padding(
                    padding: EdgeInsets.all(6),
                    child: Icon(
                      Icons.close_rounded,
                      size: 16,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAnswerField({
    required TextEditingController controller,
    required Color accentColor,
    required Color fillColor,
    required String hint,
    required Widget prefixBadge,
  }) {
    return TextField(
      controller: controller,
      style: AppTextStyles.text.copyWith(
        fontSize: 14.5,
        color: AppColors.text,
        fontWeight: FontWeight.w500,
      ),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
        filled: true,
        fillColor: fillColor,
        prefixIcon: Padding(
          padding: const EdgeInsets.only(left: 12, right: 8),
          child: prefixBadge,
        ),
        prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 14,
        ),
        suffixIcon: IconButton(
          icon: Icon(
            Icons.close_rounded,
            size: 18,
            color: Colors.grey.shade400,
          ),
          onPressed: () => controller.clear(),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(
            color: accentColor.withValues(alpha: 0.35),
            width: 1.3,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: accentColor, width: 1.8),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;
    final isEditing = widget.question != null;
    const wrongLabels = ['B', 'C', 'D'];

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5FB),
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
          ),
          child: Center(
            heightFactor: 1,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 648),
              child: SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.base,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  onPressed: _isSaving ? null : _saveQuestion,
                  icon: _isSaving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.save_rounded, size: 20),
                  label: Text(
                    isEditing ? 'Cập nhật câu hỏi' : 'Lưu câu hỏi',
                    style: const TextStyle(
                      fontSize: 15.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          // Header Gradient xanh-tím
          Container(
            width: double.infinity,
            padding: EdgeInsets.fromLTRB(16, topPadding + 14, 16, 22),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [_brandBlue, AppColors.base, _brandPurple],
              ),
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
            ),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 648),
                child: Row(
                  children: [
                    Material(
                      color: Colors.white.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(14),
                      child: InkWell(
                        onTap: () => Navigator.pop(context),
                        borderRadius: BorderRadius.circular(14),
                        child: Container(
                          width: 42,
                          height: 42,
                          alignment: Alignment.center,
                          child: const Icon(
                            Icons.arrow_back_rounded,
                            color: Colors.white,
                            size: 20,
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
                            isEditing
                                ? 'Chỉnh sửa câu hỏi'
                                : 'Câu hỏi số ${widget.nextOrder} • ${widget.creatorName}',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: Colors.white.withValues(alpha: 0.82),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            widget.quizTitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.question.copyWith(
                              fontSize: 18.5,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Material(
                      color: Colors.white.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(14),
                      child: InkWell(
                        onTap: _isSaving ? null : _saveQuestion,
                        borderRadius: BorderRadius.circular(14),
                        child: Container(
                          width: 42,
                          height: 42,
                          alignment: Alignment.center,
                          child: _isSaving
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(
                                  Icons.check_rounded,
                                  color: Colors.white,
                                  size: 22,
                                ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 648),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // 1. Thẻ câu hỏi + ảnh minh họa
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF0F172A)
                                  .withValues(alpha: 0.04),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 9,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.base.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                'NỘI DUNG CÂU HỎI',
                                style: AppTextStyles.text.copyWith(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.base,
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),
                            TextField(
                              controller: _questionController,
                              maxLines: 4,
                              minLines: 3,
                              style: AppTextStyles.text.copyWith(
                                fontSize: 15,
                                color: AppColors.text,
                                fontWeight: FontWeight.w600,
                                height: 1.4,
                              ),
                              decoration: InputDecoration(
                                hintText: 'Nhập nội dung câu hỏi tại đây...',
                                hintStyle:
                                    TextStyle(color: Colors.grey.shade400),
                                filled: true,
                                fillColor: const Color(0xFFF8FAFC),
                                contentPadding: const EdgeInsets.all(14),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: BorderSide.none,
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: const BorderSide(
                                    color: AppColors.base,
                                    width: 1.5,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            _buildQuestionImageArea(),
                          ],
                        ),
                      ),

                      const SizedBox(height: 16),

                      // 2. Thẻ các phương án trả lời
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF0F172A)
                                  .withValues(alpha: 0.04),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(
                                  Icons.check_circle_rounded,
                                  size: 18,
                                  color: Color(0xFF10B981),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'Đáp án đúng',
                                  style: AppTextStyles.question.copyWith(
                                    fontSize: 14.5,
                                    fontWeight: FontWeight.w800,
                                    color: const Color(0xFF047857),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            _buildAnswerField(
                              controller: _correctController,
                              accentColor: const Color(0xFF10B981),
                              fillColor: const Color(0xFF10B981)
                                  .withValues(alpha: 0.05),
                              hint: 'Nhập đáp án chính xác...',
                              prefixBadge: Container(
                                width: 28,
                                height: 28,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF10B981),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Text(
                                  'A',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 12.5,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                const Icon(
                                  Icons.cancel_rounded,
                                  size: 18,
                                  color: Color(0xFFEF4444),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'Các đáp án sai',
                                  style: AppTextStyles.question.copyWith(
                                    fontSize: 14.5,
                                    fontWeight: FontWeight.w800,
                                    color: const Color(0xFFB91C1C),
                                  ),
                                ),
                                const Spacer(),
                                Text(
                                  'Tối thiểu 1 đáp án',
                                  style: AppTextStyles.text.copyWith(
                                    fontSize: 11.5,
                                    color: Colors.grey.shade500,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            for (int i = 0; i < 3; i++) ...[
                              _buildAnswerField(
                                controller: _wrongControllers[i],
                                accentColor: const Color(0xFFEF4444),
                                fillColor: const Color(0xFFF8FAFC),
                                hint: 'Nhập đáp án sai ${i + 1}...',
                                prefixBadge: Container(
                                  width: 28,
                                  height: 28,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFEF4444)
                                        .withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    wrongLabels[i],
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 12.5,
                                      color: Color(0xFFB91C1C),
                                    ),
                                  ),
                                ),
                              ),
                              if (i < 2) const SizedBox(height: 10),
                            ],
                          ],
                        ),
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
}