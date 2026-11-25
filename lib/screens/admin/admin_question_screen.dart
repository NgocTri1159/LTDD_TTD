
import 'package:material_ui/material_ui.dart';

import '../../models/question_model.dart';
import '../../models/subject_model.dart';
import '../../services/admin_service.dart';
import 'admin_question_form_screen.dart';

class AdminQuestionScreen extends StatefulWidget {
  const AdminQuestionScreen({super.key});

  @override
  State<AdminQuestionScreen> createState() => _AdminQuestionScreenState();
}

class _AdminQuestionScreenState extends State<AdminQuestionScreen> {
  static const Color primaryColor = Color(0xFF6257E8);

  late Future<List<SubjectModel>> _subjectsFuture;
  late Future<List<QuestionModel>> _questionsFuture;

  String? _selectedSubjectId;
  String? _selectedDifficulty;

  @override
  void initState() {
    super.initState();
    _subjectsFuture = AdminService.getAllSubjectsAdmin();
    _loadQuestions();
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

  /// Mở form tạo câu hỏi mới.
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
        return Colors.green;
      case 'kho':
        return Colors.red;
      default:
        return Colors.orange;
    }
  }

  Widget _buildFilters() {
    return FutureBuilder<List<SubjectModel>>(
      future: _subjectsFuture,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Text(
            'Không tải được danh sách môn học: ${snapshot.error}',
          );
        }

        final subjects = snapshot.data ?? [];

        return Column(
          children: [
            DropdownButtonFormField<String?>(
              initialValue: _selectedSubjectId,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Lọc theo môn học',
                prefixIcon: Icon(Icons.menu_book_outlined),
                border: OutlineInputBorder(),
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
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String?>(
              initialValue: _selectedDifficulty,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Lọc theo độ khó',
                prefixIcon: Icon(Icons.tune),
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem<String?>(
                  value: null,
                  child: Text('Tất cả độ khó'),
                ),
                DropdownMenuItem<String?>(
                  value: 'de',
                  child: Text('Dễ'),
                ),
                DropdownMenuItem<String?>(
                  value: 'trung_binh',
                  child: Text('Trung bình'),
                ),
                DropdownMenuItem<String?>(
                  value: 'kho',
                  child: Text('Khó'),
                ),
              ],
              onChanged: (value) {
                _selectedDifficulty = value;
                _applyFilters();
              },
            ),
          ],
        );
      },
    );
  }

  Widget _buildQuestionCard(QuestionModel question, int index) {
    final answerCount = question.danhSachDapAn.length;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 17,
                  backgroundColor: primaryColor.withValues(alpha: 0.12),
                  child: Text(
                    '${index + 1}',
                    style: const TextStyle(
                      color: primaryColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    question.loaiCauHoi?.tenLoai ?? 'Câu hỏi',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Chip(
                  label: Text(_difficultyLabel(question.mucDo)),
                  labelStyle: TextStyle(
                    color: _difficultyColor(question.mucDo),
                    fontSize: 12,
                  ),
                  backgroundColor: _difficultyColor(
                    question.mucDo,
                  ).withValues(alpha: 0.1),
                  side: BorderSide.none,
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              question.noiDung,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
            ),
            if (question.hinhAnhUrl != null &&
                question.hinhAnhUrl!.isNotEmpty) ...[
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  question.hinhAnhUrl!,
                  height: 150,
                  width: double.infinity,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) =>
                      const Text('Không thể tải hình ảnh câu hỏi'),
                ),
              ),
            ],
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _infoChip(Icons.star_outline, '${question.diem} điểm'),
                _infoChip(Icons.list_alt, '$answerCount đáp án'),
                if (question.thoiGianGiay != null)
                  _infoChip(
                    Icons.timer_outlined,
                    '${question.thoiGianGiay} giây',
                  ),
                if (question.amThanhUrl != null &&
                    question.amThanhUrl!.isNotEmpty)
                  _infoChip(
                    Icons.volume_up_outlined,
                    'Có âm thanh',
                  ),
              ],
            ),
            const SizedBox(height: 8),
            if (question.danhSachDapAn.isNotEmpty)
              ExpansionTile(
                tilePadding: EdgeInsets.zero,
                title: const Text('Xem danh sách đáp án'),
                children: question.danhSachDapAn.map((answer) {
                  return ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      answer.laDung
                          ? Icons.check_circle
                          : Icons.circle_outlined,
                      color: answer.laDung ? Colors.green : Colors.grey,
                    ),
                    title: Text(answer.noiDung),
                    subtitle: answer.laDung
                        ? const Text(
                            'Đáp án đúng',
                            style: TextStyle(color: Colors.green),
                          )
                        : null,
                  );
                }).toList(),
              ),
          ],
        ),
      ),
    );
  }

  Widget _infoChip(IconData icon, String label) {
    return Chip(
      avatar: Icon(icon, size: 16),
      label: Text(label),
      visualDensity: VisualDensity.compact,
      side: BorderSide.none,
      backgroundColor: Colors.grey.withValues(alpha: 0.1),
    );
  }

  Widget _buildQuestionList() {
    return FutureBuilder<List<QuestionModel>>(
      future: _questionsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: CircularProgressIndicator(),
            ),
          );
        }

        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  const Icon(
                    Icons.error_outline,
                    color: Colors.red,
                    size: 42,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Không thể tải kho câu hỏi:\n${snapshot.error}',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: _applyFilters,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Thử lại'),
                  ),
                ],
              ),
            ),
          );
        }

        final questions = snapshot.data ?? [];

        if (questions.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: Column(
                children: [
                  Icon(
                    Icons.quiz_outlined,
                    size: 56,
                    color: Colors.grey,
                  ),
                  SizedBox(height: 12),
                  Text(
                    'Chưa có câu hỏi nào trong kho.',
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                'Tìm thấy ${questions.length} câu hỏi',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: primaryColor,
                ),
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
      appBar: AppBar(
        title: const Text('Kho câu hỏi'),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            tooltip: 'Thêm câu hỏi',
            onPressed: _openAddQuestion,
            icon: const Icon(Icons.add),
          ),
          IconButton(
            tooltip: 'Tải lại',
            onPressed: _refresh,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildFilters(),
              const SizedBox(height: 24),
              _buildQuestionList(),
            ],
          ),
        ),
      ),
    );
  }
}
