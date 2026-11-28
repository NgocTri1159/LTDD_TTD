import 'package:flutter/material.dart';
import '../../controllers/exam_controller.dart';
import '../../models/exam_model.dart';
import '../../core/theme.dart';
import '../quiz/quiz_detail_screen.dart';

class ExamListView extends StatefulWidget {
  const ExamListView({super.key});

  @override
  State<ExamListView> createState() => _ExamListViewState();
}

class _ExamListViewState extends State<ExamListView> {
  final ExamController _controller = ExamController();
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _controller.loadData(); // Tự động tải dữ liệu khi mở màn hình
  }

  @override
  void dispose() {
    _controller.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Danh sách Bộ đề'),
        centerTitle: true,
        actions: [
          // Nút làm mới dữ liệu từ Supabase
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _controller.loadData,
          ),
        ],
      ),
      body: SafeArea(
        child: ListenableBuilder(
          listenable: _controller,
          builder: (context, _) {
            final exams = _controller.filteredExams;

            return Column(
              children: [
                // 1. THANH TÌM KIẾM BỘ ĐỀ
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.base.withValues(alpha: 0.06),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: TextField(
                      controller: _searchController,
                      onChanged: _controller.setSearchQuery,
                      decoration: InputDecoration(
                        hintText: 'Tìm kiếm tên đề thi, môn học...',
                        prefixIcon: const Icon(
                          Icons.search_rounded,
                          color: AppColors.base,
                        ),
                        // Hiện nút X xóa nhanh khi có chữ trong ô tìm kiếm
                        suffixIcon: _controller.searchQuery.isNotEmpty
                            ? IconButton(
                                icon: const Icon(
                                  Icons.clear_rounded,
                                  color: Colors.grey,
                                ),
                                onPressed: () {
                                  _searchController.clear();
                                  _controller.setSearchQuery('');
                                },
                              )
                            : null,
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                ),

                // 2. THANH LỌC THEO MÔN HỌC (CUỘN NGANG)
                SizedBox(
                  height: 46,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    children: [
                      // Nút lọc "Tất cả"
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: const Text('Tất cả'),
                          selected: _controller.selectedSubjectId == null,
                          selectedColor: AppColors.base,
                          labelStyle: TextStyle(
                            color: _controller.selectedSubjectId == null
                                ? Colors.white
                                : AppColors.text,
                            fontWeight: FontWeight.w600,
                          ),
                          onSelected: (_) => _controller.selectSubject(null),
                        ),
                      ),
                      // Danh sách các nút lọc theo từng môn học từ Supabase
                      ..._controller.subjects.map((subject) {
                        final id = subject['id'].toString();
                        final isSelected = _controller.selectedSubjectId == id;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: Text((subject['ten_mon'] ?? '').toString()),
                            selected: isSelected,
                            selectedColor: AppColors.base,
                            labelStyle: TextStyle(
                              color: isSelected ? Colors.white : AppColors.text,
                              fontWeight: FontWeight.w600,
                            ),
                            onSelected: (_) => _controller.selectSubject(id),
                          ),
                        );
                      }),
                    ],
                  ),
                ),

                const SizedBox(height: 8),

                // 3. DANH SÁCH BỘ ĐỀ SAU KHI LỌC
                Expanded(child: _buildBody(exams)),
              ],
            );
          },
        ),
      ),
    );
  }

  // Hiển thị trạng thái Loading / Lỗi / Trống / Danh sách đề thi
  Widget _buildBody(List<ExamModel> exams) {
    if (_controller.isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.base),
      );
    }

    if (_controller.errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            _controller.errorMessage!,
            style: const TextStyle(color: Colors.redAccent),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    // Giao diện khi không tìm thấy bộ đề nào khớp điều kiện
    if (exams.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.search_off_rounded, size: 64, color: Colors.grey),
            const SizedBox(height: 12),
            Text(
              'Không tìm thấy bộ đề nào',
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
            ),
            if (_controller.searchQuery.isNotEmpty ||
                _controller.selectedSubjectId != null)
              TextButton(
                onPressed: () {
                  _searchController.clear();
                  _controller.clearFilters();
                },
                child: const Text(
                  'Xóa bộ lọc',
                  style: TextStyle(
                    color: AppColors.base,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
      );
    }

    // Danh sách thẻ bộ đề
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: exams.length,
      itemBuilder: (context, index) {
        final exam = exams[index];
        return GestureDetector(
          onTap: () {
            // Chuyển sang màn hình Chi tiết đề thi & Chọn chế độ chơi
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => QuizDetailScreen(exam: exam),
              ),
            );
          },
          child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: AppColors.base.withValues(alpha: 0.08),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                // Icon đại diện bộ đề
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppColors.base.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.assignment_rounded,
                    color: AppColors.base,
                  ),
                ),
                const SizedBox(width: 14),
                // Thông tin tên đề, môn học, thời gian và số câu
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        exam.tenDe,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: AppColors.text,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.base.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              exam.tenMon,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppColors.base,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Icon(
                            Icons.timer_outlined,
                            size: 14,
                            color: Colors.grey[600],
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${exam.thoiGianPhut} phút',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[700],
                            ),
                          ),
                          const SizedBox(width: 10),
                          Icon(
                            Icons.help_outline_rounded,
                            size: 14,
                            color: Colors.grey[600],
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${exam.soCauHoi} câu',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[700],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded, color: Colors.grey),
              ],
            ),
          ),
        );
      },
    );
  }
}