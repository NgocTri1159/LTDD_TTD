import 'package:flutter/material.dart';
import '../../controllers/admin_room_controller.dart';
import '../../core/theme.dart';
import '../../models/room_model.dart';

class AdminSelectExamScreen extends StatefulWidget {
  final String? currentExamId;
  const AdminSelectExamScreen({super.key, this.currentExamId});

  @override
  State<AdminSelectExamScreen> createState() => _AdminSelectExamScreenState();
}

class _AdminSelectExamScreenState extends State<AdminSelectExamScreen> {
  final _searchController = TextEditingController();

  List<RoomExamOption> _exams = [];
  bool _loading = true;
  bool _searching = false;
  String _searchQuery = '';
  String _selectedSubject = 'Tất cả';
  String? _selectedExamId;

  static const List<Color> _palette = [
    Color(0xFF3B82F6),
    Color(0xFF8B5CF6),
    Color(0xFF10B981),
    Color(0xFFF59E0B),
    Color(0xFF06B6D4),
    Color(0xFFEC4899),
  ];

  @override
  void initState() {
    super.initState();
    _selectedExamId = widget.currentExamId;
    _loadExams();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadExams() async {
    setState(() => _loading = true);
    try {
      final list = await AdminRoomController.instance.fetchExamOptions();
      if (!mounted) return;
      setState(() {
        _exams = list;
        if (_selectedExamId == null && list.isNotEmpty) {
          _selectedExamId = list.first.id;
        }
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Lỗi tải danh sách bộ đề: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  List<String> get _subjects {
    final set = <String>{'Tất cả'};
    for (final e in _exams) {
      if (e.tenMon.trim().isNotEmpty) {
        set.add(e.tenMon.trim());
      }
    }
    return set.toList();
  }

  List<RoomExamOption> get _filteredExams {
    return _exams.where((e) {
      final matchSub =
          _selectedSubject == 'Tất cả' || e.tenMon.trim() == _selectedSubject;
      final q = _searchQuery.trim().toLowerCase();
      final matchQuery = q.isEmpty ||
          e.tieuDe.toLowerCase().contains(q) ||
          e.tenMon.toLowerCase().contains(q);
      return matchSub && matchQuery;
    }).toList();
  }

  Color _colorForSubject(String subject) {
    return _palette[subject.hashCode.abs() % _palette.length];
  }

  IconData _iconForSubject(String subject) {
    final lower = subject.toLowerCase();
    if (lower.contains('toán')) return Icons.calculate_outlined;
    if (lower.contains('văn')) return Icons.auto_stories_outlined;
    if (lower.contains('anh') || lower.contains('ngoại ngữ')) {
      return Icons.language_rounded;
    }
    if (lower.contains('địa')) return Icons.terrain_outlined;
    if (lower.contains('sử')) return Icons.account_balance_outlined;
    if (lower.contains('lập trình') || lower.contains('tin')) {
      return Icons.code_rounded;
    }
    return Icons.quiz_outlined;
  }

  @override
  Widget build(BuildContext context) {
    final exams = _filteredExams;
    final subjects = _subjects;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppColors.text),
          onPressed: () => Navigator.pop(context),
        ),
        title: _searching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                style: AppTextStyles.text.copyWith(color: AppColors.text),
                decoration: InputDecoration(
                  hintText: 'Tìm bộ đề...',
                  hintStyle: TextStyle(color: Colors.grey.shade500),
                  border: InputBorder.none,
                ),
                onChanged: (val) => setState(() => _searchQuery = val),
              )
            : Text(
                'Chọn bộ đề',
                style: AppTextStyles.question.copyWith(
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                  color: AppColors.text,
                ),
              ),
        actions: [
          IconButton(
            icon: Icon(
              _searching ? Icons.close_rounded : Icons.search_rounded,
              color: AppColors.text,
            ),
            onPressed: () {
              setState(() {
                _searching = !_searching;
                if (!_searching) {
                  _searchQuery = '';
                  _searchController.clear();
                }
              });
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Dải chip lọc môn học
          SizedBox(
            height: 42,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: subjects.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, index) {
                final sub = subjects[index];
                final isSelected = _selectedSubject == sub;
                final accent = sub == 'Tất cả'
                    ? AppColors.interact
                    : _colorForSubject(sub);

                return GestureDetector(
                  onTap: () => setState(() => _selectedSubject = sub),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: isSelected ? accent : Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isSelected ? accent : Colors.grey.shade300,
                      ),
                    ),
                    child: Text(
                      sub,
                      style: AppTextStyles.text.copyWith(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: isSelected ? Colors.white : AppColors.text,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          const SizedBox(height: 10),

          // Danh sách bộ đề
          Expanded(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(color: AppColors.base),
                  )
                : exams.isEmpty
                    ? Center(
                        child: Text(
                          'Không tìm thấy bộ đề phù hợp.',
                          style: TextStyle(color: Colors.grey.shade500),
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                        itemCount: exams.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (_, index) {
                          final exam = exams[index];
                          final isSelected = exam.id == _selectedExamId;
                          final accent = _colorForSubject(exam.tenMon);

                          return GestureDetector(
                            onTap: () =>
                                setState(() => _selectedExamId = exam.id),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 160),
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: isSelected
                                      ? AppColors.base
                                      : Colors.grey.shade200,
                                  width: isSelected ? 2 : 1,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: (isSelected ? AppColors.base : accent)
                                        .withValues(alpha: 0.08),
                                    blurRadius: 12,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 60,
                                    height: 60,
                                    decoration: BoxDecoration(
                                      color: accent.withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: Icon(
                                      _iconForSubject(exam.tenMon),
                                      color: accent,
                                      size: 28,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          exam.tieuDe,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style:
                                              AppTextStyles.question.copyWith(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w800,
                                            color: AppColors.text,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          'Chủ đề: ${exam.tenMon}',
                                          style: TextStyle(
                                            fontSize: 12.5,
                                            color: Colors.grey.shade700,
                                          ),
                                        ),
                                        Text(
                                          'Số câu hỏi: ${exam.soCau}',
                                          style: TextStyle(
                                            fontSize: 12.5,
                                            color: Colors.grey.shade700,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Icon(
                                    isSelected
                                        ? Icons.check_circle_rounded
                                        : Icons.radio_button_unchecked_rounded,
                                    color: isSelected
                                        ? AppColors.base
                                        : Colors.grey.shade300,
                                    size: 24,
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),

          // Nút xác nhận "Chọn bộ đề này" ở đáy màn hình
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.interact,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(22),
                    ),
                  ),
                  onPressed: _selectedExamId == null
                      ? null
                      : () => Navigator.pop(context, _selectedExamId),
                  child: const Text(
                    'Chọn bộ đề này',
                    style: TextStyle(
                      fontSize: 15.5,
                      fontWeight: FontWeight.w800,
                    ),
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