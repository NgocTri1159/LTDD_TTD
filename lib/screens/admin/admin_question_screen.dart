import 'package:material_ui/material_ui.dart';

import '../../models/question_model.dart';
import '../../models/subject_model.dart';
import '../../services/admin_service.dart';
import '../../theme/app_theme.dart';
import 'admin_question_form_screen.dart';

class AdminQuestionScreen extends StatefulWidget {
  const AdminQuestionScreen({super.key});

  @override
  State<AdminQuestionScreen> createState() => _AdminQuestionScreenState();
}

class _AdminQuestionScreenState extends State<AdminQuestionScreen> {
  final TextEditingController _searchController = TextEditingController();

  late Future<List<SubjectModel>> _subjectsFuture;
  late Future<List<QuestionModel>> _questionsFuture;

  String? _selectedSubjectId;
  String? _selectedDifficulty;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _subjectsFuture = AdminService.getAllSubjectsAdmin();
    _loadQuestions();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _loadQuestions() {
    _questionsFuture = AdminService.getQuestionBank(
      subjectId: _selectedSubjectId,
      difficulty: _selectedDifficulty,
    );
  }

  void _applyFilters() {
    setState(_loadQuestions);
  }

  Future<void> _openAddQuestion() async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => const AdminQuestionFormScreen(),
      ),
    );

    if (result == true && mounted) {
      _applyFilters();
    }
  }

  Future<void> _refresh() async {
    setState(() {
      _subjectsFuture = AdminService.getAllSubjectsAdmin();
      _loadQuestions();
    });

    await Future.wait([_subjectsFuture, _questionsFuture]);
  }

  String _difficultyLabel(String value) {
    switch (value) {
      case 'de':
        return 'Dễ';
      case 'kho':
        return 'Khó';
      default:
        return 'Trung bình';
    }
  }

  Color _difficultyColor(String value) {
    switch (value) {
      case 'de':
        return AppTheme.success;
      case 'kho':
        return AppTheme.error;
      default:
        return const Color(0xFFF59E0B);
    }
  }

  IconData _difficultyIcon(String value) {
    switch (value) {
      case 'de':
        return Icons.sentiment_satisfied_alt_rounded;
      case 'kho':
        return Icons.local_fire_department_rounded;
      default:
        return Icons.speed_rounded;
    }
  }

  List<QuestionModel> _filterByKeyword(List<QuestionModel> questions) {
    final keyword = _searchQuery.trim().toLowerCase();
    if (keyword.isEmpty) return questions;

    return questions.where((q) {
      final contentMatch = q.noiDung.toLowerCase().contains(keyword);
      final answerMatch = q.danhSachDapAn.any(
        (a) => a.noiDung.toLowerCase().contains(keyword),
      );
      return contentMatch || answerMatch;
    }).toList();
  }

  Widget _buildDifficultyChips() {
    const options = [
      {'label': 'Tất cả', 'value': null},
      {'label': 'Dễ', 'value': 'de'},
      {'label': 'Trung bình', 'value': 'trung_binh'},
      {'label': 'Khó', 'value': 'kho'},
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: options.map((item) {
          final String? value = item['value'];
          final bool isSelected = _selectedDifficulty == value;
          final Color activeColor = value == null
              ? AppTheme.primary
              : _difficultyColor(value);

          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(item['label']!),
              selected: isSelected,
              onSelected: (_) {
                _selectedDifficulty = value;
                _applyFilters();
              },
              labelStyle: TextStyle(
                fontSize: 12.5,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                color: isSelected ? Colors.white : AppTheme.textSecondary,
              ),
              selectedColor: activeColor,
              backgroundColor: AppTheme.background,
              side: BorderSide(
                color: isSelected ? activeColor : AppTheme.cardBorder,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              showCheckmark: false,
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildFilters() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.cardBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _searchController,
            onChanged: (val) => setState(() => _searchQuery = val),
            decoration: InputDecoration(
              hintText: 'Tìm nhanh nội dung câu hỏi hoặc đáp án...',
              hintStyle: const TextStyle(fontSize: 13.5),
              prefixIcon: const Icon(
                Icons.search_rounded,
                color: AppTheme.primary,
              ),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.close_rounded, size: 20),
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _searchQuery = '');
                      },
                    )
                  : null,
              filled: true,
              fillColor: AppTheme.background,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 12,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 12),
          FutureBuilder<List<SubjectModel>>(
            future: _subjectsFuture,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Text(
                  'Không tải được danh sách môn học: ${snapshot.error}',
                  style: const TextStyle(color: AppTheme.error, fontSize: 13),
                );
              }

              final uniqueSubjects = <String, SubjectModel>{};
              for (final subject in (snapshot.data ?? <SubjectModel>[])) {
                uniqueSubjects[subject.id] = subject;
              }
              final subjects = uniqueSubjects.values.toList();

              final safeSelectedSubjectId =
                  subjects.any((s) => s.id == _selectedSubjectId)
                      ? _selectedSubjectId
                      : null;

              return DropdownButtonFormField<String?>(
                key: ValueKey(
                  'subject_filter_${subjects.length}_$safeSelectedSubjectId',
                ),
                initialValue: safeSelectedSubjectId,
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: 'Môn học',
                  prefixIcon: const Icon(
                    Icons.menu_book_outlined,
                    color: AppTheme.primary,
                  ),
                  filled: true,
                  fillColor: AppTheme.background,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
                items: [
                  const DropdownMenuItem<String?>(
                    value: null,
                    child: Text('Tất cả môn học'),
                  ),
                  ...subjects.map(
                    (subject) => DropdownMenuItem<String?>(
                      value: subject.id,
                      child: Text(subject.tenMon),
                    ),
                  ),
                ],
                onChanged: (value) {
                  _selectedSubjectId = value;
                  _applyFilters();
                },
              );
            },
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              const Icon(
                Icons.tune_rounded,
                size: 16,
                color: AppTheme.textSecondary,
              ),
              const SizedBox(width: 6),
              const Text(
                'Mức độ:',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textSecondary,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(child: _buildDifficultyChips()),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuestionCard(QuestionModel question, int index) {
    final answerCount = question.danhSachDapAn.length;
    final diffColor = _difficultyColor(question.mucDo);
    const optionLabels = ['A', 'B', 'C', 'D', 'E', 'F'];

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Material(
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: AppTheme.cardBorder),
        ),
        elevation: 1,
        shadowColor: Colors.black.withValues(alpha: 0.08),
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      'Câu #${index + 1}',
                      style: const TextStyle(
                        color: AppTheme.primary,
                        fontWeight: FontWeight.w800,
                        fontSize: 12.5,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      question.loaiCauHoi?.tenLoai ?? 'Trắc nghiệm',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: diffColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _difficultyIcon(question.mucDo),
                          size: 14,
                          color: diffColor,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _difficultyLabel(question.mucDo),
                          style: TextStyle(
                            color: diffColor,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                question.noiDung,
                style: const TextStyle(
                  fontSize: 15.5,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                  height: 1.45,
                ),
              ),
              if (question.hinhAnhUrl != null &&
                  question.hinhAnhUrl!.isNotEmpty) ...[
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    width: double.infinity,
                    color: AppTheme.background,
                    child: Image.network(
                      question.hinhAnhUrl!,
                      height: 160,
                      fit: BoxFit.contain,
                      errorBuilder: (_, _, _) => const Padding(
                        padding: EdgeInsets.all(16),
                        child: Text(
                          'Không thể tải hình ảnh câu hỏi',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: AppTheme.textSecondary),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _infoChip(
                    Icons.star_rounded,
                    '${question.diem} điểm',
                    iconColor: const Color(0xFFF59E0B),
                  ),
                  _infoChip(
                    Icons.format_list_bulleted_rounded,
                    '$answerCount đáp án',
                    iconColor: AppTheme.primary,
                  ),
                  if (question.thoiGianGiay != null)
                    _infoChip(
                      Icons.timer_outlined,
                      '${question.thoiGianGiay} giây',
                      iconColor: const Color(0xFF0288D1),
                    ),
                  if (question.amThanhUrl != null &&
                      question.amThanhUrl!.isNotEmpty)
                    _infoChip(
                      Icons.volume_up_rounded,
                      'Có âm thanh',
                      iconColor: AppTheme.success,
                    ),
                ],
              ),
              if (question.danhSachDapAn.isNotEmpty) ...[
                const SizedBox(height: 8),
                const Divider(height: 1, color: AppTheme.cardBorder),
                Theme(
                  data: Theme.of(context).copyWith(
                    dividerColor: Colors.transparent,
                  ),
                  child: ExpansionTile(
                    tilePadding: EdgeInsets.zero,
                    childrenPadding: const EdgeInsets.only(bottom: 4),
                    iconColor: AppTheme.primary,
                    collapsedIconColor: AppTheme.primary,
                    title: const Text(
                      'Xem chi tiết các đáp án',
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.primary,
                      ),
                    ),
                    children: List.generate(question.danhSachDapAn.length, (i) {
                      final answer = question.danhSachDapAn[i];
                      final label = i < optionLabels.length
                          ? optionLabels[i]
                          : '${i + 1}';

                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: answer.laDung
                              ? AppTheme.success.withValues(alpha: 0.09)
                              : AppTheme.background,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: answer.laDung
                                ? AppTheme.success.withValues(alpha: 0.45)
                                : AppTheme.cardBorder,
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 26,
                              height: 26,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: answer.laDung
                                    ? AppTheme.success
                                    : Colors.white,
                                border: answer.laDung
                                    ? null
                                    : Border.all(color: AppTheme.cardBorder),
                              ),
                              child: Text(
                                label,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: answer.laDung
                                      ? Colors.white
                                      : AppTheme.textSecondary,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                answer.noiDung,
                                style: TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: answer.laDung
                                      ? FontWeight.w600
                                      : FontWeight.normal,
                                  color: AppTheme.textPrimary,
                                ),
                              ),
                            ),
                            if (answer.laDung)
                              const Icon(
                                Icons.check_circle_rounded,
                                color: AppTheme.success,
                                size: 20,
                              ),
                          ],
                        ),
                      );
                    }),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _infoChip(IconData icon, String label, {Color? iconColor}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.background,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.cardBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: iconColor ?? AppTheme.textSecondary),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: AppTheme.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuestionList() {
    return FutureBuilder<List<QuestionModel>>(
      future: _questionsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(40),
              child: CircularProgressIndicator(color: AppTheme.primary),
            ),
          );
        }

        if (snapshot.hasError) {
          return Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppTheme.cardBorder),
            ),
            child: Column(
              children: [
                const Icon(
                  Icons.error_outline_rounded,
                  color: AppTheme.error,
                  size: 44,
                ),
                const SizedBox(height: 12),
                Text(
                  'Không thể tải kho câu hỏi:\n${snapshot.error}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppTheme.textSecondary),
                ),
                const SizedBox(height: 14),
                ElevatedButton.icon(
                  onPressed: _applyFilters,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: const Text('Thử lại'),
                ),
              ],
            ),
          );
        }

        final allQuestions = snapshot.data ?? [];
        final questions = _filterByKeyword(allQuestions);

        if (questions.isEmpty) {
          return Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppTheme.cardBorder),
            ),
            child: Column(
              children: [
                Container(
                  width: 68,
                  height: 68,
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.quiz_outlined,
                    size: 36,
                    color: AppTheme.primary,
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  _searchQuery.isNotEmpty
                      ? 'Không tìm thấy câu hỏi phù hợp'
                      : 'Chưa có câu hỏi nào trong kho',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _searchQuery.isNotEmpty
                      ? 'Thử thay đổi từ khóa hoặc xóa bộ lọc đang chọn.'
                      : 'Nhấn nút "Thêm câu hỏi" bên dưới để tạo câu hỏi mới.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 12, left: 4, right: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Hiển thị ${questions.length} câu hỏi',
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                      color: AppTheme.primary,
                    ),
                  ),
                  if (_selectedSubjectId != null ||
                      _selectedDifficulty != null ||
                      _searchQuery.isNotEmpty)
                    InkWell(
                      onTap: () {
                        _searchController.clear();
                        _searchQuery = '';
                        _selectedSubjectId = null;
                        _selectedDifficulty = null;
                        _applyFilters();
                      },
                      borderRadius: BorderRadius.circular(8),
                      child: const Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        child: Text(
                          'Xóa bộ lọc',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.error,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            ...questions.asMap().entries.map(
                  (entry) => _buildQuestionCard(
                    entry.value,
                    entry.key,
                  ),
                ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text(
          'Kho câu hỏi',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            tooltip: 'Tải lại',
            onPressed: _refresh,
            icon: const Icon(Icons.refresh_rounded),
          ),
          IconButton(
            tooltip: 'Thêm câu hỏi',
            onPressed: _openAddQuestion,
            icon: const Icon(Icons.add_circle_outline_rounded),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openAddQuestion,
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text(
          'Thêm câu hỏi',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1000),
          child: RefreshIndicator(
            onRefresh: _refresh,
            color: AppTheme.primary,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildFilters(),
                  const SizedBox(height: 18),
                  _buildQuestionList(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}