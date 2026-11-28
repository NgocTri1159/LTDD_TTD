import 'dart:async';
import 'dart:core';
import 'dart:core' as core;
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import '../../services/auth_service.dart';
import '../../services/backend_service.dart';
import '../../services/role_service.dart';

class ChangePasswordScreen extends StatefulWidget {
  final int initialStep;
  final String? initialEmail;
  final bool isForgotPasswordMode;

  const ChangePasswordScreen({
    super.key,
    this.initialStep = 0,
    this.initialEmail,
    this.isForgotPasswordMode = false,
  });

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  static const Color primaryPurple = Color(0xFF565CEB);
  static const Color cardLavender = Color(0xFFECEEFF);
  static const Color accentOrange = Color(0xFFF79E1B);
  static const Color pageBg = Color(0xFFF9FAFF);
  static const Color darkNavy = Color(0xFF1E1E2C);

  final AuthService _authService = AuthService();

  // 0: Đổi mật khẩu (nhập mật khẩu cũ)
  // 1: Đặt lại mật khẩu - Bước 1 (nhập Email + 4 ô mã OTP)
  // 2: Đặt lại mật khẩu - Bước 2 (nhập mật khẩu mới + xác nhận)
  late int _stepIndex;

  // Controllers Cách 1
  late final TextEditingController _emailController;
  final TextEditingController _oldPassController = TextEditingController();
  final TextEditingController _newPassController = TextEditingController();
  final TextEditingController _confirmPassController = TextEditingController();

  // Controllers Cách 2
  late final TextEditingController _otpEmailController;
  final core.List<TextEditingController> _otpControllers =
      core.List.generate(4, (_) => TextEditingController());
  final core.List<FocusNode> _otpFocusNodes =
      core.List.generate(4, (_) => FocusNode());
  final TextEditingController _resetNewPassController = TextEditingController();
  final TextEditingController _resetConfirmPassController =
      TextEditingController();

  bool _isLoading = false;
  bool _obscureOld = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;
  bool _obscureResetNew = true;
  bool _obscureResetConfirm = true;

  int _resendSeconds = 0;
  Timer? _resendTimer;
  String? _verifiedOtpCode;

  bool get _hasLoggedInEmail =>
      (_authService.currentUser?.email ?? '').trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    _stepIndex = widget.initialStep;

    final defaultEmail = (widget.initialEmail != null &&
            widget.initialEmail!.trim().isNotEmpty)
        ? widget.initialEmail!.trim()
        : (_authService.currentUser?.email ?? '');

    _emailController = TextEditingController(text: defaultEmail);
    _otpEmailController = TextEditingController(text: defaultEmail);

    _blockIfAdmin();
  }

  Future<void> _blockIfAdmin() async {
    if (_authService.currentUser == null) return;
    try {
      final role = await RoleService.getCurrentRole();
      if ((role == 'admin' || role == 'super_admin') && mounted) {
        _showMessage(
          'Tài khoản Quản trị viên không được phép đổi mật khẩu.',
        );
        Navigator.pop(context);
      }
    } catch (_) {}
  }

  Future<bool> _isCurrentAccountAdmin() async {
    if (_authService.currentUser == null) return false;
    try {
      final role = await RoleService.getCurrentRole();
      return role == 'admin' || role == 'super_admin';
    } catch (_) {
      return false;
    }
  }

  @override
  void dispose() {
    _resendTimer?.cancel();
    _emailController.dispose();
    _oldPassController.dispose();
    _newPassController.dispose();
    _confirmPassController.dispose();
    _otpEmailController.dispose();
    for (final c in _otpControllers) {
      c.dispose();
    }
    for (final f in _otpFocusNodes) {
      f.dispose();
    }
    _resetNewPassController.dispose();
    _resetConfirmPassController.dispose();
    super.dispose();
  }

  void _showMessage(String message, {bool isError = true}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor:
            isError ? const Color(0xFFE53935) : const Color(0xFF2E7D32),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  void _startResendCountdown() {
    _resendTimer?.cancel();
    setState(() => _resendSeconds = 60);
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_resendSeconds <= 1) {
        timer.cancel();
        setState(() => _resendSeconds = 0);
      } else {
        setState(() => _resendSeconds--);
      }
    });
  }

  // =========================
  // XỬ LÝ CÁCH 1: ĐỔI MẬT KHẨU CŨ -> MỚI
  // =========================
  Future<void> _submitChangePassword() async {
    if (await _isCurrentAccountAdmin()) {
      _showMessage('Tài khoản Quản trị viên không được phép đổi mật khẩu.');
      return;
    }

    final email = _emailController.text.trim();
    final oldPass = _oldPassController.text;
    final newPass = _newPassController.text;
    final confirmPass = _confirmPassController.text;

    if (email.isEmpty ||
        oldPass.isEmpty ||
        newPass.isEmpty ||
        confirmPass.isEmpty) {
      _showMessage('Vui lòng nhập đầy đủ tất cả các trường.');
      return;
    }
    if (newPass.length < 6) {
      _showMessage('Mật khẩu mới phải có ít nhất 6 ký tự.');
      return;
    }
    if (newPass == oldPass) {
      _showMessage('Mật khẩu mới phải khác mật khẩu cũ.');
      return;
    }
    if (newPass != confirmPass) {
      _showMessage('Xác nhận mật khẩu không khớp.');
      return;
    }

    setState(() => _isLoading = true);
    try {
      await _authService.changePasswordWithOldPassword(
        email: email,
        oldPassword: oldPass,
        newPassword: newPass,
      );
      if (!mounted) return;
      _showMessage('Đổi mật khẩu thành công!', isError: false);
      Navigator.pop(context);
    } catch (e) {
      _showMessage(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // =========================
  // XỬ LÝ CÁCH 2: GỬI MÃ OTP & ĐẶT LẠI MẬT KHẨU
  // =========================
  Future<void> _handleSendOtp() async {
    if (_resendSeconds > 0 || _isLoading) return;

    if (await _isCurrentAccountAdmin()) {
      _showMessage('Tài khoản Quản trị viên không được phép đổi mật khẩu.');
      return;
    }

    final email = _otpEmailController.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      _showMessage('Vui lòng nhập địa chỉ Email hợp lệ.');
      return;
    }

    setState(() => _isLoading = true);
    try {
      await BackendService.sendResetOtp(email);

      _startResendCountdown();
      _showMessage('Đã gửi mã xác nhận gồm 4 chữ số tới $email', isError: false);
      if (_otpFocusNodes.isNotEmpty) {
        _otpFocusNodes[0].requestFocus();
      }
    } catch (e) {
      _showMessage(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleVerifyOtpAndNext() async {
    final email = _otpEmailController.text.trim();
    final otp = _otpControllers.map((c) => c.text.trim()).join();

    if (email.isEmpty || !email.contains('@')) {
      _showMessage('Vui lòng nhập địa chỉ Email.');
      return;
    }
    if (otp.length < 4) {
      _showMessage('Vui lòng nhập đủ 4 chữ số xác nhận.');
      return;
    }

    setState(() => _isLoading = true);
    try {
      await BackendService.verifyResetOtp(email: email, otp: otp);

      _verifiedOtpCode = otp;
      setState(() {
        _stepIndex = 2;
      });
    } catch (e) {
      _showMessage(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _submitResetNewPassword() async {
    if (await _isCurrentAccountAdmin()) {
      _showMessage('Tài khoản Quản trị viên không được phép đổi mật khẩu.');
      return;
    }

    final newPass = _resetNewPassController.text;
    final confirmPass = _resetConfirmPassController.text;

    if (newPass.isEmpty || confirmPass.isEmpty) {
      _showMessage('Vui lòng nhập đầy đủ mật khẩu mới.');
      return;
    }
    if (newPass.length < 6) {
      _showMessage('Mật khẩu mới phải có ít nhất 6 ký tự.');
      return;
    }
    if (newPass != confirmPass) {
      _showMessage('Xác nhận mật khẩu không khớp.');
      return;
    }

    setState(() => _isLoading = true);
    try {
      await BackendService.resetPasswordWithOtp(
        email: _otpEmailController.text.trim(),
        otp: _verifiedOtpCode ?? '',
        newPassword: newPass,
      );

      if (!mounted) return;
      _showMessage('Đặt lại mật khẩu thành công!', isError: false);
      Navigator.pop(context);
    } catch (e) {
      _showMessage(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _handleBack() {
    if (_stepIndex == 2) {
      setState(() => _stepIndex = 1);
    } else if (_stepIndex == 1 && !widget.isForgotPasswordMode) {
      setState(() => _stepIndex = 0);
    } else {
      Navigator.pop(context);
    }
  }

  String get _subtitleText {
    if (_stepIndex == 0) {
      return 'Nhập mật khẩu hiện tại để thiết lập mật khẩu mới an toàn hơn';
    }
    if (_stepIndex == 1) {
      return 'Nhập Email đã đăng ký để nhận mã xác nhận 4 chữ số';
    }
    return 'Tạo mật khẩu mới có ít nhất 6 ký tự cho tài khoản của bạn';
  }

  @override
  Widget build(BuildContext context) {
    return Localizations.override(
      context: context,
      delegates: const [
        DefaultMaterialLocalizations.delegate,
        DefaultWidgetsLocalizations.delegate,
      ],
      child: Scaffold(
        backgroundColor: pageBg,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            onPressed: _isLoading ? null : _handleBack,
            icon: const Icon(
              Icons.arrow_back_rounded,
              color: darkNavy,
              size: 24,
            ),
          ),
        ),
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: SingleChildScrollView(
                padding:
                    const EdgeInsets.symmetric(horizontal: 26, vertical: 8),
                child: Column(
                  children: [
                    _buildBrandHeader(),
                    const SizedBox(height: 16),

                    Text(
                      _stepIndex == 0 ? 'Đổi mật khẩu' : 'Đặt lại mật khẩu',
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: darkNavy,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _subtitleText,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF666A86),
                        height: 1.4,
                      ),
                    ),

                    if (_stepIndex != 0) ...[
                      const SizedBox(height: 16),
                      _buildStepIndicator(),
                    ],

                    const SizedBox(height: 24),

                    if (_stepIndex == 0) _buildDirectChangeForm(),
                    if (_stepIndex == 1) _buildOtpEmailForm(),
                    if (_stepIndex == 2) _buildNewPasswordAfterOtpForm(),

                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStepIndicator() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildStepChip(step: 1, label: 'Xác thực OTP', active: _stepIndex >= 1),
        Container(
          width: 24,
          height: 2,
          margin: const EdgeInsets.symmetric(horizontal: 6),
          color: _stepIndex == 2 ? primaryPurple : const Color(0xFFD8DCF5),
        ),
        _buildStepChip(step: 2, label: 'Mật khẩu mới', active: _stepIndex == 2),
      ],
    );
  }

  Widget _buildStepChip({
    required int step,
    required String label,
    required bool active,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: active ? cardLavender : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: active ? primaryPurple : const Color(0xFFE0E3F5),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            radius: 9,
            backgroundColor: active ? primaryPurple : Colors.grey.shade400,
            child: Text(
              '$step',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10.5,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: active ? primaryPurple : Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBrandHeader() {
    return Image.asset(
      'assets/images/logo.png',
      height: 104,
      fit: BoxFit.contain,
      errorBuilder: (_, _, _) {
        return Column(
          children: [
            Container(
              width: 74,
              height: 74,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [primaryPurple, Color(0xFF757BFF)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(22),
                boxShadow: [
                  BoxShadow(
                    color: primaryPurple.withValues(alpha: 0.25),
                    blurRadius: 14,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: const Icon(
                Icons.quiz_rounded,
                color: Colors.white,
                size: 40,
              ),
            ),
            const SizedBox(height: 10),
            RichText(
              text: const TextSpan(
                style: TextStyle(
                  fontSize: 25,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.4,
                ),
                children: [
                  TextSpan(
                    text: 'Quiz',
                    style: TextStyle(color: darkNavy),
                  ),
                  TextSpan(
                    text: 'Master',
                    style: TextStyle(color: accentOrange),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  // =========================
  // UI CÁCH 1: ĐỔI MẬT KHẨU
  // =========================
  Widget _buildDirectChangeForm() {
    return Column(
      children: [
        _buildPillInput(
          controller: _emailController,
          hintText: 'Email',
          prefixIcon: Icons.mail_outline_rounded,
          keyboardType: TextInputType.emailAddress,
          readOnly: _hasLoggedInEmail,
        ),
        const SizedBox(height: 14),
        _buildPillInput(
          controller: _oldPassController,
          hintText: 'Nhập mật khẩu cũ',
          prefixIcon: Icons.lock_outline_rounded,
          obscureText: _obscureOld,
          onToggleObscure: () => setState(() => _obscureOld = !_obscureOld),
        ),
        const SizedBox(height: 14),
        _buildPillInput(
          controller: _newPassController,
          hintText: 'Nhập mật khẩu mới',
          prefixIcon: Icons.vpn_key_outlined,
          obscureText: _obscureNew,
          onToggleObscure: () => setState(() => _obscureNew = !_obscureNew),
        ),
        const SizedBox(height: 14),
        _buildPillInput(
          controller: _confirmPassController,
          hintText: 'Xác nhận mật khẩu mới',
          prefixIcon: Icons.check_circle_outline_rounded,
          obscureText: _obscureConfirm,
          onToggleObscure: () =>
              setState(() => _obscureConfirm = !_obscureConfirm),
        ),
        const SizedBox(height: 26),
        _buildPrimaryPillButton(
          label: 'Cập nhật mật khẩu',
          onPressed: _submitChangePassword,
        ),
        const SizedBox(height: 16),
        TextButton(
          onPressed: _isLoading
              ? null
              : () {
                  setState(() => _stepIndex = 1);
                },
          child: const Text(
            'Quên mật khẩu cũ? Đặt lại qua mã Email',
            style: TextStyle(
              color: primaryPurple,
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  // =========================
  // UI CÁCH 2 - BƯỚC 1: EMAIL + 4 Ô OTP
  // =========================
  Widget _buildOtpEmailForm() {
    return Column(
      children: [
        Container(
          height: 52,
          decoration: BoxDecoration(
            color: _hasLoggedInEmail ? const Color(0xFFF1F3FA) : Colors.white,
            borderRadius: BorderRadius.circular(26),
            border: Border.all(color: const Color(0xFFE5E8F8)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              const SizedBox(width: 16),
              const Icon(
                Icons.mail_outline_rounded,
                color: Colors.grey,
                size: 20,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: _otpEmailController,
                  readOnly: _hasLoggedInEmail,
                  keyboardType: TextInputType.emailAddress,
                  style: TextStyle(
                    fontSize: 14,
                    color: _hasLoggedInEmail
                        ? const Color(0xFF5D617A)
                        : darkNavy,
                  ),
                  decoration: const InputDecoration(
                    hintText: 'Nhập Email',
                    hintStyle: TextStyle(color: Colors.grey, fontSize: 13.5),
                    border: InputBorder.none,
                    isDense: true,
                  ),
                ),
              ),
              SizedBox(
                height: 52,
                child: ElevatedButton(
                  onPressed: (_resendSeconds > 0 || _isLoading)
                      ? null
                      : _handleSendOtp,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: accentOrange,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor:
                        accentOrange.withValues(alpha: 0.55),
                    disabledForegroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                    shape: const RoundedRectangleBorder(
                      borderRadius: BorderRadius.horizontal(
                        right: Radius.circular(26),
                      ),
                    ),
                  ),
                  child: Text(
                    _resendSeconds > 0 ? '${_resendSeconds}s' : 'Gửi mã',
                    style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),

        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: core.List.generate(4, (index) {
            return Container(
              width: 56,
              height: 60,
              margin: EdgeInsets.only(right: index < 3 ? 12 : 0),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE3E6FA)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              alignment: Alignment.center,
              child: TextField(
                controller: _otpControllers[index],
                focusNode: _otpFocusNodes[index],
                textAlign: TextAlign.center,
                keyboardType: TextInputType.number,
                maxLength: 1,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                style: const TextStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.bold,
                  color: darkNavy,
                ),
                decoration: const InputDecoration(
                  counterText: '',
                  border: InputBorder.none,
                ),
                onChanged: (value) {
                  if (value.isNotEmpty && index < 3) {
                    _otpFocusNodes[index + 1].requestFocus();
                  } else if (value.isEmpty && index > 0) {
                    _otpFocusNodes[index - 1].requestFocus();
                  }
                },
              ),
            );
          }),
        ),

        const SizedBox(height: 28),

        _buildPrimaryPillButton(
          label: 'Xác nhận & Tiếp tục',
          onPressed: _handleVerifyOtpAndNext,
        ),

        if (!widget.isForgotPasswordMode) ...[
          const SizedBox(height: 16),
          TextButton(
            onPressed: _isLoading
                ? null
                : () {
                    setState(() => _stepIndex = 0);
                  },
            child: const Text(
              'Quay lại đổi bằng mật khẩu cũ',
              style: TextStyle(
                color: primaryPurple,
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ],
    );
  }

  // =========================
  // UI CÁCH 2 - BƯỚC 2: NHẬP MẬT KHẨU MỚI
  // =========================
  Widget _buildNewPasswordAfterOtpForm() {
    return Column(
      children: [
        _buildPillInput(
          controller: _resetNewPassController,
          hintText: 'Nhập mật khẩu mới',
          prefixIcon: Icons.vpn_key_outlined,
          obscureText: _obscureResetNew,
          onToggleObscure: () =>
              setState(() => _obscureResetNew = !_obscureResetNew),
        ),
        const SizedBox(height: 14),
        _buildPillInput(
          controller: _resetConfirmPassController,
          hintText: 'Xác nhận mật khẩu mới',
          prefixIcon: Icons.check_circle_outline_rounded,
          obscureText: _obscureResetConfirm,
          onToggleObscure: () =>
              setState(() => _obscureResetConfirm = !_obscureResetConfirm),
        ),
        const SizedBox(height: 26),
        _buildPrimaryPillButton(
          label: 'Đặt lại mật khẩu',
          onPressed: _submitResetNewPassword,
        ),
      ],
    );
  }

  // =========================
  // WIDGET DÙNG CHUNG
  // =========================
  Widget _buildPillInput({
    required TextEditingController controller,
    required String hintText,
    required IconData prefixIcon,
    bool obscureText = false,
    bool readOnly = false,
    VoidCallback? onToggleObscure,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Container(
      height: 52,
      decoration: BoxDecoration(
        color: readOnly ? const Color(0xFFF1F3FA) : Colors.white,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: const Color(0xFFE5E8F8)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      alignment: Alignment.center,
      child: TextField(
        controller: controller,
        obscureText: obscureText,
        readOnly: readOnly,
        keyboardType: keyboardType,
        style: TextStyle(
          fontSize: 14,
          color: readOnly ? const Color(0xFF5D617A) : darkNavy,
        ),
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: const TextStyle(color: Colors.grey, fontSize: 13.5),
          prefixIcon: Icon(prefixIcon, color: Colors.grey, size: 20),
          suffixIcon: readOnly
              ? const Icon(
                  Icons.lock_outline_rounded,
                  color: Colors.grey,
                  size: 18,
                )
              : (onToggleObscure != null
                  ? IconButton(
                      onPressed: onToggleObscure,
                      icon: Icon(
                        obscureText
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        color: Colors.grey,
                        size: 19,
                      ),
                    )
                  : null),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 14),
        ),
      ),
    );
  }

  Widget _buildPrimaryPillButton({
    required String label,
    required VoidCallback onPressed,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton(
        onPressed: _isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryPurple,
          foregroundColor: Colors.white,
          elevation: 2,
          shadowColor: primaryPurple.withValues(alpha: 0.35),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(25),
          ),
        ),
        child: _isLoading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2.4,
                ),
              )
            : Text(
                label,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
      ),
    );
  }
}