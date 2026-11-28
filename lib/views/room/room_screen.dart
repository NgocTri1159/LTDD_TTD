import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../controllers/room_controller.dart';
import '../../models/room_model.dart';
import 'room_lobby_screen.dart';

class RoomScreen extends StatefulWidget {
  const RoomScreen({super.key});

  @override
  State<RoomScreen> createState() => _RoomScreenState();
}

class _RoomScreenState extends State<RoomScreen> {
  static const Color _navy = Color(0xFF1E293B);
  static const Color _bg = Color(0xFFF8FAFC);

  int _selectedTab = 0; // 0: Vào phòng, 1: Tạo phòng

  final TextEditingController _codeController = TextEditingController();
  bool _isJoining = false;

  final TextEditingController _roomNameController = TextEditingController();
  List<RoomExamOption> _exams = [];
  String? _selectedExamId;
  int _selectedMinutes = 15;
  bool _loadingExams = false;
  bool _isCreating = false;

  @override
  void initState() {
    super.initState();
    _loadExams();
  }

  @override
  void dispose() {
    _codeController.dispose();
    _roomNameController.dispose();
    super.dispose();
  }

  Future<void> _loadExams() async {
    setState(() => _loadingExams = true);
    try {
      final list = await RoomController.instance.fetchAvailableExams();
      if (!mounted) return;
      setState(() {
        _exams = list;
        if (_exams.isNotEmpty && _selectedExamId == null) {
          _selectedExamId = _exams.first.id;
        }
      });
    } catch (e) {
      if (!mounted) return;
      _showSnack('Không tải được danh sách bộ đề: $e', isError: true);
    } finally {
      if (mounted) setState(() => _loadingExams = false);
    }
  }

  Future<void> _handleJoinRoom() async {
    final code = _codeController.text.trim().toUpperCase();
    if (code.length != 6) {
      _showSnack('Vui lòng nhập đủ mã phòng 6 ký tự.', isError: true);
      return;
    }

    setState(() => _isJoining = true);
    try {
      final room = await RoomController.instance.joinRoomByCode(code);
      if (!mounted) return;
      _codeController.clear();
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => RoomLobbyScreen(initialRoom: room)),
      );
    } catch (e) {
      if (!mounted) return;
      _showSnack(e.toString().replaceFirst('Exception: ', ''), isError: true);
    } finally {
      if (mounted) setState(() => _isJoining = false);
    }
  }

  Future<void> _handleCreateRoom() async {
    if (_selectedExamId == null) {
      _showSnack('Vui lòng chọn một bộ đề có câu hỏi.', isError: true);
      return;
    }

    setState(() => _isCreating = true);
    try {
      final room = await RoomController.instance.createRoom(
        tenPhong: _roomNameController.text,
        deThiId: _selectedExamId!,
        thoiGianPhut: _selectedMinutes,
      );
      if (!mounted) return;
      _roomNameController.clear();
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => RoomLobbyScreen(initialRoom: room)),
      );
    } catch (e) {
      if (!mounted) return;
      _showSnack('Tạo phòng thất bại: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isCreating = false);
    }
  }

  void _showSnack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? const Color(0xFFDC2626) : _navy,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.white,
        title: const Text(
          'Phòng thi',
          style: TextStyle(color: _navy, fontWeight: FontWeight.w700, fontSize: 18),
        ),
        iconTheme: const IconThemeData(color: _navy),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildTabSwitcher(),
            const SizedBox(height: 16),
            if (_selectedTab == 0) _buildJoinCard() else _buildCreateCard(),
            const SizedBox(height: 24),
            const Text(
              'Cách hoạt động',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: _navy),
            ),
            const SizedBox(height: 12),
            _buildStepItem('1', 'Nhận mã phòng', 'Giáo viên hoặc người tạo phòng chia sẻ mã 6 ký tự.'),
            const SizedBox(height: 10),
            _buildStepItem('2', 'Vào phòng chờ', 'Chờ mọi người tham gia và sẵn sàng bắt đầu.'),
            const SizedBox(height: 10),
            _buildStepItem('3', 'Thi cùng nhau', 'Làm bài đồng thời và xem bảng xếp hạng trực tiếp.'),
          ],
        ),
      ),
    );
  }

  Widget _buildTabSwitcher() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFE2E8F0),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          _buildTabButton(index: 0, icon: Icons.login_rounded, label: 'Vào phòng'),
          _buildTabButton(index: 1, icon: Icons.add_rounded, label: 'Tạo phòng'),
        ],
      ),
    );
  }

  Widget _buildTabButton({required int index, required IconData icon, required String label}) {
    final active = _selectedTab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() => _selectedTab = index);
          if (index == 1 && _exams.isEmpty && !_loadingExams) _loadExams();
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 11),
          decoration: BoxDecoration(
            color: active ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(11),
            boxShadow: active
                ? [const BoxShadow(color: Color(0x14000000), blurRadius: 6, offset: Offset(0, 2))]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 18, color: active ? _navy : const Color(0xFF64748B)),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: active ? _navy : const Color(0xFF64748B),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildJoinCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: const Color(0xFFEEF2FF),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.login_rounded, color: Color(0xFF4F46E5), size: 28),
          ),
          const SizedBox(height: 14),
          const Text(
            'Tham gia phòng thi',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: _navy),
          ),
          const SizedBox(height: 6),
          const Text(
            'Nhập mã phòng 6 ký tự từ giáo viên hoặc bạn bè để tham gia thi cùng nhau.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13.5, color: Color(0xFF64748B), height: 1.4),
          ),
          const SizedBox(height: 18),
          TextField(
            controller: _codeController,
            textAlign: TextAlign.center,
            textCapitalization: TextCapitalization.characters,
            maxLength: 6,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9]')),
              TextInputFormatter.withFunction(
                (_, newValue) => newValue.copyWith(text: newValue.text.toUpperCase()),
              ),
            ],
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              letterSpacing: 4,
              color: _navy,
            ),
            decoration: InputDecoration(
              counterText: '',
              hintText: 'VD: A1B2C3',
              hintStyle: const TextStyle(
                color: Color(0xFF94A3B8),
                letterSpacing: 2,
                fontWeight: FontWeight.w600,
              ),
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
              contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: _navy, width: 1.5),
              ),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              onPressed: _isJoining ? null : _handleJoinRoom,
              style: ElevatedButton.styleFrom(
                backgroundColor: _navy,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
              icon: _isJoining
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.arrow_forward_rounded, size: 20),
              label: Text(
                _isJoining ? 'Đang vào phòng...' : 'Vào phòng ngay',
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCreateCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Tạo phòng thi mới',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: _navy),
          ),
          const SizedBox(height: 4),
          const Text(
            'Chọn bộ đề và thời gian làm bài, hệ thống sẽ tự tạo mã 6 ký tự.',
            style: TextStyle(fontSize: 13.5, color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 16),
          const Text('Tên phòng', style: TextStyle(fontWeight: FontWeight.w600, color: _navy)),
          const SizedBox(height: 6),
          TextField(
            controller: _roomNameController,
            decoration: InputDecoration(
              hintText: 'VD: Kiểm tra 15 phút lớp 12A1',
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Chọn bộ đề', style: TextStyle(fontWeight: FontWeight.w600, color: _navy)),
              if (!_loadingExams)
                GestureDetector(
                  onTap: _loadExams,
                  child: const Text(
                    'Tải lại',
                    style: TextStyle(fontSize: 12.5, color: Color(0xFF4F46E5), fontWeight: FontWeight.w600),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          if (_loadingExams)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            )
          else if (_exams.isEmpty)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Text(
                'Chưa có bộ đề nào có câu hỏi trong bảng de_thi.',
                style: TextStyle(color: Color(0xFFB91C1C), fontSize: 13),
              ),
            )
          else
            DropdownButtonFormField<String>(
              value: _selectedExamId,
              isExpanded: true,
              decoration: InputDecoration(
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                ),
              ),
              items: _exams.map((exam) {
                return DropdownMenuItem<String>(
                  value: exam.id,
                  child: Text(
                    '${exam.tieuDe} (${exam.soCau} câu)',
                    overflow: TextOverflow.ellipsis,
                  ),
                );
              }).toList(),
              onChanged: (val) => setState(() => _selectedExamId = val),
            ),
          const SizedBox(height: 14),
          const Text('Thời gian làm bài', style: TextStyle(fontWeight: FontWeight.w600, color: _navy)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [5, 10, 15, 30].map((min) {
              final selected = _selectedMinutes == min;
              return ChoiceChip(
                label: Text('$min phút'),
                selected: selected,
                selectedColor: _navy,
                labelStyle: TextStyle(
                  color: selected ? Colors.white : _navy,
                  fontWeight: FontWeight.w600,
                ),
                onSelected: (_) => setState(() => _selectedMinutes = min),
              );
            }).toList(),
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              onPressed: (_isCreating || _exams.isEmpty) ? null : _handleCreateRoom,
              style: ElevatedButton.styleFrom(
                backgroundColor: _navy,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
              icon: _isCreating
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.add_circle_outline_rounded, size: 20),
              label: Text(
                _isCreating ? 'Đang tạo phòng...' : 'Tạo phòng & lấy mã',
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepItem(String number, String title, String subtitle) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 30,
            height: 30,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: Color(0xFFEEF2FF),
              shape: BoxShape.circle,
            ),
            child: Text(
              number,
              style: const TextStyle(color: Color(0xFF4F46E5), fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5, color: _navy),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}