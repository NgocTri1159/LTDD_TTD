import 'package:material_ui/material_ui.dart';
import '../../theme/app_theme.dart';

/// Loading indicator đồng bộ cho QuizMaster.
class LoadingWidget extends StatelessWidget {
  final String? message;
  final double size;
  final Color? color;
  final bool isFullScreen;

  const LoadingWidget({
    super.key,
    this.message,
    this.size = 36,
    this.color,
    this.isFullScreen = false,
  });

  @override
  Widget build(BuildContext context) {
    final content = Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: size,
            height: size,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              valueColor: AlwaysStoppedAnimation<Color>(
                color ?? AppTheme.primary,
              ),
            ),
          ),
          if (message != null) ...[
            const SizedBox(height: 14),
            Text(
              message!,
              textAlign: TextAlign.center,
              style: AppTheme.bodyMedium.copyWith(
                color: AppTheme.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ],
      ),
    );

    if (isFullScreen) {
      return Scaffold(
        backgroundColor: AppTheme.background,
        body: content,
      );
    }

    return content;
  }
}
