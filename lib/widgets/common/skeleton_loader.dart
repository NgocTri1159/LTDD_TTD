import 'package:material_ui/material_ui.dart';
import '../../theme/app_theme.dart';

/// Hiệu ứng Shimmer Skeleton Loader chuẩn cho QuizMaster.
/// Sử dụng Flutter animation thuần, không cần package bên ngoài.
class SkeletonLoader extends StatefulWidget {
  final double width;
  final double height;
  final BorderRadius? borderRadius;
  final BoxShape shape;

  const SkeletonLoader({
    super.key,
    required this.width,
    required this.height,
    this.borderRadius,
    this.shape = BoxShape.rectangle,
  });

  const SkeletonLoader.circle({
    super.key,
    required double size,
  })  : width = size,
        height = size,
        borderRadius = null,
        shape = BoxShape.circle;

  const SkeletonLoader.card({
    super.key,
    this.width = double.infinity,
    this.height = 120,
    this.borderRadius,
  }) : shape = BoxShape.rectangle;

  @override
  State<SkeletonLoader> createState() => _SkeletonLoaderState();
}

class _SkeletonLoaderState extends State<SkeletonLoader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            shape: widget.shape,
            borderRadius: widget.shape == BoxShape.circle
                ? null
                : (widget.borderRadius ?? AppTheme.borderRadiusMedium),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              stops: [
                _controller.value - 0.3,
                _controller.value,
                _controller.value + 0.3,
              ],
              colors: const [
                Color(0xFFE9EAF5),
                Color(0xFFF7F8FE),
                Color(0xFFE9EAF5),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Mẫu Skeleton danh sách bài thi đang tải
class ExamCardSkeleton extends StatelessWidget {
  const ExamCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: AppTheme.borderRadiusMedium,
        border: Border.all(color: AppTheme.cardBorder),
      ),
      child: const Row(
        children: [
          SkeletonLoader(width: 54, height: 54),
          SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SkeletonLoader(width: 160, height: 16),
                SizedBox(height: 8),
                SkeletonLoader(width: 110, height: 12),
                SizedBox(height: 8),
                Row(
                  children: [
                    SkeletonLoader(width: 60, height: 10),
                    SizedBox(width: 10),
                    SkeletonLoader(width: 60, height: 10),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
