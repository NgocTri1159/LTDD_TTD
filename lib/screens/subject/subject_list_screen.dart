
import 'package:material_ui/material_ui.dart';

import '../../models/subject_model.dart';
import '../../services/subject_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common/empty_state_widget.dart';
import '../../widgets/common/error_state_widget.dart';
import '../../widgets/common/loading_widget.dart';
import 'subject_detail_screen.dart';

class SubjectListScreen extends StatefulWidget {
  final bool isEmbedded;

  const SubjectListScreen({super.key, this.isEmbedded = false});

  @override
  State<SubjectListScreen> createState() => _SubjectListScreenState();
}

class _SubjectListScreenState extends State<SubjectListScreen> {
  final TextEditingController _searchController = TextEditingController();

  late Future<List<SubjectModel>> _subjectsFuture;

  String _searchQuery = '';

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

  List<SubjectModel> _filterSubjects(List<SubjectModel> subjects) {
    if (_searchQuery.trim().isEmpty) {
      return subjects;
    }

    final query = _searchQuery.toLowerCase().trim();

    return subjects.where((subject) {
      final name = subject.tenMon.toLowerCase();
      final description = (subject.moTa ?? '').toLowerCase();

      return name.contains(query) || description.contains(query);
    }).toList();
  }

  Future<void> _openSubjectDetail(SubjectModel subject) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SubjectDetailScreen(subjectId: subject.id),
      ),
    );
    if (mounted) {
      _loadSubjects();
    }
  }

  Widget _buildSubjectIcon(
    SubjectModel subject,
    Color color, {
    double size = 52,
  }) {
    final symbol = subject.bieuTuong?.trim();

    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color.withAlpha(25),
        borderRadius: BorderRadius.circular(16),
      ),
      child: symbol != null && symbol.isNotEmpty
          ? Text(
              symbol,
              style: TextStyle(fontSize: size * 0.45),
              maxLines: 1,
            )
          : Icon(
              Icons.menu_book_rounded,
              size: size * 0.5,
              color: color,
            ),
    );
  }

  Widget _buildSubjectCard(SubjectModel subject) {
    final color = _getSubjectColor(subject.mauSac);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      color: Theme.of(context).cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: color.withAlpha(45),
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _openSubjectDetail(subject),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              _buildSubjectIcon(subject, color),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      subject.tenMon,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      subject.moTa?.trim().isNotEmpty == true
                          ? subject.moTa!
                          : 'Chưa có mô tả',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTheme.bodyMedium.copyWith(
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    if (!subject.trangThai) ...[
                      const SizedBox(height: 8),
                      const Text(
                        'Đã khóa',
                        style: TextStyle(
                          color: Colors.red,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.chevron_right_rounded,
                color: AppTheme.textSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSubjectContent(List<SubjectModel> subjects) {
    final filteredSubjects = _filterSubjects(subjects);

    if (filteredSubjects.isEmpty) {
      return EmptyStateWidget(
        icon: Icons.search_off_rounded,
        title: _searchQuery.isEmpty
            ? 'Chưa có môn học'
            : 'Không tìm thấy môn học',
        message: _searchQuery.isEmpty
            ? 'Hiện tại chưa có môn học nào được hiển thị.'
            : 'Thử tìm kiếm bằng tên hoặc mô tả khác nhé.',
        actionText: _searchQuery.isNotEmpty ? 'Xóa tìm kiếm' : null,
        onAction: _searchQuery.isNotEmpty
            ? () {
                _searchController.clear();
                setState(() => _searchQuery = '');
              }
            : null,
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        await SubjectService.getAllSubjects().then((subjects) {
          if (mounted) {
            setState(() {
              _subjectsFuture = Future.value(subjects);
            });
          }
        });
      },
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: filteredSubjects.length,
        itemBuilder: (context, index) {
          return _buildSubjectCard(filteredSubjects[index]);
        },
      ),
    );
  }

  Widget _buildEmbeddedHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Row(
        children: [
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Khám phá môn học',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF29245C),
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Tìm kiếm và lựa chọn môn học để ôn luyện',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Tải lại',
            onPressed: _loadSubjects,
            icon: const Icon(
              Icons.refresh_rounded,
              color: Color(0xFF6257E8),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1000),
        child: Column(
          children: [
            if (widget.isEmbedded) _buildEmbeddedHeader(),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: TextField(
                controller: _searchController,
                onChanged: (value) {
                  setState(() => _searchQuery = value);
                },
                decoration: InputDecoration(
                  hintText: 'Tìm kiếm môn học...',
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _searchQuery = '');
                          },
                          icon: const Icon(Icons.close_rounded),
                        )
                      : null,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  contentPadding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
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
                    return ErrorStateWidget(
                      errorMessage: snapshot.error.toString(),
                      onRetry: _loadSubjects,
                    );
                  }

                  final subjects = snapshot.data ?? [];

                  return _buildSubjectContent(subjects);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isEmbedded) {
      return _buildBody();
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Danh sách môn học'),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: 'Tải lại',
            onPressed: _loadSubjects,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: _buildBody(),
    );
  }
}
