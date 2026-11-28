import 'package:flutter/material.dart';
import '../../core/theme.dart';
import '../../models/exam_model.dart';
import '../../models/quiz_model.dart';
import 'quiz_execution_screen.dart';

class QuizDetailScreen extends StatefulWidget {
  final ExamModel? exam;
  final QuizModel? quiz;

  const QuizDetailScreen({
    super.key,
    this.exam,
    this.quiz,
  }) : assert(exam != null || quiz != null, 'Cần truyền exam hoặc quiz');

  @override
  State<QuizDetailScreen> createState() => _QuizDetailScreenState();
}

class _QuizDetailScreenState extends State<QuizDetailScreen> {
  // Chế độ chơi mặc định: 'practice' (Luyện tập)
  String _selectedMode = 'practice';

  String get _quizId => widget.exam?.id ?? widget.quiz!.id;
  String get _title => widget.exam?.tenDe ?? widget.quiz!.title;
  String get _subjectName => widget.exam?.tenMon ?? widget.quiz!.categoryId;
  int get _questionCount => widget.exam?.soCauHoi ?? 10;
  int get _durationMinutes => widget.exam?.thoiGianPhut ?? 15;
  String get _description {
    final desc = widget.exam?.moTa.trim() ?? '';
    if (desc.isNotEmpty) return desc;
    return 'Bộ đề thuộc môn $_subjectName gồm $_questionCount câu hỏi, thời gian quy định $_durationMinutes phút. Chọn chế độ chơi bên dưới và nhấn "Bắt đầu làm bài" để thử sức.';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chi tiết đề thi'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              // 1. NỘI DUNG CUỘN (THÔNG TIN ĐỀ THI & CHỌN CHẾ ĐỘ CHƠI)
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildQuizInfoCard(),
                      const SizedBox(height: 28),
                      Text(
                        'Chọn chế độ chơi',
                        style: AppTextStyles.question,
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _buildModeOption(
                              'practice',
                              'Luyện tập',
                              Icons.menu_book_rounded,
                              'Không tính thời gian/rank',
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildModeOption(
                              'competitive',
                              'Thi đấu',
                              Icons.emoji_events_rounded,
                              'Tính điểm lên Leaderboard',
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // 2. NÚT BẮT ĐẦU LÀM BÀI NỔI BẬT
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.base,
                    foregroundColor: Colors.white,
                    elevation: 3,
                    shadowColor: AppColors.base.withValues(alpha: 0.4),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  icon: const Icon(Icons.play_arrow_rounded, size: 28),
                  label: Text(
                    'BẮT ĐẦU LÀM BÀI',
                    style: AppTextStyles.button.copyWith(
                      fontSize: 17,
                      letterSpacing: 0.5,
                    ),
                  ),
                  onPressed: () {
                    // Truyền ID của bộ đề thi (quizId) và chế độ chơi sang màn hình Làm bài
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => QuizExecutionScreen(
                          quizId: _quizId,
                          gameMode: _selectedMode,
                        ),
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

  // Thẻ thông tin chi tiết đề thi: Tên đề, Môn học, Số lượng câu hỏi, Thời gian, Mô tả ngắn
  Widget _buildQuizInfoCard() {
    return Container(
      width: double.infinity,
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
          // Nhãn môn học
          _buildInfoBadge(
            Icons.bookmark_rounded,
            _subjectName,
            AppColors.base,
            AppColors.background,
          ),
          const SizedBox(height: 12),

          // Tên đề thi
          Text(
            _title,
            style: AppTextStyles.subTitle,
          ),
          const SizedBox(height: 16),

          // Các thẻ thông số: Số lượng câu hỏi & Thời gian quy định
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              _buildInfoBadge(
                Icons.quiz_outlined,
                '$_questionCount câu hỏi',
                Colors.indigo,
                Colors.indigo.withValues(alpha: 0.1),
              ),
              _buildInfoBadge(
                Icons.timer_outlined,
                '$_durationMinutes phút',
                Colors.orange.shade800,
                Colors.orange.withValues(alpha: 0.12),
              ),
            ],
          ),
          const SizedBox(height: 16),

          Divider(color: Colors.grey.shade200, thickness: 1),
          const SizedBox(height: 12),

          // Mô tả ngắn
          Text(
            'Mô tả đề thi',
            style: AppTextStyles.answer.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          Text(
            _description,
            style: AppTextStyles.text.copyWith(
              color: Colors.grey[700],
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoBadge(
    IconData icon,
    String text,
    Color textColor,
    Color bgColor,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: textColor, size: 18),
          const SizedBox(width: 6),
          Text(
            text,
            style: AppTextStyles.text.copyWith(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModeOption(
    String modeValue,
    String title,
    IconData icon,
    String subtitle,
  ) {
    final bool isSelected = _selectedMode == modeValue;
    final Color activeColor =
        modeValue == 'competitive' ? AppColors.interact : AppColors.base;

    return GestureDetector(
      onTap: () => setState(() => _selectedMode = modeValue),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 18),
        decoration: BoxDecoration(
          color: isSelected
              ? activeColor.withValues(alpha: 0.1)
              : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isSelected ? activeColor : Colors.grey.shade300,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: activeColor.withValues(alpha: 0.15),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ]
              : [],
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isSelected ? activeColor : AppColors.background,
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 30,
                color: isSelected ? Colors.white : Colors.grey[600],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: AppTextStyles.answer.copyWith(
                fontWeight: FontWeight.bold,
                color: isSelected ? AppColors.text : Colors.grey[800],
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: AppTextStyles.text.copyWith(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }
}