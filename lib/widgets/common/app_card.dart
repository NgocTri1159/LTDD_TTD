import 'package:material_ui/material_ui.dart';
import '../../theme/app_theme.dart';

/// Card tùy biến chuẩn cho QuizMaster.
/// Tích hợp bo góc mềm mại, đường viền thanh mảnh, đổ bóng nhẹ và hiệu ứng chạm.
class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final VoidCallback? onTap;
  final Color? backgroundColor;
  final Color? borderColor;
  final BorderRadius? borderRadius;
  final Gradient? gradient;
  final List<BoxShadow>? boxShadow;
  final double? width;
  final double? height;

  const AppCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.onTap,
    this.backgroundColor,
    this.borderColor,
    this.borderRadius,
    this.gradient,
    this.boxShadow,
    this.width,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveRadius = borderRadius ?? AppTheme.borderRadiusMedium;
    final effectiveBg = backgroundColor ?? AppTheme.surface;
    final effectiveBorder = borderColor ?? AppTheme.cardBorder;
    final effectiveShadow = boxShadow ?? AppTheme.cardShadow;

    final content = Container(
      width: width,
      height: height,
      padding: padding ?? const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: gradient == null ? effectiveBg : null,
        gradient: gradient,
        borderRadius: effectiveRadius,
        border: Border.all(color: effectiveBorder, width: 1),
        boxShadow: effectiveShadow,
      ),
      child: child,
    );

    if (onTap == null) {
      if (margin != null) {
        return Padding(padding: margin!, child: content);
      }
      return content;
    }

    final inkContent = Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: effectiveRadius,
        splashColor: AppTheme.primary.withAlpha(20),
        highlightColor: AppTheme.primary.withAlpha(10),
        child: content,
      ),
    );

    if (margin != null) {
      return Padding(padding: margin!, child: inkContent);
    }
    return inkContent;
  }
}
