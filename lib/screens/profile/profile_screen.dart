import 'dart:typed_data';
import 'package:material_ui/material_ui.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide User;
import '../../services/rank_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  static const Color bannerBlue = Color(0xFF72D6FF);
  static const Color progressBlue = Color(0xFF2196F3);
  static const Color primaryPurple = Color(0xFF565CEB);
  static const Color darkText = Color(0xFF1E1E2C);
  static const Color pageBg = Color(0xFFF6F7FB);

  final SupabaseClient _supabase = Supabase.instance.client;
  final ImagePicker _picker = ImagePicker();

  bool _isLoading = true;
  bool _isSaving = false;

  String _displayName = '';
  String _avatarUrl = '';
  String _bio = 'Đây là những dòng mô tả về mình.';
  int _level = 1;
  double _levelProgress = 0.05;
  String _rankTitle = 'ĐỒNG';
  int _rankPoints = 0;

  @override
  void initState() {
    super.initState();
    _loadProfileData();
  }

  User? get _firebaseUser => FirebaseAuth.instance.currentUser;

  Future<void> _loadProfileData() async {
    final user = _firebaseUser;
    if (user == null) {
      setState(() => _isLoading = false);
      return;
    }

    final fallbackName = (user.displayName != null &&
            user.displayName!.trim().isNotEmpty)
        ? user.displayName!.trim()
        : (user.email?.split('@').first ?? 'Player');

    setState(() {
      _displayName = fallbackName;
      _avatarUrl = user.photoURL ?? '';
    });

    try {
      Map<String, dynamic>? row;

      // 1. Tìm theo email
      if (user.email != null && user.email!.isNotEmpty) {
        row = await _supabase
            .from('nguoi_dung')
            .select()
            .ilike('email', user.email!)
            .maybeSingle();
      }

      // 2. Fallback tìm theo cột id nếu chưa thấy
      if (row == null) {
        try {
          row = await _supabase
              .from('nguoi_dung')
              .select()
              .eq('id', user.uid)
              .maybeSingle();
        } catch (_) {}
      }

      if (row != null && mounted) {
        final dbName = (row['ten_hien_thi'] ?? row['ho_ten'] ?? '').toString();
        final dbAvatar =
            (row['anh_dai_dien'] ?? row['avatar_url'] ?? '').toString();
        final dbBio = (row['mo_ta'] ?? '').toString();
        final dbLevel = int.tryParse((row['cap_do'] ?? '1').toString()) ?? 1;
        final dbExp =
            int.tryParse((row['diem_kinh_nghiem'] ?? '0').toString()) ?? 0;
        final dbRankPoints =
            int.tryParse((row['diem_rank'] ?? '0').toString()) ?? 0;
        final dbRank = (row['hang'] ?? '').toString();

        setState(() {
          if (dbName.trim().isNotEmpty) _displayName = dbName.trim();
          if (dbAvatar.trim().isNotEmpty) _avatarUrl = dbAvatar.trim();
          if (dbBio.trim().isNotEmpty) _bio = dbBio.trim();
          _level = dbLevel;
          _levelProgress = ((dbExp % 100) / 100).clamp(0.05, 1.0);
          _rankPoints = dbRankPoints;
          _rankTitle = dbRank.trim().isNotEmpty
              ? dbRank.trim().toUpperCase()
              : RankService.getRankFromPoints(dbRankPoints);
        });
      }
    } catch (e) {
      debugPrint('LOAD PROFILE ERROR: $e');
      _showSnack(_formatErrorMessage(e), isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSnack(String msg, {bool isError = false}) {
    if (!mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();

    messenger.showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError
                  ? Icons.error_outline_rounded
                  : Icons.check_circle_outline_rounded,
              color: Colors.white,
              size: 22,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                msg,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        backgroundColor:
            isError ? const Color(0xFFD32F2F) : const Color(0xFF2E7D32),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        duration: Duration(seconds: isError ? 4 : 2),
        action: isError
            ? SnackBarAction(
                label: 'Đóng',
                textColor: Colors.white,
                onPressed: () => messenger.hideCurrentSnackBar(),
              )
            : null,
      ),
    );
  }

  String _formatErrorMessage(Object error) {
    final raw = error.toString().toLowerCase();
    if (raw.contains('42501') || raw.contains('permission denied')) {
      return 'Không có quyền cập nhật dữ liệu. Vui lòng kiểm tra quyền bảng trên Supabase.';
    }
    if (raw.contains('bucket') || raw.contains('storage')) {
      return 'Lỗi tải ảnh lên máy chủ. Vui lòng thử lại sau.';
    }
    if (raw.contains('network') ||
        raw.contains('socket') ||
        raw.contains('failed host lookup')) {
      return 'Mất kết nối mạng. Vui lòng kiểm tra Internet và thử lại.';
    }
    return 'Đã xảy ra lỗi khi cập nhật hồ sơ. Vui lòng thử lại.';
  }

  Future<void> _saveProfileToSupabase({
    String? newName,
    String? newAvatarUrl,
    String? newBio,
  }) async {
    final user = _firebaseUser;
    if (user == null) {
      _showSnack('Bạn chưa đăng nhập. Vui lòng đăng nhập lại.', isError: true);
      return;
    }

    final updatedName = (newName ?? _displayName).trim();
    final updatedAvatar = (newAvatarUrl ?? _avatarUrl).trim();
    final updatedBio = (newBio ?? _bio).trim();

    if (updatedName.isEmpty) {
      _showSnack('Tên hiển thị không được để trống.', isError: true);
      return;
    }

    setState(() => _isSaving = true);
    try {
      final payload = <String, dynamic>{
        'ten_hien_thi': updatedName,
        'anh_dai_dien': updatedAvatar,
        'mo_ta': updatedBio,
      };

      var updatedRows = [];

      // 1. Cập nhật theo email
      if (user.email != null && user.email!.isNotEmpty) {
        updatedRows = await _supabase
            .from('nguoi_dung')
            .update(payload)
            .ilike('email', user.email!)
            .select();
      }

      // 2. Fallback cập nhật theo cột id nếu chưa khớp
      if (updatedRows.isEmpty) {
        try {
          updatedRows = await _supabase
              .from('nguoi_dung')
              .update(payload)
              .eq('id', user.uid)
              .select();
        } catch (_) {}
      }

      if (updatedRows.isEmpty) {
        _showSnack(
          'Không tìm thấy hồ sơ người dùng trên hệ thống để cập nhật.',
          isError: true,
        );
        return;
      }

      await user.updateDisplayName(updatedName);
      if (updatedAvatar.isNotEmpty) {
        await user.updatePhotoURL(updatedAvatar);
      }
      await user.reload();

      if (!mounted) return;
      setState(() {
        _displayName = updatedName;
        _avatarUrl = updatedAvatar;
        _bio = updatedBio;
      });

      if (newAvatarUrl != null) {
        _showSnack('Cập nhật ảnh đại diện thành công!');
      } else if (newName != null) {
        _showSnack('Đổi tên hiển thị thành công!');
      } else if (newBio != null) {
        _showSnack('Đã lưu phần mô tả cá nhân!');
      } else {
        _showSnack('Cập nhật thông tin cá nhân thành công!');
      }
    } catch (e) {
      debugPrint('UPDATE PROFILE ERROR: $e');
      _showSnack(_formatErrorMessage(e), isError: true);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _pickAndUploadAvatar() async {
    final user = _firebaseUser;
    if (user == null || _isSaving) return;

    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 82,
      );
      if (pickedFile == null) return;

      setState(() => _isSaving = true);

      final Uint8List bytes = await pickedFile.readAsBytes();
      final ext = pickedFile.name.split('.').last.toLowerCase();
      final safeExt = ['jpg', 'jpeg', 'png', 'webp'].contains(ext) ? ext : 'png';
      final filePath =
          'avatars/${user.uid}_${DateTime.now().millisecondsSinceEpoch}.$safeExt';

      await _supabase.storage.from('avatars').uploadBinary(
            filePath,
            bytes,
            fileOptions: FileOptions(
              contentType: 'image/$safeExt',
              upsert: true,
            ),
          );

      final publicUrl = _supabase.storage.from('avatars').getPublicUrl(filePath);

      await _saveProfileToSupabase(newAvatarUrl: publicUrl);
    } catch (e) {
      debugPrint('UPLOAD AVATAR ERROR: $e');
      if (mounted) {
        setState(() => _isSaving = false);
        _showSnack(_formatErrorMessage(e), isError: true);
      }
    }
  }

  Future<void> _showEditNameDialog() async {
    final controller = TextEditingController(text: _displayName);

    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text(
          'Đổi tên hiển thị',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 30,
          decoration: InputDecoration(
            hintText: 'Nhập tên hiển thị mới',
            filled: true,
            fillColor: pageBg,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryPurple,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text('Lưu'),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty && result != _displayName) {
      await _saveProfileToSupabase(newName: result);
    }
  }

  Future<void> _showEditBioDialog() async {
    final controller = TextEditingController(text: _bio);

    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text(
          'Chỉnh sửa mô tả',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: 4,
          maxLength: 160,
          decoration: InputDecoration(
            hintText: 'Viết vài dòng giới thiệu về bạn...',
            filled: true,
            fillColor: pageBg,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryPurple,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text('Lưu'),
          ),
        ],
      ),
    );

    if (result != null && result != _bio) {
      await _saveProfileToSupabase(newBio: result);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: pageBg,
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: primaryPurple),
            )
          : Stack(
              children: [
                SingleChildScrollView(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 560),
                      child: Column(
                        children: [
                          _buildBannerAndAvatar(),
                          const SizedBox(height: 14),
                          _buildNameSection(),
                          const SizedBox(height: 16),
                          _buildLevelProgressBar(),
                          const SizedBox(height: 16),
                          _buildRankBadge(),
                          const SizedBox(height: 20),
                          _buildBioCard(),
                          const SizedBox(height: 32),
                        ],
                      ),
                    ),
                  ),
                ),
                if (_isSaving)
                  Container(
                    color: Colors.black.withValues(alpha: 0.2),
                    child: const Center(
                      child: CircularProgressIndicator(color: primaryPurple),
                    ),
                  ),
              ],
            ),
    );
  }

  Widget _buildBannerAndAvatar() {
    final topPadding = MediaQuery.of(context).padding.top;

    return SizedBox(
      height: topPadding + 165,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.topCenter,
        children: [
          Container(
            height: topPadding + 118,
            width: double.infinity,
            padding: EdgeInsets.fromLTRB(12, topPadding + 8, 16, 12),
            color: bannerBlue,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  onPressed: () => Navigator.pop(context, true),
                  icon: const Icon(
                    Icons.arrow_back_rounded,
                    color: darkText,
                    size: 26,
                  ),
                ),
                Align(
                  alignment: Alignment.bottomRight,
                  child: InkWell(
                    onTap: _pickAndUploadAvatar,
                    borderRadius: BorderRadius.circular(20),
                    child: const Padding(
                      padding: EdgeInsets.all(6),
                      child: Icon(
                        Icons.photo_camera_outlined,
                        color: darkText,
                        size: 22,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            bottom: 0,
            child: GestureDetector(
              onTap: _pickAndUploadAvatar,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 96,
                    height: 96,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFF7B88FF),
                      border: Border.all(color: Colors.white, width: 3.5),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ClipOval(
                      child: _avatarUrl.isNotEmpty
                          ? Image.network(
                              _avatarUrl,
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) => _buildDefaultAvatar(),
                            )
                          : _buildDefaultAvatar(),
                    ),
                  ),
                  Positioned(
                    right: -2,
                    bottom: 0,
                    child: Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        border: Border.all(color: const Color(0xFFE0E4F5)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.12),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.photo_camera_outlined,
                        size: 16,
                        color: darkText,
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

  Widget _buildDefaultAvatar() {
    return Container(
      color: const Color(0xFFFFD54F),
      alignment: Alignment.center,
      child: Text(
        _displayName.isNotEmpty ? _displayName[0].toUpperCase() : 'P',
        style: const TextStyle(
          fontSize: 38,
          fontWeight: FontWeight.w900,
          color: Color(0xFF282B78),
        ),
      ),
    );
  }

  Widget _buildNameSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Text(
              _displayName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: darkText,
              ),
            ),
          ),
          const SizedBox(width: 8),
          InkWell(
            onTap: _showEditNameDialog,
            borderRadius: BorderRadius.circular(8),
            child: const Padding(
              padding: EdgeInsets.all(4),
              child: Icon(
                Icons.edit_square,
                size: 20,
                color: darkText,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLevelProgressBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Row(
        children: [
          SizedBox(
            width: 42,
            height: 42,
            child: Stack(
              alignment: Alignment.center,
              children: [
                const Icon(
                  Icons.star_rounded,
                  color: Color(0xFFFFB74D),
                  size: 42,
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    '$_level',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      color: darkText,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: _levelProgress,
                minHeight: 8,
                backgroundColor: const Color(0xFFE3E6EE),
                valueColor: const AlwaysStoppedAnimation<Color>(progressBlue),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRankBadge() {
    final rankColor = RankService.getRankColor(_rankTitle);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 8),
      decoration: BoxDecoration(
        color: rankColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: rankColor.withValues(alpha: 0.35),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.shield_outlined,
            size: 17,
            color: darkText,
          ),
          const SizedBox(width: 6),
          Text(
            '$_rankTitle • $_rankPoints RP',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: darkText,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBioCard() {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 130),
      margin: const EdgeInsets.symmetric(horizontal: 24),
      padding: const EdgeInsets.fromLTRB(18, 16, 14, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            _bio.isNotEmpty ? _bio : 'Đây là những dòng mô tả về mình.',
            style: const TextStyle(
              fontSize: 14.5,
              color: darkText,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.bottomRight,
            child: InkWell(
              onTap: _showEditBioDialog,
              borderRadius: BorderRadius.circular(8),
              child: const Padding(
                padding: EdgeInsets.all(4),
                child: Icon(
                  Icons.edit_square,
                  size: 20,
                  color: darkText,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}