// lib/screens/subject/subject_detail_screen.dart
import 'package:material_ui/material_ui.dart';
import '../../models/subject_model.dart';
import '../../services/subject_service.dart';
import '../../services/role_service.dart';
import '../../theme/app_theme.dart';

/// Màn hình chi tiết môn học.
/// - User: chỉ xem thông tin.
/// - Admin / Super Admin: có thể khóa hoặc mở môn học.
class SubjectDetailScreen extends StatefulWidget {
  final String subjectId;

  const SubjectDetailScreen({super.key, required this.subjectId});

  @override
  State<SubjectDetailScreen> createState() => _SubjectDetailScreenState();
}

class _SubjectDetailScreenState extends State<SubjectDetailScreen> {
  late Future<SubjectModel> _subjectFuture;
  late Future<String> _roleFuture;

  @override
  void initState() {
    super.initState();
    _subjectFuture = SubjectService.getSubjectById(widget.subjectId);
    _roleFuture = RoleService.getCurrentRole();
  }

  // Refresh dữ liệu sau khi thay đổi trạng thái
  void _reload() {
    setState(() {
      _subjectFuture = SubjectService.getSubjectById(widget.subjectId);
    });
  }

  Future<void> _toggleStatus(SubjectModel subject) async {
    final newStatus = !subject.trangThai;
    try {
      await SubjectService.updateSubjectStatus(subject.id, newStatus);
      if (!mounted) return;
      _reload();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(newStatus ? 'Môn học đã mở' : 'Môn học đã khóa')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi cập nhật trạng thái: $e')),
      );
    }
  }

  Color _parseColor(String? hex) {
    if (hex == null || hex.trim().isEmpty) return AppTheme.primary;
    var clean = hex.trim().replaceAll('#', '');
    if (clean.length == 6) clean = 'FF$clean';
    try {
      return Color(int.parse(clean, radix: 16));
    } catch (_) {
      return AppTheme.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chi tiết môn học'),
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
      ),
      body: FutureBuilder<SubjectModel>(
        future: _subjectFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Lỗi tải dữ liệu: ${snapshot.error}'),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: () => setState(() => _subjectFuture = SubjectService.getSubjectById(widget.subjectId)),
                    child: const Text('Thử lại'),
                  ),
                ],
              ),
            );
          }
          final subject = snapshot.data!;
          return FutureBuilder<String>(
            future: _roleFuture,
            builder: (context, roleSnap) {
              final role = roleSnap.data;
              final isAdmin = role == 'admin' || role == 'super_admin';
              return Padding(
                padding: const EdgeInsets.all(24),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Icon / màu
                      Center(
                        child: Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            color: _parseColor(subject.mauSac).withAlpha(30),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Icon(
                            subject.bieuTuong != null && subject.bieuTuong!.trim().isNotEmpty
                                ? Icons.book
                                : Icons.book,
                            color: _parseColor(subject.mauSac),
                            size: 48,
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        subject.tenMon,
                        style: AppTheme.titleLarge,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        subject.moTa?.isNotEmpty == true ? subject.moTa! : 'Chưa có mô tả.',
                        style: AppTheme.bodyMedium,
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          const Icon(Icons.sort_rounded, size: 20),
                          const SizedBox(width: 8),
                          Text('Thứ tự hiển thị: ${subject.thuTuHienThi}'),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Icon(
                            subject.trangThai ? Icons.check_circle_outline : Icons.block_outlined,
                            color: subject.trangThai ? Colors.green : AppTheme.error,
                          ),
                          const SizedBox(width: 8),
                          Text(subject.trangThai ? 'Đang hoạt động' : 'Đã khóa'),
                        ],
                      ),
                      const SizedBox(height: 24),
                      if (isAdmin)
                        ElevatedButton(
                          onPressed: () => _toggleStatus(subject),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: subject.trangThai ? Colors.red : Colors.green,
                          ),
                          child: Text(subject.trangThai ? 'Khóa môn học' : 'Mở môn học'),
                        ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
