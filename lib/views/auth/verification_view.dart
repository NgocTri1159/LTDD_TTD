import 'package:material_ui/material_ui.dart';
import '../../controllers/auth_controller.dart';

/// View dùng để xác minh email sau khi đăng ký tài khoản.
class VerificationView extends StatefulWidget {
  const VerificationView({super.key});

  @override
  State<VerificationView> createState() => _VerificationViewState();
}

class _VerificationViewState extends State<VerificationView> {
  final AuthController _authController = AuthController();

  static const Color primaryPurple = Color(0xFF565CEB);
  static const Color cardLavender = Color(0xFFECEEFF);
  static const Color accentOrange = Color(0xFFF79E1B);
  static const Color darkText = Color(0xFF1E1E2C);

  @override
  void dispose() {
    _authController.dispose();
    super.dispose();
  }

  Future<void> _checkVerification() async {
    final result = await _authController.checkEmailVerification();
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(result.message),
        backgroundColor: result.isSuccess ? Colors.green : null,
      ),
    );
  }

  Future<void> _resendVerificationEmail() async {
    final result = await _authController.resendVerificationEmail();
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(result.message),
        backgroundColor: result.isSuccess ? Colors.green : null,
      ),
    );
  }

  Future<void> _logout() async {
    final result = await _authController.logout();
    if (!mounted || result.isSuccess) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(result.message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFF),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 430),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Thanh điều hướng trên cùng đồng bộ Figma
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        icon: const Icon(
                          Icons.arrow_back_rounded,
                          color: darkText,
                        ),
                        tooltip: 'Quay lại đăng nhập',
                        onPressed: _logout,
                      ),
                      TextButton.icon(
                        onPressed: _logout,
                        icon: const Icon(
                          Icons.logout_rounded,
                          size: 18,
                          color: Color(0xFFE53935),
                        ),
                        label: const Text(
                          'Đăng xuất',
                          style: TextStyle(
                            color: Color(0xFFE53935),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 8),

                  // Icon xác minh đồng bộ cụm thương hiệu
                  Center(
                    child: Container(
                      width: 88,
                      height: 88,
                      decoration: BoxDecoration(
                        color: cardLavender,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: primaryPurple.withValues(alpha: 0.14),
                            blurRadius: 16,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          const Icon(
                            Icons.mark_email_unread_rounded,
                            size: 42,
                            color: primaryPurple,
                          ),
                          Positioned(
                            right: 14,
                            bottom: 14,
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(
                                color: accentOrange,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.priority_high_rounded,
                                size: 13,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  const Text(
                    'Xác Minh Tài Khoản',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: darkText,
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Thẻ thông tin email màu tím nhạt
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: cardLavender,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: const Color(0xFFE3E6FA)),
                    ),
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.mail_outline_rounded,
                                size: 18,
                                color: primaryPurple,
                              ),
                              const SizedBox(width: 8),
                              Flexible(
                                child: Text(
                                  _authController.currentUserEmail,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: darkText,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                        const Text(
                          'Vui lòng kiểm tra hộp thư email và nhấn vào liên kết xác minh đã được gửi. Sau đó nhấn nút bên dưới để tiếp tục.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14,
                            height: 1.5,
                            color: Color(0xFF4E526B),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 26),

                  // Nút xác nhận chính màu xanh tím
                  AnimatedBuilder(
                    animation: _authController,
                    builder: (context, _) => SizedBox(
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _authController.isCheckingVerification
                            ? null
                            : _checkVerification,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryPurple,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: _authController.isCheckingVerification
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2.5,
                                ),
                              )
                            : const Text(
                                'Tôi đã xác minh email',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Nút gửi lại email dạng viền trắng
                  AnimatedBuilder(
                    animation: _authController,
                    builder: (context, _) => SizedBox(
                      height: 48,
                      child: OutlinedButton(
                        onPressed: _authController.isResendingVerification
                            ? null
                            : _resendVerificationEmail,
                        style: OutlinedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: primaryPurple,
                          side: const BorderSide(color: Color(0xFFD5DAFA)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: _authController.isResendingVerification
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  color: primaryPurple,
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text(
                                'Gửi lại email xác minh',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}