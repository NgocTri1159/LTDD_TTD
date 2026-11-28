class CategoryModel {
  final String id;
  final String name;
  final String iconUrl;

  CategoryModel({ 
    required this.id,
    required this.name,
    this.iconUrl = '', // Có thể dùng chuỗi URL ảnh hoặc tên icon
  });

  // Chuyển từ Firebase Map sang Object
  factory CategoryModel.fromMap(Map<String, dynamic> data, String documentId) {
    return CategoryModel(
      id: documentId,
      name: data['name'] ?? '',
      iconUrl: data['iconUrl'] ?? '',
    );
  }

  // Chuyển từ Object sang Map đẩy lên Firebase
  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'iconUrl': iconUrl,
      'createdAt': DateTime.now().toIso8601String(), // Lưu vết thời gian tạo
    };
  }
}