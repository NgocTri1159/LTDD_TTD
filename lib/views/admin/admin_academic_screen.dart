import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/theme.dart';
import 'admin_quiz_screen.dart';
import 'admin_subject_screen.dart';

class AdminAcademicScreen extends StatefulWidget {
  const AdminAcademicScreen({super.key});

  @override
  State<AdminAcademicScreen> createState() => _AdminAcademicScreenState();
}

class _AdminAcademicScreenState extends State<AdminAcademicScreen> {
  final _supabase = Supabase.instance.client;

  static const Color _brandBlue = Color(0xFF3B5BFD);
  static const Color _brandPurple = Color(0xFF7C3AED);
  static const Color _subjectBlue = Color(0xFF2563EB);
  static const Color _subjectCyan = Color(0xFF0EA5E9);
  static const Color _quizEmerald = Color(0xFF059669);
  static const Color _quizTeal = Color(0xFF14B8A6);

  int _subjectCount = 0;
  int _quizCount = 0;
  int _questionCount = 0;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadCounts();
  }

  Future<void> _loadCounts() async {
    if (mounted) setState(() => _loading = true);

    int subjects = 0;
    int quizzes = 0;
    int questions = 0;

    try {
      final dynamic rows = await _supabase.from('mon_hoc').select('id');
      if (rows is Iterable) subjects = rows.length;
    } catch (_) {}

    try {
      final dynamic rows = await _supabase.from('de_thi').select('id');
      if (rows is Iterable) quizzes = rows.length;
    } catch (_) {}

    try {
      final dynamic rows = await _supabase.from('cau_hoi').select('id');
      if (rows is Iterable) questions = rows.length;
    } catch (_) {}

    if (!mounted) return;
    setState(() {
      _subjectCount = subjects;
      _quizCount = quizzes;
      _questionCount = questions;
      _loading = false;
    });
  }

  Future<void> _openScreen(Widget screen) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => screen),
    );
    _loadCounts();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5FB),
      body: RefreshIndicator(
        color: AppColors.base,
        onRefresh: _loadCounts,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            children: [
              // 1. HEADER GRADIENT + THỐNG KÊ KHO HỌC LIỆU
              _buildHeader(context),

              // 2. HAI KHU VỰC QUẢN LÍ CHÍNH (MÔN HỌC & BỘ ĐỀ)
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 680),
                  child: Transform.translate(
                    offset: const Offset(0, -24),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Card 1: Môn học
                          _buildAcademicCard(
                            badge: 'DANH MỤC',
                            countLabel: '$_subjectCount môn học',
                            title: 'Quản lí Môn học',
                            subtitle:
                                'Thêm mới, chỉnh sửa và phân nhóm danh mục các môn học trong hệ thống.',
                            icon: Icons.bookmarks_rounded,
                            watermarkIcon: Icons.auto_stories_rounded,
                            primaryColor: _subjectBlue,
                            secondaryColor: _subjectCyan,
                            actionLabel: 'Mở danh sách môn học',
                            onTap: () => _openScreen(const AdminSubjectScreen()),
                          ),

                          const SizedBox(height: 16),

                          // Card 2: Bộ đề
                          _buildAcademicCard(
                            badge: 'KHO ĐỀ THI',
                            countLabel: '$_quizCount bộ đề',
                            title: 'Quản lí Bộ đề',
                            subtitle:
                                'Soạn câu hỏi, thiết lập đáp án và quản lí toàn bộ đề thi trắc nghiệm.',
                            icon: Icons.menu_book_rounded,
                            watermarkIcon: Icons.quiz_rounded,
                            primaryColor: _quizEmerald,
                            secondaryColor: _quizTeal,
                            actionLabel: 'Mở danh sách bộ đề',
                            onTap: () => _openScreen(const AdminQuizScreen()),
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
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(20, topPadding + 16, 20, 48),
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
                right: -24,
                top: -26,
                child: Container(
                  width: 130,
                  height: 130,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.08),
                  ),
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.16),
                                borderRadius: BorderRadius.circular(99),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.school_rounded,
                                    size: 13,
                                    color: Color(0xFFFDE68A),
                                  ),
                                  SizedBox(width: 5),
                                  Text(
                                    'QUẢN LÍ HỌC VỤ',
                                    style: TextStyle(
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 0.8,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              'Kho học liệu',
                              style: AppTextStyles.question.copyWith(
                                fontSize: 23,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                                letterSpacing: -0.3,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Material(
                        color: Colors.white.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(15),
                        child: InkWell(
                          onTap: _loading ? null : _loadCounts,
                          borderRadius: BorderRadius.circular(15),
                          child: Container(
                            width: 44,
                            height: 44,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(15),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.28),
                              ),
                            ),
                            child: _loading
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
                                    size: 21,
                                  ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // 3 ô số liệu thật của kho học liệu
                  Row(
                    children: [
                      Expanded(
                        child: _buildHeaderStat(
                          icon: Icons.bookmarks_rounded,
                          label: 'Môn học',
                          value: '$_subjectCount',
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _buildHeaderStat(
                          icon: Icons.menu_book_rounded,
                          label: 'Bộ đề',
                          value: '$_quizCount',
                          highlightColor: const Color(0xFF6EE7B7),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _buildHeaderStat(
                          icon: Icons.help_outline_rounded,
                          label: 'Câu hỏi',
                          value: '$_questionCount',
                          highlightColor: const Color(0xFFFDE68A),
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
    );
  }

  Widget _buildHeaderStat({
    required IconData icon,
    required String label,
    required String value,
    Color? highlightColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                icon,
                size: 15,
                color: highlightColor ?? Colors.white.withValues(alpha: 0.88),
              ),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Colors.white.withValues(alpha: 0.85),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              height: 1.1,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAcademicCard({
    required String badge,
    required String countLabel,
    required String title,
    required String subtitle,
    required IconData icon,
    required IconData watermarkIcon,
    required Color primaryColor,
    required Color secondaryColor,
    required String actionLabel,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withValues(alpha: 0.08),
            blurRadius: 18,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(23),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            splashColor: primaryColor.withValues(alpha: 0.1),
            highlightColor: primaryColor.withValues(alpha: 0.04),
            child: Stack(
              children: [
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
                Positioned(
                  right: -12,
                  bottom: -12,
                  child: Icon(
                    watermarkIcon,
                    size: 104,
                    color: primaryColor.withValues(alpha: 0.05),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 22, 18, 18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 58,
                            height: 58,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [primaryColor, secondaryColor],
                              ),
                              borderRadius: BorderRadius.circular(18),
                              boxShadow: [
                                BoxShadow(
                                  color: primaryColor.withValues(alpha: 0.28),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Icon(
                              icon,
                              size: 28,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Wrap(
                                  spacing: 6,
                                  runSpacing: 4,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 9,
                                        vertical: 3,
                                      ),
                                      decoration: BoxDecoration(
                                        color:
                                            primaryColor.withValues(alpha: 0.11),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        badge,
                                        style: TextStyle(
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.w800,
                                          letterSpacing: 0.6,
                                          color: primaryColor,
                                        ),
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 9,
                                        vertical: 3,
                                      ),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF1F5F9),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        countLabel,
                                        style: const TextStyle(
                                          fontSize: 10.8,
                                          fontWeight: FontWeight.w700,
                                          color: Color(0xFF475569),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 7),
                                Text(
                                  title,
                                  style: AppTextStyles.question.copyWith(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w900,
                                    color: AppColors.text,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: primaryColor.withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.arrow_forward_rounded,
                              size: 19,
                              color: primaryColor,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Text(
                        subtitle,
                        style: AppTextStyles.text.copyWith(
                          fontSize: 13.4,
                          color: Colors.grey.shade600,
                          height: 1.45,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Divider(height: 1, color: Colors.grey.shade100),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Text(
                            actionLabel,
                            style: AppTextStyles.text.copyWith(
                              fontSize: 13.2,
                              fontWeight: FontWeight.w800,
                              color: primaryColor,
                            ),
                          ),
                          const Spacer(),
                          Icon(
                            Icons.arrow_right_alt_rounded,
                            size: 20,
                            color: primaryColor,
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
      ),
    );
  }
}