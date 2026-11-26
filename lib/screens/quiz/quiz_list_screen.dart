import 'package:material_ui/material_ui.dart';
import '../../models/exam_model.dart';
import '../../services/exam_service.dart';
import 'quiz_taking_screen.dart';

class QuizListScreen extends StatefulWidget {
  final String? subjectId;
  final String? subjectName;
  final String? initialSearchQuery;

  const QuizListScreen({
    super.key,
    this.subjectId,
    this.subjectName,
    this.initialSearchQuery,
  });

  @override
  State<QuizListScreen> createState() => _QuizListScreenState();
}

class _QuizListScreenState extends State<QuizListScreen> {
  late final TextEditingController _searchController;
  String _selectedDifficultyLabel = 'Tất cả';

  final Map<String, String?> _difficultyMap = {
    'Tất cả': null,
    'Dễ': 'de',
    'Trung bình': 'trung_binh',
    'Khó': 'kho',
  };

  late Future<List<ExamModel>> _examsFuture;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(
      text: widget.initialSearchQuery ?? '',
    );
    _fetchExams();
  }

  void _fetchExams() {
    setState(() {
      _examsFuture = ExamService.getPublishedExams(
        subjectId: widget.subjectId,
        difficulty: _difficultyMap[_selectedDifficultyLabel],
        searchQuery: _searchController.text,
      );
    });
  }

  Color _getDifficultyColor(String? code) {
    switch (code) {
      case 'de':
        return Colors.green;
      case 'kho':
        return Colors.red;
      case 'trung_binh':
      default:
        return Colors.orange;
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.subjectName != null && widget.subjectName!.isNotEmpty
        ? 'Đề thi: ${widget.subjectName}'
        : 'Danh sách bộ đề';

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        foregroundColor: const Color(0xFF1E293B),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
      ),
      body: Column(
        children: [
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Column(
              children: [
                TextField(
                  controller: _searchController,
                  textInputAction: TextInputAction.search,
                  onSubmitted: (_) => _fetchExams(),
                  onChanged: (val) {
                    if (val.isEmpty) _fetchExams();
                  },
                  decoration: InputDecoration(
                    hintText: 'Tìm kiếm tên đề thi...',
                    prefixIcon: const Icon(Icons.search, color: Colors.grey),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.arrow_forward_rounded),
                      onPressed: _fetchExams,
                    ),
                    filled: true,
                    fillColor: const Color(0xFFF1F5F9),
                    contentPadding: const EdgeInsets.symmetric(vertical: 0),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 36,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _difficultyMap.keys.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 8),
                    itemBuilder: (context, index) {
                      final label = _difficultyMap.keys.elementAt(index);
                      final isSelected = _selectedDifficultyLabel == label;
                      return ChoiceChip(
                        label: Text(label),
                        selected: isSelected,
                        selectedColor: const Color(0xFF4F46E5),
                        backgroundColor: const Color(0xFFF1F5F9),
                        labelStyle: TextStyle(
                          color: isSelected
                              ? Colors.white
                              : const Color(0xFF475569),
                          fontWeight: FontWeight.w600,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                          side: BorderSide.none,
                        ),
                        onSelected: (_) {
                          _selectedDifficultyLabel = label;
                          _fetchExams();
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: FutureBuilder<List<ExamModel>>(
              future: _examsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '${snapshot.error}',
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Colors.red),
                          ),
                          const SizedBox(height: 12),
                          ElevatedButton.icon(
                            onPressed: _fetchExams,
                            icon: const Icon(Icons.refresh),
                            label: const Text('Thử lại'),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                final exams = snapshot.data ?? [];
                if (exams.isEmpty) {
                  return const Center(
                    child: Text(
                      'Chưa có đề thi nào phù hợp.',
                      style: TextStyle(color: Colors.grey, fontSize: 15),
                    ),
                  );
                }

                return RefreshIndicator(
                  onRefresh: () async => _fetchExams(),
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: exams.length,
                    itemBuilder: (context, index) {
                      final exam = exams[index];
                      final badgeColor = _getDifficultyColor(exam.mucDo);

                      return Container(
                        margin: const EdgeInsets.only(bottom: 14),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.04),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Text(
                                    exam.tieuDe,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF1E293B),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: badgeColor.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    exam.mucDoDisplay,
                                    style: TextStyle(
                                      color: badgeColor,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            if (exam.moTa != null &&
                                exam.moTa!.trim().isNotEmpty) ...[
                              const SizedBox(height: 6),
                              Text(
                                exam.moTa!,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: Color(0xFF64748B),
                                ),
                              ),
                            ],
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                const Icon(
                                  Icons.help_outline,
                                  size: 16,
                                  color: Colors.grey,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '${exam.soLuongCauHoi ?? 0} câu hỏi',
                                  style: const TextStyle(
                                    color: Colors.grey,
                                    fontSize: 13,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                const Text(
                                  '•',
                                  style: TextStyle(color: Colors.grey),
                                ),
                                const SizedBox(width: 12),
                                const Icon(
                                  Icons.timer_outlined,
                                  size: 16,
                                  color: Colors.grey,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '${exam.thoiGianPhut} phút',
                                  style: const TextStyle(
                                    color: Colors.grey,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF4F46E5),
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          QuizTakingScreen(exam: exam),
                                    ),
                                  );
                                },
                                child: const Text(
                                  'Làm ngay',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}