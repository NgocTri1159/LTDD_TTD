import 'dart:async';
import 'package:flutter/material.dart';
import '../../controllers/room_controller.dart';
import '../../models/room_model.dart';
import 'room_leaderboard_screen.dart';

class RoomQuizScreen extends StatefulWidget {
  final RoomModel room;
  final String tenDeThi;
  final String monHoc;

  const RoomQuizScreen({
    super.key,
    required this.room,
    required this.tenDeThi,
    required this.monHoc,
  });

  @override
  State<RoomQuizScreen> createState() => _RoomQuizScreenState();
}

class _RoomQuizScreenState extends State<RoomQuizScreen> {
  static const Color _navy = Color(0xFF1E293B);

  List<RoomQuestionModel> _questions = [];
  final Map<String, String> _selectedAnswers = {};
  int _currentIndex = 0;
  bool _loading = true;
  bool _submitting = false;

  late int _totalSeconds;
  late int _remainingSeconds;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _totalSeconds = widget.room.thoiGianPhut * 60;
    _remainingSeconds = _totalSeconds;
    _loadQuestions();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _loadQuestions() async {
    try {
      final list = await RoomController.instance.fetchRoomQuestions(widget.room.deThiId);
      if (!mounted) return;
      setState(() {
        _questions = list;
        _loading = false;
      });
      _startTimer();
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi tải câu hỏi: $e')),
      );
    }
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_remainingSeconds <= 1) {
        timer.cancel();
        _submitExam(autoSubmit: true);
      } else {
        setState(() => _remainingSeconds--);
      }
    });
  }

  String _formatTime(int sec) {
    final m = (sec ~/ 60).toString().padLeft(2, '0');
    final s = (sec % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  Future<void> _submitExam({bool autoSubmit = false}) async {
    if (_submitting) return;
    _timer?.cancel();
    setState(() => _submitting = true);

    int correctCount = 0;
    for (final q in _questions) {
      final chosenId = _selectedAnswers[q.id];
      final isRight = q.dapAn.any((a) => a.id == chosenId && a.isCorrect);
      if (isRight) correctCount++;
    }

    final total = _questions.length;
    final score = total == 0 ? 0 : ((correctCount / total) * 100).round();
    final usedSeconds = (_totalSeconds - _remainingSeconds).clamp(1, _totalSeconds);

    try {
      await RoomController.instance.submitRoomResult(
        roomId: widget.room.id,
        deThiId: widget.room.deThiId,
        tenDeThi: widget.tenDeThi,
        monHoc: widget.monHoc,
        diemSo: score,
        soCauDung: correctCount,
        tongSoCau: total,
        thoiGianGiay: usedSeconds,
        questions: _questions,
        dapAnDaChon: _selectedAnswers,
      );

      if (!mounted) return;
      if (autoSubmit) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đã hết giờ, hệ thống tự động nộp bài!')),
        );
      }
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => RoomLeaderboardScreen(room: widget.room)),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Nộp bài thất bại: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_questions.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Phòng thi')),
        body: const Center(child: Text('Bộ đề này chưa có câu hỏi nào.')),
      );
    }

    final q = _questions[_currentIndex];
    final chosenId = _selectedAnswers[q.id];

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          'Câu ${_currentIndex + 1}/${_questions.length}',
          style: const TextStyle(color: _navy, fontWeight: FontWeight.w700),
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 14, top: 10, bottom: 10),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: _remainingSeconds <= 60 ? const Color(0xFFFEE2E2) : const Color(0xFFEEF2FF),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.timer_outlined,
                  size: 16,
                  color: _remainingSeconds <= 60 ? const Color(0xFFDC2626) : const Color(0xFF4F46E5),
                ),
                const SizedBox(width: 4),
                Text(
                  _formatTime(_remainingSeconds),
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: _remainingSeconds <= 60 ? const Color(0xFFDC2626) : const Color(0xFF4F46E5),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          LinearProgressIndicator(
            value: (_currentIndex + 1) / _questions.length,
            backgroundColor: const Color(0xFFE2E8F0),
            color: _navy,
            minHeight: 4,
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Text(
                      q.noiDung,
                      style: const TextStyle(
                        fontSize: 16.5,
                        fontWeight: FontWeight.w600,
                        color: _navy,
                        height: 1.45,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  ...List.generate(q.dapAn.length, (i) {
                    final ans = q.dapAn[i];
                    final isSelected = chosenId == ans.id;
                    final letter = String.fromCharCode(65 + i);
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: () => setState(() => _selectedAnswers[q.id] = ans.id),
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: isSelected ? const Color(0xFFEEF2FF) : Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: isSelected ? const Color(0xFF4F46E5) : const Color(0xFFE2E8F0),
                              width: isSelected ? 1.8 : 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 30,
                                height: 30,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: isSelected ? const Color(0xFF4F46E5) : const Color(0xFFF1F5F9),
                                  shape: BoxShape.circle,
                                ),
                                child: Text(
                                  letter,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    color: isSelected ? Colors.white : _navy,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  ans.noiDung,
                                  style: const TextStyle(fontSize: 15, color: _navy),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  if (_currentIndex > 0)
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => setState(() => _currentIndex--),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text('Câu trước'),
                      ),
                    ),
                  if (_currentIndex > 0) const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: _submitting
                          ? null
                          : () {
                              if (_currentIndex < _questions.length - 1) {
                                setState(() => _currentIndex++);
                              } else {
                                _submitExam();
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _navy,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text(
                        _currentIndex < _questions.length - 1
                            ? 'Câu tiếp theo'
                            : (_submitting
                                ? 'Đang nộp bài...'
                                : 'Nộp bài (${_selectedAnswers.length}/${_questions.length})'),
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}