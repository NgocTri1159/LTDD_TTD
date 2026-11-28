import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/theme.dart';
import 'quiz_review_screen.dart';

typedef QuizHistoryItem = Map<String, dynamic>;

class QuizHistoryScreen extends StatefulWidget {
  /// Truyền callback này nếu đặt trong BottomNavigationBar
  /// để nút "Chơi ngay" nhảy thẳng về tab Trang chủ.
  final VoidCallback? onPlayNow;

  const QuizHistoryScreen({
    super.key,
    this.onPlayNow,
  });

  @override
  State<QuizHistoryScreen> createState() => _QuizHistoryScreenState();
}

class _QuizHistoryScreenState extends State<QuizHistoryScreen> {
  final _supabase = Supabase.instance.client;

  List<QuizHistoryItem> _allHistory = [];
  bool _isLoading = true;
  String? _errorMessage;

  // Bộ lọc nhanh
  String _selectedSubject = 'Tất cả';
  String _selectedMode = 'all'; // 'all' | 'practice' | 'competitive'

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Đồng bộ với Bước 2: nếu chưa đăng nhập sẽ đọc lịch sử của 'guest'
      final String userId = _supabase.auth.currentUser?.id ?? 'guest';

      final dynamic rawRows = await _supabase
          .from('lich_su_thi')
          .select('*')
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      final loaded = <QuizHistoryItem>[];
      if (rawRows is Iterable) {
        for (final row in rawRows) {
          if (row is Map) {
            loaded.add(Map<String, dynamic>.from(row));
          }
        }
      }

      if (!mounted) return;
      setState(() {
        _allHistory = loaded;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Không thể tải lịch sử làm bài: $e';
      });
    }
  }

  /// Danh sách các môn học có trong lịch sử để tạo thanh lọc ngang
  List<String> get _availableSubjects {
    final subjects = <String>{'Tất cả'};
    for (final item in _allHistory) {
      final subject = (item['mon_hoc'] ?? 'Tổng hợp').toString().trim();
      if (subject.isNotEmpty) {
        subjects.add(subject);
      }
    }
    return subjects.toList();
  }

  /// Lọc danh sách theo Môn học + Chế độ chơi
  List<QuizHistoryItem> get _filteredHistory {
    return _allHistory.where((item) {
      final subject = (item['mon_hoc'] ?? 'Tổng hợp').toString().trim();
      final mode = (item['che_do'] ?? 'practice').toString();

      final matchSubject =
          _selectedSubject == 'Tất cả' || subject == _selectedSubject;
      final matchMode = _selectedMode == 'all' || mode == _selectedMode;

      return matchSubject && matchMode;
    }).toList();
  }

  void _openReviewScreen(QuizHistoryItem record) {
    final dynamic rawQuestions = record['chi_tiet_cau_hoi'];
    final dynamic rawAnswers = record['dap_an_da_chon'];

    final List<dynamic> questions =
        rawQuestions is List ? List<dynamic>.from(rawQuestions) : [];

    if (questions.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Bài làm này không có dữ liệu chi tiết câu hỏi để xem lại.'),
        ),
      );
      return;
    }

    final Map<int, String> selectedAnswers = {};
    if (rawAnswers is Map) {
      rawAnswers.forEach((key, value) {
        final index = int.tryParse(key.toString());
        if (index != null && value != null) {
          selectedAnswers[index] = value.toString();
        }
      });
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => QuizReviewScreen(
          questions: questions,
          selectedAnswers: selectedAnswers,
        ),
      ),
    );
  }

  String _formatDate(dynamic rawDate) {
    if (rawDate == null) return '--/--/----';
    final parsed = DateTime.tryParse(rawDate.toString())?.toLocal();
    if (parsed == null) return '--/--/----';

    final dd = parsed.day.toString().padLeft(2, '0');
    final mm = parsed.month.toString().padLeft(2, '0');
    final yyyy = parsed.year;
    final hh = parsed.hour.toString().padLeft(2, '0');
    final min = parsed.minute.toString().padLeft(2, '0');
    return '$dd/$mm/$yyyy • $hh:$min';
  }

  Color _scoreColor(int score) {
    if (score >= 80) return Colors.green;
    if (score >= 50) return AppColors.interact;
    return Colors.redAccent;
  }

  void _handlePlayNow() {
    if (widget.onPlayNow != null) {
      widget.onPlayNow!();
    } else if (Navigator.canPop(context)) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredHistory;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Lịch sử làm bài'),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: 'Làm mới',
            onPressed: _loadHistory,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: _buildBody(filtered),
    );
  }

  Widget _buildBody(List<QuizHistoryItem> filtered) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.base),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline_rounded, size: 56, color: Colors.redAccent),
              const SizedBox(height: 12),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: AppTextStyles.text.copyWith(color: Colors.redAccent),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _loadHistory,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Thử lại'),
              ),
            ],
          ),
        ),
      );
    }

    if (_allHistory.isEmpty) {
      return _buildEmptyState();
    }

    return RefreshIndicator(
      color: AppColors.base,
      onRefresh: _loadHistory,
      child: Column(
        children: [
          _buildSummaryBanner(),
          _buildFilterSection(),
          Expanded(
            child: filtered.isEmpty
                ? _buildEmptyFilterResult()
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                    physics: const AlwaysScrollableScrollPhysics(),
                    itemCount: filtered.length,
                    itemBuilder: (context, index) => _buildHistoryCard(filtered[index]),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryBanner() {
    final int totalAttempts = _allHistory.length;
    final int totalScore = _allHistory.fold<int>(
      0,
      (sum, item) => sum + ((item['diem_so'] as num?)?.toInt() ?? 0),
    );
    final int avgScore =
        totalAttempts == 0 ? 0 : (totalScore / totalAttempts).round();

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.base,
            AppColors.base.withValues(alpha: 0.85),
          ],
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: AppColors.base.withValues(alpha: 0.25),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildStatItem(
              icon: Icons.assignment_turned_in_rounded,
              label: 'Đề đã làm',
              value: '$totalAttempts bài',
            ),
          ),
          Container(
            width: 1,
            height: 36,
            color: Colors.white.withValues(alpha: 0.25),
          ),
          Expanded(
            child: _buildStatItem(
              icon: Icons.emoji_events_rounded,
              label: 'Điểm trung bình',
              value: '$avgScore/100',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.18),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: Colors.white, size: 22),
        ),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: AppTextStyles.text.copyWith(
                fontSize: 12,
                color: Colors.white.withValues(alpha: 0.85),
              ),
            ),
            Text(
              value,
              style: AppTextStyles.answer.copyWith(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildFilterSection() {
    final subjects = _availableSubjects;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Bộ lọc Chế độ chơi
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                _buildModeChip('Tất cả', 'all'),
                const SizedBox(width: 8),
                _buildModeChip('Luyện tập', 'practice'),
                const SizedBox(width: 8),
                _buildModeChip('Thi đấu', 'competitive'),
              ],
            ),
          ),
          const SizedBox(height: 10),
          // Bộ lọc Môn học cuộn ngang
          SizedBox(
            height: 38,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: subjects.length,
              separatorBuilder: (context, index) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final subject = subjects[index];
                final isSelected = _selectedSubject == subject;

                return ChoiceChip(
                  label: Text(subject),
                  selected: isSelected,
                  onSelected: (_) {
                    setState(() => _selectedSubject = subject);
                  },
                  selectedColor: AppColors.base,
                  backgroundColor: Colors.white,
                  side: BorderSide(
                    color: isSelected ? AppColors.base : Colors.grey.shade300,
                  ),
                  labelStyle: AppTextStyles.text.copyWith(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isSelected ? Colors.white : AppColors.text,
                  ),
                  showCheckmark: false,
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModeChip(String label, String value) {
    final bool isSelected = _selectedMode == value;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedMode = value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 9),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isSelected ? AppColors.interact : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? AppColors.interact : Colors.grey.shade300,
            ),
          ),
          child: Text(
            label,
            style: AppTextStyles.text.copyWith(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: isSelected ? Colors.white : AppColors.text,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHistoryCard(QuizHistoryItem item) {
    final String title = (item['ten_de_thi'] ?? 'Bộ đề trắc nghiệm').toString();
    final String subject = (item['mon_hoc'] ?? 'Tổng hợp').toString();
    final String mode = (item['che_do'] ?? 'practice').toString();
    final int score = (item['diem_so'] as num?)?.toInt() ?? 0;
    final int correctCount = (item['so_cau_dung'] as num?)?.toInt() ?? 0;
    final int totalQuestions = (item['tong_so_cau'] as num?)?.toInt() ?? 0;
    final String duration = (item['thoi_gian_lam'] ?? '00:00').toString();
    final String dateText = _formatDate(item['created_at']);

    final bool isCompetitive = mode == 'competitive';
    final Color badgeColor = _scoreColor(score);

    return GestureDetector(
      onTap: () => _openReviewScreen(item),
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: AppColors.base.withValues(alpha: 0.08),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Hàng 1: Môn học + Chế độ chơi + Điểm số
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      _buildTag(
                        label: subject,
                        bgColor: AppColors.base.withValues(alpha: 0.12),
                        textColor: AppColors.base,
                      ),
                      _buildTag(
                        label: isCompetitive ? 'Thi đấu' : 'Luyện tập',
                        bgColor: isCompetitive
                            ? AppColors.interact.withValues(alpha: 0.15)
                            : Colors.teal.withValues(alpha: 0.12),
                        textColor:
                            isCompetitive ? AppColors.interact : Colors.teal.shade700,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: badgeColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: badgeColor.withValues(alpha: 0.4)),
                  ),
                  child: Text(
                    '$score điểm',
                    style: AppTextStyles.text.copyWith(
                      fontWeight: FontWeight.bold,
                      fontSize: 13.5,
                      color: badgeColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Hàng 2: Tên bộ đề
            Text(
              title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.question.copyWith(
                fontSize: 16.5,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 12),

            // Hàng 3: Số câu đúng + Thời gian hoàn thành
            Row(
              children: [
                Icon(Icons.check_circle_outline_rounded,
                    size: 16, color: Colors.green.shade600),
                const SizedBox(width: 4),
                Text(
                  '$correctCount/$totalQuestions câu',
                  style: AppTextStyles.text.copyWith(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade800,
                  ),
                ),
                const SizedBox(width: 14),
                Icon(Icons.timer_outlined, size: 16, color: Colors.grey.shade600),
                const SizedBox(width: 4),
                Text(
                  duration,
                  style: AppTextStyles.text.copyWith(
                    fontSize: 13,
                    color: Colors.grey.shade700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Divider(color: Colors.grey.shade200, height: 16),

            // Hàng 4: Ngày giờ thi + Xem đáp án
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.calendar_today_rounded,
                        size: 14, color: Colors.grey.shade500),
                    const SizedBox(width: 6),
                    Text(
                      dateText,
                      style: AppTextStyles.text.copyWith(
                        fontSize: 12.5,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    Text(
                      'Xem đáp án',
                      style: AppTextStyles.text.copyWith(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: AppColors.base,
                      ),
                    ),
                    const SizedBox(width: 2),
                    const Icon(
                      Icons.chevron_right_rounded,
                      size: 18,
                      color: AppColors.base,
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTag({
    required String label,
    required Color bgColor,
    required Color textColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: AppTextStyles.text.copyWith(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: textColor,
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.base.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.history_edu_rounded,
                size: 64,
                color: AppColors.base,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Chưa có lịch sử làm bài',
              style: AppTextStyles.question.copyWith(fontSize: 19),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Hãy thử sức với một bộ đề ngay hôm nay để lưu lại thành tích và ôn tập lại các câu hỏi đã làm!',
              textAlign: TextAlign.center,
              style: AppTextStyles.text.copyWith(
                color: Colors.grey.shade600,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: 200,
              height: 50,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.base,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                onPressed: _handlePlayNow,
                icon: const Icon(Icons.play_arrow_rounded, size: 24),
                label: Text(
                  'Chơi ngay',
                  style: AppTextStyles.button.copyWith(
                    fontSize: 16,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyFilterResult() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.filter_list_off_rounded,
                size: 54, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            Text(
              'Không tìm thấy bài thi nào phù hợp với bộ lọc hiện tại.',
              textAlign: TextAlign.center,
              style: AppTextStyles.text.copyWith(color: Colors.grey.shade600),
            ),
            const SizedBox(height: 14),
            TextButton(
              onPressed: () {
                setState(() {
                  _selectedSubject = 'Tất cả';
                  _selectedMode = 'all';
                });
              },
              child: const Text(
                'Đặt lại bộ lọc',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppColors.base,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}