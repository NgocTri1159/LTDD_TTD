import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class QuestionManageScreen extends StatefulWidget {
  final String? subjectId;
  final String subjectName;

  const QuestionManageScreen({
    super.key,
    this.subjectId,
    this.subjectName = 'Toán',
  });

  @override
  State<QuestionManageScreen> createState() => _QuestionManageScreenState();
}

class _QuestionManageScreenState extends State<QuestionManageScreen> {
  final _supabase = Supabase.instance.client;
  List _questions = [];
  Map<String, String> _correctAnswersMap = {};
  bool _isLoading = true;
  bool _isSearching = false;
  String _searchQuery = '';
  String _selectedLevel = 'Tất cả';
  int _currentTab = 1;

  static const Color _inkColor = Color(0xFF1E293B);
  static const Color _amberColor = Color(0xFFFBB03B);
  static const Color _bgColor = Color(0xFFF3F5F9);

  final List<String> _levels = ['Tất cả', 'Dễ', 'Trung bình', 'Khó'];

  @override
  void initState() {
    super.initState();
    _fetchQuestions();
  }

  Future<void> _fetchQuestions() async {
    setState(() => _isLoading = true);
    try {
      final rawQuestions = widget.subjectId != null
          ? await _supabase
              .from('cau_hoi')
              .select()
              .eq('mon_hoc_id', widget.subjectId!)
          : await _supabase.from('cau_hoi').select();

      final list = List.from(rawQuestions);
      final ids =
          list.map((q) => q['id']).where((id) => id != null).toList();

      final Map<String, String> answersMap = {};
      if (ids.isNotEmpty) {
        try {
          final answersData = await _supabase
              .from('dap_an')
              .select()
              .inFilter('cau_hoi_id', ids)
              .eq('la_dap_an_dung', true);
          for (final ans in answersData) {
            final qId = ans['cau_hoi_id']?.toString();
            if (qId != null) {
              answersMap[qId] = (ans['noi_dung'] ?? '').toString();
            }
          }
        } catch (_) {}
      }

      setState(() {
        _questions = list;
        _correctAnswersMap = answersMap;
      });
    } catch (e) {
      _showSnack('Lỗi tải câu hỏi: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSnack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? Colors.red : Colors.green,
      ),
    );
  }

  String _getLevel(Map<String, dynamic> q) {
    return (q['muc_do'] ?? q['do_kho'] ?? 'Dễ').toString();
  }

  String _getCorrectAnswer(Map<String, dynamic> q) {
    final direct = q['dap_an_dung']?.toString();
    if (direct != null && direct.isNotEmpty) return direct;
    final id = q['id']?.toString() ?? '';
    return _correctAnswersMap[id] ?? '';
  }

  Widget _buildLevelBadge(String level) {
    Color bg;
    Color text;
    switch (level) {
      case 'Khó':
        bg = const Color(0xFFFEE2E2);
        text = const Color(0xFFDC2626);
        break;
      case 'Trung bình':
        bg = const Color(0xFFFEF3C7);
        text = const Color(0xFFD97706);
        break;
      default:
        bg = const Color(0xFFDCFCE7);
        text = const Color(0xFF16A34A);
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        level,
        style: TextStyle(
          color: text,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  void _showFilterSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Lọc theo mức độ',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: _inkColor,
              ),
            ),
            const SizedBox(height: 12),
            ..._levels.map((lv) => ListTile(
                  title: Text(lv),
                  trailing: _selectedLevel == lv
                      ? const Icon(Icons.check, color: _amberColor)
                      : null,
                  onTap: () {
                    setState(() => _selectedLevel = lv);
                    Navigator.pop(ctx);
                  },
                )),
          ],
        ),
      ),
    );
  }

  void _showQuestionDialog({Map<String, dynamic>? question}) {
    final isEdit = question != null;
    final contentCtrl =
        TextEditingController(text: isEdit ? (question['noi_dung'] ?? '') : '');
    final answerCtrl = TextEditingController(
        text: isEdit ? _getCorrectAnswer(question) : '');
    String level = isEdit ? _getLevel(question) : 'Dễ';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => Dialog(
          backgroundColor: const Color(0xFFF2F4F8),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isEdit ? 'Chỉnh sửa câu hỏi' : 'Tạo câu hỏi mới',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: _inkColor,
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: contentCtrl,
                    maxLines: 3,
                    decoration: InputDecoration(
                      hintText: 'Nhập nội dung câu hỏi...',
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: answerCtrl,
                    decoration: InputDecoration(
                      hintText: 'Đáp án đúng...',
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: _levels.contains(level) && level != 'Tất cả'
                        ? level
                        : 'Dễ',
                    decoration: InputDecoration(
                      labelText: 'Mức độ',
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    items: const ['Dễ', 'Trung bình', 'Khó']
                        .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                        .toList(),
                    onChanged: (val) {
                      if (val != null) setDialogState(() => level = val);
                    },
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _amberColor,
                        foregroundColor: _inkColor,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(25)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      onPressed: () async {
                        final noiDung = contentCtrl.text.trim();
                        final dapAn = answerCtrl.text.trim();
                        if (noiDung.isEmpty || dapAn.isEmpty) {
                          _showSnack('Vui lòng nhập đủ câu hỏi và đáp án',
                              isError: true);
                          return;
                        }
                        try {
                          if (isEdit) {
                            await _supabase.from('cau_hoi').update({
                              'noi_dung': noiDung,
                              'muc_do': level,
                            }).eq('id', question['id']);
                            await _supabase
                                .from('dap_an')
                                .delete()
                                .eq('cau_hoi_id', question['id']);
                            await _supabase.from('dap_an').insert({
                              'cau_hoi_id': question['id'],
                              'noi_dung': dapAn,
                              'la_dap_an_dung': true,
                              'thu_tu': 1,
                            });
                            _showSnack('Đã cập nhật câu hỏi');
                          } else {
                            final inserted = await _supabase
                                .from('cau_hoi')
                                .insert({
                                  if (widget.subjectId != null)
                                    'mon_hoc_id': widget.subjectId,
                                  'noi_dung': noiDung,
                                  'muc_do': level,
                                })
                                .select()
                                .single();
                            await _supabase.from('dap_an').insert({
                              'cau_hoi_id': inserted['id'],
                              'noi_dung': dapAn,
                              'la_dap_an_dung': true,
                              'thu_tu': 1,
                            });
                            _showSnack('Đã thêm câu hỏi mới');
                          }
                          if (ctx.mounted) Navigator.pop(ctx);
                          _fetchQuestions();
                        } catch (e) {
                          _showSnack('Lỗi lưu: $e', isError: true);
                        }
                      },
                      child: Text(
                        isEdit ? 'Sửa' : 'Tạo',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                    ),
                  ),
                  if (isEdit) ...[
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFF3B30),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(25)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        onPressed: () async {
                          try {
                            await _supabase
                                .from('dap_an')
                                .delete()
                                .eq('cau_hoi_id', question['id']);
                            await _supabase
                                .from('cau_hoi')
                                .delete()
                                .eq('id', question['id']);
                            if (ctx.mounted) Navigator.pop(ctx);
                            _showSnack('Đã xóa câu hỏi');
                            _fetchQuestions();
                          } catch (e) {
                            _showSnack('Lỗi xóa: $e', isError: true);
                          }
                        },
                        child: const Text(
                          'Xóa',
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _questions.where((q) {
      final text = (q['noi_dung'] ?? '').toString().toLowerCase();
      final level = _getLevel(q);
      final matchSearch = text.contains(_searchQuery.toLowerCase());
      final matchLevel = _selectedLevel == 'Tất cả' || level == _selectedLevel;
      return matchSearch && matchLevel;
    }).toList();

    return Scaffold(
      backgroundColor: _bgColor,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        foregroundColor: _inkColor,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, size: 22, color: _inkColor),
          onPressed: () => Navigator.maybePop(context),
        ),
        title: _isSearching
            ? TextField(
                autofocus: true,
                style: const TextStyle(color: _inkColor),
                decoration: const InputDecoration(
                  hintText: 'Tìm kiếm câu hỏi...',
                  border: InputBorder.none,
                ),
                onChanged: (val) => setState(() => _searchQuery = val),
              )
            : Text(
                'Câu hỏi môn ${widget.subjectName}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: _inkColor,
                ),
              ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(_isSearching ? Icons.close : Icons.search,
                color: _inkColor),
            onPressed: () {
              setState(() {
                _isSearching = !_isSearching;
                if (!_isSearching) _searchQuery = '';
              });
            },
          ),
          IconButton(
            icon: const Icon(Icons.filter_alt_outlined, color: _inkColor),
            onPressed: _showFilterSheet,
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                GestureDetector(
                  onTap: _showFilterSheet,
                  child: Row(
                    children: [
                      Text(
                        'Mức độ: ',
                        style: TextStyle(
                            color: Colors.grey.shade600, fontSize: 13),
                      ),
                      Text(
                        _selectedLevel,
                        style: const TextStyle(
                          color: _inkColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  '${filtered.length} câu hỏi',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                ),
              ],
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : filtered.isEmpty
                    ? const Center(
                        child: Text(
                          'Chưa có câu hỏi nào.\nBấm nút + để thêm mới.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey),
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _fetchQuestions,
                        child: ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 88),
                          itemCount: filtered.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            final q = filtered[index];
                            final level = _getLevel(q);
                            final correctAns = _getCorrectAnswer(q);
                            return GestureDetector(
                              onTap: () => _showQuestionDialog(question: q),
                              child: Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(14),
                                  boxShadow: [
                                    BoxShadow(
                                      color:
                                          Colors.black.withValues(alpha: 0.04),
                                      blurRadius: 6,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          'Câu ${index + 1}:',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                            color: _inkColor,
                                          ),
                                        ),
                                        _buildLevelBadge(level),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      q['noi_dung'] ?? '',
                                      style: const TextStyle(
                                        fontSize: 14,
                                        color: _inkColor,
                                        height: 1.4,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    RichText(
                                      text: TextSpan(
                                        style: const TextStyle(
                                            fontSize: 13, color: _inkColor),
                                        children: [
                                          const TextSpan(text: 'Đáp án: '),
                                          TextSpan(
                                            text: correctAns,
                                            style: const TextStyle(
                                              color: Color(0xFF16A34A),
                                              fontWeight: FontWeight.bold,
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
          ),
        ],
      ),
      floatingActionButton: SizedBox(
        width: 56,
        height: 56,
        child: FloatingActionButton(
          backgroundColor: _amberColor,
          foregroundColor: _inkColor,
          elevation: 3,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          onPressed: () => _showQuestionDialog(),
          child: const Icon(Icons.add, size: 28),
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentTab,
        onTap: (i) => setState(() => _currentTab = i),
        type: BottomNavigationBarType.fixed,
        backgroundColor: Colors.white,
        selectedItemColor: const Color(0xFFF59E0B),
        unselectedItemColor: _inkColor,
        selectedFontSize: 12,
        unselectedFontSize: 12,
        items: const [
          BottomNavigationBarItem(
              icon: Icon(Icons.home_outlined),
              activeIcon: Icon(Icons.home),
              label: 'Tổng quan'),
          BottomNavigationBarItem(
              icon: Icon(Icons.menu_book_outlined),
              activeIcon: Icon(Icons.menu_book),
              label: 'Học liệu'),
          BottomNavigationBarItem(
              icon: Icon(Icons.people_outline),
              activeIcon: Icon(Icons.people),
              label: 'Phòng'),
          BottomNavigationBarItem(
              icon: Icon(Icons.settings_outlined),
              activeIcon: Icon(Icons.settings),
              label: 'Người dùng'),
        ],
      ),
    );
  }
}