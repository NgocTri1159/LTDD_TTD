
import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';

import '../../models/answer_model.dart';
import '../../models/question_model.dart';
import '../../models/subject_model.dart';
import '../../services/admin_service.dart';
import '../../services/question_media_service.dart';

class AdminQuestionFormScreen extends StatefulWidget {
  const AdminQuestionFormScreen({super.key});

  @override
  State<AdminQuestionFormScreen> createState() =>
      _AdminQuestionFormScreenState();
}

class _AdminQuestionFormScreenState extends State<AdminQuestionFormScreen> {
  static const Color primaryColor = Color(0xFF6257E8);

  // ID loại câu hỏi mot_dap_an trong Supabase.
  static const String questionTypeId = '112ab3f4-f6f5-4754-97c1-fe27f900c5ea';

  final _formKey = GlobalKey<FormState>();

  final _contentController = TextEditingController();
  final _explanationController = TextEditingController();
  final _pointController = TextEditingController(text: '1');
  final _durationController = TextEditingController(text: '60');

  final List<TextEditingController> _answerControllers = List.generate(
    4,
    (_) => TextEditingController(),
  );

  late Future<List<SubjectModel>> _subjectsFuture;

  String? _selectedSubjectId;
  String _difficulty = 'trung_binh';
  int _correctAnswerIndex = 0;

  String? _imageUrl;
  String? _audioUrl;

  bool _uploadingImage = false;
  bool _uploadingAudio = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _subjectsFuture = AdminService.getAllSubjectsAdmin();
  }

  @override
  void dispose() {
    _contentController.dispose();
    _explanationController.dispose();
    _pointController.dispose();
    _durationController.dispose();

    for (final controller in _answerControllers) {
      controller.dispose();
    }

    super.dispose();
  }

  Future<void> _pickImage() async {
    setState(() => _uploadingImage = true);

    try {
      final file = await QuestionMediaService.pickAndUploadImage();

      if (file == null) return;

      final url = file['url'] as String?;

      if (url == null || url.isEmpty) {
        throw Exception('Không nhận được URL hình ảnh');
      }

      if (!mounted) return;

      setState(() => _imageUrl = url);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Upload hình ảnh thành công')),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Lỗi upload hình ảnh: $e')));
    } finally {
      if (mounted) {
        setState(() => _uploadingImage = false);
      }
    }
  }

  Future<void> _pickAudio() async {
    setState(() => _uploadingAudio = true);

    try {
      final file = await QuestionMediaService.pickAndUploadAudio();

      if (file == null) return;

      final url = file['url'] as String?;

      if (url == null || url.isEmpty) {
        throw Exception('Không nhận được URL âm thanh');
      }

      if (!mounted) return;

      setState(() => _audioUrl = url);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Upload âm thanh thành công')),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Lỗi upload âm thanh: $e')));
    } finally {
      if (mounted) {
        setState(() => _uploadingAudio = false);
      }
    }
  }

  Future<void> _saveQuestion() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_selectedSubjectId == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Vui lòng chọn môn học')));
      return;
    }

    final point = double.tryParse(_pointController.text.trim());
    final duration = int.tryParse(_durationController.text.trim());

    if (point == null || point <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Điểm phải là số lớn hơn 0')),
      );
      return;
    }

    if (duration == null || duration <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Thời gian phải là số nguyên lớn hơn 0')),
      );
      return;
    }

    setState(() => _saving = true);

    try {
      final question = QuestionModel(
        id: '',
        monHocId: _selectedSubjectId,
        loaiCauHoiId: questionTypeId,
        noiDung: _contentController.text.trim(),
        giaiThich: _explanationController.text.trim().isEmpty
            ? null
            : _explanationController.text.trim(),
        hinhAnhUrl: _imageUrl,
        amThanhUrl: _audioUrl,
        diem: point,
        thoiGianGiay: duration,
        thuTu: 1,
        mucDo: _difficulty,
        daLuuTru: false,
      );

      final answers = List.generate(4, (index) {
        return AnswerModel(
          id: '',
          cauHoiId: '',
          noiDung: _answerControllers[index].text.trim(),
          laDung: index == _correctAnswerIndex,
          thuTu: index + 1,
        );
      });

      await AdminService.saveQuestionWithAnswers(
        question: question,
        answers: answers,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Thêm câu hỏi thành công'),
          backgroundColor: Colors.green,
        ),
      );

      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Không thể lưu câu hỏi: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  Widget _buildSectionTitle(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, top: 20),
      child: Row(
        children: [
          Icon(icon, color: primaryColor),
          const SizedBox(width: 8),
          Text(
            title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildSubjectDropdown(List<SubjectModel> subjects) {
    return DropdownButtonFormField<String>(
      initialValue: _selectedSubjectId,
      isExpanded: true,
      decoration: const InputDecoration(
        labelText: 'Môn học',
        prefixIcon: Icon(Icons.menu_book_outlined),
        border: OutlineInputBorder(),
      ),
      items: subjects.map((subject) {
        return DropdownMenuItem<String>(
          value: subject.id,
          child: Text(subject.tenMon),
        );
      }).toList(),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Vui lòng chọn môn học';
        }
        return null;
      },
      onChanged: (value) {
        setState(() => _selectedSubjectId = value);
      },
    );
  }

  Widget _buildDifficultyDropdown() {
    return DropdownButtonFormField<String>(
      initialValue: _difficulty,
      decoration: const InputDecoration(
        labelText: 'Mức độ',
        prefixIcon: Icon(Icons.tune),
        border: OutlineInputBorder(),
      ),
      items: const [
        DropdownMenuItem(value: 'de', child: Text('Dễ')),
        DropdownMenuItem(value: 'trung_binh', child: Text('Trung bình')),
        DropdownMenuItem(value: 'kho', child: Text('Khó')),
      ],
      onChanged: (value) {
        if (value != null) {
          setState(() => _difficulty = value);
        }
      },
    );
  }

  // RadioGroup quản lý đáp án đúng theo API Flutter mới.
  Widget _buildAnswers() {
    return RadioGroup<int>(
      groupValue: _correctAnswerIndex,
      onChanged: (value) {
        if (value != null) {
          setState(() => _correctAnswerIndex = value);
        }
      },
      child: Column(
        children: List.generate(4, (index) {
          final letter = String.fromCharCode(65 + index);
          final isCorrect = _correctAnswerIndex == index;

          return Card(
            margin: const EdgeInsets.only(bottom: 10),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Radio<int>(
                    value: index,
                    activeColor: Colors.green,
                  ),
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: isCorrect
                        ? Colors.green.withValues(alpha: 0.12)
                        : Colors.grey.withValues(alpha: 0.12),
                    child: Text(
                      letter,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: isCorrect ? Colors.green : Colors.grey,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _answerControllers[index],
                      decoration: InputDecoration(
                        labelText: 'Đáp án $letter',
                        border: const OutlineInputBorder(),
                        isDense: true,
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Vui lòng nhập đáp án $letter';
                        }
                        return null;
                      },
                    ),
                  ),
                  if (isCorrect)
                    const Padding(
                      padding: EdgeInsets.only(left: 8),
                      child: Icon(
                        Icons.check_circle,
                        color: Colors.green,
                      ),
                    ),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildMediaSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        OutlinedButton.icon(
          onPressed: _uploadingImage || _saving ? null : _pickImage,
          icon: _uploadingImage
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.image_outlined),
          label: Text(_uploadingImage ? 'Đang upload ảnh...' : 'Chọn hình ảnh'),
        ),
        if (_imageUrl != null) ...[
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.network(
              _imageUrl!,
              height: 160,
              width: double.infinity,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) {
                return const Text('Không thể hiển thị hình ảnh');
              },
            ),
          ),
          TextButton.icon(
            onPressed: _saving ? null : () => setState(() => _imageUrl = null),
            icon: const Icon(Icons.delete_outline),
            label: const Text('Xóa hình ảnh'),
          ),
        ],
        const Divider(height: 28),
        OutlinedButton.icon(
          onPressed: _uploadingAudio || _saving ? null : _pickAudio,
          icon: _uploadingAudio
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.audio_file_outlined),
          label: Text(
            _uploadingAudio ? 'Đang upload âm thanh...' : 'Chọn âm thanh',
          ),
        ),
        if (_audioUrl != null) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.green),
              const SizedBox(width: 8),
              const Expanded(child: Text('Đã upload âm thanh thành công')),
              IconButton(
                tooltip: 'Xóa âm thanh',
                onPressed: _saving
                    ? null
                    : () => setState(() => _audioUrl = null),
                icon: const Icon(Icons.delete_outline),
              ),
            ],
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Thêm câu hỏi'),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
      ),
      body: FutureBuilder<List<SubjectModel>>(
        future: _subjectsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Không thể tải danh sách môn học:\n${snapshot.error}',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          final subjects = snapshot.data ?? [];

          if (subjects.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Chưa có môn học. Vui lòng tạo môn học trước.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          return Form(
            key: _formKey,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionTitle('Thông tin câu hỏi', Icons.quiz_outlined),
                  TextFormField(
                    controller: _contentController,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      labelText: 'Nội dung câu hỏi',
                      hintText: 'Nhập nội dung câu hỏi...',
                      alignLabelWithHint: true,
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Vui lòng nhập nội dung câu hỏi';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  _buildSubjectDropdown(subjects),
                  const SizedBox(height: 16),
                  _buildDifficultyDropdown(),

                  _buildSectionTitle('Điểm và thời gian', Icons.timer_outlined),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _pointController,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(
                              RegExp(r'[0-9.]'),
                            ),
                          ],
                          decoration: const InputDecoration(
                            labelText: 'Điểm',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: _durationController,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          decoration: const InputDecoration(
                            labelText: 'Thời gian (giây)',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                    ],
                  ),

                  _buildSectionTitle('Danh sách đáp án', Icons.checklist),
                  const Text(
                    'Chọn nút tròn bên cạnh đáp án để đánh dấu đáp án đúng.',
                    style: TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 12),
                  _buildAnswers(),

                  _buildSectionTitle(
                    'Giải thích đáp án',
                    Icons.lightbulb_outline,
                  ),
                  TextFormField(
                    controller: _explanationController,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      hintText: 'Nhập lời giải thích (không bắt buộc)...',
                      border: OutlineInputBorder(),
                    ),
                  ),

                  _buildSectionTitle(
                    'Hình ảnh và âm thanh',
                    Icons.perm_media_outlined,
                  ),
                  _buildMediaSection(),

                  const SizedBox(height: 28),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      onPressed: _saving || _uploadingImage || _uploadingAudio
                          ? null
                          : _saveQuestion,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        foregroundColor: Colors.white,
                      ),
                      icon: _saving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.save_outlined),
                      label: Text(_saving ? 'Đang lưu...' : 'LƯU CÂU HỎI'),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
