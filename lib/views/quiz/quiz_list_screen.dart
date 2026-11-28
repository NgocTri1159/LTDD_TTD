import 'package:flutter/material.dart';
import '../../core/theme.dart';
import '../../controllers/quiz_controller.dart';
import '../../models/quiz_model.dart';
import 'quiz_detail_screen.dart';

class QuizListScreen extends StatefulWidget {
  const QuizListScreen({super.key});

  @override
  State<QuizListScreen> createState() => _QuizListScreenState();
}

class _QuizListScreenState extends State<QuizListScreen> {
  final QuizController _quizController = QuizController();
  final TextEditingController _searchController = TextEditingController();

  String _searchQuery = '';
  String _selectedDifficulty = 'All';
  String _selectedCategory = 'All';

  final List<String> _difficulties = ['All', 'Dễ', 'Trung bình', 'Khó'];
  final List<String> _categories = ['All', 'Toán', 'Lập trình', 'Anh văn'];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Color _getDifficultyColor(String difficulty) {
    switch (difficulty) {
      case 'Dễ':
        return Colors.green;
      case 'Trung bình':
        return Colors.orange;
      case 'Khó':
        return Colors.redAccent;
      default:
        return AppColors.base;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tìm kiếm & Lọc Đề Thi'),
        centerTitle: true,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. THANH TÌM KIẾM
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.base.withOpacity(0.08),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: TextField(
                controller: _searchController,
                style: AppTextStyles.text,
                decoration: InputDecoration(
                  hintText: 'Nhập tên đề thi cần tìm...',
                  hintStyle: AppTextStyles.text.copyWith(color: Colors.grey[500]),
                  prefixIcon: const Icon(Icons.search_rounded, color: AppColors.base),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.close_rounded, color: Colors.grey),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _searchQuery = '');
                          },
                        )
                      : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 14),
                ),
                onChanged: (value) {
                  setState(() => _searchQuery = value);
                },
              ),
            ),
          ),

          // 2. BỘ LỌC ĐỘ KHÓ
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Text(
                  'Độ khó:',
                  style: AppTextStyles.answer.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(width: 10),
                ..._difficulties.map((diff) {
                  final isSelected = _selectedDifficulty == diff;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(diff),
                      selected: isSelected,
                      showCheckmark: false,
                      labelStyle: AppTextStyles.text.copyWith(
                        fontSize: 14,
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                        color: isSelected ? Colors.white : AppColors.text,
                      ),
                      selectedColor: AppColors.base,
                      backgroundColor: Colors.white,
                      side: BorderSide(
                        color: isSelected ? AppColors.base : Colors.grey.shade300,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      onSelected: (_) {
                        setState(() => _selectedDifficulty = diff);
                      },
                    ),
                  );
                }),
              ],
            ),
          ),

          const SizedBox(height: 8),

          // 3. BỘ LỌC MÔN HỌC
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Text(
                  'Môn học:',
                  style: AppTextStyles.answer.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(width: 10),
                ..._categories.map((cat) {
                  final isSelected = _selectedCategory == cat;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(cat),
                      selected: isSelected,
                      showCheckmark: false,
                      labelStyle: AppTextStyles.text.copyWith(
                        fontSize: 14,
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                        color: isSelected ? AppColors.text : Colors.grey[700],
                      ),
                      selectedColor: AppColors.interact,
                      backgroundColor: Colors.white,
                      side: BorderSide(
                        color: isSelected ? AppColors.interact : Colors.grey.shade300,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      onSelected: (_) {
                        setState(() => _selectedCategory = cat);
                      },
                    ),
                  );
                }),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // 4. DANH SÁCH ĐỀ THI
          Expanded(
            child: StreamBuilder<List<QuizModel>>(
              stream: _quizController.getFilteredQuizzes(
                searchQuery: _searchQuery,
                categoryId: _selectedCategory == 'All' ? null : _selectedCategory,
                difficulty: _selectedDifficulty == 'All' ? null : _selectedDifficulty,
              ),
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
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.search_off_rounded,
                          size: 64,
                          color: AppColors.base.withOpacity(0.4),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Không tìm thấy bộ đề nào phù hợp.',
                          style: AppTextStyles.text.copyWith(color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  );
                }

                final quizzes = snapshot.data!;
                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
                  itemCount: quizzes.length,
                  itemBuilder: (context, index) {
                    final quiz = quizzes[index];
                    final diffColor = _getDifficultyColor(quiz.difficulty);

                    return Card(
                      color: Colors.white,
                      elevation: 1.5,
                      shadowColor: AppColors.base.withOpacity(0.1),
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => QuizDetailScreen(quiz: quiz),
                            ),
                          );
                        },
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Row(
                            children: [
                              Container(
                                width: 50,
                                height: 50,
                                decoration: BoxDecoration(
                                  color: AppColors.base.withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: const Icon(
                                  Icons.quiz_rounded,
                                  color: AppColors.base,
                                  size: 26,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      quiz.title,
                                      style: AppTextStyles.answer.copyWith(
                                        fontWeight: FontWeight.w600,
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 8),
                                    Wrap(
                                      spacing: 8,
                                      runSpacing: 6,
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: AppColors.background,
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Text(
                                            quiz.categoryId,
                                            style: AppTextStyles.text.copyWith(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w500,
                                              color: AppColors.base,
                                            ),
                                          ),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: diffColor.withOpacity(0.12),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Text(
                                            quiz.difficulty,
                                            style: AppTextStyles.text.copyWith(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                              color: diffColor,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Icon(
                                Icons.arrow_forward_ios_rounded,
                                size: 16,
                                color: AppColors.base.withOpacity(0.6),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}