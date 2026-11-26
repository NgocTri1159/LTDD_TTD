import 'package:material_ui/material_ui.dart';
import '../../models/attempt_detail_model.dart';
import '../../models/question_model.dart';
import '../../models/quiz_submission_result_model.dart';
import '../../services/quiz_service.dart';

class QuizResultScreen extends StatelessWidget {
  final String examTitle;
  final QuizSubmissionResultModel result;
  final List<QuestionModel> fallbackQuestions;
  final Map<String, Set<String>> fallbackSelectedAnswers;

  const QuizResultScreen({
    super.key,
    required this.examTitle,
    required this.result,
    this.fallbackQuestions = const [],
    this.fallbackSelectedAnswers = const {},
  });

  String _formatDuration(int totalSeconds) {
    final mins = (totalSeconds ~/ 60).toString().padLeft(2, '0');
    final secs = (totalSeconds % 60).toString().padLeft(2, '0');
    return '$mins:$secs';
  }

  String _formatScore() {
    final s = result.totalScore;
    return s % 1 == 0 ? s.toInt().toString() : s.toStringAsFixed(1);
  }

  void _showReviewModal(BuildContext context) {
    const labels = ['A', 'B', 'C', 'D', 'E', 'F'];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFFF8FAFC),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) => Column(
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Chi tiết đáp án',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E293B),
                ),
              ),
            ),
            Expanded(
              child: FutureBuilder<List<AttemptDetailModel>>(
                future: QuizService.getAttemptReview(result.attemptId),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final details = snapshot.data ?? [];
                  if (details.isEmpty && fallbackQuestions.isEmpty) {
                    return const Center(
                      child: Text('Không có dữ liệu chi tiết bài làm.'),
                    );
                  }

                  final itemCount = details.isNotEmpty
                      ? details.length
                      : fallbackQuestions.length;

                  return ListView.builder(
                    controller: scrollController,
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                    itemCount: itemCount,
                    itemBuilder: (context, index) {
                      final QuestionModel question;
                      final Set<String> chosenIds;
                      final bool isRight;

                      if (details.isNotEmpty && details[index].cauHoi != null) {
                        final detail = details[index];
                        question = detail.cauHoi!;
                        chosenIds = detail.danhSachDapAnDaChon
                            .map((e) => e.dapAnId)
                            .whereType<String>()
                            .toSet();
                        isRight = detail.laDung ?? false;
                      } else {
                        question = fallbackQuestions[index];
                        chosenIds = fallbackSelectedAnswers[question.id] ?? {};
                        final correctIds = question.danhSachDapAn
                            .where((a) => a.laDung)
                            .map((a) => a.id)
                            .toSet();
                        isRight = correctIds.isNotEmpty &&
                            chosenIds.length == correctIds.length &&
                            correctIds.containsAll(chosenIds);
                      }

                      final answers = question.danhSachDapAn;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 14),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isRight
                                ? const Color(0xFF10B981).withValues(alpha: 0.4)
                                : const Color(0xFFEF4444)
                                    .withValues(alpha: 0.4),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  isRight ? Icons.check_circle : Icons.cancel,
                                  color: isRight
                                      ? const Color(0xFF10B981)
                                      : const Color(0xFFEF4444),
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Câu ${index + 1}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              question.noiDung,
                              style: const TextStyle(
                                fontSize: 15,
                                color: Color(0xFF1E293B),
                              ),
                            ),
                            const SizedBox(height: 12),
                            ...List.generate(answers.length, (optIdx) {
                              final ans = answers[optIdx];
                              final isCorrectOpt = ans.laDung;
                              final isUserOpt = chosenIds.contains(ans.id);
                              final label = optIdx < labels.length
                                  ? labels[optIdx]
                                  : '${optIdx + 1}';

                              Color bgColor = const Color(0xFFF8FAFC);
                              Color borderColor = const Color(0xFFE2E8F0);
                              if (isCorrectOpt) {
                                bgColor = const Color(0xFFECFDF5);
                                borderColor = const Color(0xFF10B981);
                              } else if (isUserOpt) {
                                bgColor = const Color(0xFFFEF2F2);
                                borderColor = const Color(0xFFEF4444);
                              }

                              return Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 10,
                                ),
                                decoration: BoxDecoration(
                                  color: bgColor,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: borderColor),
                                ),
                                child: Row(
                                  children: [
                                    Text(
                                      '$label. ',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Expanded(child: Text(ans.noiDung)),
                                    if (isCorrectOpt)
                                      const Icon(
                                        Icons.check,
                                        color: Color(0xFF10B981),
                                        size: 18,
                                      ),
                                    if (isUserOpt && !isCorrectOpt)
                                      const Icon(
                                        Icons.close,
                                        color: Color(0xFFEF4444),
                                        size: 18,
                                      ),
                                  ],
                                ),
                              );
                            }),
                            if (question.giaiThich != null &&
                                question.giaiThich!.trim().isNotEmpty) ...[
                              const SizedBox(height: 6),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFEEF2FF),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  'Giải thích: ${question.giaiThich!}',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: Color(0xFF3730A3),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF5552E8),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(flex: 2),
              Container(
                width: 140,
                height: 140,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.12),
                ),
                child: const Icon(
                  Icons.emoji_events_rounded,
                  size: 96,
                  color: Color(0xFFFFC107),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                result.isOverdue ? 'Đã hết giờ làm bài!' : 'Bạn đã hoàn thành!',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFFFB72B),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                examTitle,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.white.withValues(alpha: 0.85),
                ),
              ),
              const SizedBox(height: 28),
              Container(
                padding:
                    const EdgeInsets.symmetric(vertical: 20, horizontal: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.12),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: IntrinsicHeight(
                  child: Row(
                    children: [
                      Expanded(
                        child: _StatColumn(
                          icon: Icons.star_rounded,
                          iconColor: const Color(0xFFFBBF24),
                          label: 'Điểm số',
                          value: _formatScore(),
                        ),
                      ),
                      VerticalDivider(
                        color: Colors.grey.shade200,
                        thickness: 1,
                        width: 1,
                      ),
                      Expanded(
                        child: _StatColumn(
                          icon: Icons.check_box_rounded,
                          iconColor: const Color(0xFF10B981),
                          label: 'Số câu đúng',
                          value:
                              '${result.correctCount}/${result.totalQuestions}',
                        ),
                      ),
                      VerticalDivider(
                        color: Colors.grey.shade200,
                        thickness: 1,
                        width: 1,
                      ),
                      Expanded(
                        child: _StatColumn(
                          icon: Icons.access_time_filled_rounded,
                          iconColor: const Color(0xFF3B82F6),
                          label: 'Thời gian hoàn thành',
                          value: _formatDuration(result.timeSpentSeconds),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFF59E0B),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(25),
                    ),
                  ),
                  onPressed: () => _showReviewModal(context),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Xem đáp án',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(width: 6),
                      Icon(Icons.arrow_forward_rounded, size: 20),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFF1E293B),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(25),
                    ),
                  ),
                  onPressed: () {
                    Navigator.of(context).popUntil((route) => route.isFirst);
                  },
                  child: const Text(
                    'Về trang chính',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const Spacer(flex: 3),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatColumn extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;

  const _StatColumn({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: iconColor, size: 26),
          const SizedBox(height: 6),
          Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 2,
            style: const TextStyle(
              fontSize: 11.5,
              color: Color(0xFF64748B),
              height: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E293B),
            ),
          ),
        ],
      ),
    );
  }
}