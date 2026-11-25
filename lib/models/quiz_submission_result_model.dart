/// Model nhận kết quả chấm bài từ Backend.
class QuizSubmissionResultModel {
  final String attemptId;
  final double totalScore;
  final int correctCount;
  final int wrongCount;
  final int unansweredCount;
  final int totalQuestions;
  final int timeSpentSeconds;
  final String status;

  const QuizSubmissionResultModel({
    required this.attemptId,
    required this.totalScore,
    required this.correctCount,
    required this.wrongCount,
    required this.unansweredCount,
    required this.totalQuestions,
    required this.timeSpentSeconds,
    required this.status,
  });

  factory QuizSubmissionResultModel.fromJson(
    Map<String, dynamic> json,
  ) {
    return QuizSubmissionResultModel(
      attemptId: json['attemptId']?.toString() ?? '',
      totalScore: (json['totalScore'] as num?)?.toDouble() ?? 0,
      correctCount: (json['correctCount'] as num?)?.toInt() ?? 0,
      wrongCount: (json['wrongCount'] as num?)?.toInt() ?? 0,
      unansweredCount:
          (json['unansweredCount'] as num?)?.toInt() ?? 0,
      totalQuestions:
          (json['totalQuestions'] as num?)?.toInt() ?? 0,
      timeSpentSeconds:
          (json['timeSpentSeconds'] as num?)?.toInt() ?? 0,
      status: json['status']?.toString() ?? '',
    );
  }

  bool get isCompleted => status == 'hoan_thanh';
  bool get isOverdue => status == 'qua_gio';
}