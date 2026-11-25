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
      appBar: AppBar(
        title: const Text(
          'QuizMaster',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Đăng xuất',
            onPressed: _logout,
          ),
        ],
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.mark_email_unread_rounded,
                  size: 85,
                  color: Color(0xFF6257E8),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Xác minh tài khoản',
                  style: TextStyle(fontSize: 25, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                Text(
                  'Tài khoản: ${_authController.currentUserEmail}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Vui lòng kiểm tra hộp thư email và nhấn vào '
                  'liên kết xác minh mà Firebase đã gửi. '
                  'Sau đó quay lại ứng dụng để tiếp tục.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 15, height: 1.5),
                ),
                const SizedBox(height: 30),

                // Nút kiểm tra xác minh
                SizedBox(
                  width: double.infinity,
                  child: AnimatedBuilder(
                    animation: _authController,
                    builder: (context, _) => ElevatedButton(
                      onPressed: _authController.isCheckingVerification
                          ? null
                          : _checkVerification,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF6257E8),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _authController.isCheckingVerification
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Text(
                              'Tôi đã xác minh email',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Nút gửi lại email
                AnimatedBuilder(
                  animation: _authController,
                  builder: (context, _) => TextButton(
                    onPressed: _authController.isResendingVerification
                        ? null
                        : _resendVerificationEmail,
                    child: _authController.isResendingVerification
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Gửi lại email xác minh'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
