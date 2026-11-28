import 'dart:convert';
import 'dart:core';
import 'dart:core' as core;
import 'dart:typed_data';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:material_ui/material_ui.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../services/quiz_service.dart';

Widget buildSmartQuizImage(
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

Future<core.String?> pickAndUploadQuizImage(
  BuildContext context, {
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

core.String normalizeVisibility(dynamic rawStatus) {
  final val = (rawStatus ?? 'public').toString().trim().toLowerCase();
  if (val == 'private' || val == 'rieng_tu' || val == 'draft') {
    return 'private';
  }
  return 'public';
}

class QuizSetManagementScreen extends StatefulWidget {
  const QuizSetManagementScreen({super.key});

  @override
  State<QuizSetManagementScreen> createState() =>
      _QuizSetManagementScreenState();
}

class _QuizSetManagementScreenState extends State<QuizSetManagementScreen> {
  static const Color primaryPurple = Color(0xFF565CEB);
  static const Color cardLavender = Color(0xFFECEEFF);
  static const Color bgLight = Color(0xFFF6F7FC);
  static const Color darkText = Color(0xFF1E1E2C);

  final SupabaseClient _supabase = Supabase.instance.client;
  final TextEditingController _searchController = TextEditingController();

  core.List<core.Map<core.String, dynamic>> _quizSets = [];
  core.List<core.Map<core.String, dynamic>> _subjects = [];
  core.Map<core.String, core.String> _creatorNames = {};

  bool _isLoading = true;
  bool _showSearchBar = false;
  core.String? _errorMessage;
  core.String _searchQuery = '';
  core.String _selectedSubjectFilter = 'all';
  core.String _selectedVisibilityFilter = 'all';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      core.List<core.Map<core.String, dynamic>> loadedSubjects = [];
      try {
        loadedSubjects = await QuizService.getSubjects();
      } catch (_) {
        try {
          final res = await _supabase.from('mon_hoc').select();
          loadedSubjects = (res as core.List)
              .map((e) => core.Map<core.String, dynamic>.from(e as core.Map))
              .toList();
        } catch (_) {}
      }

      final core.Map<core.String, core.String> userMap = {};
      try {
        final usersRes =
            await _supabase.from('nguoi_dung').select('id, ho_ten, email');
        for (final row in (usersRes as core.List)) {
          if (row is core.Map) {
            final id = row['id']?.toString() ?? '';
            final name = (row['ho_ten'] ?? '').toString().trim();
            final email = (row['email'] ?? '').toString().trim();
            if (id.isNotEmpty) {
              userMap[id] = name.isNotEmpty
                  ? name
                  : (email.contains('@') ? email.split('@').first : 'Player');
            }
          }
        }
      } catch (_) {}

      final setsRes = await _supabase
          .from('bo_de')
          .select()
          .order('ngay_tao', ascending: false);

      final loadedSets = (setsRes as core.List)
          .map((e) => core.Map<core.String, dynamic>.from(e as core.Map))
          .toList();

      try {
        final qRes = await _supabase.from('cau_hoi').select('id, bo_de_id');
        final core.Map<core.String, int> countMap = {};
        for (final q in (qRes as core.List)) {
          if (q is core.Map) {
            final setId = q['bo_de_id']?.toString() ?? '';
            if (setId.isNotEmpty) {
              countMap[setId] = (countMap[setId] ?? 0) + 1;
            }
          }
        }
        for (final s in loadedSets) {
          final id = s['id']?.toString() ?? '';
          if (countMap.containsKey(id)) {
            s['_computed_question_count'] = countMap[id];
          }
        }
      } catch (_) {}

      if (!mounted) return;
      setState(() {
        _subjects = loadedSubjects;
        _creatorNames = userMap;
        _quizSets = loadedSets;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  core.String _getSubjectName(core.Map<core.String, dynamic> quizSet) {
    final directName = (quizSet['ten_mon'] ??
            quizSet['ten_mon_hoc'] ??
            quizSet['ten_chu_de'] ??
            quizSet['chu_de'] ??
            '')
        .toString()
        .trim();
    if (directName.isNotEmpty) return directName;

    final subjectId =
        (quizSet['mon_hoc_id'] ?? quizSet['chu_de_id'] ?? '').toString();
    if (subjectId.isNotEmpty) {
      for (final s in _subjects) {
        if (s['id']?.toString() == subjectId) {
          return (s['ten_mon'] ??
                  s['ten_mon_hoc'] ??
                  s['ten_chu_de'] ??
                  s['ten'] ??
                  'Chung')
              .toString();
        }
      }
    }
    return 'Chung';
  }

  core.String _getCreatorName(core.Map<core.String, dynamic> quizSet) {
    final direct = (quizSet['ten_nguoi_tao'] ?? '').toString().trim();
    if (direct.isNotEmpty) return direct;

    final creatorId =
        (quizSet['nguoi_tao_id'] ?? quizSet['user_id'] ?? '').toString();
    if (creatorId.isNotEmpty && _creatorNames.containsKey(creatorId)) {
      return _creatorNames[creatorId]!;
    }
    return 'Admin';
  }

  int _getQuestionCount(core.Map<core.String, dynamic> quizSet) {
    if (quizSet['_computed_question_count'] != null) {
      return quizSet['_computed_question_count'] as int;
    }
    final raw = quizSet['so_cau_hoi'] ?? quizSet['question_count'] ?? 0;
    return int.tryParse(raw.toString()) ?? 0;
  }

  core.String _formatDuration(dynamic rawSecondsOrText) {
    if (rawSecondsOrText == null) return '20:00';
    final str = rawSecondsOrText.toString().trim();
    if (str.contains(':')) return str;
    final totalSeconds = int.tryParse(str) ?? 1200;
    final minutes = (totalSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (totalSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  core.List<core.Map<core.String, dynamic>> get _filteredQuizSets {
    return _quizSets.where((item) {
      final title =
          (item['ten_bo_de'] ?? item['tieu_de'] ?? '').toString().toLowerCase();
      final subject = _getSubjectName(item);
      final creator = _getCreatorName(item).toLowerCase();
      final visibility = normalizeVisibility(item['trang_thai']);

      if (_selectedSubjectFilter != 'all' &&
          subject != _selectedSubjectFilter) {
        return false;
      }

      if (_selectedVisibilityFilter != 'all' &&
          visibility != _selectedVisibilityFilter) {
        return false;
      }

      if (_searchQuery.trim().isNotEmpty) {
        final q = _searchQuery.trim().toLowerCase();
        return title.contains(q) ||
            subject.toLowerCase().contains(q) ||
            creator.contains(q);
      }
      return true;
    }).toList();
  }

  void _openFilterSheet() {
    final subjectNames = <core.String>{
      'all',
      ..._quizSets.map(_getSubjectName),
    }.toList();

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'Lọc bộ đề',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: darkText,
                      ),
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'Chủ đề / Môn học',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF4A4E69),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: subjectNames.map((sub) {
                        final selected = _selectedSubjectFilter == sub;
                        return ChoiceChip(
                          label: Text(sub == 'all' ? 'Tất cả' : sub),
                          selected: selected,
                          selectedColor: primaryPurple,
                          labelStyle: TextStyle(
                            color: selected ? Colors.white : darkText,
                            fontWeight: FontWeight.w600,
                            fontSize: 12.5,
                          ),
                          onSelected: (_) {
                            setModalState(() => _selectedSubjectFilter = sub);
                            setState(() {});
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Chế độ hiển thị',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF4A4E69),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: [
                        {'key': 'all', 'label': 'Tất cả'},
                        {'key': 'public', 'label': 'Công khai'},
                        {'key': 'private', 'label': 'Riêng tư'},
                      ].map((st) {
                        final key = st['key']!;
                        final selected = _selectedVisibilityFilter == key;
                        return ChoiceChip(
                          label: Text(st['label']!),
                          selected: selected,
                          selectedColor: primaryPurple,
                          labelStyle: TextStyle(
                            color: selected ? Colors.white : darkText,
                            fontWeight: FontWeight.w600,
                            fontSize: 12.5,
                          ),
                          onSelected: (_) {
                            setModalState(
                              () => _selectedVisibilityFilter = key,
                            );
                            setState(() {});
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 18),
                    SizedBox(
                      width: double.infinity,
                      height: 46,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryPurple,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text(
                          'Áp dụng bộ lọc',
                          style: TextStyle(fontWeight: FontWeight.w700),
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

  Future<void> _deleteQuizSet(core.Map<core.String, dynamic> quizSet) async {
    final id = quizSet['id']?.toString() ?? '';
    final title = (quizSet['ten_bo_de'] ?? quizSet['tieu_de'] ?? 'bộ đề này')
        .toString();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('Xóa bộ đề?'),
        content: Text(
          'Bạn có chắc muốn xóa bộ đề "$title"? Toàn bộ câu hỏi bên trong cũng sẽ bị xóa.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade600,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );

    if (confirmed != true || id.isEmpty) return;

    try {
      try {
        await _supabase.from('cau_hoi').delete().eq('bo_de_id', id);
      } catch (_) {}
      await _supabase.from('bo_de').delete().eq('id', id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Đã xóa bộ đề thành công.'),
          backgroundColor: Colors.green,
        ),
      );
      await _loadData();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Lỗi khi xóa: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _openQuizSetDetail({
    core.Map<core.String, dynamic>? quizSet,
  }) async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => QuizSetDetailScreen(
          quizSet: quizSet,
          subjects: _subjects,
          creatorName: quizSet != null ? _getCreatorName(quizSet) : 'Admin',
        ),
      ),
    );

    if (changed == true && mounted) {
      await _loadData();
    }
  }

  Widget _buildVisibilityBadge(bool isPublic) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
      decoration: BoxDecoration(
        color: isPublic ? const Color(0xFFE8F7EE) : const Color(0xFFFFF3E0),
        borderRadius: BorderRadius.circular(7),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isPublic ? Icons.public_rounded : Icons.lock_outline_rounded,
            size: 12,
            color: isPublic
                ? const Color(0xFF2E9E5B)
                : const Color(0xFFE67E22),
          ),
          const SizedBox(width: 3),
          Text(
            isPublic ? 'Công khai' : 'Riêng tư',
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              color: isPublic
                  ? const Color(0xFF2E9E5B)
                  : const Color(0xFFE67E22),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuizSetCard(core.Map<core.String, dynamic> quizSet) {
    final title =
        (quizSet['ten_bo_de'] ?? quizSet['tieu_de'] ?? 'Bộ đề chưa đặt tên')
            .toString();
    final subject = _getSubjectName(quizSet);
    final questionCount = _getQuestionCount(quizSet);
    final creator = _getCreatorName(quizSet);
    final duration =
        _formatDuration(quizSet['thoi_gian'] ?? quizSet['thoi_gian_lam_bai']);
    final imageUrl =
        (quizSet['anh_bia_url'] ?? quizSet['hinh_anh'] ?? '').toString().trim();
    final isPublic = normalizeVisibility(quizSet['trang_thai']) == 'public';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE6E8F8)),
        boxShadow: [
          BoxShadow(
            color: primaryPurple.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: InkWell(
        onTap: () => _openQuizSetDetail(quizSet: quizSet),
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                width: 68,
                height: 68,
                decoration: BoxDecoration(
                  color: cardLavender,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFDDE1FA)),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(13),
                  child: buildSmartQuizImage(
                    imageUrl,
                    fallback: const Icon(
                      Icons.quiz_rounded,
                      color: primaryPurple,
                      size: 30,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: darkText,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        _buildVisibilityBadge(isPublic),
                        const SizedBox(width: 2),
                        SizedBox(
                          width: 28,
                          height: 28,
                          child: PopupMenuButton<core.String>(
                            padding: EdgeInsets.zero,
                            icon: const Icon(
                              Icons.drag_handle_rounded,
                              color: Color(0xFF4A4E69),
                              size: 20,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            onSelected: (value) {
                              if (value == 'edit') {
                                _openQuizSetDetail(quizSet: quizSet);
                              } else if (value == 'delete') {
                                _deleteQuizSet(quizSet);
                              }
                            },
                            itemBuilder: (_) => const [
                              PopupMenuItem(
                                value: 'edit',
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.edit_outlined,
                                      size: 18,
                                      color: primaryPurple,
                                    ),
                                    SizedBox(width: 8),
                                    Text(
                                      'Chỉnh sửa',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              PopupMenuItem(
                                value: 'delete',
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.delete_outline_rounded,
                                      size: 18,
                                      color: Colors.red,
                                    ),
                                    SizedBox(width: 8),
                                    Text(
                                      'Xóa',
                                      style: TextStyle(
                                        color: Colors.red,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Chủ đề: $subject',
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF4A4E69),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Số câu hỏi: $questionCount',
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: Color(0xFF6B708D),
                      ),
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Người tạo: $creator',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF7D829E),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          duration,
                          style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: primaryPurple,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredQuizSets;
    final topPadding = MediaQuery.of(context).padding.top;
    final hasActiveFilter =
        _selectedSubjectFilter != 'all' || _selectedVisibilityFilter != 'all';

    return Scaffold(
      backgroundColor: bgLight,
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openQuizSetDetail(),
        backgroundColor: const Color(0xFFF6A623),
        foregroundColor: darkText,
        shape: const CircleBorder(),
        child: const Icon(Icons.add_rounded, size: 30),
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: EdgeInsets.fromLTRB(16, topPadding + 10, 16, 16),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF565CEB), Color(0xFF3E44C6)],
              ),
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(26)),
            ),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760),
                child: Column(
                  children: [
                    Row(
                      children: [
                        if (Navigator.canPop(context))
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
                          )
                        else
                          const SizedBox(width: 40),
                        const Expanded(
                          child: Text(
                            'Quản lí bộ đề',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 19,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        InkWell(
                          onTap: () {
                            setState(() {
                              _showSearchBar = !_showSearchBar;
                              if (!_showSearchBar) {
                                _searchController.clear();
                                _searchQuery = '';
                              }
                            });
                          },
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.16),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              _showSearchBar
                                  ? Icons.close_rounded
                                  : Icons.search_rounded,
                              color: Colors.white,
                              size: 22,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (_showSearchBar) ...[
                      const SizedBox(height: 12),
                      TextField(
                        controller: _searchController,
                        autofocus: true,
                        onChanged: (v) => setState(() => _searchQuery = v),
                        style: const TextStyle(fontSize: 14, color: darkText),
                        decoration: InputDecoration(
                          hintText: 'Tìm tên bộ đề, chủ đề, người tạo...',
                          prefixIcon: const Icon(
                            Icons.search_rounded,
                            color: primaryPurple,
                          ),
                          filled: true,
                          fillColor: Colors.white,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
                child: Row(
                  children: [
                    InkWell(
                      onTap: _openFilterSheet,
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: hasActiveFilter ? primaryPurple : Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: hasActiveFilter
                                ? primaryPurple
                                : const Color(0xFFE1E4F5),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.filter_alt_outlined,
                              size: 19,
                              color: hasActiveFilter ? Colors.white : darkText,
                            ),
                            if (hasActiveFilter) ...[
                              const SizedBox(width: 6),
                              const Text(
                                'Đang lọc',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '${filtered.length} bộ đề',
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF6B708D),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: primaryPurple),
                  )
                : _errorMessage != null
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.error_outline_rounded,
                                color: Colors.red,
                                size: 48,
                              ),
                              const SizedBox(height: 10),
                              Text(
                                _errorMessage!,
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 14),
                              ElevatedButton(
                                onPressed: _loadData,
                                child: const Text('Thử lại'),
                              ),
                            ],
                          ),
                        ),
                      )
                    : Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 760),
                          child: filtered.isEmpty
                              ? const Center(
                                  child: Text(
                                    'Chưa có bộ đề nào phù hợp.',
                                    style: TextStyle(color: Colors.grey),
                                  ),
                                )
                              : RefreshIndicator(
                                  onRefresh: _loadData,
                                  color: primaryPurple,
                                  child: ListView.builder(
                                    padding: const EdgeInsets.fromLTRB(
                                      16,
                                      6,
                                      16,
                                      84,
                                    ),
                                    itemCount: filtered.length,
                                    itemBuilder: (_, idx) =>
                                        _buildQuizSetCard(filtered[idx]),
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

// ============================================================================
// MÀN HÌNH 2: CHI TIẾT BỘ ĐỀ & QUẢN LÍ DANH SÁCH CÂU HỎI
// ============================================================================

class QuizSetDetailScreen extends StatefulWidget {
  final core.Map<core.String, dynamic>? quizSet;
  final core.List<core.Map<core.String, dynamic>> subjects;
  final core.String creatorName;

  const QuizSetDetailScreen({
    super.key,
    this.quizSet,
    required this.subjects,
    required this.creatorName,
  });

  @override
  State<QuizSetDetailScreen> createState() => _QuizSetDetailScreenState();
}

class _QuizSetDetailScreenState extends State<QuizSetDetailScreen> {
  static const Color primaryPurple = Color(0xFF565CEB);
  static const Color cardLavender = Color(0xFFECEEFF);
  static const Color bgLight = Color(0xFFF6F7FC);
  static const Color darkText = Color(0xFF1E1E2C);

  final SupabaseClient _supabase = Supabase.instance.client;
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descController = TextEditingController();

  core.String _coverImageSource = '';
  bool _isUploadingCover = false;
  bool _isLoadingBank = false;

  core.List<core.Map<core.String, dynamic>> _questions = [];
  core.String _selectedSubject = 'Lập trình';
  core.String _selectedDuration = '40:00';
  core.String _selectedVisibility = 'public'; // 'public' | 'private'

  bool _isLoadingQuestions = false;
  bool _isSaving = false;
  bool _hasChanges = false;

  static const core.List<core.String> _defaultSubjects = [
    'Lập trình',
    'Toán',
    'Địa lý',
    'Ngoại ngữ',
    'Ngữ văn',
    'Tin học',
  ];

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

  bool get _isEditing => widget.quizSet != null;
  core.String get _quizSetId => widget.quizSet?['id']?.toString() ?? '';

  core.List<core.String> get _subjectItems {
    final set = <core.String>{..._defaultSubjects};
    for (final s in widget.subjects) {
      final name = (s['ten_mon'] ??
              s['ten_mon_hoc'] ??
              s['ten_chu_de'] ??
              s['ten'] ??
              '')
          .toString()
          .trim();
      if (name.isNotEmpty) set.add(name);
    }
    if (_selectedSubject.isNotEmpty) set.add(_selectedSubject);
    return set.toList();
  }

  core.String? _getSelectedSubjectId() {
    for (final s in widget.subjects) {
      final name = (s['ten_mon'] ??
              s['ten_mon_hoc'] ??
              s['ten_chu_de'] ??
              s['ten'] ??
              '')
          .toString()
          .trim();
      if (name == _selectedSubject) {
        return s['id']?.toString();
      }
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    if (widget.quizSet != null) {
      final qs = widget.quizSet!;
      _titleController.text =
          (qs['ten_bo_de'] ?? qs['tieu_de'] ?? '').toString();
      _descController.text = (qs['mo_ta'] ?? '').toString();
      _coverImageSource =
          (qs['anh_bia_url'] ?? qs['hinh_anh'] ?? '').toString().trim();

      final rawSub = (qs['ten_mon'] ??
              qs['ten_mon_hoc'] ??
              qs['ten_chu_de'] ??
              qs['chu_de'] ??
              '')
          .toString()
          .trim();
      if (rawSub.isNotEmpty) {
        _selectedSubject = rawSub;
      } else if (_subjectItems.isNotEmpty) {
        _selectedSubject = _subjectItems.first;
      }

      final rawTime =
          (qs['thoi_gian'] ?? qs['thoi_gian_lam_bai'] ?? '40:00').toString();
      if (rawTime.contains(':')) {
        _selectedDuration = rawTime;
      } else {
        final sec = int.tryParse(rawTime) ?? 2400;
        final formatted =
            '${(sec ~/ 60).toString().padLeft(2, '0')}:${(sec % 60).toString().padLeft(2, '0')}';
        _selectedDuration = _durationOptions.contains(formatted)
            ? formatted
            : '40:00';
      }

      _selectedVisibility = normalizeVisibility(qs['trang_thai']);
      _loadQuestions();
    } else {
      _titleController.text = 'Bộ đề mới';
      if (_subjectItems.isNotEmpty) {
        _selectedSubject = _subjectItems.first;
      }
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _loadQuestions() async {
    if (_quizSetId.isEmpty) return;
    setState(() => _isLoadingQuestions = true);
    try {
      final res = await _supabase
          .from('cau_hoi')
          .select()
          .eq('bo_de_id', _quizSetId);
      if (!mounted) return;
      setState(() {
        _questions = (res as core.List)
            .map((e) => core.Map<core.String, dynamic>.from(e as core.Map))
            .toList();
        _isLoadingQuestions = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoadingQuestions = false);
    }
  }

  Future<void> _pickCoverFromDevice() async {
    if (_isUploadingCover) return;
    setState(() => _isUploadingCover = true);
    try {
      final uploaded = await pickAndUploadQuizImage(
        context,
        folder: 'covers',
      );
      if (uploaded != null && mounted) {
        setState(() => _coverImageSource = uploaded);
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
      if (mounted) setState(() => _isUploadingCover = false);
    }
  }

  Future<void> _openQuestionBankPicker() async {
    final subjectId = _getSelectedSubjectId();
    if (subjectId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Môn học này chưa có dữ liệu trong kho câu hỏi.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isLoadingBank = true);
    core.List<core.Map<core.String, dynamic>> bankQuestions = [];

    try {
      bankQuestions = await QuizService.getQuestionsBySubject(subjectId);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi tải kho câu hỏi: $e')),
        );
        setState(() => _isLoadingBank = false);
      }
      return;
    }

    if (!mounted) return;
    setState(() => _isLoadingBank = false);

    if (bankQuestions.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Môn học này chưa có câu hỏi nào trong kho!'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

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
                          final isChecked = selectedIds.contains(id);
                          final answers = (q['dap_an'] as core.List?) ?? [];

                          return InkWell(
                            onTap: () {
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
                                    onChanged: (val) {
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
                                        Text(
                                          'Câu ${idx + 1}',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12,
                                            color: primaryPurple,
                                          ),
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
                              : () async {
                                  final chosen = bankQuestions
                                      .where((q) => selectedIds
                                          .contains(q['id'].toString()))
                                      .toList();
                                  Navigator.pop(ctx);
                                  await _importFromBank(chosen);
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

  Future<void> _importFromBank(
    core.List<core.Map<core.String, dynamic>> chosen,
  ) async {
    for (final q in chosen) {
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

      final newQuestion = <core.String, dynamic>{
        'noi_dung': q['noi_dung']?.toString() ?? '',
        'dap_an_dung': correctText,
        'dap_an_sai_1': wrongList[0],
        'dap_an_sai_2': wrongList[1],
        'dap_an_sai_3': wrongList[2],
        'hinh_anh_url': (q['hinh_anh_url'] ?? q['hinh_anh'] ?? '').toString(),
      };

      if (_isEditing && _quizSetId.isNotEmpty) {
        try {
          newQuestion['bo_de_id'] = _quizSetId;
          await _supabase.from('cau_hoi').insert(newQuestion);
          _hasChanges = true;
        } catch (_) {}
      } else {
        setState(() => _questions.add(newQuestion));
      }
    }

    if (_isEditing && _quizSetId.isNotEmpty) {
      await _loadQuestions();
    }
  }

  int _durationToSeconds(core.String mmss) {
    final parts = mmss.split(':');
    if (parts.length != 2) return 2400;
    final m = int.tryParse(parts[0]) ?? 40;
    final s = int.tryParse(parts[1]) ?? 0;
    return m * 60 + s;
  }

  Future<void> _saveQuizSet() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng nhập tên bộ đề.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      final currentUid = FirebaseAuth.instance.currentUser?.uid;
      final seconds = _durationToSeconds(_selectedDuration);
      final subjectId = _getSelectedSubjectId();

      final payload = <core.String, dynamic>{
        'ten_bo_de': title,
        'chu_de': _selectedSubject,
        'mon_hoc_id': ?subjectId,
        'thoi_gian': seconds,
        'trang_thai': _selectedVisibility,
        'so_cau_hoi': _questions.length,
        'anh_bia_url':
            _coverImageSource.isNotEmpty ? _coverImageSource : null,
      };

      if (_isEditing && _quizSetId.isNotEmpty) {
        await _supabase.from('bo_de').update(payload).eq('id', _quizSetId);
      } else {
        if (currentUid != null) {
          payload['nguoi_tao_id'] = currentUid;
        }
        final inserted =
            await _supabase.from('bo_de').insert(payload).select().single();
        final newId = inserted['id']?.toString() ?? '';

        for (final q in _questions) {
          final qData = core.Map<core.String, dynamic>.from(q)
            ..remove('id')
            ..['bo_de_id'] = newId;
          await _supabase.from('cau_hoi').insert(qData);
        }
      }

      _hasChanges = true;
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Đã lưu bộ đề thành công!'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Lỗi lưu bộ đề: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _openQuestionEditor({
    core.Map<core.String, dynamic>? question,
    int? index,
  }) async {
    final result = await Navigator.push<core.Map<core.String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (_) => QuestionEditorScreen(
          quizTitle: _titleController.text.trim().isEmpty
              ? 'Bộ đề'
              : _titleController.text.trim(),
          creatorName: widget.creatorName,
          question: question,
        ),
      ),
    );

    if (result == null || !mounted) return;

    if (_isEditing && _quizSetId.isNotEmpty) {
      try {
        final dbPayload = core.Map<core.String, dynamic>.from(result)
          ..['bo_de_id'] = _quizSetId;
        final qId = question?['id']?.toString() ?? '';
        if (qId.isNotEmpty) {
          await _supabase.from('cau_hoi').update(dbPayload).eq('id', qId);
        } else {
          dbPayload.remove('id');
          await _supabase.from('cau_hoi').insert(dbPayload);
        }
        _hasChanges = true;
        await _loadQuestions();
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi lưu câu hỏi: $e')),
        );
      }
    } else {
      setState(() {
        if (index != null) {
          _questions[index] = result;
        } else {
          _questions.add(result);
        }
      });
    }
  }

  Future<void> _deleteQuestion(int index) async {
    final q = _questions[index];
    final qId = q['id']?.toString() ?? '';

    if (_isEditing && qId.isNotEmpty) {
      try {
        await _supabase.from('cau_hoi').delete().eq('id', qId);
        _hasChanges = true;
      } catch (_) {}
    }

    setState(() {
      _questions.removeAt(index);
    });
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
                          'Chỉ mình bạn quản lý',
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

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.pop(context, _hasChanges);
      },
      child: Scaffold(
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
                  colors: [Color(0xFF565CEB), Color(0xFF3E44C6)],
                ),
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(26)),
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 760),
                  child: Row(
                    children: [
                      InkWell(
                        onTap: () => Navigator.pop(context, _hasChanges),
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
                                  ? 'Chi tiết bộ đề'
                                  : _titleController.text.trim(),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 17.5,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Người tạo: ${widget.creatorName}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.white70,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      InkWell(
                        onTap: _isSaving ? null : _saveQuizSet,
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
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 36),
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
                                        : buildSmartQuizImage(
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
                            hintText: 'Nhập tên bộ đề...',
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
                                        value: _selectedSubject,
                                        isExpanded: true,
                                        items: _subjectItems
                                            .map(
                                              (s) => DropdownMenuItem(
                                                value: s,
                                                child: Text(s),
                                              ),
                                            )
                                            .toList(),
                                        onChanged: (val) {
                                          if (val != null) {
                                            setState(
                                              () => _selectedSubject = val,
                                            );
                                          }
                                        },
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
                        Text(
                          'Câu hỏi (${_questions.length})',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: darkText,
                          ),
                        ),
                        const SizedBox(height: 10),
                        if (_isLoadingQuestions)
                          const Center(
                            child: Padding(
                              padding: EdgeInsets.all(24),
                              child: CircularProgressIndicator(
                                color: primaryPurple,
                              ),
                            ),
                          )
                        else if (_questions.isEmpty)
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: const Color(0xFFE6E8F8),
                              ),
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
                              final content = (q['noi_dung'] ??
                                      q['cau_hoi'] ??
                                      'Câu hỏi ${idx + 1}')
                                  .toString();
                              final correctAns = (q['dap_an_dung'] ??
                                      q['correct_answer'] ??
                                      '')
                                  .toString();
                              final qImg =
                                  (q['hinh_anh_url'] ?? q['hinh_anh'] ?? '')
                                      .toString()
                                      .trim();

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
                                    question: q,
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
                                            child: buildSmartQuizImage(
                                              qImg,
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
                                              Text(
                                                content,
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(
                                                  fontSize: 13.5,
                                                  fontWeight: FontWeight.w700,
                                                  color: darkText,
                                                ),
                                              ),
                                              if (correctAns.isNotEmpty) ...[
                                                const SizedBox(height: 3),
                                                Text(
                                                  correctAns,
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: const TextStyle(
                                                    fontSize: 12.5,
                                                    fontWeight: FontWeight.w700,
                                                    color: Color(0xFF2E9E5B),
                                                  ),
                                                ),
                                              ],
                                            ],
                                          ),
                                        ),
                                        IconButton(
                                          icon: const Icon(
                                            Icons.delete_outline_rounded,
                                            color: Colors.red,
                                            size: 21,
                                          ),
                                          onPressed: () => _deleteQuestion(idx),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        const SizedBox(height: 14),
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
                        SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: ElevatedButton(
                            onPressed: _isSaving ? null : _saveQuizSet,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFF6A623),
                              foregroundColor: darkText,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            child: _isSaving
                                ? const CircularProgressIndicator(
                                    color: darkText,
                                  )
                                : const Text(
                                    'Hoàn tất & Lưu bộ đề',
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
      ),
    );
  }
}

// ============================================================================
// MÀN HÌNH 3: QUẢN LÍ CÂU HỎI (THÊM / SỬA CHI TIẾT CÂU HỎI)
// ============================================================================

class QuestionEditorScreen extends StatefulWidget {
  final core.String quizTitle;
  final core.String creatorName;
  final core.Map<core.String, dynamic>? question;

  const QuestionEditorScreen({
    super.key,
    required this.quizTitle,
    required this.creatorName,
    this.question,
  });

  @override
  State<QuestionEditorScreen> createState() => _QuestionEditorScreenState();
}

class _QuestionEditorScreenState extends State<QuestionEditorScreen> {
  static const Color primaryPurple = Color(0xFF565CEB);
  static const Color bgLight = Color(0xFFF6F7FC);
  static const Color darkText = Color(0xFF1E1E2C);

  final TextEditingController _questionController = TextEditingController();
  final TextEditingController _correctAnswerController = TextEditingController();
  final TextEditingController _wrong1Controller = TextEditingController();
  final TextEditingController _wrong2Controller = TextEditingController();
  final TextEditingController _wrong3Controller = TextEditingController();

  core.String _questionImageSource = '';
  bool _isUploadingQuestionImg = false;

  @override
  void initState() {
    super.initState();
    final q = widget.question;
    if (q != null) {
      _questionController.text =
          (q['noi_dung'] ?? q['cau_hoi'] ?? '').toString();
      _questionImageSource =
          (q['hinh_anh_url'] ?? q['hinh_anh'] ?? '').toString().trim();
      _correctAnswerController.text =
          (q['dap_an_dung'] ?? q['correct_answer'] ?? '').toString();
      _wrong1Controller.text = (q['dap_an_sai_1'] ?? '').toString();
      _wrong2Controller.text = (q['dap_an_sai_2'] ?? '').toString();
      _wrong3Controller.text = (q['dap_an_sai_3'] ?? '').toString();
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

  Future<void> _pickQuestionImageFromDevice() async {
    if (_isUploadingQuestionImg) return;
    setState(() => _isUploadingQuestionImg = true);
    try {
      final uploaded = await pickAndUploadQuizImage(
        context,
        folder: 'questions',
      );
      if (uploaded != null && mounted) {
        setState(() => _questionImageSource = uploaded);
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
      if (mounted) setState(() => _isUploadingQuestionImg = false);
    }
  }

  void _saveQuestion() {
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

    final result = <core.String, dynamic>{
      'id': ?widget.question?['id'],
      'noi_dung': content,
      'dap_an_dung': correct,
      'dap_an_sai_1': w1,
      'dap_an_sai_2': w2,
      'dap_an_sai_3': w3,
      'hinh_anh_url':
          _questionImageSource.isNotEmpty ? _questionImageSource : null,
    };

    Navigator.pop(context, result);
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
                colors: [Color(0xFF565CEB), Color(0xFF3E44C6)],
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
                          Text(
                            'Người tạo: ${widget.creatorName}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.white70,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    InkWell(
                      onTap: _saveQuestion,
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
                              onTap: _pickQuestionImageFromDevice,
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
                                  child: _isUploadingQuestionImg
                                      ? const Center(
                                          child: CircularProgressIndicator(
                                            color: primaryPurple,
                                            strokeWidth: 2.5,
                                          ),
                                        )
                                      : buildSmartQuizImage(
                                          _questionImageSource,
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
                            if (_questionImageSource.isNotEmpty)
                              Positioned(
                                right: -6,
                                top: -6,
                                child: InkWell(
                                  onTap: () => setState(
                                    () => _questionImageSource = '',
                                  ),
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