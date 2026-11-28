import 'package:flutter/material.dart';
import '../../core/theme.dart'; // Import bộ màu & font chuẩn của nhóm

class QuizReviewScreen extends StatelessWidget {
  final List<dynamic> questions;
  final Map<int, String> selectedAnswers;

  const QuizReviewScreen({
    super.key,
    required this.questions,
    required this.selectedAnswers,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Tự động nhận nền #F5F7FF từ AppTheme.lightTheme
      appBar: AppBar(
        title: const Text('Chi tiết đáp án'),
        centerTitle: true,
      ),
      body: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        itemCount: questions.length,
        itemBuilder: (context, index) {
          // Ép kiểu dữ liệu an toàn
          final question = questions[index] as Map<String, dynamic>;
          final String questionText = question['questionText'] ?? '';
          final List<String> options = List<String>.from(question['options'] ?? []);
          final String correctAnswer = question['correctAnswer'] ?? '';
          final String explanation = question['explanation'] ??
              'Đây là phần giải thích chi tiết cho câu hỏi này từ cơ sở dữ liệu.';
          final String userAnswer = selectedAnswers[index] ?? '';

          // Trạng thái của câu hỏi để hiển thị nhãn (Đúng / Sai / Bỏ qua)
          final bool isAnswered = userAnswer.isNotEmpty;
          final bool isQuestionCorrect = userAnswer == correctAnswer;

          return Container(
            margin: const EdgeInsets.only(bottom: 20),
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: AppColors.base.withOpacity(0.08),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. TIÊU ĐỀ CÂU HỎI & NHÃN TRẠNG THÁI
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.base.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        'Câu ${index + 1}',
                        style: AppTextStyles.text.copyWith(
                          fontWeight: FontWeight.bold,
                          color: AppColors.base,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    _buildStatusBadge(isAnswered, isQuestionCorrect),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  questionText,
                  style: AppTextStyles.question.copyWith(height: 1.4),
                ),
                const SizedBox(height: 16),

                // 2. DANH SÁCH ĐÁP ÁN (A, B, C, D)
                ...options.asMap().entries.map((entry) {
                  final int optIndex = entry.key;
                  final String option = entry.value;
                  final String optionLabel = String.fromCharCode(65 + optIndex);

                  final bool isCorrect = option == correctAnswer;
                  final bool isUserSelected = option == userAnswer;

                  // Màu mặc định
                  Color bgColor = Colors.white;
                  Color borderColor = Colors.grey.shade300;
                  Color badgeBgColor = AppColors.background;
                  Color badgeTextColor = Colors.grey.shade700;
                  Color textColor = AppColors.text;
                  IconData? icon;
                  Color iconColor = Colors.transparent;

                  // Bôi xanh câu đúng, bôi đỏ câu người dùng chọn sai
                  if (isCorrect) {
                    bgColor = Colors.green.shade50;
                    borderColor = Colors.green;
                    badgeBgColor = Colors.green;
                    badgeTextColor = Colors.white;
                    textColor = Colors.green.shade800;
                    icon = Icons.check_circle_rounded;
                    iconColor = Colors.green;
                  } else if (isUserSelected && !isCorrect) {
                    bgColor = Colors.red.shade50;
                    borderColor = Colors.redAccent;
                    badgeBgColor = Colors.redAccent;
                    badgeTextColor = Colors.white;
                    textColor = Colors.red.shade800;
                    icon = Icons.cancel_rounded;
                    iconColor = Colors.redAccent;
                  }

                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: bgColor,
                      border: Border.all(
                        color: borderColor,
                        width: (isCorrect || isUserSelected) ? 1.8 : 1,
                      ),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      children: [
                        // Ô chữ cái A, B, C, D
                        Container(
                          width: 30,
                          height: 30,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: badgeBgColor,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            optionLabel,
                            style: AppTextStyles.text.copyWith(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: badgeTextColor,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            option,
                            style: AppTextStyles.answer.copyWith(
                              fontWeight: (isCorrect || isUserSelected)
                                  ? FontWeight.w600
                                  : FontWeight.normal,
                              color: textColor,
                            ),
                          ),
                        ),
                        if (icon != null) ...[
                          const SizedBox(width: 8),
                          Icon(icon, color: iconColor, size: 22),
                        ],
                      ],
                    ),
                  );
                }),

                const SizedBox(height: 8),

                // 3. KHUNG LỜI GIẢI CHI TIẾT
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.interact.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: AppColors.interact.withOpacity(0.35),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.lightbulb_rounded,
                            color: AppColors.interact,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Lời giải chi tiết',
                            style: AppTextStyles.answer.copyWith(
                              fontWeight: FontWeight.bold,
                              color: AppColors.text,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        explanation,
                        style: AppTextStyles.text.copyWith(
                          color: Colors.grey.shade800,
                          fontSize: 14.5,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // Nhãn trạng thái nhanh cho từng câu (Đúng / Sai / Chưa trả lời)
  Widget _buildStatusBadge(bool isAnswered, bool isCorrect) {
    final Color color = !isAnswered
        ? Colors.grey
        : (isCorrect ? Colors.green : Colors.redAccent);
    final String label = !isAnswered
        ? 'Chưa trả lời'
        : (isCorrect ? 'Chính xác' : 'Chưa đúng');
    final IconData icon = !isAnswered
        ? Icons.remove_circle_outline_rounded
        : (isCorrect ? Icons.check_circle_outline_rounded : Icons.highlight_off_rounded);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: AppTextStyles.text.copyWith(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}