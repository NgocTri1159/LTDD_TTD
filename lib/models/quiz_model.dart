  class QuizModel {
    String id;
    String title;
    String categoryId; // Liên kết với CategoryModel bạn làm lúc nãy
    String difficulty;

    QuizModel({
      required this.id,
      required this.title,
      required this.categoryId,
      required this.difficulty,
    });

    // Chuyển từ Firebase về Code (dùng ở Bước 1)
    factory QuizModel.fromMap(Map<String, dynamic> map, String documentId) {
      return QuizModel(
        id: documentId,
        title: map['title'] ?? '',
        categoryId: map['categoryId'] ?? '',
        difficulty: map['difficulty'] ?? 'Dễ',
      );
    }

    // Chuyển từ Code lên Firebase
    Map<String, dynamic> toMap() {
      return {
        'title': title,
        'categoryId': categoryId,
        'difficulty': difficulty,
      };
    }
  }