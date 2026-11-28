import 'dart:convert';
import 'dart:core';
import 'dart:core' as core;
import 'dart:typed_data';

import 'package:image_picker/image_picker.dart';
import 'package:material_ui/material_ui.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../services/quiz_service.dart';

Widget _buildSmartImage(
  core.String source, {
  BoxFit fit = BoxFit.cover,
  required Widget fallback,
}) {
  final trimmed = source.trim();
  if (trimmed.isEmpty) return fallback;

  if (trimmed.startsWith('data:image')) {
    try {
      final commaIndex = trimmed.indexOf(',');
      if (commaIndex != -1) {
        final bytes = base64Decode(trimmed.substring(commaIndex + 1));
        return Image.memory(
          bytes,
          fit: fit,
          errorBuilder: (_, _, _) => fallback,
        );
      }
    } catch (_) {
      return fallback;
    }
  }

  return Image.network(
    trimmed,
    fit: fit,
    errorBuilder: (_, _, _) => fallback,
  );
}

Future<core.String?> _pickAndUploadImage({
  required core.String folder,
}) async {
  final picker = ImagePicker();
  final XFile? picked = await picker.pickImage(
    source: ImageSource.gallery,
    maxWidth: 1024,
    maxHeight: 1024,
    imageQuality: 80,
  );

  if (picked == null) return null;

  final Uint8List bytes = await picked.readAsBytes();
  final ext = picked.name.contains('.')
      ? picked.name.split('.').last.toLowerCase()
      : 'jpg';
  final mimeExt = ext == 'jpg' ? 'jpeg' : ext;
  final fileName =
      '$folder/${core.DateTime.now().millisecondsSinceEpoch}.$ext';

  try {
    final supabase = Supabase.instance.client;
    await supabase.storage.from('quiz_images').uploadBinary(
          fileName,
          bytes,
          fileOptions: FileOptions(
            contentType: 'image/$mimeExt',
            upsert: true,
          ),
        );
    return supabase.storage.from('quiz_images').getPublicUrl(fileName);
  } catch (_) {
    final base64Str = base64Encode(bytes);
    return 'data:image/$mimeExt;base64,$base64Str';
  }
}

class _UserQuestionItem {
  core.String content;
  core.String correctAnswer;
  core.List<core.String> wrongAnswers;
  core.String imageUrl;
  core.String? bankQuestionId;

  _UserQuestionItem({
    required this.content,
    required this.correctAnswer,
    required this.wrongAnswers,
    this.imageUrl = '',
    this.bankQuestionId,
  });
}

class CreateQuizScreen extends StatefulWidget {
  const CreateQuizScreen({super.key});

  @override
  State<CreateQuizScreen> createState() => _CreateQuizScreenState();
}

class _CreateQuizScreenState extends State<CreateQuizScreen> {
  static const Color primaryPurple = Color(0xFF565CEB);
  static const Color darkPurple = Color(0xFF3E44C6);
  static const Color cardLavender = Color(0xFFECEEFF);
  static const Color bgLight = Color(0xFFF6F7FC);
  static const Color darkText = Color(0xFF1E1E2C);

  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descController = TextEditingController();

  core.List<core.Map<core.String, dynamic>> _subjects = [];
  core.String? _selectedSubjectId;
  core.String _selectedDuration = '40:00';
  core.String _selectedVisibility = 'public'; // 'public' | 'private'
  core.String _coverImageSource = '';

  bool _isLoadingSubjects = true;
  bool _isUploadingCover = false;
  bool _isLoadingBank = false;
  bool _isSaving = false;

  final core.List<_UserQuestionItem> _questions = [];

  static const core.List<core.String> _durationOptions = [
    '10:00',
    '15:00',
    '20:00',
    '30:00',
    '40:00',
    '45:00',
    '50:00',
    '60:00',
  ];

  @override
  void initState() {
    super.initState();
    _loadSubjects();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    super.dispose();
  }

  core.Future<void> _loadSubjects() async {
    try {
      final list = await QuizService.getSubjects();
      if (!mounted) return;
      setState(() {
        _subjects = list;
        if (_subjects.isNotEmpty) {
          _selectedSubjectId = _subjects.first['id'].toString();
        }
        _isLoadingSubjects = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoadingSubjects = false);
      _showSnack(e.toString().replaceFirst('Exception: ', ''), isError: true);
    }
  }

  core.Future<void> _pickCoverFromDevice() async {
    if (_isUploadingCover) return;
    setState(() => _isUploadingCover = true);
    try {
      final uploaded = await _pickAndUploadImage(folder: 'covers');
      if (uploaded != null && mounted) {
        setState(() => _coverImageSource = uploaded);
      }
    } catch (e) {
      if (!mounted) return;
      _showSnack('Không thể chọn ảnh: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isUploadingCover = false);
    }
  }

  core.Future<void> _openQuestionEditor({
    _UserQuestionItem? existing,
    int? index,
  }) async {
    final result = await Navigator.push<_UserQuestionItem>(
      context,
      MaterialPageRoute(
        builder: (_) => _UserQuestionEditorScreen(
          quizTitle: _titleController.text.trim().isEmpty
              ? 'Tạo bộ đề mới'
              : _titleController.text.trim(),
          initialItem: existing,
        ),
      ),
    );

    if (result == null || !mounted) return;
    setState(() {
      if (index != null) {
        _questions[index] = result;
      } else {
        _questions.add(result);
      }
    });
  }

  void _removeQuestion(int index) {
    setState(() => _questions.removeAt(index));
  }

  core.Future<void> _openQuestionBankPicker() async {
    if (_selectedSubjectId == null) {
      _showSnack('Vui lòng chọn môn học trước!', isError: true);
      return;
    }

    setState(() => _isLoadingBank = true);
    core.List<core.Map<core.String, dynamic>> bankQuestions = [];

    try {
      bankQuestions =
          await QuizService.getQuestionsBySubject(_selectedSubjectId!);
    } catch (e) {
      if (mounted) {
        _showSnack(e.toString().replaceFirst('Exception: ', ''), isError: true);
        setState(() => _isLoadingBank = false);
      }
      return;
    }

    if (!mounted) return;
    setState(() => _isLoadingBank = false);

    if (bankQuestions.isEmpty) {
      _showSnack('Môn học này chưa có câu hỏi nào trong kho!', isError: true);
      return;
    }

    final existingIds = _questions
        .map((q) => q.bankQuestionId)
        .whereType<core.String>()
        .toSet();
    final selectedIds = <core.String>{};

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return SafeArea(
              child: SizedBox(
                height: MediaQuery.of(ctx).size.height * 0.78,
                child: Column(
                  children: [
                    const SizedBox(height: 10),
                    Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Kho câu hỏi (${bankQuestions.length} câu)',
                              style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                                color: darkText,
                              ),
                            ),
                          ),
                          TextButton(
                            onPressed: () {
                              setSheetState(() {
                                if (selectedIds.length ==
                                    bankQuestions.length) {
                                  selectedIds.clear();
                                } else {
                                  selectedIds.addAll(
                                    bankQuestions
                                        .map((e) => e['id'].toString()),
                                  );
                                }
                              });
                            },
                            child: Text(
                              selectedIds.length == bankQuestions.length
                                  ? 'Bỏ chọn tất cả'
                                  : 'Chọn tất cả',
                              style: const TextStyle(
                                color: primaryPurple,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    Expanded(
                      child: ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: bankQuestions.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 10),
                        itemBuilder: (_, idx) {
                          final q = bankQuestions[idx];
                          final id = q['id'].toString();
                          final alreadyAdded = existingIds.contains(id);
                          final isChecked =
                              alreadyAdded || selectedIds.contains(id);
                          final answers = (q['dap_an'] as core.List?) ?? [];

                          return InkWell(
                            onTap: alreadyAdded
                                ? null
                                : () {
                                    setSheetState(() {
                                      if (selectedIds.contains(id)) {
                                        selectedIds.remove(id);
                                      } else {
                                        selectedIds.add(id);
                                      }
                                    });
                                  },
                            borderRadius: BorderRadius.circular(14),
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: isChecked
                                    ? cardLavender
                                    : const Color(0xFFF7F8FC),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: isChecked
                                      ? primaryPurple
                                      : const Color(0xFFE3E6FA),
                                ),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Checkbox(
                                    value: isChecked,
                                    activeColor: primaryPurple,
                                    onChanged: alreadyAdded
                                        ? null
                                        : (val) {
                                            setSheetState(() {
                                              if (val == true) {
                                                selectedIds.add(id);
                                              } else {
                                                selectedIds.remove(id);
                                              }
                                            });
                                          },
                                  ),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Text(
                                              'Câu ${idx + 1}',
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 12,
                                                color: primaryPurple,
                                              ),
                                            ),
                                            if (alreadyAdded) ...[
                                              const SizedBox(width: 8),
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                  horizontal: 8,
                                                  vertical: 2,
                                                ),
                                                decoration: BoxDecoration(
                                                  color:
                                                      const Color(0xFFE8F5E9),
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                ),
                                                child: const Text(
                                                  'Đã có trong đề',
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    color: Color(0xFF2E7D32),
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          q['noi_dung']?.toString() ?? '',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 14,
                                            color: darkText,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          '${answers.length} đáp án',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey.shade600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton(
                          onPressed: selectedIds.isEmpty
                              ? null
                              : () {
                                  final chosen = bankQuestions
                                      .where((q) => selectedIds
                                          .contains(q['id'].toString()))
                                      .toList();
                                  _importSelectedBankQuestions(chosen);
                                  Navigator.pop(ctx);
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryPurple,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: Text(
                            selectedIds.isEmpty
                                ? 'Chọn câu hỏi để thêm'
                                : 'Thêm ${selectedIds.length} câu hỏi vào bộ đề',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _importSelectedBankQuestions(
    core.List<core.Map<core.String, dynamic>> chosenQuestions,
  ) {
    setState(() {
      for (final q in chosenQuestions) {
        final rawAnswers = (q['dap_an'] as core.List?) ?? [];
        core.String correctText = '';
        final wrongList = <core.String>[];

        for (final ans in rawAnswers) {
          if (ans is core.Map) {
            final text = ans['noi_dung']?.toString() ?? '';
            final isRight = ans['la_dap_an_dung'] == true ||
                ans['is_correct'] == true ||
                ans['dung_sai'] == true ||
                ans['is_dung'] == true ||
                ans['dung'] == true;
            if (isRight && correctText.isEmpty) {
              correctText = text;
            } else {
              wrongList.add(text);
            }
          }
        }

        if (correctText.isEmpty && wrongList.isNotEmpty) {
          correctText = wrongList.removeAt(0);
        }
        while (wrongList.length < 3) {
          wrongList.add('');
        }

        _questions.add(
          _UserQuestionItem(
            content: q['noi_dung']?.toString() ?? '',
            correctAnswer: correctText,
            wrongAnswers: wrongList.take(3).toList(),
            imageUrl: (q['hinh_anh_url'] ?? q['hinh_anh'] ?? '').toString(),
            bankQuestionId: q['id'].toString(),
          ),
        );
      }
    });

    _showSnack('Đã thêm ${chosenQuestions.length} câu hỏi từ kho!');
  }

  int _durationToSeconds(core.String mmss) {
    final parts = mmss.split(':');
    if (parts.length != 2) return 2400;
    final m = int.tryParse(parts[0]) ?? 40;
    final s = int.tryParse(parts[1]) ?? 0;
    return m * 60 + s;
  }

  core.Future<void> _submitQuiz() async {
    if (_titleController.text.trim().isEmpty) {
      _showSnack('Vui lòng nhập tên bộ đề!', isError: true);
      return;
    }
    if (_selectedSubjectId == null) {
      _showSnack('Vui lòng chọn môn học!', isError: true);
      return;
    }
    if (_questions.isEmpty) {
      _showSnack('Vui lòng thêm ít nhất 1 câu hỏi cho bộ đề!', isError: true);
      return;
    }

    setState(() => _isSaving = true);

    try {
      final payload = _questions.map((q) {
        final allOptions = <core.Map<core.String, dynamic>>[
          {'noi_dung': q.correctAnswer.trim(), 'is_correct': true},
          for (final w in q.wrongAnswers)
            if (w.trim().isNotEmpty)
              {'noi_dung': w.trim(), 'is_correct': false},
        ];

        return <core.String, dynamic>{
          'noi_dung': q.content.trim(),
          if (q.imageUrl.trim().isNotEmpty) 'hinh_anh_url': q.imageUrl.trim(),
          'options': allOptions,
        };
      }).toList();

      await QuizService.createExam(
        tieuDe: _titleController.text.trim(),
        moTa: _descController.text.trim(),
        monHocId: _selectedSubjectId!,
        questions: payload,
      );

      // Cập nhật thêm các trường mở rộng (thời gian, công khai/riêng tư, ảnh bìa) nếu bảng hỗ trợ
      try {
        final supabase = Supabase.instance.client;
        final seconds = _durationToSeconds(_selectedDuration);
        final latest = await supabase
            .from('bo_de')
            .select('id')
            .order('ngay_tao', ascending: false)
            .limit(1)
            .maybeSingle();
        if (latest != null && latest['id'] != null) {
          await supabase.from('bo_de').update({
            'thoi_gian': seconds,
            'trang_thai': _selectedVisibility,
            if (_coverImageSource.isNotEmpty) 'anh_bia_url': _coverImageSource,
          }).eq('id', latest['id']);
        }
      } catch (_) {}

      if (!mounted) return;
      _showSnack('Tạo bộ đề thành công!');
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      _showSnack(e.toString().replaceFirst('Exception: ', ''), isError: true);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showSnack(core.String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor:
            isError ? const Color(0xFFD32F2F) : const Color(0xFF2E7D32),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Widget _buildVisibilitySelector() {
    final isPublic = _selectedVisibility == 'public';

    return Row(
      children: [
        Expanded(
          child: InkWell(
            onTap: () => setState(() => _selectedVisibility = 'public'),
            borderRadius: BorderRadius.circular(14),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              decoration: BoxDecoration(
                color: isPublic ? const Color(0xFFEBF9F1) : Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isPublic
                      ? const Color(0xFF2E9E5B)
                      : const Color(0xFFE1E4F5),
                  width: isPublic ? 1.6 : 1,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.public_rounded,
                    size: 20,
                    color: isPublic
                        ? const Color(0xFF2E9E5B)
                        : const Color(0xFF6B708D),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Công khai',
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w800,
                            color: isPublic
                                ? const Color(0xFF2E9E5B)
                                : darkText,
                          ),
                        ),
                        const Text(
                          'Hiển thị cho mọi người',
                          style: TextStyle(
                            fontSize: 11,
                            color: Color(0xFF6B708D),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: InkWell(
            onTap: () => setState(() => _selectedVisibility = 'private'),
            borderRadius: BorderRadius.circular(14),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              decoration: BoxDecoration(
                color: !isPublic ? const Color(0xFFFFF6EA) : Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: !isPublic
                      ? const Color(0xFFE67E22)
                      : const Color(0xFFE1E4F5),
                  width: !isPublic ? 1.6 : 1,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.lock_outline_rounded,
                    size: 20,
                    color: !isPublic
                        ? const Color(0xFFE67E22)
                        : const Color(0xFF6B708D),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Riêng tư',
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w800,
                            color: !isPublic
                                ? const Color(0xFFE67E22)
                                : darkText,
                          ),
                        ),
                        const Text(
                          'Chỉ mình bạn sử dụng',
                          style: TextStyle(
                            fontSize: 11,
                            color: Color(0xFF6B708D),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: bgLight,
      body: Column(
        children: [
          // Header tím đồng nhất
          Container(
            width: double.infinity,
            padding: EdgeInsets.fromLTRB(16, topPadding + 10, 16, 18),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [primaryPurple, darkPurple],
              ),
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(26)),
            ),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760),
                child: Row(
                  children: [
                    InkWell(
                      onTap: () => Navigator.pop(context),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.16),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.arrow_back_rounded,
                          color: Colors.white,
                          size: 22,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        children: [
                          Text(
                            _titleController.text.trim().isEmpty
                                ? 'Tạo Bộ Đề Mới'
                                : _titleController.text.trim(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 2),
                          const Text(
                            'Thiết lập bộ đề & câu hỏi',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.white70,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    InkWell(
                      onTap: _isSaving ? null : _submitQuiz,
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.16),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: _isSaving
                            ? const Padding(
                                padding: EdgeInsets.all(10),
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(
                                Icons.save_outlined,
                                color: Colors.white,
                                size: 22,
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Nội dung chính
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 36),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 760),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Khung chọn ảnh bìa
                      Center(
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            InkWell(
                              onTap: _pickCoverFromDevice,
                              borderRadius: BorderRadius.circular(18),
                              child: Container(
                                width: 118,
                                height: 118,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFE2E5F3),
                                  borderRadius: BorderRadius.circular(18),
                                  border: Border.all(
                                    color: const Color(0xFFD0D5EE),
                                    width: 1.5,
                                  ),
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(16),
                                  child: _isUploadingCover
                                      ? const Center(
                                          child: CircularProgressIndicator(
                                            color: primaryPurple,
                                            strokeWidth: 2.5,
                                          ),
                                        )
                                      : _buildSmartImage(
                                          _coverImageSource,
                                          fallback: const Column(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              Icon(
                                                Icons
                                                    .add_photo_alternate_outlined,
                                                size: 34,
                                                color: primaryPurple,
                                              ),
                                              SizedBox(height: 5),
                                              Text(
                                                'Chọn ảnh bìa',
                                                style: TextStyle(
                                                  fontSize: 11.5,
                                                  fontWeight: FontWeight.w700,
                                                  color: Color(0xFF4A4E69),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                ),
                              ),
                            ),
                            if (_coverImageSource.isNotEmpty)
                              Positioned(
                                right: -6,
                                top: -6,
                                child: InkWell(
                                  onTap: () =>
                                      setState(() => _coverImageSource = ''),
                                  child: Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: const BoxDecoration(
                                      color: Colors.red,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.close_rounded,
                                      size: 14,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      const Text(
                        'Tên bộ đề:',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF4A4E69),
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _titleController,
                        onChanged: (_) => setState(() {}),
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: darkText,
                        ),
                        decoration: InputDecoration(
                          hintText: 'VD: Đề ôn tập giữa kỳ...',
                          filled: true,
                          fillColor: Colors.white,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: Color(0xFFE1E4F5),
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: Color(0xFFE1E4F5),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),

                      const Text(
                        'Mô tả ngắn:',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF4A4E69),
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _descController,
                        maxLines: 2,
                        style: const TextStyle(fontSize: 14, color: darkText),
                        decoration: InputDecoration(
                          hintText: 'Nhập mô tả cho bộ đề (không bắt buộc)...',
                          filled: true,
                          fillColor: Colors.white,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: Color(0xFFE1E4F5),
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: Color(0xFFE1E4F5),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Hàng Môn học & Thời gian
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Môn học:',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF4A4E69),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                _isLoadingSubjects
                                    ? const SizedBox(
                                        height: 48,
                                        child: Center(
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: primaryPurple,
                                          ),
                                        ),
                                      )
                                    : Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius:
                                              BorderRadius.circular(12),
                                          border: Border.all(
                                            color: const Color(0xFFE1E4F5),
                                          ),
                                        ),
                                        child: DropdownButtonHideUnderline(
                                          child: DropdownButton<core.String>(
                                            value: _selectedSubjectId,
                                            isExpanded: true,
                                            items: _subjects.map((sub) {
                                              final label = (sub['ten_mon'] ??
                                                      sub['ten_mon_hoc'] ??
                                                      sub['ten'] ??
                                                      '')
                                                  .toString();
                                              return DropdownMenuItem<
                                                  core.String>(
                                                value: sub['id'].toString(),
                                                child: Text(
                                                  label,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              );
                                            }).toList(),
                                            onChanged: (val) => setState(
                                              () => _selectedSubjectId = val,
                                            ),
                                          ),
                                        ),
                                      ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Thời gian:',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF4A4E69),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: const Color(0xFFE1E4F5),
                                    ),
                                  ),
                                  child: DropdownButtonHideUnderline(
                                    child: DropdownButton<core.String>(
                                      value: _selectedDuration,
                                      isExpanded: true,
                                      items: _durationOptions
                                          .map(
                                            (d) => DropdownMenuItem(
                                              value: d,
                                              child: Text(d),
                                            ),
                                          )
                                          .toList(),
                                      onChanged: (val) {
                                        if (val != null) {
                                          setState(
                                            () => _selectedDuration = val,
                                          );
                                        }
                                      },
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // Chế độ Công khai / Riêng tư
                      const Text(
                        'Chế độ hiển thị:',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF4A4E69),
                        ),
                      ),
                      const SizedBox(height: 6),
                      _buildVisibilitySelector(),
                      const SizedBox(height: 18),

                      // Danh sách câu hỏi
                      Row(
                        children: [
                          Text(
                            'Câu hỏi (${_questions.length})',
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: darkText,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      if (_questions.isEmpty)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFFE6E8F8)),
                          ),
                          child: const Text(
                            'Chưa có câu hỏi nào. Bấm "Chọn từ kho" hoặc "Thêm câu mới" bên dưới.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.grey),
                          ),
                        )
                      else
                        ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _questions.length,
                          itemBuilder: (_, idx) {
                            final q = _questions[idx];
                            return Container(
                              margin: const EdgeInsets.only(bottom: 10),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: const Color(0xFFE6E8F8),
                                ),
                              ),
                              child: InkWell(
                                onTap: () => _openQuestionEditor(
                                  existing: q,
                                  index: idx,
                                ),
                                borderRadius: BorderRadius.circular(14),
                                child: Padding(
                                  padding: const EdgeInsets.all(10),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 48,
                                        height: 48,
                                        decoration: BoxDecoration(
                                          color: cardLavender,
                                          borderRadius:
                                              BorderRadius.circular(10),
                                        ),
                                        child: ClipRRect(
                                          borderRadius:
                                              BorderRadius.circular(10),
                                          child: _buildSmartImage(
                                            q.imageUrl,
                                            fallback: const Icon(
                                              Icons.image_outlined,
                                              color: primaryPurple,
                                              size: 22,
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Expanded(
                                                  child: Text(
                                                    q.content,
                                                    maxLines: 2,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                    style: const TextStyle(
                                                      fontSize: 13.5,
                                                      fontWeight:
                                                          FontWeight.w700,
                                                      color: darkText,
                                                    ),
                                                  ),
                                                ),
                                                if (q.bankQuestionId != null)
                                                  Container(
                                                    margin:
                                                        const EdgeInsets.only(
                                                      left: 6,
                                                    ),
                                                    padding: const EdgeInsets
                                                        .symmetric(
                                                      horizontal: 6,
                                                      vertical: 2,
                                                    ),
                                                    decoration: BoxDecoration(
                                                      color: cardLavender,
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                        6,
                                                      ),
                                                    ),
                                                    child: const Text(
                                                      'Từ kho',
                                                      style: TextStyle(
                                                        fontSize: 10,
                                                        fontWeight:
                                                            FontWeight.w700,
                                                        color: primaryPurple,
                                                      ),
                                                    ),
                                                  ),
                                              ],
                                            ),
                                            const SizedBox(height: 3),
                                            Text(
                                              q.correctAnswer,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                fontSize: 12.5,
                                                fontWeight: FontWeight.w700,
                                                color: Color(0xFF2E9E5B),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      IconButton(
                                        icon: const Icon(
                                          Icons.delete_outline_rounded,
                                          color: Colors.red,
                                          size: 21,
                                        ),
                                        onPressed: () => _removeQuestion(idx),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),

                      const SizedBox(height: 14),

                      // Hai nút: Chọn từ kho & Thêm câu mới
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _isLoadingBank
                                  ? null
                                  : _openQuestionBankPicker,
                              style: OutlinedButton.styleFrom(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 14),
                                backgroundColor: cardLavender,
                                side: const BorderSide(
                                  color: primaryPurple,
                                  width: 1.5,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              icon: _isLoadingBank
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: primaryPurple,
                                      ),
                                    )
                                  : const Icon(
                                      Icons.library_add_check_outlined,
                                      color: primaryPurple,
                                    ),
                              label: const Text(
                                'Chọn từ kho',
                                style: TextStyle(
                                  color: primaryPurple,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => _openQuestionEditor(),
                              style: OutlinedButton.styleFrom(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 14),
                                backgroundColor: Colors.white,
                                side: const BorderSide(
                                  color: primaryPurple,
                                  width: 1.5,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              icon: const Icon(
                                Icons.add_circle_outline_rounded,
                                color: primaryPurple,
                              ),
                              label: const Text(
                                'Thêm câu mới',
                                style: TextStyle(
                                  color: primaryPurple,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 18),

                      // Nút Hoàn tất & Tạo bộ đề
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton(
                          onPressed: _isSaving ? null : _submitQuiz,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFF6A623),
                            foregroundColor: darkText,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: _isSaving
                              ? const CircularProgressIndicator(color: darkText)
                              : const Text(
                                  'Hoàn tất & Tạo bộ đề',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _UserQuestionEditorScreen extends StatefulWidget {
  final core.String quizTitle;
  final _UserQuestionItem? initialItem;

  const _UserQuestionEditorScreen({
    required this.quizTitle,
    this.initialItem,
  });

  @override
  State<_UserQuestionEditorScreen> createState() =>
      _UserQuestionEditorScreenState();
}

class _UserQuestionEditorScreenState extends State<_UserQuestionEditorScreen> {
  static const Color primaryPurple = Color(0xFF565CEB);
  static const Color darkPurple = Color(0xFF3E44C6);
  static const Color bgLight = Color(0xFFF6F7FC);
  static const Color darkText = Color(0xFF1E1E2C);

  final TextEditingController _questionController = TextEditingController();
  final TextEditingController _correctAnswerController = TextEditingController();
  final TextEditingController _wrong1Controller = TextEditingController();
  final TextEditingController _wrong2Controller = TextEditingController();
  final TextEditingController _wrong3Controller = TextEditingController();

  core.String _imageSource = '';
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    final item = widget.initialItem;
    if (item != null) {
      _questionController.text = item.content;
      _correctAnswerController.text = item.correctAnswer;
      _imageSource = item.imageUrl;
      if (item.wrongAnswers.isNotEmpty) {
        _wrong1Controller.text = item.wrongAnswers[0];
      }
      if (item.wrongAnswers.length > 1) {
        _wrong2Controller.text = item.wrongAnswers[1];
      }
      if (item.wrongAnswers.length > 2) {
        _wrong3Controller.text = item.wrongAnswers[2];
      }
    }
  }

  @override
  void dispose() {
    _questionController.dispose();
    _correctAnswerController.dispose();
    _wrong1Controller.dispose();
    _wrong2Controller.dispose();
    _wrong3Controller.dispose();
    super.dispose();
  }

  core.Future<void> _pickImage() async {
    if (_isUploading) return;
    setState(() => _isUploading = true);
    try {
      final uploaded = await _pickAndUploadImage(folder: 'questions');
      if (uploaded != null && mounted) {
        setState(() => _imageSource = uploaded);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Không thể chọn ảnh: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  void _save() {
    final content = _questionController.text.trim();
    final correct = _correctAnswerController.text.trim();
    final w1 = _wrong1Controller.text.trim();
    final w2 = _wrong2Controller.text.trim();
    final w3 = _wrong3Controller.text.trim();

    if (content.isEmpty || correct.isEmpty || w1.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Vui lòng nhập nội dung câu hỏi, đáp án đúng và ít nhất 1 đáp án sai.',
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    Navigator.pop(
      context,
      _UserQuestionItem(
        content: content,
        correctAnswer: correct,
        wrongAnswers: [w1, w2, w3],
        imageUrl: _imageSource,
        bankQuestionId: widget.initialItem?.bankQuestionId,
      ),
    );
  }

  InputDecoration _fieldDecoration({
    required core.String hint,
    Color borderColor = const Color(0xFFE1E4F5),
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      hintText: hint,
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: borderColor, width: 1.4),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: borderColor, width: 1.4),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: borderColor, width: 1.8),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: bgLight,
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: EdgeInsets.fromLTRB(16, topPadding + 10, 16, 18),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [primaryPurple, darkPurple],
              ),
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(26)),
            ),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760),
                child: Row(
                  children: [
                    InkWell(
                      onTap: () => Navigator.pop(context),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.16),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.arrow_back_rounded,
                          color: Colors.white,
                          size: 22,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        children: [
                          Text(
                            widget.quizTitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 17.5,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 2),
                          const Text(
                            'Soạn nội dung câu hỏi',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.white70,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    InkWell(
                      onTap: _save,
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.16),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.save_outlined,
                          color: Colors.white,
                          size: 22,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 32),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 760),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            InkWell(
                              onTap: _pickImage,
                              borderRadius: BorderRadius.circular(18),
                              child: Container(
                                width: 118,
                                height: 118,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFE2E5F3),
                                  borderRadius: BorderRadius.circular(18),
                                  border: Border.all(
                                    color: const Color(0xFFD0D5EE),
                                    width: 1.5,
                                  ),
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(16),
                                  child: _isUploading
                                      ? const Center(
                                          child: CircularProgressIndicator(
                                            color: primaryPurple,
                                            strokeWidth: 2.5,
                                          ),
                                        )
                                      : _buildSmartImage(
                                          _imageSource,
                                          fallback: const Column(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              Icon(
                                                Icons
                                                    .add_photo_alternate_outlined,
                                                size: 34,
                                                color: primaryPurple,
                                              ),
                                              SizedBox(height: 5),
                                              Text(
                                                'Chọn ảnh',
                                                style: TextStyle(
                                                  fontSize: 11.5,
                                                  fontWeight: FontWeight.w700,
                                                  color: Color(0xFF4A4E69),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                ),
                              ),
                            ),
                            if (_imageSource.isNotEmpty)
                              Positioned(
                                right: -6,
                                top: -6,
                                child: InkWell(
                                  onTap: () =>
                                      setState(() => _imageSource = ''),
                                  child: Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: const BoxDecoration(
                                      color: Colors.red,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.close_rounded,
                                      size: 14,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),
                      const Text(
                        'Câu hỏi:',
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          color: darkText,
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _questionController,
                        maxLines: 2,
                        onChanged: (_) => setState(() {}),
                        style: const TextStyle(fontSize: 14, color: darkText),
                        decoration: _fieldDecoration(
                          hint: 'Nhập nội dung câu hỏi...',
                          suffixIcon: _questionController.text.isNotEmpty
                              ? IconButton(
                                  icon:
                                      const Icon(Icons.close_rounded, size: 19),
                                  onPressed: () {
                                    _questionController.clear();
                                    setState(() {});
                                  },
                                )
                              : null,
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Đáp án đúng:',
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF2E9E5B),
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _correctAnswerController,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: darkText,
                        ),
                        decoration: _fieldDecoration(
                          hint: 'Nhập đáp án đúng...',
                          borderColor: const Color(0xFF3CC172),
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Đáp án sai:',
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFFE05252),
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _wrong1Controller,
                        style: const TextStyle(fontSize: 14, color: darkText),
                        decoration: _fieldDecoration(
                          hint: 'Đáp án sai 1...',
                          borderColor: const Color(0xFFE89B9B),
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _wrong2Controller,
                        style: const TextStyle(fontSize: 14, color: darkText),
                        decoration: _fieldDecoration(
                          hint: 'Đáp án sai 2...',
                          borderColor: const Color(0xFFE89B9B),
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _wrong3Controller,
                        style: const TextStyle(fontSize: 14, color: darkText),
                        decoration: _fieldDecoration(
                          hint: 'Đáp án sai 3...',
                          borderColor: const Color(0xFFE89B9B),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}