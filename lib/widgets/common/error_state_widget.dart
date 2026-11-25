import 'package:material_ui/material_ui.dart';
import '../../theme/app_theme.dart';
import 'app_button.dart';

/// Widget hiển thị trạng thái lỗi kèm nút thử lại.
class ErrorStateWidget extends StatelessWidget {
  final String errorMessage;
  final VoidCallback? onRetry;
  final String title;
  final IconData icon;

  const ErrorStateWidget({
    super.key,
    required this.errorMessage,
    this.onRetry,
    this.title = 'Đã có lỗi xảy ra',
    this.icon = Icons.error_outline_rounded,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 36),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(
                color: AppTheme.errorContainer,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 38, color: AppTheme.error),
            ),
            const SizedBox(height: 18),
            Text(
              title,
              textAlign: TextAlign.center,
              style: AppTheme.titleLarge.copyWith(fontSize: 18),
            ),
            const SizedBox(height: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 380),
              child: Text(
                errorMessage,
                textAlign: TextAlign.center,
                style: AppTheme.bodyMedium.copyWith(color: AppTheme.textSecondary),
              ),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 22),
              AppButton(
                text: 'Thử lại',
                icon: Icons.refresh_rounded,
                onPressed: onRetry,
                type: AppButtonType.primary,
                height: 42,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
