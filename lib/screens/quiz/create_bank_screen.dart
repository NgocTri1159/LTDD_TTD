import 'dart:core';
import 'dart:core' as core;
import 'package:material_ui/material_ui.dart';
import '../../services/quiz_service.dart';

class QuestionBankScreen extends StatefulWidget {
  const QuestionBankScreen({super.key});

  @override
  State<QuestionBankScreen> createState() => _QuestionBankScreenState();
}

class _QuestionBankScreenState extends State<QuestionBankScreen> {
  core.List<core.Map<String, dynamic>> _subjects = [];
  core.List<core.Map<String, dynamic>> _questions = [];
  String? _selectedSubjectId;
  bool _isLoadingSubjects = true;
  bool _isLoadingQuestions = false;
  String _searchQuery = '';

  static const Color primaryPurple = Color(0xFF565CEB);
  static const Color cardLavender = Color(0xFFECEEFF);
  static const Color darkText = Color(0xFF1E1E2C);
  static const Color pageBg = Color(0xFFF9FAFF);

  @override
  void initState() {
    super.initState();
    _loadSubjects();
  }

  core.Future<void> _loadSubjects() async {
    try {
      final list = await QuizService.getSubjects();
      if (!mounted) return;
      setState(() {
        _subjects = list;
        _isLoadingSubjects = false;
        if (_subjects.isNotEmpty) {
          _selectedSubjectId = _subjects.first['id'].toString();
        }
      });
      if (_selectedSubjectId != null) {
        await _loadQuestions(_selectedSubjectId!);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoadingSubjects = false);
      _showError(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  core.Future<void> _loadQuestions(String subjectId) async {
    setState(() => _isLoadingQuestions = true);
    try {
      final data = await QuizService.getQuestionsBySubject(subjectId);
      if (!mounted) return;
      setState(() {
        _questions = data;
        _isLoadingQuestions = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _questions = [];
        _isLoadingQuestions = false;
      });
      _showError(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: const Color(0xFFD32F2F),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  bool _isCorrectAnswer(core.Map ans) {
    return ans['la_dap_an_dung'] == true ||
        ans['is_correct'] == true ||
        ans['dung_sai'] == true ||
        ans['is_dung'] == true ||
        ans['dung'] == true;
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _questions.where((q) {
      if (_searchQuery.trim().isEmpty) return true;
      final content = (q['noi_dung']?.toString() ?? '').toLowerCase();
      return content.contains(_searchQuery.trim().toLowerCase());
    }).toList();

    return Scaffold(
      backgroundColor: pageBg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        title: const Text(
          'Kho Câu Hỏi',
          style: TextStyle(
            color: darkText,
            fontWeight: FontWeight.w800,
            fontSize: 18,
          ),
        ),
        iconTheme: const IconThemeData(color: darkText),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: Column(
            children: [
              Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE3E6FA)),
                ),
                child: Column(
                  children: [
                    _isLoadingSubjects
                        ? const LinearProgressIndicator(color: primaryPurple)
                        : DropdownButtonFormField<String>(
                            initialValue: _selectedSubjectId,
                            decoration: InputDecoration(
                              labelText: 'Chọn môn học',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            items: _subjects.map((sub) {
                              return DropdownMenuItem<String>(
                                value: sub['id'].toString(),
                                child: Text(sub['ten_mon']?.toString() ?? ''),
                              );
                            }).toList(),
                            onChanged: (val) {
                              if (val == null) return;
                              setState(() => _selectedSubjectId = val);
                              _loadQuestions(val);
                            },
                          ),
                    const SizedBox(height: 10),
                    TextField(
                      onChanged: (val) => setState(() => _searchQuery = val),
                      decoration: InputDecoration(
                        hintText: 'Tìm nội dung câu hỏi...',
                        prefixIcon: const Icon(Icons.search_rounded),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                child: Row(
                  children: [
                    Text(
                      'Tìm thấy ${filtered.length} câu hỏi',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: primaryPurple,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: _isLoadingQuestions
                    ? const Center(
                        child: CircularProgressIndicator(color: primaryPurple),
                      )
                    : filtered.isEmpty
                        ? const Center(
                            child: Text(
                              'Không có câu hỏi nào cho môn học này.',
                              style: TextStyle(color: Colors.grey),
                            ),
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                            itemCount: filtered.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(height: 12),
                            itemBuilder: (_, idx) {
                              final q = filtered[idx];
                              final answers =
                                  (q['dap_an'] as core.List?) ?? [];
                              return Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: const Color(0xFFE3E6FA),
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: cardLavender,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        'Câu ${idx + 1}',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                          color: primaryPurple,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      q['noi_dung']?.toString() ?? '',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 15,
                                        color: darkText,
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    ...answers.map((raw) {
                                      if (raw is! core.Map) {
                                        return const SizedBox.shrink();
                                      }
                                      final isRight = _isCorrectAnswer(raw);
                                      return Container(
                                        margin:
                                            const EdgeInsets.only(bottom: 6),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 8,
                                        ),
                                        decoration: BoxDecoration(
                                          color: isRight
                                              ? const Color(0xFFE8F5E9)
                                              : const Color(0xFFF7F8FC),
                                          borderRadius:
                                              BorderRadius.circular(10),
                                        ),
                                        child: Row(
                                          children: [
                                            Icon(
                                              isRight
                                                  ? Icons.check_circle_rounded
                                                  : Icons
                                                      .radio_button_unchecked,
                                              size: 18,
                                              color: isRight
                                                  ? const Color(0xFF2E7D32)
                                                  : Colors.grey,
                                            ),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: Text(
                                                raw['noi_dung']?.toString() ??
                                                    '',
                                                style: TextStyle(
                                                  fontWeight: isRight
                                                      ? FontWeight.w600
                                                      : FontWeight.normal,
                                                  color: darkText,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    }),
                                  ],
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