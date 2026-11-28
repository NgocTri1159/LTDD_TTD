import 'package:flutter/material.dart';
import '../../core/theme.dart';
import '../../controllers/question_controller.dart';
import '../../models/question_model.dart';
import '../../models/answer_model.dart';

class QuestionFormScreen extends StatefulWidget {
  final QuestionModel? question; // null = Thêm mới, có dữ liệu = Chỉnh sửa
  final String? deThiId;

  const QuestionFormScreen({
    super.key,
    this.question,
    this.deThiId,
  });

  @override
  State<QuestionFormScreen> createState() => _QuestionFormScreenState();
}

class _QuestionFormScreenState extends State<QuestionFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final QuestionController _controller = QuestionController();

  // Các ô nhập thông tin câu hỏi
  late TextEditingController _noiDungController;
  late TextEditingController _giaiThichController;
  late TextEditingController _hinhAnhController;
  late TextEditingController _tagsController;

  // 4 ô nhập cho 4 đáp án A, B, C, D
  final List<TextEditingController> _answerControllers = List.generate(
    4,
    (_) => TextEditingController(),
  );

  int _correctAnswerIndex = 0; // Vị trí đáp án đúng (0 = A, 1 = B, 2 = C, 3 = D)
  String _selectedMucDo = 'trung_binh';
  bool _isSaving = false;

  bool get _isEditing => widget.question != null;

  @override
  void initState() {
    super.initState();
    final q = widget.question;

    _noiDungController = TextEditingController(text: q?.noiDung ?? '');
    _giaiThichController = TextEditingController(text: q?.giaiThich ?? '');
    _hinhAnhController = TextEditingController(text: q?.hinhAnhUrl ?? '');

    // Đọc danh sách tag cũ từ duLieuBoSung['tags'] nếu đang sửa
    final existingTags = (q?.duLieuBoSung['tags'] as List?)
            ?.map((e) => e.toString())
            .join(', ') ??
        '';
    _tagsController = TextEditingController(text: existingTags);

    _selectedMucDo = q?.mucDo ?? 'trung_binh';

    // Đổ danh sách đáp án cũ vào 4 ô nhập (nếu đang sửa)
    if (q != null && q.danhSachDapAn.isNotEmpty) {
      for (int i = 0; i < 4; i++) {
        if (i < q.danhSachDapAn.length) {
          _answerControllers[i].text = q.danhSachDapAn[i].noiDung;
          if (q.danhSachDapAn[i].laDapAnDung) {
            _correctAnswerIndex = i;
          }
        }
      }
    }
  }

  @override
  void dispose() {
    _noiDungController.dispose();
    _giaiThichController.dispose();
    _hinhAnhController.dispose();
    _tagsController.dispose();
    for (var c in _answerControllers) {
      c.dispose();
    }
    super.dispose();
  }

  // Hàm lưu câu hỏi (Tạo mới hoặc Cập nhật) lên Supabase
  Future<void> _saveQuestion() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      // Tách chuỗi tag nhập bằng dấu phẩy thành List<String>
      final List<String> tags = _tagsController.text
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();

      final Map<String, dynamic> extraData = Map<String, dynamic>.from(
        widget.question?.duLieuBoSung ?? {},
      );
      extraData['tags'] = tags;

      // Tạo đối tượng QuestionModel
      final questionData = QuestionModel(
        id: widget.question?.id ?? '',
        deThiId: widget.question?.deThiId ?? widget.deThiId,
        monHocId: widget.question?.monHocId,
        // Lưu ý: Thay ID loại câu hỏi mặc định khớp với bảng public.loai_cau_hoi của bạn
        loaiCauHoiId: widget.question?.loaiCauHoiId ?? 'trac_nghiem',
        noiDung: _noiDungController.text.trim(),
        giaiThich: _giaiThichController.text.trim().isEmpty
            ? null
            : _giaiThichController.text.trim(),
        hinhAnhUrl: _hinhAnhController.text.trim().isEmpty
            ? null
            : _hinhAnhController.text.trim(),
        mucDo: _selectedMucDo,
        duLieuBoSung: extraData,
      );

      // Tạo danh sách 4 đáp án
      final List<AnswerModel> answers = List.generate(4, (index) {
        return AnswerModel(
          id: '',
          cauHoiId: questionData.id,
          noiDung: _answerControllers[index].text.trim(),
          laDapAnDung: index == _correctAnswerIndex,
          thuTu: index + 1,
        );
      });

      if (_isEditing) {
        await _controller.updateQuestion(questionData, answers);
      } else {
        await _controller.createQuestion(questionData, answers);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _isEditing ? 'Đã cập nhật câu hỏi!' : 'Đã thêm câu hỏi mới!',
            ),
          ),
        );
        Navigator.pop(context, true); // Trả về true để màn hình danh sách tự reload
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi lưu câu hỏi: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  InputDecoration _buildInputDecoration(String label, {String? hint}) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.base, width: 1.5),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final labels = ['A', 'B', 'C', 'D'];

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Chỉnh sửa câu hỏi' : 'Thêm câu hỏi mới'),
        centerTitle: true,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // 1. NỘI DUNG CÂU HỎI
            TextFormField(
              controller: _noiDungController,
              maxLines: 3,
              decoration: _buildInputDecoration('Nội dung câu hỏi *'),
              validator: (val) =>
                  (val == null || val.trim().isEmpty) ? 'Vui lòng nhập câu hỏi' : null,
            ),
            const SizedBox(height: 16),

            // 2. CHỌN MỨC ĐỘ
            DropdownButtonFormField<String>(
              value: _selectedMucDo,
              decoration: _buildInputDecoration('Mức độ'),
              items: const [
                DropdownMenuItem(value: 'de', child: Text('Dễ')),
                DropdownMenuItem(value: 'trung_binh', child: Text('Trung bình')),
                DropdownMenuItem(value: 'kho', child: Text('Khó')),
              ],
              onChanged: (val) {
                if (val != null) setState(() => _selectedMucDo = val);
              },
            ),
            const SizedBox(height: 16),

            // 3. LINK HÌNH ẢNH MINH HỌA + XEM TRƯỚC
            TextFormField(
              controller: _hinhAnhController,
              decoration: _buildInputDecoration(
                'Link hình ảnh minh họa (tùy chọn)',
                hint: 'https://...',
              ),
              onChanged: (_) => setState(() {}),
            ),
            if (_hinhAnhController.text.trim().isNotEmpty) ...[
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  _hinhAnhController.text.trim(),
                  height: 150,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    height: 80,
                    color: Colors.grey.shade200,
                    alignment: Alignment.center,
                    child: const Text('Không tải được ảnh xem trước'),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 20),

            // 4. DANH SÁCH 4 ĐÁP ÁN + RADIO CHỌN ĐÁP ÁN ĐÚNG
            Text(
              'Các đáp án (tích chọn đáp án đúng):',
              style: AppTextStyles.answer.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 10),
            ...List.generate(4, (index) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  children: [
                    Radio<int>(
                      value: index,
                      groupValue: _correctAnswerIndex,
                      activeColor: Colors.green,
                      onChanged: (val) {
                        if (val != null) {
                          setState(() => _correctAnswerIndex = val);
                        }
                      },
                    ),
                    Expanded(
                      child: TextFormField(
                        controller: _answerControllers[index],
                        decoration: _buildInputDecoration('Đáp án ${labels[index]} *'),
                        validator: (val) => (val == null || val.trim().isEmpty)
                            ? 'Nhập đáp án ${labels[index]}'
                            : null,
                      ),
                    ),
                  ],
                ),
              );
            }),
            const SizedBox(height: 12),

            // 5. GIẢI THÍCH ĐÁP ÁN
            TextFormField(
              controller: _giaiThichController,
              maxLines: 2,
              decoration: _buildInputDecoration(
                'Giải thích đáp án (tùy chọn)',
                hint: 'Hiển thị ở màn hình Xem đáp án sau khi nộp bài',
              ),
            ),
            const SizedBox(height: 16),

            // 6. GẮN THẺ (TAGGING)
            TextFormField(
              controller: _tagsController,
              decoration: _buildInputDecoration(
                'Gắn thẻ (cách nhau bằng dấu phẩy)',
                hint: 'VD: chương 1, giải tích, ôn thi',
              ),
            ),
            const SizedBox(height: 28),

            // 7. NÚT LƯU
            SizedBox(
              height: 52,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.base,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: _isSaving ? null : _saveQuestion,
                child: _isSaving
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2.5,
                        ),
                      )
                    : Text(
                        _isEditing ? 'CẬP NHẬT CÂU HỎI' : 'LƯU CÂU HỎI',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}