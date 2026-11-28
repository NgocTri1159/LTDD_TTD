import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../controllers/admin_account_controller.dart';
import '../../core/theme.dart';
import '../../models/account_model.dart';

class AdminAccountDetailScreen extends StatefulWidget {
  final AccountModel? account;

  const AdminAccountDetailScreen({super.key, this.account});

  @override
  State<AdminAccountDetailScreen> createState() =>
      _AdminAccountDetailScreenState();
}

class _AdminAccountDetailScreenState extends State<AdminAccountDetailScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _levelController = TextEditingController();
  final _bioController = TextEditingController();

  static const Color _brandBlue = Color(0xFF3B5BFD);
  static const Color _brandPurple = Color(0xFF7C3AED);
  static const Color _brandEmerald = Color(0xFF10B981);
  static const Color _brandAmber = Color(0xFFF59E0B);

  static const List<String> _roleOptions = ['User', 'Admin'];
  static const List<String> _rankOptions = [
    'Đồng',
    'Bạc',
    'Vàng',
    'Bạch kim',
    'Kim cương',
  ];
  static const List<int> _quickLevels = [1, 5, 10, 20, 50];

  String _role = 'User';
  String _rank = 'Đồng';
  int _level = 1;
  String _avatarUrl = '';
  XFile? _pickedImage;
  Uint8List? _pickedBytes;
  bool _saving = false;
  bool _deleting = false;

  bool get _isEditing => widget.account != null;

  @override
  void initState() {
    super.initState();
    final acc = widget.account;
    if (acc != null) {
      _nameController.text = acc.fullName;
      _level = acc.level < 1 ? 1 : acc.level;
      _levelController.text = '$_level';
      _bioController.text = acc.bio;
      _avatarUrl = acc.avatarUrl;
      _role = _roleOptions.any(
        (r) => r.toLowerCase() == acc.role.trim().toLowerCase(),
      )
          ? _roleOptions.firstWhere(
              (r) => r.toLowerCase() == acc.role.trim().toLowerCase(),
            )
          : 'User';
      _rank = _rankOptions.contains(acc.rank) ? acc.rank : 'Vàng';
    } else {
      _nameController.text = '';
      _level = 1;
      _levelController.text = '1';
      _bioController.text = '';
      _role = 'User';
      _rank = 'Đồng';
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _levelController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  String _formatDate(DateTime? dt) {
    final d = (dt ?? DateTime.now()).toLocal();
    final day = d.day.toString().padLeft(2, '0');
    final month = d.month.toString().padLeft(2, '0');
    return '$day/$month/${d.year}';
  }

  void _setLevel(int newLevel) {
    final clamped = newLevel.clamp(1, 999);
    setState(() {
      _level = clamped;
      _levelController.text = '$clamped';
      _levelController.selection = TextSelection.collapsed(
        offset: _levelController.text.length,
      );
    });
  }

  Color _rankColor(String rank) {
    switch (rank) {
      case 'Đồng':
        return const Color(0xFFB45309);
      case 'Bạc':
        return const Color(0xFF64748B);
      case 'Vàng':
        return const Color(0xFFD97706);
      case 'Bạch kim':
        return const Color(0xFF0891B2);
      case 'Kim cương':
        return const Color(0xFF4F46E5);
      default:
        return _brandEmerald;
    }
  }

  IconData _rankIcon(String rank) {
    switch (rank) {
      case 'Đồng':
        return Icons.workspace_premium_outlined;
      case 'Bạc':
        return Icons.military_tech_outlined;
      case 'Vàng':
        return Icons.emoji_events_rounded;
      case 'Bạch kim':
        return Icons.auto_awesome_rounded;
      case 'Kim cương':
        return Icons.diamond_rounded;
      default:
        return Icons.emoji_events_rounded;
    }
  }

  Future<void> _pickAvatar() async {
    if (_saving || _deleting) return;
    final picker = ImagePicker();
    final file = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 600,
      imageQuality: 85,
    );
    if (file == null) return;
    final bytes = await file.readAsBytes();
    if (!mounted) return;
    setState(() {
      _pickedImage = file;
      _pickedBytes = bytes;
    });
  }

  void _clearPickedAvatar() {
    setState(() {
      _pickedImage = null;
      _pickedBytes = null;
    });
  }

  Future<String> _uploadAvatarIfNeeded() async {
    if (_pickedImage == null || _pickedBytes == null) {
      return _avatarUrl.trim();
    }
    try {
      final parts = _pickedImage!.name.split('.');
      final ext = parts.length > 1 ? parts.last.toLowerCase() : 'jpg';
      final mime = ext == 'jpg' ? 'jpeg' : ext;
      final fileName = 'avatar_${DateTime.now().millisecondsSinceEpoch}.$ext';

      await Supabase.instance.client.storage.from('avatars').uploadBinary(
            fileName,
            _pickedBytes!,
            fileOptions: FileOptions(contentType: 'image/$mime'),
          );
      return Supabase.instance.client.storage
          .from('avatars')
          .getPublicUrl(fileName);
    } catch (_) {
      return _avatarUrl.trim();
    }
  }

  Future<void> _save() async {
    if (_saving || _deleting) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _saving = true);
    try {
      final finalAvatar = await _uploadAvatarIfNeeded();
      final parsedLevel = int.tryParse(_levelController.text.trim()) ?? _level;
      final finalLevel = parsedLevel < 1 ? 1 : parsedLevel;

      if (_isEditing) {
        await AdminAccountController.instance.updateAccount(
          id: widget.account!.id,
          fullName: _nameController.text.trim(),
          avatarUrl: finalAvatar,
          role: _role,
          level: finalLevel,
          rank: _rank,
          bio: _bioController.text.trim(),
        );
      } else {
        await AdminAccountController.instance.createAccount(
          fullName: _nameController.text.trim(),
          avatarUrl: finalAvatar,
          role: _role,
          level: finalLevel,
          rank: _rank,
          bio: _bioController.text.trim(),
        );
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isEditing
                ? 'Đã cập nhật tài khoản thành công'
                : 'Đã tạo tài khoản mới thành công',
          ),
          backgroundColor: _brandEmerald,
          behavior: SnackBarBehavior.floating,
        ),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Lỗi lưu tài khoản: $e'),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _confirmDelete() async {
    if (!_isEditing || _saving || _deleting) return;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFEF4444).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.delete_outline_rounded,
                color: Color(0xFFEF4444),
                size: 20,
              ),
            ),
            const SizedBox(width: 10),
            const Text(
              'Xóa tài khoản',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
            ),
          ],
        ),
        content: Text(
          'Bạn có chắc muốn xóa tài khoản "${widget.account!.fullName}" không? Hành động này không thể hoàn tác.',
          style: TextStyle(color: Colors.grey.shade700, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Hủy', style: TextStyle(color: Colors.grey.shade700)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Xóa',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );

    if (ok != true) return;

    setState(() => _deleting = true);
    try {
      await AdminAccountController.instance.deleteAccount(widget.account!.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Đã xóa tài khoản'),
          backgroundColor: Color(0xFFEF4444),
          behavior: SnackBarBehavior.floating,
        ),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _deleting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Lỗi xóa tài khoản: $e'),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5FB),
      body: Form(
        key: _formKey,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            // 1. HEADER GRADIENT + THẺ HỒ SƠ & CHỌN ẢNH ĐẠI DIỆN
            SliverToBoxAdapter(
              child: _buildHeaderAndProfileCard(context),
            ),

            // 2. NỘI DUNG FORM CHIA THẺ
            SliverToBoxAdapter(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 680),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Thẻ 1: Thông tin cơ bản
                        _buildSectionCard(
                          icon: Icons.badge_rounded,
                          iconColor: _brandBlue,
                          title: 'Thông tin tài khoản',
                          subtitle: 'Tên hiển thị, ngày khởi tạo và mô tả ngắn',
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildInputField(
                                controller: _nameController,
                                label: 'Tên tài khoản',
                                hint: 'Ví dụ: Player2020',
                                prefixIcon: Icons.person_outline_rounded,
                                onChanged: (_) => setState(() {}),
                                validator: (val) {
                                  if (val == null || val.trim().isEmpty) {
                                    return 'Vui lòng nhập tên tài khoản';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 14),

                              // Ngày tạo (chỉ đọc)
                              Text(
                                'Ngày tạo',
                                style: AppTextStyles.text.copyWith(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF334155),
                                ),
                              ),
                              const SizedBox(height: 7),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 13,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: const Color(0xFFE2E8F0),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.calendar_today_rounded,
                                      size: 18,
                                      color: Colors.grey.shade500,
                                    ),
                                    const SizedBox(width: 10),
                                    Text(
                                      _formatDate(widget.account?.createdAt),
                                      style: AppTextStyles.text.copyWith(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                        color: const Color(0xFF475569),
                                      ),
                                    ),
                                    const Spacer(),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 3,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        _isEditing ? 'Hệ thống' : 'Tự động',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                          color: Colors.grey.shade500,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 14),

                              _buildInputField(
                                controller: _bioController,
                                label: 'Mô tả',
                                hint: 'Nhập giới thiệu ngắn về người chơi...',
                                prefixIcon: Icons.notes_rounded,
                                maxLines: 4,
                                minLines: 3,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),

                        // Thẻ 2: Loại tài khoản / Phân quyền
                        _buildSectionCard(
                          icon: Icons.admin_panel_settings_rounded,
                          iconColor: _brandAmber,
                          title: 'Loại tài khoản',
                          subtitle: 'Chọn quyền truy cập trong ứng dụng',
                          child: Row(
                            children: [
                              Expanded(
                                child: _buildRoleCard(
                                  value: 'User',
                                  title: 'Người chơi',
                                  subtitle: 'Làm bộ đề & xếp hạng',
                                  icon: Icons.sports_esports_rounded,
                                  color: const Color(0xFF0284C7),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: _buildRoleCard(
                                  value: 'Admin',
                                  title: 'Admin',
                                  subtitle: 'Quản lí toàn hệ thống',
                                  icon: Icons.shield_rounded,
                                  color: _brandAmber,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),

                        // Thẻ 3: Cấp độ & Xếp hạng
                        _buildSectionCard(
                          icon: Icons.emoji_events_rounded,
                          iconColor: _brandPurple,
                          title: 'Cấp độ & Xếp hạng',
                          subtitle: 'Thiết lập tiến độ và thứ hạng hiện tại',
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Cấp độ',
                                style: AppTextStyles.text.copyWith(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF334155),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  _buildStepButton(
                                    icon: Icons.remove_rounded,
                                    onTap: _level > 1
                                        ? () => _setLevel(_level - 1)
                                        : null,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: TextFormField(
                                      controller: _levelController,
                                      textAlign: TextAlign.center,
                                      keyboardType: TextInputType.number,
                                      inputFormatters: [
                                        FilteringTextInputFormatter.digitsOnly,
                                        LengthLimitingTextInputFormatter(3),
                                      ],
                                      style: AppTextStyles.question.copyWith(
                                        fontSize: 17,
                                        fontWeight: FontWeight.w800,
                                        color: AppColors.text,
                                      ),
                                      onChanged: (v) {
                                        final parsed = int.tryParse(v);
                                        if (parsed != null && parsed >= 1) {
                                          setState(() => _level = parsed);
                                        }
                                      },
                                      decoration: InputDecoration(
                                        filled: true,
                                        fillColor: const Color(0xFFF8FAFC),
                                        prefixText: 'Lv. ',
                                        prefixStyle: const TextStyle(
                                          fontWeight: FontWeight.w800,
                                          color: _brandPurple,
                                          fontSize: 15,
                                        ),
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                          vertical: 12,
                                          horizontal: 12,
                                        ),
                                        enabledBorder: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(14),
                                          borderSide: const BorderSide(
                                            color: Color(0xFFE2E8F0),
                                          ),
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(14),
                                          borderSide: const BorderSide(
                                            color: AppColors.base,
                                            width: 1.5,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  _buildStepButton(
                                    icon: Icons.add_rounded,
                                    onTap: _level < 999
                                        ? () => _setLevel(_level + 1)
                                        : null,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),

                              // Chọn nhanh cấp độ
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: _quickLevels.map((lv) {
                                  final selected = _level == lv;
                                  return GestureDetector(
                                    onTap: () => _setLevel(lv),
                                    child: AnimatedContainer(
                                      duration:
                                          const Duration(milliseconds: 160),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 6,
                                      ),
                                      decoration: BoxDecoration(
                                        color: selected
                                            ? _brandPurple
                                            : const Color(0xFFF1F5F9),
                                        borderRadius:
                                            BorderRadius.circular(10),
                                      ),
                                      child: Text(
                                        'Lv.$lv',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                          color: selected
                                              ? Colors.white
                                              : const Color(0xFF475569),
                                        ),
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),
                              const SizedBox(height: 18),

                              Text(
                                'Xếp hạng',
                                style: AppTextStyles.text.copyWith(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF334155),
                                ),
                              ),
                              const SizedBox(height: 10),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: _rankOptions.map((rk) {
                                  final selected = _rank == rk;
                                  final color = _rankColor(rk);
                                  return GestureDetector(
                                    onTap: () => setState(() => _rank = rk),
                                    child: AnimatedContainer(
                                      duration:
                                          const Duration(milliseconds: 180),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 9,
                                      ),
                                      decoration: BoxDecoration(
                                        color: selected
                                            ? color
                                            : color.withValues(alpha: 0.08),
                                        borderRadius:
                                            BorderRadius.circular(13),
                                        border: Border.all(
                                          color: selected
                                              ? color
                                              : color.withValues(alpha: 0.25),
                                        ),
                                        boxShadow: selected
                                            ? [
                                                BoxShadow(
                                                  color: color.withValues(
                                                    alpha: 0.28,
                                                  ),
                                                  blurRadius: 8,
                                                  offset: const Offset(0, 3),
                                                ),
                                              ]
                                            : null,
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            _rankIcon(rk),
                                            size: 15,
                                            color: selected
                                                ? Colors.white
                                                : color,
                                          ),
                                          const SizedBox(width: 6),
                                          Text(
                                            rk,
                                            style: TextStyle(
                                              fontSize: 12.8,
                                              fontWeight: FontWeight.w700,
                                              color: selected
                                                  ? Colors.white
                                                  : color,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),
                            ],
                          ),
                        ),

                        // Khu vực Xóa tài khoản (chỉ hiện khi chỉnh sửa)
                        if (_isEditing) ...[
                          const SizedBox(height: 14),
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFF5F5),
                              borderRadius: BorderRadius.circular(22),
                              border: Border.all(
                                color: const Color(0xFFFECACA),
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFEF4444)
                                        .withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Icon(
                                    Icons.warning_amber_rounded,
                                    color: Color(0xFFDC2626),
                                    size: 21,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Xóa tài khoản này',
                                        style: TextStyle(
                                          fontSize: 14.5,
                                          fontWeight: FontWeight.w800,
                                          color: Color(0xFF991B1B),
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        'Xóa vĩnh viễn hồ sơ khỏi danh sách quản trị.',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.red.shade700
                                              .withValues(alpha: 0.8),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 10),
                                ElevatedButton(
                                  onPressed: (_saving || _deleting)
                                      ? null
                                      : _confirmDelete,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFFEF4444),
                                    foregroundColor: Colors.white,
                                    elevation: 0,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 10,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  child: _deleting
                                      ? const SizedBox(
                                          width: 16,
                                          height: 16,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white,
                                          ),
                                        )
                                      : const Text(
                                          'Xóa',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w800,
                                            fontSize: 13,
                                          ),
                                        ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),

      // THANH NÚT LƯU CỐ ĐỊNH DƯỚI CÙNG
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          border: const Border(top: BorderSide(color: Color(0xFFE2E8F0))),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF0F172A).withValues(alpha: 0.05),
              blurRadius: 14,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: Center(
            heightFactor: 1,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 680),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                child: Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: OutlinedButton(
                        onPressed: (_saving || _deleting)
                            ? null
                            : () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF475569),
                          side: const BorderSide(color: Color(0xFFCBD5E1)),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15),
                          ),
                        ),
                        child: const Text(
                          'Hủy',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 14.5,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 5,
                      child: ElevatedButton.icon(
                        onPressed: (_saving || _deleting) ? null : _save,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.base,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15),
                          ),
                        ),
                        icon: _saving
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.2,
                                  color: Colors.white,
                                ),
                              )
                            : Icon(
                                _isEditing
                                    ? Icons.save_rounded
                                    : Icons.person_add_alt_1_rounded,
                                size: 20,
                              ),
                        label: Text(
                          _saving
                              ? 'Đang lưu...'
                              : (_isEditing
                                  ? 'Lưu thay đổi'
                                  : 'Tạo tài khoản'),
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 14.5,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderAndProfileCard(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;
    final isAdmin = _role == 'Admin';
    final displayName = _nameController.text.trim().isEmpty
        ? 'Thành viên mới'
        : _nameController.text.trim();
    final rankColor = _rankColor(_rank);
    final hasAnyImage = _pickedBytes != null || _avatarUrl.trim().isNotEmpty;

    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: EdgeInsets.fromLTRB(20, topPadding + 14, 20, 62),
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
                  Row(
                    children: [
                      _buildHeaderIconButton(
                        tooltip: 'Quay lại',
                        onTap: () => Navigator.pop(context),
                        child: const Icon(
                          Icons.arrow_back_ios_new_rounded,
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _isEditing
                                  ? 'CHỈNH SỬA HỒ SƠ'
                                  : 'THÀNH VIÊN MỚI',
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.9,
                                color: Colors.white.withValues(alpha: 0.8),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _isEditing
                                  ? 'Quản lí tài khoản'
                                  : 'Thêm tài khoản mới',
                              style: AppTextStyles.question.copyWith(
                                fontSize: 21,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                                letterSpacing: -0.3,
                              ),
                            ),
                          ],
                        ),
                      ),
                      _buildHeaderIconButton(
                        tooltip: 'Lưu tài khoản',
                        onTap: (_saving || _deleting) ? null : _save,
                        child: _saving
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(
                                Icons.check_rounded,
                                color: Colors.white,
                                size: 22,
                              ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),

        // Thẻ xem trước hồ sơ + chọn ảnh đại diện nổi đè lên Header
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: Transform.translate(
              offset: const Offset(0, -38),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: isAdmin
                          ? _brandAmber.withValues(alpha: 0.45)
                          : const Color(0xFFE2E8F0),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF0F172A).withValues(alpha: 0.08),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          // Khung chọn ảnh đại diện
                          GestureDetector(
                            onTap: _pickAvatar,
                            child: Stack(
                              clipBehavior: Clip.none,
                              children: [
                                Container(
                                  width: 78,
                                  height: 78,
                                  padding: const EdgeInsets.all(3),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(22),
                                    border: Border.all(
                                      color:
                                          (isAdmin ? _brandAmber : AppColors.base)
                                              .withValues(alpha: 0.45),
                                      width: 1.8,
                                    ),
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(18),
                                    child: _buildAvatarContent(
                                      displayName,
                                      isAdmin,
                                    ),
                                  ),
                                ),
                                Positioned(
                                  right: -5,
                                  bottom: -5,
                                  child: Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      color: AppColors.base,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: Colors.white,
                                        width: 2,
                                      ),
                                    ),
                                    child: const Icon(
                                      Icons.camera_alt_rounded,
                                      size: 14,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 15),

                          // Xem trước tên, vai trò, cấp độ, hạng
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  displayName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppTextStyles.question.copyWith(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.text,
                                  ),
                                ),
                                const SizedBox(height: 7),
                                Wrap(
                                  spacing: 6,
                                  runSpacing: 6,
                                  children: [
                                    _buildPreviewPill(
                                      icon: isAdmin
                                          ? Icons.verified_user_rounded
                                          : Icons.person_rounded,
                                      label: isAdmin ? 'Admin' : 'User',
                                      bg: isAdmin
                                          ? const Color(0xFFFEF3C7)
                                          : const Color(0xFFE0F2FE),
                                      fg: isAdmin
                                          ? const Color(0xFFB45309)
                                          : const Color(0xFF0369A1),
                                    ),
                                    _buildPreviewPill(
                                      icon: Icons.bolt_rounded,
                                      label: 'Lv.$_level',
                                      bg: _brandPurple.withValues(alpha: 0.1),
                                      fg: _brandPurple,
                                    ),
                                    _buildPreviewPill(
                                      icon: _rankIcon(_rank),
                                      label: _rank,
                                      bg: rankColor.withValues(alpha: 0.12),
                                      fg: rankColor,
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      const Divider(height: 1, color: Color(0xFFF1F5F9)),
                      const SizedBox(height: 10),

                      // Thanh thao tác nhanh chọn/đổi ảnh đại diện
                      Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              onTap: _pickAvatar,
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 9,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.base.withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(
                                      Icons.add_photo_alternate_rounded,
                                      size: 17,
                                      color: AppColors.base,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      hasAnyImage
                                          ? 'Đổi ảnh đại diện'
                                          : 'Chọn ảnh đại diện từ máy',
                                      style: const TextStyle(
                                        fontSize: 12.8,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.base,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          if (_pickedBytes != null) ...[
                            const SizedBox(width: 8),
                            InkWell(
                              onTap: _clearPickedAvatar,
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 9,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  'Hoàn tác',
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.grey.shade700,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAvatarContent(String displayName, bool isAdmin) {
    if (_pickedBytes != null) {
      return Image.memory(_pickedBytes!, fit: BoxFit.cover);
    }
    if (_avatarUrl.trim().isNotEmpty) {
      return Image.network(
        _avatarUrl.trim(),
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _buildFallbackAvatar(displayName, isAdmin),
      );
    }
    return _buildFallbackAvatar(displayName, isAdmin);
  }

  Widget _buildFallbackAvatar(String name, bool isAdmin) {
    final accent = isAdmin ? _brandAmber : AppColors.base;
    return Container(
      color: accent.withValues(alpha: 0.12),
      alignment: Alignment.center,
      child: _nameController.text.trim().isEmpty
          ? Icon(
              Icons.person_add_alt_1_rounded,
              size: 30,
              color: accent.withValues(alpha: 0.8),
            )
          : Text(
              name[0].toUpperCase(),
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w900,
                color: accent,
              ),
            ),
    );
  }

  Widget _buildPreviewPill({
    required IconData icon,
    required String label,
    required Color bg,
    required Color fg,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: fg),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderIconButton({
    required String tooltip,
    required VoidCallback? onTap,
    required Widget child,
  }) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            width: 42,
            height: 42,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.28),
              ),
            ),
            child: child,
          ),
        ),
      ),
    );
  }

  Widget _buildSectionCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.04),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, size: 20, color: iconColor),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: AppTextStyles.question.copyWith(
                        fontSize: 15.2,
                        fontWeight: FontWeight.w800,
                        color: AppColors.text,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      subtitle,
                      style: AppTextStyles.text.copyWith(
                        fontSize: 12,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData prefixIcon,
    int maxLines = 1,
    int? minLines,
    ValueChanged<String>? onChanged,
    FormFieldValidator<String>? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTextStyles.text.copyWith(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF334155),
          ),
        ),
        const SizedBox(height: 7),
        TextFormField(
          controller: controller,
          maxLines: maxLines,
          minLines: minLines,
          onChanged: onChanged,
          validator: validator,
          style: AppTextStyles.text.copyWith(
            fontSize: 14,
            color: AppColors.text,
            fontWeight: FontWeight.w500,
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13.5),
            filled: true,
            fillColor: const Color(0xFFF8FAFC),
            prefixIcon: Icon(
              prefixIcon,
              size: 20,
              color: AppColors.base.withValues(alpha: 0.75),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 13,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: AppColors.base, width: 1.5),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Colors.redAccent),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Colors.redAccent, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRoleCard({
    required String value,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
  }) {
    final selected = _role == value;
    return GestureDetector(
      onTap: () => setState(() => _role = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: selected
              ? color.withValues(alpha: 0.08)
              : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? color : const Color(0xFFE2E8F0),
            width: selected ? 1.6 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: selected ? color : color.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    icon,
                    size: 18,
                    color: selected ? Colors.white : color,
                  ),
                ),
                const Spacer(),
                Icon(
                  selected
                      ? Icons.check_circle_rounded
                      : Icons.radio_button_unchecked_rounded,
                  size: 19,
                  color: selected ? color : Colors.grey.shade400,
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              title,
              style: AppTextStyles.question.copyWith(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: selected ? color : AppColors.text,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: AppTextStyles.text.copyWith(
                fontSize: 11.5,
                color: Colors.grey.shade500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStepButton({
    required IconData icon,
    required VoidCallback? onTap,
  }) {
    final enabled = onTap != null;
    return Material(
      color: enabled
          ? AppColors.base.withValues(alpha: 0.1)
          : const Color(0xFFF1F5F9),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: SizedBox(
          width: 46,
          height: 46,
          child: Icon(
            icon,
            color: enabled ? AppColors.base : Colors.grey.shade400,
          ),
        ),
      ),
    );
  }
}