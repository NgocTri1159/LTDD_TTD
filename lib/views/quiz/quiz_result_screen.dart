import 'package:flutter/material.dart';
import '../../core/theme.dart'; // Import bộ màu & font chuẩn của nhóm
import 'quiz_review_screen.dart';

class QuizResultScreen extends StatelessWidget {
  final int score;
  final int correctAnswers;
  final int totalQuestions;
  final String timeTaken;

  // Nhận dữ liệu bài thi để truyền tiếp sang màn hình Xem đáp án
  final List<dynamic> questions;
  final Map<int, String> selectedAnswers;

  const QuizResultScreen({
    super.key,
    required this.score,
    required this.correctAnswers,
    required this.totalQuestions,
    required this.timeTaken,
    required this.questions,
    required this.selectedAnswers,
  });

  // Lời động viên tự động theo mức điểm
  String _getFeedbackMessage() {
    if (score >= 80) return 'Xuất sắc! Bạn nắm bài rất chắc.';
    if (score >= 50) return 'Làm tốt lắm! Cố gắng thêm chút nữa nhé.';
    return 'Đừng nản lòng! Hãy xem lại đáp án để rút kinh nghiệm.';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Tự động nhận nền #F5F7FF từ AppTheme.lightTheme
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // 1. BIỂU TƯỢNG CÚP VÀNG & LỜI CHÚC
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: AppColors.interact.withOpacity(0.15),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppColors.interact.withOpacity(0.4),
                      width: 2,
                    ),
                  ),
                  child: const Icon(
                    Icons.emoji_events_rounded,
                    size: 88,
                    color: AppColors.interact,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'Bạn đã hoàn thành!',
                  style: AppTextStyles.subTitle.copyWith(
                    color: AppColors.base,
                    fontSize: 26,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  _getFeedbackMessage(),
                  style: AppTextStyles.text.copyWith(color: Colors.grey[700]),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 36),

                // 2. 3 Ô THÔNG SỐ (ĐIỂM SỐ, SỐ CÂU ĐÚNG, THỜI GIAN)
                Row(
                  children: [
                    Expanded(
                      child: _buildStatCard(
                        icon: Icons.stars_rounded,
                        title: 'Điểm số',
                        value: score.toString(),
                        color: AppColors.interact,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildStatCard(
                        icon: Icons.check_circle_rounded,
                        title: 'Đúng',
                        value: '$correctAnswers/$totalQuestions',
                        color: Colors.green,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildStatCard(
                        icon: Icons.timer_rounded,
                        title: 'Thời gian',
                        value: timeTaken,
                        color: AppColors.base,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 44),

                // 3. NÚT XEM ĐÁP ÁN
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.base,
                      foregroundColor: Colors.white,
                      elevation: 2,
                      shadowColor: AppColors.base.withOpacity(0.4),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    icon: const Icon(Icons.fact_check_outlined, size: 22),
                    label: Text(
                      'XEM ĐÁP ÁN',
                      style: AppTextStyles.button.copyWith(
                        fontSize: 17,
                        letterSpacing: 0.5,
                      ),
                    ),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => QuizReviewScreen(
                            questions: questions,
                            selectedAnswers: selectedAnswers,
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 14),

                // 4. NÚT VỀ TRANG CHỦ
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: AppColors.base,
                      side: const BorderSide(color: AppColors.base, width: 1.5),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    icon: const Icon(Icons.home_rounded, size: 22),
                    label: Text(
                      'VỀ TRANG CHỦ',
                      style: AppTextStyles.button.copyWith(
                        fontSize: 17,
                        color: AppColors.base,
                        letterSpacing: 0.5,
                      ),
                    ),
                    onPressed: () {
                      Navigator.popUntil(context, (route) => route.isFirst);
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Thẻ thông số đồng bộ Design System
  Widget _buildStatCard({
    required IconData icon,
    required String title,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withOpacity(0.3), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.08),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 26),
          const SizedBox(height: 10),
          Text(
            value,
            style: AppTextStyles.question.copyWith(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: AppTextStyles.text.copyWith(
              fontSize: 13,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}