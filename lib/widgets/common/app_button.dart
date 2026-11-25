import 'package:material_ui/material_ui.dart';
import '../../theme/app_theme.dart';

enum AppButtonType {
  primary,
  secondary,
  outline,
  text,
  danger,
}

/// Nút bấm chuẩn hóa cho QuizMaster.
/// Tự động xử lý trạng thái Loading, Disabled, Icon, kích thước thích ứng.
class AppButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final AppButtonType type;
  final IconData? icon;
  final bool isLoading;
  final bool fullWidth;
  final double? height;
  final double? width;
  final BorderRadius? borderRadius;
  final EdgeInsetsGeometry? padding;

  const AppButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.type = AppButtonType.primary,
    this.icon,
    this.isLoading = false,
    this.fullWidth = false,
    this.height = 50,
    this.width,
    this.borderRadius,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveRadius = borderRadius ?? AppTheme.borderRadiusMedium;
    final isEnabled = onPressed != null && !isLoading;

    Color bg;
    Color fg;
    BorderSide? border;

    switch (type) {
      case AppButtonType.primary:
        bg = isEnabled ? AppTheme.primary : AppTheme.primary.withAlpha(120);
        fg = Colors.white;
        border = BorderSide.none;
        break;
      case AppButtonType.secondary:
        bg = isEnabled ? AppTheme.primaryContainer : AppTheme.background;
        fg = AppTheme.primary;
        border = BorderSide.none;
        break;
      case AppButtonType.outline:
        bg = Colors.transparent;
        fg = isEnabled ? AppTheme.primary : AppTheme.textMuted;
        border = BorderSide(
          color: isEnabled ? AppTheme.primary : AppTheme.cardBorder,
          width: 1.5,
        );
        break;
      case AppButtonType.text:
        bg = Colors.transparent;
        fg = isEnabled ? AppTheme.primary : AppTheme.textMuted;
        border = BorderSide.none;
        break;
      case AppButtonType.danger:
        bg = isEnabled ? AppTheme.error : AppTheme.error.withAlpha(120);
        fg = Colors.white;
        border = BorderSide.none;
        break;
    }

    Widget content;
    if (isLoading) {
      content = SizedBox(
        height: 20,
        width: 20,
        child: CircularProgressIndicator(
          strokeWidth: 2.2,
          valueColor: AlwaysStoppedAnimation<Color>(fg),
        ),
      );
    } else {
      final textWidget = Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: fg,
          fontSize: 14,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.2,
        ),
      );

      if (icon != null) {
        content = Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: fg),
            const SizedBox(width: 8),
            Flexible(child: textWidget),
          ],
        );
      } else {
        content = textWidget;
      }
    }

    return SizedBox(
      width: fullWidth ? double.infinity : width,
      height: height,
      child: Material(
        color: bg,
        shape: RoundedRectangleBorder(
          borderRadius: effectiveRadius,
          side: border,
        ),
        child: InkWell(
          onTap: isEnabled ? onPressed : null,
          borderRadius: effectiveRadius,
          splashColor: fg.withAlpha(30),
          highlightColor: fg.withAlpha(15),
          child: Padding(
            padding: padding ?? const EdgeInsets.symmetric(horizontal: 16),
            child: Center(child: content),
          ),
        ),
      ),
    );
  }
}
