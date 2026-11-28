import 'package:flutter/material.dart';
import '../../core/theme.dart'; // Import bộ màu & font chuẩn của nhóm
import '../../models/category_model.dart';
import '../../controllers/category_controller.dart';

class AdminCategoryScreen extends StatelessWidget {
  AdminCategoryScreen({super.key});

  final CategoryController _controller = CategoryController();

  // Danh sách các icon có sẵn để chọn
  static const Map<String, IconData> _availableIcons = {
    'code': Icons.code,               // Lập trình
    'science': Icons.science,         // Khoa học
    'language': Icons.language,       // Tiếng Anh
    'calculate': Icons.calculate,     // Toán học
    'history': Icons.history_edu,     // Lịch sử / Xã hội
    'default_icon': Icons.book,       // Mặc định
  };

  // Chuyển đổi chuỗi lưu trên Firebase thành IconData
  IconData _getIconData(String iconName) {
    return _availableIcons[iconName] ?? Icons.book;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Tự động nhận nền #F5F7FF từ AppTheme.lightTheme
      appBar: AppBar(
        title: const Text('Quản lý Môn học'),
        centerTitle: true,
      ),
      body: StreamBuilder<List<CategoryModel>>(
        stream: _controller.getCategories(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.base),
            );
          }
          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Lỗi tải dữ liệu: ${snapshot.error}',
                style: AppTextStyles.text.copyWith(color: Colors.redAccent),
              ),
            );
          }

          final categories = snapshot.data ?? [];
          if (categories.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.folder_open_rounded, size: 64, color: AppColors.base.withOpacity(0.4)),
                  const SizedBox(height: 12),
                  Text(
                    'Chưa có môn học nào.\nBấm dấu + để thêm mới.',
                    textAlign: TextAlign.center,
                    style: AppTextStyles.text.copyWith(color: Colors.grey[600]),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 88), // Chừa khoảng trống dưới cho nút +
            itemCount: categories.length,
            itemBuilder: (context, index) {
              final cat = categories[index];
              return Card(
                color: Colors.white,
                elevation: 1.5,
                shadowColor: AppColors.base.withOpacity(0.1),
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  leading: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: AppColors.base.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      _getIconData(cat.iconUrl),
                      color: AppColors.base,
                      size: 26,
                    ),
                  ),
                  title: Text(
                    cat.name,
                    style: AppTextStyles.answer.copyWith(fontWeight: FontWeight.w600),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit_rounded, color: AppColors.base),
                        onPressed: () => _showFormDialog(context, category: cat),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
                        onPressed: () => _showDeleteConfirm(context, cat),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
      // Tự động nhận màu cam điểm nhấn #FFB84D từ AppTheme
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showFormDialog(context),
        child: const Icon(Icons.add, size: 28),
      ),
    );
  }

  // Popup Thêm / Sửa có kèm chọn Icon
  void _showFormDialog(BuildContext context, {CategoryModel? category}) {
    final isEdit = category != null;
    final nameController = TextEditingController(text: isEdit ? category.name : '');

    String selectedIcon = (isEdit && _availableIcons.containsKey(category.iconUrl))
        ? category.iconUrl
        : 'default_icon';

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Text(
              isEdit ? 'Sửa môn học' : 'Thêm môn học',
              style: AppTextStyles.question,
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: nameController,
                  style: AppTextStyles.text,
                  decoration: InputDecoration(
                    labelText: 'Tên môn học',
                    labelStyle: AppTextStyles.text.copyWith(color: Colors.grey[600]),
                    filled: true,
                    fillColor: AppColors.background,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.base, width: 2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text('Chọn biểu tượng:', style: AppTextStyles.answer),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: _availableIcons.entries.map((entry) {
                    final isSelected = selectedIcon == entry.key;
                    return InkWell(
                      onTap: () {
                        setState(() {
                          selectedIcon = entry.key;
                        });
                      },
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isSelected ? AppColors.base : AppColors.background,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: isSelected ? AppColors.base : Colors.grey.shade300,
                            width: 1.5,
                          ),
                        ),
                        child: Icon(
                          entry.value,
                          color: isSelected ? Colors.white : AppColors.text,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: Text('Hủy', style: AppTextStyles.text.copyWith(color: Colors.grey[600])),
              ),
              ElevatedButton(
                onPressed: () async {
                  if (nameController.text.trim().isEmpty) return;

                  if (isEdit) {
                    await _controller.updateCategory(category.id, nameController.text, selectedIcon);
                  } else {
                    await _controller.addCategory(nameController.text, selectedIcon);
                  }

                  if (dialogContext.mounted) {
                    Navigator.pop(dialogContext);
                  }
                },
                child: const Text('Lưu'),
              ),
            ],
          );
        },
      ),
    );
  }

  // Popup Xóa an toàn
  void _showDeleteConfirm(BuildContext context, CategoryModel category) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Xác nhận xóa', style: AppTextStyles.question),
        content: Text(
          'Bạn có chắc muốn xóa môn "${category.name}" không?',
          style: AppTextStyles.text,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text('Hủy', style: AppTextStyles.text.copyWith(color: Colors.grey[600])),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () async {
              try {
                await _controller.deleteCategory(category.id);

                if (!dialogContext.mounted) return;
                Navigator.pop(dialogContext);
              } catch (e) {
                if (!dialogContext.mounted) return;
                Navigator.pop(dialogContext);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(e.toString(), style: AppTextStyles.text.copyWith(color: Colors.white)),
                      backgroundColor: Colors.redAccent,
                    ),
                  );
                }
              }
            },
            child: const Text('Xóa'),
          ),
        ],
      ),
    );
  }
}