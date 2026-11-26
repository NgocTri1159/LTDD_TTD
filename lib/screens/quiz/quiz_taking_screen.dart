import 'dart:async';
import 'package:material_ui/material_ui.dart';
import '../../models/exam_model.dart';
import '../../models/game_mode_model.dart';
import '../../models/question_model.dart';
import '../../models/quiz_attempt_model.dart';
import '../../services/exam_service.dart';
import '../../services/quiz_service.dart';
import 'quiz_result_screen.dart';

class QuizTakingScreen extends StatefulWidget {
  final ExamModel exam;
  final String? gameModeId;

  const QuizTakingScreen({
    super.key,
    required this.exam,
    this.gameModeId,
  });

  @override
  State<QuizTakingScreen> createState() => _QuizTakingScreenState();
}

class _QuizTakingScreenState extends State<QuizTakingScreen> {
  final PageController _pageController = PageController();

  bool _isLoading = true;
  bool _isSubmitting = false;
  String? _errorMessage;

  List<QuestionModel> _questions = [];
  QuizAttemptModel? _attempt;

  int _currentIndex = 0;
  final Map<String, Set<String>> _selectedAnswers = {};

  late int _remainingSeconds;
  DateTime? _startedAt;
  Timer? _timer;

  final List<String> _optionLabels = ['A', 'B', 'C', 'D', 'E', 'F'];

  @override
  void initState() {
    super.initState();
    _initQuiz();
  }

  Future<void> _initQuiz() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final results = await Future.wait([
        ExamService.getExamQuestions(widget.exam.id),
        QuizService.getActiveGameModes(),
      ]);

      final questions = results[0] as List<QuestionModel>;
      final modes = results[1] as List<GameModeModel>;

      if (questions.isEmpty) {
        throw Exception('Đề thi này chưa có câu hỏi nào.');
      }

      String resolvedModeId = widget.gameModeId ?? '';
      if (resolvedModeId.isEmpty) {
        if (modes.isEmpty) {
          throw Exception('Chưa cấu hình chế độ chơi trên hệ thống.');
        }
        final soloMode = modes.firstWhere(
          (m) =>
              m.tenCheDo.toLowerCase().contains('solo') ||
              m.tenCheDo.toLowerCase().contains('luyện'),
          orElse: () => modes.first,
        );
        resolvedModeId = soloMode.id;
      }

      final attempt = await QuizService.startAttempt(
        examId: widget.exam.id,
        gameModeId: resolvedModeId,
      );

      if (!mounted) return;

      final durationSecs = widget.exam.thoiGianLamBaiGiay > 0
          ? widget.exam.thoiGianLamBaiGiay
          : 900;

      setState(() {
        _questions = questions;
        _attempt = attempt;
        _remainingSeconds = durationSecs;
        _startedAt = DateTime.now();
        _isLoading = false;
      });

      _startTimer();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingSeconds > 0) {
        setState(() => _remainingSeconds--);
      } else {
        _timer?.cancel();
        _submitQuiz();
      }
    });
  }

  String _formatTime(int seconds) {
    final mins = (seconds ~/ 60).toString().padLeft(2, '0');
    final secs = (seconds % 60).toString().padLeft(2, '0');
    return '$mins:$secs';
  }

  Future<void> _confirmSubmit() async {
    final unanswered = _questions.length - _selectedAnswers.length;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Nộp bài thi'),
        content: Text(
          unanswered > 0
              ? 'Bạn còn $unanswered câu chưa chọn đáp án. Bạn vẫn muốn nộp bài chứ?'
              : 'Bạn đã trả lời tất cả câu hỏi. Xác nhận nộp bài?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Làm tiếp'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4F46E5),
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Nộp bài'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _submitQuiz();
    }
  }

  Future<void> _submitQuiz() async {
    if (_isSubmitting || _attempt == null) return;

    _timer?.cancel();
    setState(() => _isSubmitting = true);

    try {
      final timeSpent = _startedAt != null
          ? DateTime.now().difference(_startedAt!).inSeconds
          : (widget.exam.thoiGianLamBaiGiay - _remainingSeconds);

      final questionDetails = _questions.map((q) {
        final selectedIds = _selectedAnswers[q.id]?.toList() ?? <String>[];
        return {
          'cau_hoi_id': q.id,
          'dap_an_da_chon':
              selectedIds.map((id) => {'dap_an_id': id}).toList(),
        };
      }).toList();

      final result = await QuizService.submitAttempt(
        attemptId: _attempt!.id,
        timeSpentSeconds: timeSpent,
        totalScore: 0,
        correctCount: 0,
        wrongCount: 0,
        totalQuestions: _questions.length,
        questionDetails: questionDetails,
      );

      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => QuizResultScreen(
            examTitle: widget.exam.tieuDe,
            result: result,
            fallbackQuestions: _questions,
            fallbackSelectedAnswers: _selectedAnswers,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<bool> _confirmExit() async {
    final shouldExit = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Thoát bài làm?'),
        content: const Text(
          'Tiến trình làm bài hiện tại sẽ không được lưu nếu bạn thoát ngay bây giờ.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Ở lại'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Thoát'),
          ),
        ],
      ),
    );
    return shouldExit ?? false;
  }

  void _showQuestionGrid() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Danh sách câu hỏi',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            GridView.builder(
              shrinkWrap: true,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 5,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
              ),
              itemCount: _questions.length,
              itemBuilder: (context, index) {
                final qId = _questions[index].id;
                final isAnswered = (_selectedAnswers[qId]?.isNotEmpty ?? false);
                final isCurrent = index == _currentIndex;
                return InkWell(
                  onTap: () {
                    Navigator.pop(context);
                    _pageController.jumpToPage(index);
                  },
                  child: Container(
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: isAnswered
                          ? const Color(0xFF4F46E5)
                          : const Color(0xFFF1F5F9),
                      border: isCurrent
                          ? Border.all(color: Colors.orange, width: 2.5)
                          : null,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${index + 1}',
                      style: TextStyle(
                        color:
                            isAnswered ? Colors.white : const Color(0xFF334155),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFFF8FAFC),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Đang chuẩn bị đề thi...'),
            ],
          ),
        ),
      );
    }

    if (_errorMessage != null) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.exam.tieuDe)),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _errorMessage!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.red, fontSize: 15),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _initQuiz,
                  child: const Text('Thử lại'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final progress = (_currentIndex + 1) / _questions.length;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final navigator = Navigator.of(context);
        if (await _confirmExit() && mounted) {
          navigator.pop();
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          foregroundColor: const Color(0xFF1E293B),
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: () async {
              final navigator = Navigator.of(context);
              if (await _confirmExit() && mounted) {
                navigator.pop();
              }
            },
          ),
          title: Text(
            'Câu ${_currentIndex + 1}/${_questions.length}',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
          ),
          centerTitle: true,
          actions: [
            Container(
              margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFFECACA)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.timer, size: 16, color: Color(0xFFEF4444)),
                  const SizedBox(width: 4),
                  Text(
                    _formatTime(_remainingSeconds),
                    style: const TextStyle(
                      color: Color(0xFFEF4444),
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ],
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(4),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: const Color(0xFFE2E8F0),
              valueColor:
                  const AlwaysStoppedAnimation<Color>(Color(0xFF4F46E5)),
            ),
          ),
        ),
        body: Stack(
          children: [
            PageView.builder(
              controller: _pageController,
              itemCount: _questions.length,
              onPageChanged: (index) => setState(() => _currentIndex = index),
              itemBuilder: (context, qIndex) {
                final question = _questions[qIndex];
                final answers = question.danhSachDapAn;
                final selectedSet = _selectedAnswers[question.id] ?? {};

                return SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
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
                            Text(
                              'Câu ${qIndex + 1}: ${question.noiDung}',
                              style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF1E293B),
                                height: 1.4,
                              ),
                            ),
                            if (question.hinhAnhUrl != null &&
                                question.hinhAnhUrl!.trim().isNotEmpty) ...[
                              const SizedBox(height: 14),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Image.network(
                                  question.hinhAnhUrl!,
                                  fit: BoxFit.contain,
                                  errorBuilder: (_, _, _) =>
                                      const SizedBox.shrink(),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      ...List.generate(answers.length, (optIndex) {
                        final answer = answers[optIndex];
                        final isSelected = selectedSet.contains(answer.id);
                        final label = optIndex < _optionLabels.length
                            ? _optionLabels[optIndex]
                            : '${optIndex + 1}';

                        return GestureDetector(
                          onTap: () {
                            setState(() {
                              _selectedAnswers[question.id] = {answer.id};
                            });
                          },
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? const Color(0xFFEEF2FF)
                                  : Colors.white,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: isSelected
                                    ? const Color(0xFF4F46E5)
                                    : const Color(0xFFE2E8F0),
                                width: isSelected ? 2 : 1,
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 34,
                                  height: 34,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: isSelected
                                        ? const Color(0xFF4F46E5)
                                        : const Color(0xFFF1F5F9),
                                  ),
                                  child: Text(
                                    label,
                                    style: TextStyle(
                                      color: isSelected
                                          ? Colors.white
                                          : const Color(0xFF475569),
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Text(
                                    answer.noiDung,
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: isSelected
                                          ? FontWeight.w600
                                          : FontWeight.normal,
                                      color: const Color(0xFF1E293B),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }),
                    ],
                  ),
                );
              },
            ),
            if (_isSubmitting)
              Container(
                color: Colors.black26,
                child: const Center(child: CircularProgressIndicator()),
              ),
          ],
        ),
        bottomNavigationBar: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: SafeArea(
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: _currentIndex > 0
                        ? () => _pageController.previousPage(
                              duration: const Duration(milliseconds: 250),
                              curve: Curves.easeInOut,
                            )
                        : null,
                    child: const Text('Câu trước'),
                  ),
                ),
                const SizedBox(width: 12),
                IconButton.filledTonal(
                  onPressed: _showQuestionGrid,
                  icon: const Icon(Icons.grid_view_rounded),
                  tooltip: 'Danh sách câu',
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _currentIndex == _questions.length - 1
                          ? const Color(0xFF10B981)
                          : const Color(0xFF4F46E5),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: _isSubmitting
                        ? null
                        : () {
                            if (_currentIndex < _questions.length - 1) {
                              _pageController.nextPage(
                                duration: const Duration(milliseconds: 250),
                                curve: Curves.easeInOut,
                              );
                            } else {
                              _confirmSubmit();
                            }
                          },
                    child: Text(
                      _currentIndex == _questions.length - 1
                          ? 'Nộp bài'
                          : 'Câu tiếp',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}