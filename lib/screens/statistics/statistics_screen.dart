import 'dart:core';
import 'dart:core' as core;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:material_ui/material_ui.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class StatisticsScreen extends StatefulWidget {
  const StatisticsScreen({super.key});

  @override
  State<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends State<StatisticsScreen> {
  static const Color primaryPurple = Color(0xFF565CEB);
  static const Color cardLavender = Color(0xFFECEEFF);
  static const Color accentOrange = Color(0xFFF79E1B);
  static const Color darkText = Color(0xFF1E1E2C);
  static const Color subText = Color(0xFF5A5E77);
  static const Color backgroundColor = Color(0xFFF9FAFF);

  final SupabaseClient _supabase = Supabase.instance.client;

  bool _isLoading = true;
  String? _errorMessage;

  String _rankTier = 'ĐỒNG';
  int _rankPoints = 0;
  int _rankPosition = 0;
  int _level = 1;
  int _totalAnswered = 0;
  int _totalCorrect = 0;
  int _totalPlaySeconds = 0;
  int _totalMatches = 0;

  String get _currentUid => FirebaseAuth.instance.currentUser?.uid ?? '';

  @override
  void initState() {
    super.initState();
    _loadStatistics();
  }

  Future<void> _loadStatistics() async {
    if (_currentUid.isEmpty) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Bạn chưa đăng nhập.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final userRow = await _supabase
          .from('nguoi_dung')
          .select('id, diem_rank, hang, cap_do')
          .eq('id', _currentUid)
          .maybeSingle();

      final historyRes = await _supabase
          .from('lich_su_thi')
          .select('so_cau_dung, tong_so_cau, thoi_gian_lam')
          .eq('user_id', _currentUid);

      final historyList =
          core.List<core.Map<String, dynamic>>.from(historyRes as core.List);

      final myRankPoints = (userRow?['diem_rank'] as num?)?.toInt() ?? 0;
      final myRankTier = (userRow?['hang'] ?? 'ĐỒNG').toString();
      final myLevel = (userRow?['cap_do'] as num?)?.toInt() ?? 1;

      // Tính thứ hạng thực tế trên toàn hệ thống
      final higherUsers = await _supabase
          .from('nguoi_dung')
          .select('id')
          .eq('trang_thai', true)
          .gt('diem_rank', myRankPoints);

      int answered = 0;
      int correct = 0;
      int seconds = 0;

      for (final item in historyList) {
        answered += (item['tong_so_cau'] as num?)?.toInt() ?? 0;
        correct += (item['so_cau_dung'] as num?)?.toInt() ?? 0;
        seconds += _parseDurationToSeconds(item['thoi_gian_lam']?.toString());
      }

      if (!mounted) return;
      setState(() {
        _rankTier = myRankTier;
        _rankPoints = myRankPoints;
        _rankPosition = (higherUsers as core.List).length + 1;
        _level = myLevel;
        _totalMatches = historyList.length;
        _totalAnswered = answered;
        _totalCorrect = correct;
        _totalPlaySeconds = seconds;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Không thể tải dữ liệu thống kê: $e';
      });
    }
  }

  /// Chuyển chuỗi 'MM:SS' hoặc 'HH:MM:SS' hoặc số giây thành tổng số giây
  int _parseDurationToSeconds(String? raw) {
    if (raw == null || raw.trim().isEmpty) return 0;
    final clean = raw.trim();
    if (!clean.contains(':')) {
      return int.tryParse(clean) ?? 0;
    }

    final parts = clean.split(':').map((e) => int.tryParse(e) ?? 0).toList();
    if (parts.length == 2) {
      return parts[0] * 60 + parts[1];
    }
    if (parts.length == 3) {
      return parts[0] * 3600 + parts[1] * 60 + parts[2];
    }
    return 0;
  }

  String _formatTotalPlayTime(int totalSeconds) {
    if (totalSeconds <= 0) return '0 phút';
    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    final secs = totalSeconds % 60;

    if (hours > 0) {
      return '${hours}g ${minutes}p';
    }
    if (minutes > 0) {
      return '${minutes}p ${secs}s';
    }
    return '$secs giây';
  }

  @override
  Widget build(BuildContext context) {
    final double accuracy =
        _totalAnswered > 0 ? (_totalCorrect / _totalAnswered) * 100 : 0.0;

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: const Text(
          'Thống kê cá nhân',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: primaryPurple,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: _isLoading
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
                        Text(
                          _errorMessage!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Color(0xFFE53935)),
                        ),
                        const SizedBox(height: 12),
                        ElevatedButton(
                          onPressed: _loadStatistics,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryPurple,
                            foregroundColor: Colors.white,
                          ),
                          child: const Text('Thử lại'),
                        ),
                      ],
                    ),
                  ),
                )
              : RefreshIndicator(
                  color: primaryPurple,
                  onRefresh: _loadStatistics,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(20),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 720),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Thẻ nổi bật: Xếp hạng & Cấp độ
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [
                                    Color(0xFF565CEB),
                                    Color(0xFF7B80F7),
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(22),
                                boxShadow: [
                                  BoxShadow(
                                    color:
                                        primaryPurple.withValues(alpha: 0.28),
                                    blurRadius: 14,
                                    offset: const Offset(0, 6),
                                  ),
                                ],
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 64,
                                    height: 64,
                                    decoration: BoxDecoration(
                                      color:
                                          Colors.white.withValues(alpha: 0.2),
                                      borderRadius: BorderRadius.circular(18),
                                    ),
                                    child: const Icon(
                                      Icons.military_tech_rounded,
                                      color: Color(0xFFFFD54F),
                                      size: 38,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'Xếp hạng hiện tại',
                                          style: TextStyle(
                                            color: Colors.white70,
                                            fontSize: 13,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          'Top #$_rankPosition • $_rankTier',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 20,
                                            fontWeight: FontWeight.w900,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          '$_rankPoints điểm rank • Cấp độ $_level',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 13.5,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(height: 22),
                            const Text(
                              'Tổng quan thành tích',
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                                color: darkText,
                              ),
                            ),
                            const SizedBox(height: 14),

                            // Lưới 4 chỉ số thống kê chính
                            GridView.count(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              crossAxisCount: 2,
                              crossAxisSpacing: 14,
                              mainAxisSpacing: 14,
                              childAspectRatio: 1.25,
                              children: [
                                _buildStatCard(
                                  icon: Icons.leaderboard_rounded,
                                  iconColor: primaryPurple,
                                  bgColor: cardLavender,
                                  title: 'Xếp hạng',
                                  value: '#$_rankPosition',
                                  subtitle: '$_rankTier ($_rankPoints RP)',
                                ),
                                _buildStatCard(
                                  icon: Icons.quiz_rounded,
                                  iconColor: const Color(0xFF0288D1),
                                  bgColor: const Color(0xFFE1F5FE),
                                  title: 'Câu hỏi đã trả lời',
                                  value: '$_totalAnswered',
                                  subtitle: 'Đúng $_totalCorrect câu',
                                ),
                                _buildStatCard(
                                  icon: Icons.timer_rounded,
                                  iconColor: accentOrange,
                                  bgColor: const Color(0xFFFFF3E0),
                                  title: 'Tổng thời gian chơi',
                                  value:
                                      _formatTotalPlayTime(_totalPlaySeconds),
                                  subtitle: 'Qua $_totalMatches lượt thi',
                                ),
                                _buildStatCard(
                                  icon: Icons.check_circle_rounded,
                                  iconColor: const Color(0xFF2E7D32),
                                  bgColor: const Color(0xFFE8F5E9),
                                  title: 'Tỷ lệ trả lời đúng',
                                  value: '${accuracy.toStringAsFixed(1)}%',
                                  subtitle: '$_totalCorrect / $_totalAnswered câu',
                                ),
                              ],
                            ),

                            const SizedBox(height: 20),

                            // Thanh trực quan tỷ lệ chính xác
                            Container(
                              padding: const EdgeInsets.all(18),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(18),
                                border:
                                    Border.all(color: const Color(0xFFE8EAFA)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      const Text(
                                        'Độ chính xác trung bình',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14.5,
                                          color: darkText,
                                        ),
                                      ),
                                      Text(
                                        '${accuracy.toStringAsFixed(1)}%',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w900,
                                          fontSize: 15,
                                          color: Color(0xFF2E7D32),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: LinearProgressIndicator(
                                      value: (accuracy / 100).clamp(0.0, 1.0),
                                      minHeight: 10,
                                      backgroundColor: const Color(0xFFECEEFF),
                                      valueColor:
                                          const AlwaysStoppedAnimation<Color>(
                                        Color(0xFF2E7D32),
                                      ),
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
                ),
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required Color iconColor,
    required Color bgColor,
    required String title,
    required String value,
    required String subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE8EAFA)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: iconColor, size: 22),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12.5,
                  color: subText,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: darkText,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 11.5,
                  color: subText,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}