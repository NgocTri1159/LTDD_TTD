import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/theme.dart';

typedef SubjectRow = Map<String, dynamic>;

class AdminSubjectScreen extends StatefulWidget {
  const AdminSubjectScreen({super.key});

  @override
  State<AdminSubjectScreen> createState() => _AdminSubjectScreenState();
}

class _AdminSubjectScreenState extends State<AdminSubjectScreen> {
  final _supabase = Supabase.instance.client;
  final _searchController = TextEditingController();
  final _picker = ImagePicker();

  static const Color _brandBlue = Color(0xFF3B5BFD);
  static const Color _brandPurple = Color(0xFF7C3AED);

  List<SubjectRow> _subjects = [];
  Map<String, int> _quizCountBySubject = {};
  int _totalQuizzes = 0;
  bool _isLoading = true;
  bool _hasLoadedOnce = false;
  String _searchQuery = '';

  static const List<(Color, Color)> _subjectPalettes = [
    (Color(0xFF2563EB), Color(0xFF38BDF8)), // Xanh dương
    (Color(0xFF7C3AED), Color(0xFFA78BFA)), // Tím
    (Color(0xFF059669), Color(0xFF34D399)), // Xanh ngọc
    (Color(0xFFD97706), Color(0xFFFBBF24)), // Vàng cam
    (Color(0xFF0891B2), Color(0xFF22D3EE)), // Cyan
    (Color(0xFFDB2777), Color(0xFFF472B6)), // Hồng
    (Color(0xFF4F46E5), Color(0xFF818CF8)), // Chàm
    (Color(0xFF0D9488), Color(0xFF2DD4BF)), // Teal
    (Color(0xFFEA580C), Color(0xFFFB923C)), // Cam đậm
  ];

  @override
  void initState() {
    super.initState();
    _loadSubjects();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadSubjects() async {
    if (mounted) setState(() => _isLoading = true);
    try {
      final dynamic rows =
          await _supabase.from('mon_hoc').select('*').order('ten_mon');
      final loaded = <SubjectRow>[];
      if (rows is Iterable) {
        for (final r in rows) {
          if (r is Map) {
            loaded.add(Map<String, dynamic>.from(r));
          }
        }
      }

      // Đếm số bộ đề thuộc từng môn học
      final counts = <String, int>{};
      int totalQuiz = 0;
      try {
        final dynamic quizRows =
            await _supabase.from('de_thi').select('mon_hoc_id');
        if (quizRows is Iterable) {
          for (final q in quizRows) {
            if (q is Map && q['mon_hoc_id'] != null) {
              final key = q['mon_hoc_id'].toString();
              counts[key] = (counts[key] ?? 0) + 1;
              totalQuiz++;
            }
          }
        }
      } catch (_) {}

      if (!mounted) return;
      setState(() {
        _subjects = loaded;
        _quizCountBySubject = counts;
        _totalQuizzes = totalQuiz;
        _isLoading = false;
        _hasLoadedOnce = true;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _hasLoadedOnce = true;
      });
      _showSnack('Không thể tải danh sách môn học: $e', isError: true);
    }
  }

  /// Chọn ảnh từ thư mục Download / Thư viện ảnh trên thiết bị
  Future<Uint8List?> _pickImageFromDevice() async {
    try {
      final XFile? file = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 256,
        maxHeight: 256,
        imageQuality: 85,
      );
      if (file == null) return null;
      return await file.readAsBytes();
    } catch (e) {
      _showSnack('Không thể mở trình chọn ảnh: $e', isError: true);
      return null;
    }
  }

  /// Tải ảnh lên Supabase Storage (bucket: subject_icons) hoặc chuyển sang Base64 nếu chưa tạo bucket
  Future<String?> _uploadOrEncodeImage(Uint8List bytes) async {
    try {
      final fileName = 'subject_${DateTime.now().millisecondsSinceEpoch}.png';
      await _supabase.storage.from('subject_icons').uploadBinary(
            fileName,
            bytes,
            fileOptions: const FileOptions(contentType: 'image/png'),
          );
      return _supabase.storage.from('subject_icons').getPublicUrl(fileName);
    } catch (_) {
      return 'data:image/png;base64,${base64Encode(bytes)}';
    }
  }

  IconData _fallbackIcon(String subjectName) {
    final name = subjectName.toLowerCase();
    if (name.contains('toán')) return Icons.calculate_rounded;
    if (name.contains('văn')) return Icons.auto_stories_rounded;
    if (name.contains('anh') || name.contains('ngoại ngữ')) {
      return Icons.language_rounded;
    }
    if (name.contains('địa')) return Icons.public_rounded;
    if (name.contains('vật lý') || name.contains('lý')) {
      return Icons.bolt_rounded;
    }
    if (name.contains('hóa')) return Icons.science_rounded;
    if (name.contains('sinh')) return Icons.biotech_rounded;
    if (name.contains('sử')) return Icons.account_balance_rounded;
    if (name.contains('tin')) return Icons.computer_rounded;
    if (name.contains('công dân') || name.contains('gdcd')) {
      return Icons.gavel_rounded;
    }
    if (name.contains('nhạc')) return Icons.music_note_rounded;
    if (name.contains('mỹ thuật') || name.contains('vẽ')) {
      return Icons.palette_rounded;
    }
    return Icons.menu_book_rounded;
  }

  bool _hasCustomImage(SubjectRow subject) {
    final rawUrl =
        (subject['icon_url'] ?? subject['hinh_anh'] ?? '').toString().trim();
    return rawUrl.startsWith('data:image') || rawUrl.startsWith('http');
  }

  /// Hiển thị ảnh đã chọn (URL hoặc Base64) hoặc icon mặc định
  Widget _buildSubjectImage(
    SubjectRow subject,
    Color iconColor, {
    double size = 26,
    double borderRadius = 12,
  }) {
    final rawUrl =
        (subject['icon_url'] ?? subject['hinh_anh'] ?? '').toString().trim();

    if (rawUrl.startsWith('data:image')) {
      try {
        final base64Str = rawUrl.split(',').last;
        final bytes = base64Decode(base64Str);
        return ClipRRect(
          borderRadius: BorderRadius.circular(borderRadius),
          child: Image.memory(
            bytes,
            width: size,
            height: size,
            fit: BoxFit.cover,
          ),
        );
      } catch (_) {}
    } else if (rawUrl.startsWith('http')) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: Image.network(
          rawUrl,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Icon(
            _fallbackIcon((subject['ten_mon'] ?? '').toString()),
            size: size * 0.72,
            color: iconColor,
          ),
        ),
      );
    }

    return Icon(
      _fallbackIcon((subject['ten_mon'] ?? '').toString()),
      size: size,
      color: iconColor,
    );
  }

  /// Giữ màu ổn định theo vị trí trong danh sách gốc kể cả khi lọc tìm kiếm
  (Color, Color) _resolvePalette(SubjectRow subject) {
    final idx = _subjects.indexOf(subject);
    final safeIdx = idx >= 0
        ? idx
        : (subject['ten_mon'] ?? '').toString().hashCode.abs();
    return _subjectPalettes[safeIdx % _subjectPalettes.length];
  }

  List<SubjectRow> get _filteredSubjects {
    if (_searchQuery.trim().isEmpty) return _subjects;
    final q = _searchQuery.toLowerCase().trim();
    return _subjects.where((s) {
      final name = (s['ten_mon'] ?? '').toString().toLowerCase();
      return name.contains(q);
    }).toList();
  }

  void _showSnack(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.redAccent : const Color(0xFF059669),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  // HỘP THOẠI TẠO MÔN HỌC MỚI
  Future<void> _openCreateDialog() async {
    final nameController = TextEditingController();
    Uint8List? pickedImageBytes;
    bool isSaving = false;

    await showDialog(
      context: context,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return Dialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 400),
                child: Padding(
                  padding: const EdgeInsets.all(22),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [_brandBlue, _brandPurple],
                              ),
                              borderRadius: BorderRadius.circular(13),
                            ),
                            child: const Icon(
                              Icons.bookmark_add_rounded,
                              color: Colors.white,
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Tạo môn học mới',
                                  style: AppTextStyles.question.copyWith(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.text,
                                  ),
                                ),
                                Text(
                                  'Nhập tên và chọn ảnh đại diện (tùy chọn)',
                                  style: AppTextStyles.text.copyWith(
                                    fontSize: 12,
                                    color: Colors.grey.shade500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),

                      // Khung chọn ảnh môn học
                      Center(
                        child: GestureDetector(
                          onTap: isSaving
                              ? null
                              : () async {
                                  final bytes = await _pickImageFromDevice();
                                  if (bytes != null) {
                                    setDialogState(
                                        () => pickedImageBytes = bytes);
                                  }
                                },
                          child: Stack(
                            clipBehavior: Clip.none,
                            children: [
                              Container(
                                width: 76,
                                height: 76,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF1F5FB),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: pickedImageBytes != null
                                        ? AppColors.base
                                        : const Color(0xFFCBD5E1),
                                    width: 1.5,
                                  ),
                                ),
                                child: pickedImageBytes != null
                                    ? ClipRRect(
                                        borderRadius: BorderRadius.circular(18),
                                        child: Image.memory(
                                          pickedImageBytes!,
                                          fit: BoxFit.cover,
                                        ),
                                      )
                                    : Icon(
                                        Icons.add_photo_alternate_rounded,
                                        color: AppColors.base
                                            .withValues(alpha: 0.7),
                                        size: 30,
                                      ),
                              ),
                              Positioned(
                                right: -4,
                                bottom: -4,
                                child: Container(
                                  padding: const EdgeInsets.all(5),
                                  decoration: BoxDecoration(
                                    color: AppColors.base,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: Colors.white,
                                      width: 2,
                                    ),
                                  ),
                                  child: const Icon(
                                    Icons.upload_rounded,
                                    size: 13,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      TextField(
                        controller: nameController,
                        autofocus: true,
                        style: AppTextStyles.text.copyWith(
                          color: AppColors.text,
                          fontSize: 14.5,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Nhập tên môn học...',
                          hintStyle: TextStyle(color: Colors.grey.shade400),
                          prefixIcon: Icon(
                            Icons.menu_book_rounded,
                            color: AppColors.base.withValues(alpha: 0.75),
                            size: 20,
                          ),
                          filled: true,
                          fillColor: const Color(0xFFF8FAFC),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide:
                                const BorderSide(color: Color(0xFFE2E8F0)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide:
                                const BorderSide(color: Color(0xFFE2E8F0)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: const BorderSide(
                              color: AppColors.base,
                              width: 1.5,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),

                      Row(
                        children: [
                          Expanded(
                            child: SizedBox(
                              height: 46,
                              child: OutlinedButton(
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.grey.shade700,
                                  side:
                                      const BorderSide(color: Color(0xFFE2E8F0)),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                                onPressed: isSaving
                                    ? null
                                    : () => Navigator.pop(dialogCtx),
                                child: const Text(
                                  'Hủy',
                                  style: TextStyle(fontWeight: FontWeight.w700),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            flex: 2,
                            child: SizedBox(
                              height: 46,
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.base,
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                                onPressed: isSaving
                                    ? null
                                    : () async {
                                        final name = nameController.text.trim();
                                        if (name.isEmpty) {
                                          _showSnack(
                                            'Vui lòng nhập tên môn học',
                                            isError: true,
                                          );
                                          return;
                                        }
                                        setDialogState(() => isSaving = true);
                                        try {
                                          String? imageUrl;
                                          if (pickedImageBytes != null) {
                                            imageUrl =
                                                await _uploadOrEncodeImage(
                                                    pickedImageBytes!);
                                          }

                                          try {
                                            await _supabase
                                                .from('mon_hoc')
                                                .insert({
                                              'ten_mon': name,
                                              if (imageUrl != null)
                                                'icon_url': imageUrl,
                                            });
                                          } catch (_) {
                                            await _supabase
                                                .from('mon_hoc')
                                                .insert({'ten_mon': name});
                                          }

                                          if (dialogCtx.mounted) {
                                            Navigator.pop(dialogCtx);
                                          }
                                          _showSnack('Đã tạo môn học "$name"');
                                          _loadSubjects();
                                        } catch (e) {
                                          setDialogState(
                                              () => isSaving = false);
                                          _showSnack(
                                            'Lỗi tạo môn học: $e',
                                            isError: true,
                                          );
                                        }
                                      },
                                child: isSaving
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : const Text(
                                        'Tạo môn học',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 14.5,
                                        ),
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
          },
        );
      },
    );
  }

  // HỘP THOẠI CHỈNH SỬA / XÓA MÔN HỌC
  Future<void> _openEditDialog(
    SubjectRow subject,
    Color primaryColor,
    Color secondaryColor,
  ) async {
    final oldName = (subject['ten_mon'] ?? '').toString();
    final nameController = TextEditingController(text: oldName);
    final quizCount = _quizCountBySubject[subject['id']?.toString() ?? ''] ?? 0;
    Uint8List? newImageBytes;
    bool isProcessing = false;

    await showDialog(
      context: context,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return Dialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 400),
                child: Padding(
                  padding: const EdgeInsets.all(22),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          GestureDetector(
                            onTap: isProcessing
                                ? null
                                : () async {
                                    final bytes = await _pickImageFromDevice();
                                    if (bytes != null) {
                                      setDialogState(
                                          () => newImageBytes = bytes);
                                    }
                                  },
                            child: Stack(
                              clipBehavior: Clip.none,
                              children: [
                                Container(
                                  width: 52,
                                  height: 52,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: [primaryColor, secondaryColor],
                                    ),
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: newImageBytes != null
                                      ? ClipRRect(
                                          borderRadius:
                                              BorderRadius.circular(14),
                                          child: Image.memory(
                                            newImageBytes!,
                                            width: 48,
                                            height: 48,
                                            fit: BoxFit.cover,
                                          ),
                                        )
                                      : _buildSubjectImage(
                                          subject,
                                          Colors.white,
                                          size: _hasCustomImage(subject)
                                              ? 48
                                              : 26,
                                          borderRadius: 14,
                                        ),
                                ),
                                Positioned(
                                  right: -4,
                                  bottom: -4,
                                  child: Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      shape: BoxShape.circle,
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black
                                              .withValues(alpha: 0.14),
                                          blurRadius: 4,
                                        ),
                                      ],
                                    ),
                                    child: Icon(
                                      Icons.camera_alt_rounded,
                                      size: 12,
                                      color: primaryColor,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 13),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Chỉnh sửa môn học',
                                  style: AppTextStyles.question.copyWith(
                                    fontSize: 16.5,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.text,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Đang có $quizCount bộ đề • Chạm icon để đổi ảnh',
                                  style: AppTextStyles.text.copyWith(
                                    fontSize: 11.8,
                                    color: Colors.grey.shade500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),

                      TextField(
                        controller: nameController,
                        style: AppTextStyles.text.copyWith(
                          color: AppColors.text,
                          fontSize: 14.5,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Tên môn học...',
                          filled: true,
                          fillColor: const Color(0xFFF8FAFC),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide:
                                const BorderSide(color: Color(0xFFE2E8F0)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide:
                                const BorderSide(color: Color(0xFFE2E8F0)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(
                              color: primaryColor,
                              width: 1.5,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),

                      Row(
                        children: [
                          Expanded(
                            child: SizedBox(
                              height: 46,
                              child: OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: const Color(0xFFEF4444),
                                  side: const BorderSide(
                                    color: Color(0xFFFCA5A5),
                                  ),
                                  backgroundColor: const Color(0xFFFEF2F2),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                                onPressed: isProcessing
                                    ? null
                                    : () async {
                                        setDialogState(
                                            () => isProcessing = true);
                                        try {
                                          final dynamic linkedQuizzes =
                                              await _supabase
                                                  .from('de_thi')
                                                  .select('id')
                                                  .eq('mon_hoc_id',
                                                      subject['id'])
                                                  .limit(1);

                                          if (linkedQuizzes is Iterable &&
                                              linkedQuizzes.isNotEmpty) {
                                            setDialogState(
                                                () => isProcessing = false);
                                            _showSnack(
                                              'Không thể xóa vì môn "$oldName" đang có bộ đề!',
                                              isError: true,
                                            );
                                            return;
                                          }

                                          await _supabase
                                              .from('mon_hoc')
                                              .delete()
                                              .eq('id', subject['id']);
                                          if (dialogCtx.mounted) {
                                            Navigator.pop(dialogCtx);
                                          }
                                          _showSnack('Đã xóa môn "$oldName"');
                                          _loadSubjects();
                                        } catch (e) {
                                          setDialogState(
                                              () => isProcessing = false);
                                          _showSnack(
                                            'Không thể xóa môn học: $e',
                                            isError: true,
                                          );
                                        }
                                      },
                                icon: const Icon(
                                  Icons.delete_outline_rounded,
                                  size: 18,
                                ),
                                label: const Text(
                                  'Xóa',
                                  style: TextStyle(fontWeight: FontWeight.w700),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            flex: 2,
                            child: SizedBox(
                              height: 46,
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.base,
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                                onPressed: isProcessing
                                    ? null
                                    : () async {
                                        final newName =
                                            nameController.text.trim();
                                        if (newName.isEmpty) {
                                          _showSnack(
                                            'Tên môn học không được để trống',
                                            isError: true,
                                          );
                                          return;
                                        }
                                        setDialogState(
                                            () => isProcessing = true);
                                        try {
                                          String? newUrl;
                                          if (newImageBytes != null) {
                                            newUrl = await _uploadOrEncodeImage(
                                                newImageBytes!);
                                          }

                                          try {
                                            await _supabase
                                                .from('mon_hoc')
                                                .update({
                                              'ten_mon': newName,
                                              if (newUrl != null)
                                                'icon_url': newUrl,
                                            }).eq('id', subject['id']);
                                          } catch (_) {
                                            await _supabase
                                                .from('mon_hoc')
                                                .update({'ten_mon': newName})
                                                .eq('id', subject['id']);
                                          }

                                          if (dialogCtx.mounted) {
                                            Navigator.pop(dialogCtx);
                                          }
                                          _showSnack(
                                              'Đã cập nhật thành "$newName"');
                                          _loadSubjects();
                                        } catch (e) {
                                          setDialogState(
                                              () => isProcessing = false);
                                          _showSnack(
                                            'Lỗi cập nhật: $e',
                                            isError: true,
                                          );
                                        }
                                      },
                                child: isProcessing
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : const Text(
                                        'Lưu thay đổi',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 14.5,
                                        ),
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
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final items = _filteredSubjects;
    final screenWidth = MediaQuery.sizeOf(context).width;
    final crossAxisCount = screenWidth >= 620 ? 4 : (screenWidth < 330 ? 2 : 3);

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5FB),
      body: !_hasLoadedOnce && _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.base),
            )
          : RefreshIndicator(
              color: AppColors.base,
              onRefresh: _loadSubjects,
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  // 1. HEADER GRADIENT + THỐNG KÊ NHANH + THANH TÌM KIẾM NỔI
                  SliverToBoxAdapter(
                    child: _buildHeaderAndSearch(context),
                  ),

                  // 2. TIÊU ĐỀ DANH SÁCH
                  SliverToBoxAdapter(
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 680),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                          child: Row(
                            children: [
                              Container(
                                width: 4,
                                height: 17,
                                decoration: BoxDecoration(
                                  color: AppColors.base,
                                  borderRadius: BorderRadius.circular(99),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Danh mục môn học',
                                style: AppTextStyles.question.copyWith(
                                  fontSize: 15.5,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.text,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.base.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(99),
                                ),
                                child: Text(
                                  '${items.length}',
                                  style: AppTextStyles.text.copyWith(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.base,
                                  ),
                                ),
                              ),
                              const Spacer(),
                              if (_searchQuery.trim().isNotEmpty)
                                GestureDetector(
                                  onTap: () {
                                    _searchController.clear();
                                    setState(() => _searchQuery = '');
                                  },
                                  child: Text(
                                    'Xóa tìm kiếm',
                                    style: AppTextStyles.text.copyWith(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.base,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),

                  // 3. LƯỚI MÔN HỌC HOẶC EMPTY STATE
                  if (items.isEmpty)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 680),
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
                            child: _buildEmptyState(),
                          ),
                        ),
                      ),
                    )
                  else
                    SliverToBoxAdapter(
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 680),
                          child: GridView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            padding: const EdgeInsets.fromLTRB(16, 2, 16, 100),
                            gridDelegate:
                                SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: crossAxisCount,
                              mainAxisSpacing: 12,
                              crossAxisSpacing: 12,
                              childAspectRatio: 0.80,
                            ),
                            itemCount: items.length,
                            itemBuilder: (context, index) =>
                                _buildSubjectCard(items[index]),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openCreateDialog,
        backgroundColor: AppColors.base,
        foregroundColor: Colors.white,
        elevation: 3,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        icon: const Icon(Icons.add_rounded, size: 22),
        label: const Text(
          'Thêm môn học',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
        ),
      ),
    );
  }

  Widget _buildHeaderAndSearch(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;

    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: EdgeInsets.fromLTRB(16, topPadding + 14, 16, 44),
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [_brandBlue, AppColors.base, _brandPurple],
            ),
            borderRadius: BorderRadius.vertical(
              bottom: Radius.circular(30),
            ),
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 648),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned(
                    right: -20,
                    top: -24,
                    child: Container(
                      width: 124,
                      height: 124,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: 0.08),
                      ),
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Hàng điều hướng trên cùng: Quay lại + Tiêu đề + Làm mới
                      Row(
                        children: [
                          _buildHeaderIconButton(
                            tooltip: 'Quay lại',
                            onTap: () => Navigator.pop(context),
                            child: const Icon(
                              Icons.arrow_back_rounded,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'KHO HỌC LIỆU',
                                  style: TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.9,
                                    color: Colors.white.withValues(alpha: 0.8),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Quản lí môn học',
                                  style: AppTextStyles.question.copyWith(
                                    fontSize: 21,
                                    fontWeight: FontWeight.w900,
                                    color: Colors.white,
                                    letterSpacing: -0.3,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          _buildHeaderIconButton(
                            tooltip: 'Làm mới',
                            onTap: _isLoading ? null : _loadSubjects,
                            child: _isLoading
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(
                                    Icons.refresh_rounded,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // 2 ô thống kê nhanh
                      Row(
                        children: [
                          Expanded(
                            child: _buildHeaderStat(
                              icon: Icons.bookmarks_rounded,
                              label: 'Tổng môn học',
                              value: '${_subjects.length}',
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _buildHeaderStat(
                              icon: Icons.menu_book_rounded,
                              label: 'Bộ đề đã gắn',
                              value: '$_totalQuizzes',
                              highlightColor: const Color(0xFF6EE7B7),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),

        // Thanh tìm kiếm nổi chồng nhẹ lên mép dưới Header
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: Transform.translate(
              offset: const Offset(0, -24),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF0F172A).withValues(alpha: 0.06),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: TextField(
                    controller: _searchController,
                    style: AppTextStyles.text.copyWith(
                      color: AppColors.text,
                      fontSize: 14,
                    ),
                    onChanged: (val) => setState(() => _searchQuery = val),
                    decoration: InputDecoration(
                      hintText: 'Tìm nhanh tên môn học...',
                      hintStyle: TextStyle(
                        color: Colors.grey.shade400,
                        fontSize: 13.8,
                      ),
                      prefixIcon: Icon(
                        Icons.search_rounded,
                        color: AppColors.base.withValues(alpha: 0.8),
                        size: 21,
                      ),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: Icon(
                                Icons.close_rounded,
                                size: 19,
                                color: Colors.grey.shade500,
                              ),
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _searchQuery = '');
                              },
                            )
                          : null,
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 14,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHeaderIconButton({
    required String tooltip,
    required VoidCallback? onTap,
    required Widget child,
  }) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            width: 42,
            height: 42,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.28),
              ),
            ),
            child: child,
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderStat({
    required IconData icon,
    required String label,
    required String value,
    Color? highlightColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(
              icon,
              size: 18,
              color: highlightColor ?? Colors.white,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Colors.white.withValues(alpha: 0.85),
                  ),
                ),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 17.5,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    height: 1.15,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubjectCard(SubjectRow subject) {
    final name = (subject['ten_mon'] ?? 'Môn học').toString();
    final (primaryColor, secondaryColor) = _resolvePalette(subject);
    final quizCount = _quizCountBySubject[subject['id']?.toString() ?? ''] ?? 0;
    final hasImage = _hasCustomImage(subject);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: primaryColor.withValues(alpha: 0.22),
          width: 1.1,
        ),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withValues(alpha: 0.10),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(19),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => _openEditDialog(subject, primaryColor, secondaryColor),
            splashColor: primaryColor.withValues(alpha: 0.12),
            highlightColor: primaryColor.withValues(alpha: 0.05),
            child: Stack(
              children: [
                // Dải màu nhấn trên đỉnh thẻ
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    height: 4,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [primaryColor, secondaryColor],
                      ),
                    ),
                  ),
                ),

                // Họa tiết icon chìm góc dưới
                Positioned(
                  right: -10,
                  bottom: -10,
                  child: Icon(
                    _fallbackIcon(name),
                    size: 56,
                    color: primaryColor.withValues(alpha: 0.06),
                  ),
                ),

                // Icon chỉnh sửa nhỏ ở góc trên phải
                Positioned(
                  top: 9,
                  right: 8,
                  child: Icon(
                    Icons.edit_rounded,
                    size: 13,
                    color: primaryColor.withValues(alpha: 0.45),
                  ),
                ),

                // Nội dung chính của thẻ
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 16, 8, 10),
                  child: SizedBox.expand(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Khung Icon Gradient nổi bật
                        Container(
                          width: 48,
                          height: 48,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [primaryColor, secondaryColor],
                            ),
                            borderRadius: BorderRadius.circular(15),
                            boxShadow: [
                              BoxShadow(
                                color: primaryColor.withValues(alpha: 0.30),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: _buildSubjectImage(
                            subject,
                            Colors.white,
                            size: hasImage ? 44 : 24,
                            borderRadius: 13,
                          ),
                        ),
                        const SizedBox(height: 10),

                        // Tên môn học
                        Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: AppTextStyles.question.copyWith(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w800,
                            color: AppColors.text,
                          ),
                        ),
                        const SizedBox(height: 5),

                        // Huy hiệu số bộ đề thuộc môn
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: primaryColor.withValues(alpha: 0.10),
                            borderRadius: BorderRadius.circular(99),
                          ),
                          child: Text(
                            '$quizCount bộ đề',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                              color: primaryColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    final isFiltered = _searchQuery.trim().isNotEmpty;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 38),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  _brandBlue.withValues(alpha: 0.14),
                  _brandPurple.withValues(alpha: 0.14),
                ],
              ),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.bookmarks_outlined,
              size: 34,
              color: AppColors.base,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            isFiltered
                ? 'Không tìm thấy môn học phù hợp'
                : 'Chưa có môn học nào',
            textAlign: TextAlign.center,
            style: AppTextStyles.question.copyWith(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: AppColors.text,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            isFiltered
                ? 'Thử nhập từ khóa khác hoặc xóa bộ lọc tìm kiếm hiện tại.'
                : 'Nhấn nút "Thêm môn học" bên dưới để tạo danh mục môn học đầu tiên.',
            textAlign: TextAlign.center,
            style: AppTextStyles.text.copyWith(
              fontSize: 13.2,
              color: Colors.grey.shade500,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 18),
          ElevatedButton.icon(
            onPressed: isFiltered
                ? () {
                    _searchController.clear();
                    setState(() => _searchQuery = '');
                  }
                : _openCreateDialog,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.base,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            icon: Icon(
              isFiltered ? Icons.filter_alt_off_rounded : Icons.add_rounded,
              size: 18,
            ),
            label: Text(
              isFiltered ? 'Xóa tìm kiếm' : 'Tạo môn học đầu tiên',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}