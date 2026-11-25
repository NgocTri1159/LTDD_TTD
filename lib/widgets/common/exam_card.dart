import 'package:material_ui/material_ui.dart';
import '../../models/exam_model.dart';
import '../../theme/app_theme.dart';
import 'app_card.dart';

/// Thẻ hiển thị Đề thi tái sử dụng trên toàn ứng dụng QuizMaster.
class ExamCard extends StatelessWidget {
  final ExamModel exam;
  final VoidCallback? onTap;

  const ExamCard({
    super.key,
    required this.exam,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    Color badgeColor;
    switch (exam.mucDo) {
      case 'de':
        badgeColor = AppTheme.success;
        break;
      case 'kho':
        badgeColor = AppTheme.error;
        break;
      case 'trung_binh':
      default:
        badgeColor = AppTheme.warning;
        break;
    }

    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Icon hoặc ảnh bìa
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: AppTheme.primaryContainer,
              borderRadius: AppTheme.borderRadiusMedium,
              image: exam.anhBiaUrl != null && exam.anhBiaUrl!.isNotEmpty
                  ? DecorationImage(
                      image: NetworkImage(exam.anhBiaUrl!),
                      fit: BoxFit.cover,
                    )
                  : null,
            ),
            child: exam.anhBiaUrl == null || exam.anhBiaUrl!.isEmpty
                ? const Icon(
                    Icons.assignment_outlined,
                    color: AppTheme.primary,
                    size: 30,
                  )
                : null,
          ),
          const SizedBox(width: 14),

          // Nội dung đề thi
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    if (exam.tenMonHoc != null) ...[
                      Text(
                        exam.tenMonHoc!,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primary,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        width: 3,
                        height: 3,
                        decoration: const BoxDecoration(
                          color: AppTheme.textMuted,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: badgeColor.withAlpha(25),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        exam.mucDoDisplay,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: badgeColor,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  exam.tieuDe,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(
                      Icons.schedule_rounded,
                      size: 14,
                      color: AppTheme.textMuted,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${exam.thoiGianPhut} phút',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppTheme.textMuted,
                      ),
                    ),
                    if (exam.soLuongCauHoi != null && exam.soLuongCauHoi! > 0) ...[
                      const SizedBox(width: 14),
                      const Icon(
                        Icons.help_outline_rounded,
                        size: 14,
                        color: AppTheme.textMuted,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${exam.soLuongCauHoi} câu',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppTheme.textMuted,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),

          // Mũi tên điều hướng
          const Icon(
            Icons.arrow_forward_ios_rounded,
            size: 16,
            color: AppTheme.primary,
          ),
        ],
      ),
    );
  }
}
