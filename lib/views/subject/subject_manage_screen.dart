import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../question/question_manage_screen.dart';

class SubjectManageScreen extends StatefulWidget {
  const SubjectManageScreen({super.key});

  @override
  State<SubjectManageScreen> createState() => _SubjectManageScreenState();
}

class _SubjectManageScreenState extends State<SubjectManageScreen> {
  final _supabase = Supabase.instance.client;
  List _subjects = [];
  bool _isLoading = true;
  bool _isSearching = false;
  String _searchQuery = '';
  int _currentTab = 1; // Tab "Học liệu" đang chọn

  static const Color _inkColor = Color(0xFF1E293B);
  static const Color _amberColor = Color(0xFFFBB03B);
  static const Color _bgColor = Color(0xFFF3F5F9);

  final Map<String, IconData> _iconMap = {
    'calculate': Icons.calculate_outlined,
    'menu_book': Icons.auto_stories_outlined,
    'language': Icons.language,
    'bolt': Icons.bolt,
    'science': Icons.science_outlined,
    'history_edu': Icons.temple_buddhist_outlined,
    'public': Icons.forest_outlined,
    'computer': Icons.computer,
    'code': Icons.code,
    'music_note': Icons.music_note_outlined,
    'palette': Icons.palette_outlined,
    'biotech': Icons.biotech_outlined,
  };

  @override
  void initState() {
    super.initState();
    _fetchSubjects();
  }

  Widget _buildSubjectSymbol(dynamic rawSymbol) {
    final symbol = rawSymbol?.toString().trim() ?? '';
    if (_iconMap.containsKey(symbol)) {
      return Icon(_iconMap[symbol], size: 30, color: _inkColor);
    }
    if (symbol.isNotEmpty) {
      return Text(symbol, style: const TextStyle(fontSize: 26));
    }
    return const Icon(Icons.auto_stories_outlined, size: 30, color: _inkColor);
  }

  Future<void> _fetchSubjects() async {
    setState(() => _isLoading = true);
    try {
      final data = await _supabase
          .from('mon_hoc')
          .select()
          .order('ten_mon', ascending: true);
      setState(() {
        _subjects = List.from(data);
      });
    } catch (e) {
      _showSnack('Lỗi tải môn học: $e', isError: true);
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

  void _showSubjectDialog({Map<String, dynamic>? subject}) {
    final isEdit = subject != null;
    final nameController =
        TextEditingController(text: isEdit ? (subject['ten_mon'] ?? '') : '');
    final currentIcon = isEdit ? subject['bieu_tuong']?.toString() : null;
    String selectedIconKey =
        (currentIcon != null && _iconMap.containsKey(currentIcon))
            ? currentIcon
            : 'calculate';
    bool hasPickedIcon = isEdit;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          return Dialog(
            backgroundColor: const Color(0xFFF2F4F8),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          isEdit
                              ? 'Chỉnh sửa “${subject['ten_mon']}”'
                              : 'Tạo môn học mới',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: _inkColor,
                          ),
                        ),
                      ),
                      InkWell(
                        borderRadius: BorderRadius.circular(10),
                        onTap: () {
                          showModalBottomSheet(
                            context: ctx,
                            builder: (sheetCtx) => GridView.count(
                              crossAxisCount: 4,
                              padding: const EdgeInsets.all(16),
                              children: _iconMap.entries.map((entry) {
                                return IconButton(
                                  icon: Icon(entry.value,
                                      size: 30, color: _inkColor),
                                  onPressed: () {
                                    setDialogState(() {
                                      selectedIconKey = entry.key;
                                      hasPickedIcon = true;
                                    });
                                    Navigator.pop(sheetCtx);
                                  },
                                );
                              }).toList(),
                            ),
                          );
                        },
                        child: Padding(
                          padding: const EdgeInsets.all(4),
                          child: Icon(
                            hasPickedIcon
                                ? (_iconMap[selectedIconKey] ??
                                    Icons.calculate_outlined)
                                : Icons.add_photo_alternate_outlined,
                            size: 28,
                            color: _inkColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: nameController,
                    style: const TextStyle(fontSize: 14, color: _inkColor),
                    decoration: InputDecoration(
                      hintText: 'Tên môn học...',
                      hintStyle:
                          TextStyle(color: Colors.grey.shade500, fontSize: 14),
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 18, vertical: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(25),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(25),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(25),
                        borderSide:
                            const BorderSide(color: _amberColor, width: 1.5),
                      ),
                    ),
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
                        final tenMon = nameController.text.trim();
                        if (tenMon.isEmpty) {
                          _showSnack('Vui lòng nhập tên môn học',
                              isError: true);
                          return;
                        }
                        try {
                          if (isEdit) {
                            await _supabase.from('mon_hoc').update({
                              'ten_mon': tenMon,
                              'bieu_tuong': selectedIconKey,
                            }).eq('id', subject['id']);
                            _showSnack('Đã cập nhật môn học');
                          } else {
                            await _supabase.from('mon_hoc').insert({
                              'ten_mon': tenMon,
                              'bieu_tuong': selectedIconKey,
                              'mau_sac': '#1E293B',
                            });
                            _showSnack('Đã tạo môn học mới');
                          }
                          if (ctx.mounted) Navigator.pop(ctx);
                          _fetchSubjects();
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
                                .from('mon_hoc')
                                .delete()
                                .eq('id', subject['id']);
                            if (ctx.mounted) Navigator.pop(ctx);
                            _showSnack('Đã xóa môn học');
                            _fetchSubjects();
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
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _subjects.where((s) {
      final name = (s['ten_mon'] ?? '').toString().toLowerCase();
      return name.contains(_searchQuery.toLowerCase());
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
                  hintText: 'Tìm kiếm môn học...',
                  border: InputBorder.none,
                ),
                onChanged: (val) => setState(() => _searchQuery = val),
              )
            : const Text(
                'Quản lí môn học',
                style: TextStyle(
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
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : filtered.isEmpty
              ? const Center(
                  child: Text(
                    'Chưa có môn học nào.\nBấm nút + để tạo mới.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _fetchSubjects,
                  child: GridView.builder(
                    padding: const EdgeInsets.all(16),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 4,
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 12,
                      childAspectRatio: 0.92,
                    ),
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final item = Map<String, dynamic>.from(filtered[index]);

                      return GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => QuestionManageScreen(
                                subjectId: item['id']?.toString(),
                                subjectName:
                                    item['ten_mon']?.toString() ?? 'Môn học',
                              ),
                            ),
                          );
                        },
                        onLongPress: () => _showSubjectDialog(subject: item),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 4, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.04),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              _buildSubjectSymbol(item['bieu_tuong']),
                              const SizedBox(height: 6),
                              Text(
                                item['ten_mon'] ?? '',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: _inkColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
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
          onPressed: () => _showSubjectDialog(),
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