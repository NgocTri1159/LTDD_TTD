class Quiz {
  final String id;
  final String title;
  final String description;
  final int durationMinutes;
  final int totalQuestions;

  Quiz({
    required this.id,
    required this.title,
    required this.description,
    required this.durationMinutes,
    required this.totalQuestions,
  });
}

class Option {
  final String id;
  final String text;

  Option({required this.id, required this.text});
}

class Question {
  final String id;
  final String content;
  final List<Option> options;

  Question({
    required this.id,
    required this.content,
    required this.options,
  });
}