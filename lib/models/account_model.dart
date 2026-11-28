class AccountModel {
  final String id;
  final String fullName;
  final String email;
  final String avatarUrl;
  final String role; // User | Admin
  final int level;
  final String rank; // Đồng | Bạc | Vàng | Bạch kim | Kim cương
  final String bio;
  final DateTime createdAt;

  const AccountModel({
    required this.id,
    required this.fullName,
    this.email = '',
    this.avatarUrl = '',
    this.role = 'User',
    this.level = 1,
    this.rank = 'Đồng',
    this.bio = '',
    required this.createdAt,
  });

  String get formattedCreatedDate {
    final String d = createdAt.day.toString().padLeft(2, '0');
    final String m = createdAt.month.toString().padLeft(2, '0');
    final String y = createdAt.year.toString();
    return '$d/$m/$y';
  }

  factory AccountModel.fromMap(Map<String, dynamic> map) {
    DateTime parsedDate = DateTime.now();
    final dynamic rawDate = map['created_at'];
    if (rawDate != null) {
      parsedDate = DateTime.tryParse(rawDate.toString()) ?? DateTime.now();
    }

    return AccountModel(
      id: map['id'].toString(),
      fullName: (map['full_name'] ?? 'Player').toString(),
      email: (map['email'] ?? '').toString(),
      avatarUrl: (map['avatar_url'] ?? '').toString(),
      role: (map['role'] ?? 'User').toString(),
      level: (map['level'] as num?)?.toInt() ?? 1,
      rank: (map['rank'] ?? 'Đồng').toString(),
      bio: (map['bio'] ?? '').toString(),
      createdAt: parsedDate,
    );
  }
}