import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/theme.dart';
import 'quiz_result_screen.dart';

class QuizExecutionScreen extends StatefulWidget {
  final String quizId;
  final String gameMode;

  const QuizExecutionScreen({
    super.key,
    required this.quizId,
    required this.gameMode,
  });

  @override
  State<QuizExecutionScreen> createState() => _QuizExecutionScreenState();
}

class _QuizExecutionScreenState extends State<QuizExecutionScreen> {
  static const int _defaultExamMinutes = 15;

  final _supabase = Supabase.instance.client;

  var _questions = [];
  bool _isLoading = true;
  bool _isSubmitting = false;
  String? _errorMessage;

  String _quizTitle = 'Bộ đề trắc nghiệm';
  String _subjectName = 'Tổng hợp';

  int _currentIndex = 0;
  Timer? _timer;
  int _timeLeft = _defaultExamMinutes * 60; // Đếm ngược tổng thời gian cả bài (giây)
  int _totalSecondsElapsed = 0;
  Timer? _elapsedTimer;

  final _selectedAnswers = <int, String>{};

  @override
  void initState() {
    super.initState();
    _loadQuestionsFromSupabase();
  }

  Future<void> _loadQuestionsFromSupabase() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // 0. Lấy thông tin bộ đề từ bảng de_thi (dùng * để không lỗi nếu thiếu cột thời gian)
      final dynamic examRow = await _supabase
          .from('de_thi')
          .select('*')
          .eq('id', widget.quizId)
          .maybeSingle();

      int dbMinutes = 0;
      String loadedTitle = 'Bộ đề trắc nghiệm';
      String loadedSubject = 'Tổng hợp';

      if (examRow is Map) {
        final rawMinutes = examRow['thoi_gian_phut'] ??
            examRow['thoi_gian'] ??
            examRow['duration'];
        dbMinutes = (rawMinutes as num?)?.toInt() ?? 0;

        final rawTitle = examRow['tieu_de'] ?? examRow['ten_de'];
        if (rawTitle != null && rawTitle.toString().trim().isNotEmpty) {
          loadedTitle = rawTitle.toString().trim();
        }

        // Lấy tên môn học từ bảng mon_hoc dựa theo mon_hoc_id
        final monHocId = examRow['mon_hoc_id'];
        if (monHocId != null) {
          final dynamic subjectRow = await _supabase
              .from('mon_hoc')
              .select('ten_mon')
              .eq('id', monHocId)
              .maybeSingle();

          if (subjectRow is Map &&
              subjectRow['ten_mon'] != null &&
              subjectRow['ten_mon'].toString().trim().isNotEmpty) {
            loadedSubject = subjectRow['ten_mon'].toString().trim();
          }
        }
      }

      final int totalMinutes = dbMinutes > 0 ? dbMinutes : _defaultExamMinutes;

      // 1. Lấy câu hỏi thuộc đề thi qua bảng trung gian de_thi_cau_hoi
      final dynamic rawLinkRows = await _supabase
          .from('de_thi_cau_hoi')
          .select('thu_tu, cau_hoi(*, dap_an(*))')
          .eq('de_thi_id', widget.quizId)
          .order('thu_tu', ascending: true);

      final loadedQuestions = [];

      if (rawLinkRows is Iterable) {
        for (final row in rawLinkRows) {
          if (row is Map && row['cau_hoi'] is Map) {
            final mapped = _mapQuestionFromDb(
              Map<String, dynamic>.from(row['cau_hoi'] as Map),
            );
            if (mapped != null) {
              loadedQuestions.add(mapped);
            }
          }
        }
      }

      // 2. Fallback: Nếu chưa có trong de_thi_cau_hoi, tìm trực tiếp ở bảng cau_hoi
      if (loadedQuestions.isEmpty) {
        final dynamic rawDirectRows = await _supabase
            .from('cau_hoi')
            .select('*, dap_an(*)')
            .eq('de_thi_id', widget.quizId)
            .order('thu_tu', ascending: true);

        if (rawDirectRows is Iterable) {
          for (final qData in rawDirectRows) {
            if (qData is Map) {
              final mapped = _mapQuestionFromDb(
                Map<String, dynamic>.from(qData),
              );
              if (mapped != null) {
                loadedQuestions.add(mapped);
              }
            }
          }
        }
      }

      if (!mounted) return;

      setState(() {
        _questions = loadedQuestions;
        _quizTitle = loadedTitle;
        _subjectName = loadedSubject;
        _isLoading = false;
        _timeLeft = totalMinutes * 60;
      });

      if (_questions.isNotEmpty) {
        _startElapsedTimer();
        if (widget.gameMode == 'competitive') {
          _startTimer();
        }
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Lỗi tải câu hỏi: $e';
      });
    }
  }

  Map<String, dynamic>? _mapQuestionFromDb(Map<String, dynamic> qData) {
    final dynamic rawList = qData['dap_an'];
    if (rawList is! Iterable || rawList.isEmpty) return null;

    final rawAnswers = rawList
        .whereType()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();

    if (rawAnswers.isEmpty) return null;

    // Sắp xếp đáp án theo thứ tự A, B, C, D
    rawAnswers.sort((a, b) {
      final orderA = (a['thu_tu'] as num?)?.toInt() ?? 0;
      final orderB = (b['thu_tu'] as num?)?.toInt() ?? 0;
      return orderA.compareTo(orderB);
    });

    final options = <String>[];
    String correctAnswer = '';

    for (final ans in rawAnswers) {
      final text = (ans['noi_dung'] ?? '').toString();
      options.add(text);

      // Tự nhận diện cột boolean đánh dấu đáp án đúng
      final bool isCorrect = ans.values.any((val) => val == true);
      if (isCorrect) {
        correctAnswer = text;
      }
    }

    if (correctAnswer.isEmpty && options.isNotEmpty) {
      correctAnswer = options.first;
    }

    return <String, dynamic>{
      'questionText': (qData['noi_dung'] ?? '').toString(),
      'imageUrl': (qData['hinh_anh_url'] ?? '').toString(),
      'options': options,
      'correctAnswer': correctAnswer,
      'explanation':
          (qData['giai_thich'] ?? 'Không có giải thích chi tiết.').toString(),
    };
  }

  void _startElapsedTimer() {
    _elapsedTimer?.cancel();
    _elapsedTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _totalSecondsElapsed++;
    });
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_timeLeft > 0) {
        setState(() => _timeLeft--);
      } else {
        // Hết tổng thời gian -> Tự động nộp bài
        _timer?.cancel();
        _elapsedTimer?.cancel();
        _submitQuiz();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _elapsedTimer?.cancel();
    super.dispose();
  }

  void _previousQuestion() {
    if (_currentIndex > 0) {
      setState(() {
        _currentIndex--;
      });
    }
  }

  void _nextQuestion() {
    if (_currentIndex < _questions.length - 1) {
      setState(() {
        _currentIndex++;
      });
    } else {
      _submitQuiz();
    }
  }

  String _formatDuration(int totalSeconds) {
    final minutes = (totalSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (totalSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  Future<void> _submitQuiz() async {
    if (_isSubmitting) return;
    setState(() => _isSubmitting = true);

    _timer?.cancel();
    _elapsedTimer?.cancel();

    int correctCount = 0;

    for (int i = 0; i < _questions.length; i++) {
      final currentQ = _questions[i] as Map<String, dynamic>;
      if (_selectedAnswers[i] == currentQ['correctAnswer']) {
        correctCount++;
      }
    }

    final int finalScore = _questions.isEmpty
        ? 0
        : (correctCount / _questions.length * 100).round();
    final String formattedTime = _formatDuration(_totalSecondsElapsed);

    // Lưu lịch sử làm bài lên bảng lich_su_thi (nếu chưa đăng nhập sẽ tạm gán 'guest' để dễ test)
    try {
      final String userId = _supabase.auth.currentUser?.id ?? 'guest';
      final Map<String, String> answersJson = _selectedAnswers.map(
        (key, value) => MapEntry(key.toString(), value),
      );

      await _supabase.from('lich_su_thi').insert({
        'user_id': userId,
        'de_thi_id': widget.quizId,
        'ten_de_thi': _quizTitle,
        'mon_hoc': _subjectName,
        'che_do': widget.gameMode,
        'diem_so': finalScore,
        'so_cau_dung': correctCount,
        'tong_so_cau': _questions.length,
        'thoi_gian_lam': formattedTime,
        'chi_tiet_cau_hoi': _questions,
        'dap_an_da_chon': answersJson,
      });
    } catch (e) {
      debugPrint('Lỗi lưu lịch sử làm bài: $e');
    }

    if (!mounted) return;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => QuizResultScreen(
          score: finalScore,
          correctAnswers: correctCount,
          totalQuestions: _questions.length,
          timeTaken: formattedTime,
          questions: _questions,
          selectedAnswers: _selectedAnswers,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Đang tải đề thi...'), centerTitle: true),
        body: const Center(
          child: CircularProgressIndicator(color: AppColors.base),
        ),
      );
    }

    if (_errorMessage != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Lỗi tải đề thi'), centerTitle: true),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  _errorMessage!,
                  style: const TextStyle(color: Colors.redAccent),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _loadQuestionsFromSupabase,
                  child: const Text('Thử lại'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (_questions.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Chi tiết bộ đề'), centerTitle: true),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.inbox_outlined, size: 64, color: Colors.grey),
                const SizedBox(height: 12),
                const Text(
                  'Bộ đề này chưa có câu hỏi nào trên hệ thống.\n(Hãy thử chọn đề môn Địa lý để test 10 - 15 câu mẫu)',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 15, color: Colors.grey),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Quay lại danh sách đề'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final currentQ = _questions[_currentIndex] as Map<String, dynamic>;
    final String questionText = currentQ['questionText'].toString();
    final String imageUrl = currentQ['imageUrl'].toString();
    final options =
        (currentQ['options'] as Iterable).map((e) => e.toString()).toList();
    final bool isLastQuestion = _currentIndex == _questions.length - 1;
    final double progress = (_currentIndex + 1) / _questions.length;
    final bool isLowTime = _timeLeft <= 60; // Cảnh báo đỏ khi còn <= 1 phút

    return Scaffold(
      appBar: AppBar(
        title: Text('Câu hỏi ${_currentIndex + 1}/${_questions.length}'),
        centerTitle: true,
        actions: [
          if (widget.gameMode == 'competitive')
            Padding(
              padding: const EdgeInsets.only(right: 16.0),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: isLowTime
                        ? Colors.redAccent.withValues(alpha: 0.15)
                        : AppColors.interact.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isLowTime ? Colors.redAccent : AppColors.interact,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.timer_outlined,
                        size: 16,
                        color: isLowTime ? Colors.redAccent : AppColors.text,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _formatDuration(_timeLeft),
                        style: AppTextStyles.text.copyWith(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: isLowTime ? Colors.redAccent : AppColors.text,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. THANH TIẾN ĐỘ CÂU HỎI
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 8,
                  backgroundColor: AppColors.base.withValues(alpha: 0.15),
                  valueColor: const AlwaysStoppedAnimation<Color>(AppColors.base),
                ),
              ),
              const SizedBox(height: 20),

              // 2. KHUNG NỘI DUNG CÂU HỎI + ẢNH MINH HỌA
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.base.withValues(alpha: 0.08),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (imageUrl.isNotEmpty) ...[
                      ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: Container(
                          height: 150,
                          width: double.infinity,
                          color: AppColors.background,
                          child: Image.network(
                            imageUrl,
                            fit: BoxFit.contain,
                            errorBuilder: (_, _, _) => const Center(
                              child: Icon(Icons.broken_image_outlined, color: Colors.grey),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                    Text(
                      questionText,
                      style: AppTextStyles.question.copyWith(height: 1.4),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // 3. DANH SÁCH ĐÁP ÁN (A, B, C, D)
              Expanded(
                child: ListView.builder(
                  itemCount: options.length,
                  itemBuilder: (context, index) {
                    final String option = options[index];
                    final bool isSelected = _selectedAnswers[_currentIndex] == option;
                    final String optionLabel = String.fromCharCode(65 + index);

                    return GestureDetector(
                      onTap: _isSubmitting
                          ? null
                          : () {
                              setState(() {
                                _selectedAnswers[_currentIndex] = option;
                              });
                            },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        decoration: BoxDecoration(
                          color: isSelected ? AppColors.base : Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isSelected ? AppColors.base : Colors.grey.shade300,
                            width: isSelected ? 2 : 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: isSelected
                                  ? AppColors.base.withValues(alpha: 0.25)
                                  : Colors.black.withValues(alpha: 0.03),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 34,
                              height: 34,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? Colors.white.withValues(alpha: 0.2)
                                    : AppColors.background,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                optionLabel,
                                style: AppTextStyles.answer.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: isSelected ? Colors.white : AppColors.base,
                                ),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Text(
                                option,
                                style: AppTextStyles.answer.copyWith(
                                  color: isSelected ? Colors.white : AppColors.text,
                                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                                ),
                              ),
                            ),
                            if (isSelected)
                              const Icon(
                                Icons.check_circle_rounded,
                                color: Colors.white,
                                size: 22,
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),

              const SizedBox(height: 12),

              // 4. THANH ĐIỀU HƯỚNG: QUAY LẠI & TIẾP THEO / NỘP BÀI
              Row(
                children: [
                  if (_currentIndex > 0) ...[
                    Expanded(
                      flex: 2,
                      child: SizedBox(
                        height: 56,
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.base,
                            side: const BorderSide(color: AppColors.base, width: 1.5),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          onPressed: _isSubmitting ? null : _previousQuestion,
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.arrow_back_rounded, size: 20),
                              SizedBox(width: 6),
                              Text(
                                'TRƯỚC',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                  ],
                  Expanded(
                    flex: 3,
                    child: SizedBox(
                      height: 56,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.base,
                          foregroundColor: Colors.white,
                          elevation: 2,
                          shadowColor: AppColors.base.withValues(alpha: 0.4),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        onPressed: _isSubmitting ? null : _nextQuestion,
                        child: _isSubmitting
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  color: Colors.white,
                                ),
                              )
                            : Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    isLastQuestion ? 'NỘP BÀI' : 'TIẾP THEO',
                                    style: AppTextStyles.button.copyWith(
                                      fontSize: 17,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Icon(
                                    isLastQuestion
                                        ? Icons.check_rounded
                                        : Icons.arrow_forward_rounded,
                                    size: 22,
                                    color: Colors.white,
                                  ),
                                ],
                              ),
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
}