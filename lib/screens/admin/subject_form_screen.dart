import 'package:material_ui/material_ui.dart';

import '../../models/subject_model.dart';
import '../../services/role_service.dart';
import '../../services/subject_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common/app_button.dart';
import '../../widgets/common/app_card.dart';
import '../../widgets/common/app_text_field.dart';

class SubjectFormScreen extends StatefulWidget {
  final SubjectModel? subject;

  const SubjectFormScreen({super.key, this.subject});

  @override
  State<SubjectFormScreen> createState() => _SubjectFormScreenState();
}

class _SubjectFormScreenState extends State<SubjectFormScreen> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _nameController;
  late final TextEditingController _descController;
  late final TextEditingController _iconController;
  late final TextEditingController _colorController;
  late final TextEditingController _orderController;

  late bool _status;
  bool _isLoading = false;

  bool get _isEditing => widget.subject != null;

  static const List<String> _emojiSuggestions = [
    '📐',
    '💻',
    '🔬',
    '📚',
    '🌐',
    '🧪',
    '🎨',
    '🎵',
    '⚡',
    '🏆',
    '📖',
    '🧠',
  ];

  static const List<Color> _colorPresets = [
    Color(0xFF6257E8),
    Color(0xFF29B6F6),
    Color(0xFF66BB6A),
    Color(0xFFFFA726),
    Color(0xFFEF5350),
    Color(0xFFAB47BC),
    Color(0xFF009688),
    Color(0xFF3F51B5),
  ];

  @override
  void initState() {
    super.initState();

    final subject = widget.subject;

    _nameController = TextEditingController(text: subject?.tenMon ?? '');
    _descController = TextEditingController(text: subject?.moTa ?? '');
    _iconController = TextEditingController(text: subject?.bieuTuong ?? '');
    _colorController = TextEditingController(text: subject?.mauSac ?? '');
    _orderController = TextEditingController(
      text: (subject?.thuTuHienThi ?? 0).toString(),
    );

    _status = subject?.trangThai ?? true;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    _iconController.dispose();
    _colorController.dispose();
    _orderController.dispose();
    super.dispose();
  }

  Color _previewColor() {
    final hex = _colorController.text.trim().replaceAll('#', '');

    if (hex.length == 6 || hex.length == 8) {
      try {
        final value = hex.length == 6 ? 'FF$hex' : hex;
        return Color(int.parse(value, radix: 16));
      } catch (_) {
        // Sử dụng màu mặc định nếu mã HEX không hợp lệ.
      }
    }

    return AppTheme.primary;
  }

  Future<void> _submit() async {
    if (_isLoading || !_formKey.currentState!.validate()) return;

    // Kiểm tra quyền Admin trước khi thực hiện.
    final role = await RoleService.getCurrentRole();

    if (!mounted) return;

    if (role != 'admin' && role != 'super_admin') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Bạn không có quyền thực hiện thao tác này.'),
          backgroundColor: AppTheme.error,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final name = _nameController.text.trim();

      final desc = _descController.text.trim().isEmpty
          ? null
          : _descController.text.trim();

      final icon = _iconController.text.trim().isEmpty
          ? null
          : _iconController.text.trim();

      String? color = _colorController.text.trim().isEmpty
          ? null
          : _colorController.text.trim();

      if (color != null && !color.startsWith('#')) {
        color = '#$color';
      }

      final order = int.parse(_orderController.text.trim());

      if (_isEditing) {
        await SubjectService.updateSubject(
          widget.subject!.id,
          tenMon: name,
          moTa: desc,
          bieuTuong: icon,
          mauSac: color,
          thuTuHienThi: order,
          trangThai: _status,
        );
      } else {
        await SubjectService.createSubject(
          tenMon: name,
          moTa: desc,
          bieuTuong: icon,
          mauSac: color,
          thuTuHienThi: order,
          trangThai: _status,
        );
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isEditing
                ? 'Cập nhật môn học thành công!'
                : 'Thêm môn học thành công!',
          ),
          backgroundColor: AppTheme.success,
        ),
      );

      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi: $e'), backgroundColor: AppTheme.error),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text(
          _isEditing ? 'Chỉnh sửa môn học' : 'Thêm môn học mới',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Thông tin cơ bản.
                  AppCard(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Thông tin cơ bản',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 16),

                        AppTextField(
                          controller: _nameController,
                          label: 'Tên môn học *',
                          hint:
                              'Nhập tên môn học (ví dụ: Toán học, Lịch sử...)',
                          prefixIcon: Icons.menu_book_rounded,
                          enabled: !_isLoading,
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Tên môn học không được để trống';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),

                        AppTextField(
                          controller: _descController,
                          label: 'Mô tả môn học',
                          hint: 'Mô tả ngắn gọn về kiến thức của môn học...',
                          prefixIcon: Icons.description_outlined,
                          maxLines: 3,
                          enabled: !_isLoading,
                        ),
                        const SizedBox(height: 16),

                        AppTextField(
                          controller: _orderController,
                          label: 'Thứ tự hiển thị *',
                          hint: '0, 1, 2, 3...',
                          prefixIcon: Icons.sort_rounded,
                          keyboardType: TextInputType.number,
                          enabled: !_isLoading,
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Vui lòng nhập thứ tự hiển thị';
                            }

                            final number = int.tryParse(value.trim());

                            if (number == null || number < 0) {
                              return 'Thứ tự hiển thị phải là số nguyên không âm';
                            }

                            return null;
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Giao diện và biểu tượng.
                  AppCard(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Giao diện & Biểu tượng',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 16),

                        AppTextField(
                          controller: _iconController,
                          label: 'Biểu tượng (Ký tự / Emoji)',
                          hint: 'Ví dụ: 📐, 💻, 🔬...',
                          prefixIcon: Icons.emoji_emotions_outlined,
                          enabled: !_isLoading,
                          onChanged: (_) => setState(() {}),
                        ),
                        const SizedBox(height: 10),

                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _emojiSuggestions.map((emoji) {
                            return InkWell(
                              onTap: _isLoading
                                  ? null
                                  : () {
                                      setState(() {
                                        _iconController.text = emoji;
                                      });
                                    },
                              borderRadius: BorderRadius.circular(8),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: AppTheme.background,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: _iconController.text == emoji
                                        ? AppTheme.primary
                                        : AppTheme.cardBorder,
                                    width: _iconController.text == emoji
                                        ? 2
                                        : 1,
                                  ),
                                ),
                                child: Text(
                                  emoji,
                                  style: const TextStyle(fontSize: 18),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 20),

                        AppTextField(
                          controller: _colorController,
                          label: 'Màu sắc môn học (Mã HEX)',
                          hint: 'Ví dụ: #6257E8',
                          prefixIcon: Icons.palette_outlined,
                          enabled: !_isLoading,
                          onChanged: (_) => setState(() {}),
                          suffixIcon: Padding(
                            padding: const EdgeInsets.all(10),
                            child: Container(
                              width: 24,
                              height: 24,
                              decoration: BoxDecoration(
                                color: _previewColor(),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.black12,
                                  width: 1,
                                ),
                              ),
                            ),
                          ),
                          validator: (value) {
                            if (value != null && value.trim().isNotEmpty) {
                              final clean = value.trim().replaceAll('#', '');

                              if ((clean.length != 6 && clean.length != 8) ||
                                  int.tryParse(clean, radix: 16) == null) {
                                return 'Mã màu HEX không hợp lệ (ví dụ: #6257E8)';
                              }
                            }

                            return null;
                          },
                        ),
                        const SizedBox(height: 10),

                        Wrap(
                          spacing: 10,
                          runSpacing: 8,
                          children: _colorPresets.map((colorValue) {
                            final hexStr =
                                '#${colorValue.toARGB32().toRadixString(16).substring(2).toUpperCase()}';

                            final isSelected =
                                _colorController.text.toUpperCase() == hexStr;

                            return InkWell(
                              onTap: _isLoading
                                  ? null
                                  : () {
                                      setState(() {
                                        _colorController.text = hexStr;
                                      });
                                    },
                              borderRadius: BorderRadius.circular(16),
                              child: Container(
                                width: 32,
                                height: 32,
                                decoration: BoxDecoration(
                                  color: colorValue,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: isSelected
                                        ? Colors.white
                                        : Colors.transparent,
                                    width: 2.5,
                                  ),
                                  boxShadow: [
                                    if (isSelected)
                                      BoxShadow(
                                        color: colorValue.withAlpha(120),
                                        blurRadius: 8,
                                        spreadRadius: 2,
                                      ),
                                  ],
                                ),
                                child: isSelected
                                    ? const Icon(
                                        Icons.check,
                                        color: Colors.white,
                                        size: 18,
                                      )
                                    : null,
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Cài đặt trạng thái.
                  AppCard(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                    child: Material(
                      color: Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                      clipBehavior: Clip.antiAlias,
                      child: SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text(
                          'Trạng thái hoạt động',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        subtitle: Text(
                          _status
                              ? 'Đang hoạt động (Học viên có thể nhìn thấy và làm bài)'
                              : 'Đã khóa (Chỉ Admin nhìn thấy, học viên bị ẩn)',
                          style: TextStyle(
                            fontSize: 12,
                            color: _status ? AppTheme.success : AppTheme.error,
                          ),
                        ),
                        value: _status,
                        activeTrackColor: AppTheme.primary.withAlpha(120),
                        activeThumbColor: AppTheme.primary,
                        onChanged: _isLoading
                            ? null
                            : (value) {
                                setState(() => _status = value);
                              },
                      ),
                    ),
                  ),
                  const SizedBox(height: 30),

                  // Nút hành động.
                  Row(
                    children: [
                      Expanded(
                        child: AppButton(
                          text: 'Hủy',
                          type: AppButtonType.outline,
                          onPressed: _isLoading
                              ? null
                              : () => Navigator.pop(context, false),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: AppButton(
                          text: _isEditing ? 'Lưu thay đổi' : 'Tạo môn học',
                          type: AppButtonType.primary,
                          isLoading: _isLoading,
                          onPressed: _submit,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
