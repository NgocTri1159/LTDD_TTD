import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/theme.dart';

class ForgotPasswordScreen extends StatefulWidget {
  final String initialEmail;

  const ForgotPasswordScreen({
    super.key,
    this.initialEmail = '',
  });

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  static const Color _brandBlue = Color(0xFF3B5BFD);
  static const Color _brandPurple = Color(0xFF7C3AED);
  static final RegExp _emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  late final TextEditingController _emailController;
  final _pinController = TextEditingController();
  final _pinFocusNode = FocusNode();

  bool _isSendingCode = false;
  bool _isVerifying = false;
  bool _hasSentCode = false;
  int _countdown = 0;
  Timer? _timer;

  String? _emailError;
  String? _pinError;
  String? _infoMessage;

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController(text: widget.initialEmail);
    _pinFocusNode.addListener(_handlePinFocusChange);
  }

  void _handlePinFocusChange() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pinFocusNode.removeListener(_handlePinFocusChange);
    _emailController.dispose();
    _pinController.dispose();
    _pinFocusNode.dispose();
    super.dispose();
  }

  void _startCountdown() {
    _timer?.cancel();
    setState(() => _countdown = 60);
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_countdown <= 1) {
        timer.cancel();
        if (mounted) setState(() => _countdown = 0);
      } else {
        if (mounted) setState(() => _countdown--);
      }
    });
  }

  // BƯỚC 1: Sinh mã PIN 6 số và đẩy lên bảng password_reset_pins trên Supabase
  Future<void> _sendPinCode() async {
    final email = _emailController.text.trim().toLowerCase();
    if (!_emailRegex.hasMatch(email)) {
      setState(() {
        _emailError = 'Vui lòng nhập địa chỉ email hợp lệ.';
        _infoMessage = null;
      });
      return;
    }

    setState(() {
      _isSendingCode = true;
      _emailError = null;
      _pinError = null;
      _infoMessage = null;
    });

    try {
      final generatedPin = (100000 + Random().nextInt(900000)).toString();

      await Supabase.instance.client.from('password_reset_pins').upsert({
        'email': email,
        'pin': generatedPin,
        'created_at': DateTime.now().toIso8601String(),
      });

      if (!mounted) return;
      _pinController.clear();
      setState(() {
        _hasSentCode = true;
        _infoMessage =
            'Đã tạo mã PIN 6 số cho $email. Mở bảng password_reset_pins trên Supabase để lấy mã.';
      });
      _startCountdown();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _pinFocusNode.requestFocus();
      });
    } on PostgrestException catch (e) {
      if (!mounted) return;
      setState(() => _emailError = 'Lỗi Supabase: ${e.message}');
    } catch (_) {
      if (!mounted) return;
      setState(
        () => _emailError = 'Không thể gửi mã xác nhận. Vui lòng thử lại.',
      );
    } finally {
      if (mounted) setState(() => _isSendingCode = false);
    }
  }

  // BƯỚC 2: Đối chiếu mã PIN với bảng trên Supabase -> đúng sang ResetPasswordScreen
  Future<void> _verifyPinCode() async {
    final email = _emailController.text.trim().toLowerCase();
    final pin = _pinController.text.trim();

    if (!_emailRegex.hasMatch(email)) {
      setState(() => _emailError = 'Vui lòng nhập địa chỉ email hợp lệ.');
      return;
    }

    if (pin.isEmpty) {
      setState(() => _pinError = 'Vui lòng nhập mã Pin.');
      return;
    }

    if (pin.length != 6) {
      setState(() => _pinError = 'Mã Pin không chính xác!');
      return;
    }

    setState(() {
      _isVerifying = true;
      _emailError = null;
      _pinError = null;
    });

    try {
      final record = await Supabase.instance.client
          .from('password_reset_pins')
          .select('pin')
          .eq('email', email)
          .maybeSingle();

      if (!mounted) return;

      if (record == null || record['pin'] != pin) {
        setState(() => _pinError = 'Mã Pin không chính xác!');
        return;
      }

      // Xác thực thành công -> xóa mã PIN khỏi bảng để không dùng lại được lần 2
      await Supabase.instance.client
          .from('password_reset_pins')
          .delete()
          .eq('email', email);

      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => ResetPasswordScreen(email: email),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _pinError = 'Mã Pin không chính xác!');
    } finally {
      if (mounted) setState(() => _isVerifying = false);
    }
  }

  Widget _buildPinBoxes(bool isBusy) {
    final code = _pinController.text;
    final hasError = _pinError != null;

    return GestureDetector(
      onTap: () {
        if (!isBusy) _pinFocusNode.requestFocus();
      },
      child: Stack(
        alignment: Alignment.center,
        children: [
          Row(
            children: List.generate(6, (index) {
              final hasChar = index < code.length;
              final isActive = _pinFocusNode.hasFocus &&
                  (index == code.length || (code.length == 6 && index == 5));

              Color borderColor = const Color(0xFFE2E8F0);
              double borderWidth = 1.4;
              Color bgColor = const Color(0xFFF8FAFC);

              if (hasError) {
                borderColor = const Color(0xFFDC2626);
                borderWidth = 1.8;
                bgColor = const Color(0xFFFEF2F2);
              } else if (isActive) {
                borderColor = _brandPurple;
                borderWidth = 2.0;
                bgColor = Colors.white;
              } else if (hasChar) {
                borderColor = AppColors.base.withValues(alpha: 0.65);
                bgColor = AppColors.base.withValues(alpha: 0.04);
              }

              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(right: index == 5 ? 0 : 8),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    height: 56,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: bgColor,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: borderColor, width: borderWidth),
                      boxShadow: isActive && !hasError
                          ? [
                              BoxShadow(
                                color: _brandPurple.withValues(alpha: 0.16),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ]
                          : null,
                    ),
                    child: Text(
                      hasChar ? code[index] : '',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: hasError
                            ? const Color(0xFFB91C1C)
                            : const Color(0xFF0F172A),
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
          Positioned.fill(
            child: Opacity(
              opacity: 0,
              child: TextField(
                controller: _pinController,
                focusNode: _pinFocusNode,
                enabled: !isBusy,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.done,
                maxLength: 6,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                onSubmitted: (_) {
                  if (!isBusy) _verifyPinCode();
                },
                onChanged: (_) {
                  setState(() {
                    if (_pinError != null) _pinError = null;
                  });
                },
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  counterText: '',
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isBusy = _isSendingCode || _isVerifying;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: const Color(0xFFF1F5FB),
        body: SingleChildScrollView(
          child: Column(
            children: [
              _AuthHeroHeader(
                icon: Icons.mark_email_read_rounded,
                title: 'Quên mật khẩu',
                subtitle:
                    'Xác thực email bằng mã PIN 6 số để khôi phục quyền truy cập tài khoản của bạn.',
                currentStep: 1,
                onBack: () => Navigator.of(context).pop(),
              ),
              Transform.translate(
                offset: const Offset(0, -34),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 440),
                      child: Container(
                        padding: const EdgeInsets.fromLTRB(22, 24, 22, 24),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(28),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF1E293B)
                                  .withValues(alpha: 0.08),
                              blurRadius: 30,
                              offset: const Offset(0, 14),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // BƯỚC 1: EMAIL + NÚT GỬI MÃ
                            Row(
                              children: [
                                const _StepBadge(number: '1', active: true),
                                const SizedBox(width: 8),
                                const Text(
                                  'Nhập Email đã đăng ký',
                                  style: TextStyle(
                                    fontSize: 14.5,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF0F172A),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: _emailController,
                                    enabled: !isBusy,
                                    keyboardType: TextInputType.emailAddress,
                                    onChanged: (_) {
                                      if (_emailError != null) {
                                        setState(() => _emailError = null);
                                      }
                                    },
                                    decoration: InputDecoration(
                                      hintText: 'example@gmail.com',
                                      hintStyle: const TextStyle(
                                        color: Color(0xFF94A3B8),
                                        fontSize: 14,
                                      ),
                                      prefixIcon: const Icon(
                                        Icons.email_outlined,
                                        color: AppColors.base,
                                        size: 20,
                                      ),
                                      filled: true,
                                      fillColor: _emailError != null
                                          ? const Color(0xFFFEF2F2)
                                          : const Color(0xFFF8FAFC),
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                        horizontal: 14,
                                        vertical: 16,
                                      ),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(16),
                                        borderSide: BorderSide(
                                          color: _emailError != null
                                              ? const Color(0xFFDC2626)
                                              : const Color(0xFFE2E8F0),
                                          width: 1.3,
                                        ),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(16),
                                        borderSide: BorderSide(
                                          color: _emailError != null
                                              ? const Color(0xFFDC2626)
                                              : AppColors.base,
                                          width: 1.8,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                SizedBox(
                                  height: 54,
                                  child: ElevatedButton(
                                    onPressed: (isBusy || _countdown > 0)
                                        ? null
                                        : _sendPinCode,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: _brandBlue,
                                      foregroundColor: Colors.white,
                                      disabledBackgroundColor:
                                          const Color(0xFFE2E8F0),
                                      disabledForegroundColor:
                                          const Color(0xFF64748B),
                                      elevation: 0,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 15,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                    ),
                                    child: _isSendingCode
                                        ? const SizedBox(
                                            width: 18,
                                            height: 18,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2.2,
                                              color: Colors.white,
                                            ),
                                          )
                                        : Text(
                                            _countdown > 0
                                                ? '${_countdown}s'
                                                : (_hasSentCode
                                                    ? 'Gửi lại'
                                                    : 'Gửi mã'),
                                            style: const TextStyle(
                                              fontSize: 13.5,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                  ),
                                ),
                              ],
                            ),

                            if (_emailError != null) ...[
                              const SizedBox(height: 8),
                              _InlineFeedback(
                                text: _emailError!,
                                isError: true,
                              ),
                            ],

                            if (_infoMessage != null) ...[
                              const SizedBox(height: 12),
                              _InlineFeedback(
                                text: _infoMessage!,
                                isError: false,
                              ),
                            ],

                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 20),
                              child: Divider(
                                height: 1,
                                color: Color(0xFFF1F5F9),
                              ),
                            ),

                            // BƯỚC 2: NHẬP 6 Ô MÃ PIN
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    _StepBadge(
                                      number: '2',
                                      active: _hasSentCode,
                                    ),
                                    const SizedBox(width: 8),
                                    const Text(
                                      'Nhập mã PIN 6 số',
                                      style: TextStyle(
                                        fontSize: 14.5,
                                        fontWeight: FontWeight.w800,
                                        color: Color(0xFF0F172A),
                                      ),
                                    ),
                                  ],
                                ),
                                if (_pinController.text.isNotEmpty)
                                  GestureDetector(
                                    onTap: isBusy
                                        ? null
                                        : () {
                                            _pinController.clear();
                                            setState(() => _pinError = null);
                                          },
                                    child: const Text(
                                      'Xóa mã',
                                      style: TextStyle(
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF64748B),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            _buildPinBoxes(isBusy),

                            // HIỂN THỊ "Mã Pin không chính xác!" KHI SAI
                            if (_pinError != null) ...[
                              const SizedBox(height: 10),
                              _InlineFeedback(
                                text: _pinError!,
                                isError: true,
                              ),
                            ],

                            const SizedBox(height: 24),

                            // NÚT XÁC NHẬN
                            _GradientPrimaryButton(
                              text: 'Xác nhận mã PIN',
                              icon: Icons.arrow_forward_rounded,
                              isLoading: _isVerifying,
                              onPressed: isBusy ? null : _verifyPinCode,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// MÀN HÌNH 2: ĐẶT LẠI MẬT KHẨU (MỞ KHI NHẬP ĐÚNG MÃ PIN)
// ============================================================================
class ResetPasswordScreen extends StatefulWidget {
  final String email;

  const ResetPasswordScreen({
    super.key,
    required this.email,
  });

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  static const Color _brandPurple = Color(0xFF7C3AED);

  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _isLoading = false;
  bool _obscureNewPass = true;
  bool _obscureConfirmPass = true;
  String? _errorMessage;

  @override
  void dispose() {
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  int get _passwordStrength {
    final pass = _newPasswordController.text;
    if (pass.isEmpty) return 0;
    int score = 0;
    if (pass.length >= 6) score++;
    if (pass.length >= 8) score++;
    if (RegExp(r'[A-Z]').hasMatch(pass) || RegExp(r'[0-9]').hasMatch(pass)) {
      score++;
    }
    return score;
  }

  Future<void> _updatePassword() async {
    final newPassword = _newPasswordController.text;
    final confirmPassword = _confirmPasswordController.text;

    if (newPassword.length < 6) {
      setState(() => _errorMessage = 'Mật khẩu mới phải có ít nhất 6 ký tự.');
      return;
    }

    if (newPassword != confirmPassword) {
      setState(() => _errorMessage = 'Mật khẩu xác nhận không khớp.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Giả lập lưu mật khẩu khi test luồng không qua Supabase Auth OTP
      await Future.delayed(const Duration(milliseconds: 500));

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'Đặt lại mật khẩu thành công! Vui lòng đăng nhập lại.',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          backgroundColor: const Color(0xFF15803D),
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      );
      Navigator.of(context).pop();
    } catch (_) {
      if (!mounted) return;
      setState(
        () => _errorMessage = 'Đặt lại mật khẩu thất bại. Vui lòng thử lại.',
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  InputDecoration _passwordDecoration({
    required String hint,
    required bool obscure,
    required VoidCallback onToggle,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
      prefixIcon: Padding(
        padding: const EdgeInsets.only(left: 10, right: 10),
        child: Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: _brandPurple.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(
            Icons.lock_outline_rounded,
            color: _brandPurple,
            size: 18,
          ),
        ),
      ),
      prefixIconConstraints: const BoxConstraints(minWidth: 54, minHeight: 44),
      suffixIcon: IconButton(
        icon: Icon(
          obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
          color: const Color(0xFF64748B),
          size: 20,
        ),
        onPressed: onToggle,
      ),
      filled: true,
      fillColor: const Color(0xFFF8FAFC),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0), width: 1.3),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: _brandPurple, width: 1.8),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final strength = _passwordStrength;
    final pass = _newPasswordController.text;
    final hasMinLength = pass.length >= 6;
    final isMatched =
        pass.isNotEmpty && pass == _confirmPasswordController.text;

    final strengthLabel = strength == 0
        ? ''
        : strength == 1
            ? 'Yếu'
            : strength == 2
                ? 'Trung bình'
                : 'Mạnh';

    final strengthColor = strength <= 1
        ? const Color(0xFFEF4444)
        : strength == 2
            ? const Color(0xFFF59E0B)
            : const Color(0xFF16A34A);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: const Color(0xFFF1F5FB),
        body: SingleChildScrollView(
          child: Column(
            children: [
              _AuthHeroHeader(
                icon: Icons.lock_reset_rounded,
                title: 'Đặt lại mật khẩu',
                subtitle: 'Xác thực thành công cho ${widget.email}',
                currentStep: 2,
                onBack: () => Navigator.of(context).pop(),
              ),
              Transform.translate(
                offset: const Offset(0, -34),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 440),
                      child: Container(
                        padding: const EdgeInsets.fromLTRB(22, 24, 22, 24),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(28),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF1E293B)
                                  .withValues(alpha: 0.08),
                              blurRadius: 30,
                              offset: const Offset(0, 14),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (_errorMessage != null) ...[
                              _InlineFeedback(
                                text: _errorMessage!,
                                isError: true,
                              ),
                              const SizedBox(height: 16),
                            ],
                            const Text(
                              'Mật khẩu mới',
                              style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF1E293B),
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextField(
                              controller: _newPasswordController,
                              enabled: !_isLoading,
                              obscureText: _obscureNewPass,
                              onChanged: (_) => setState(() {
                                if (_errorMessage != null) _errorMessage = null;
                              }),
                              decoration: _passwordDecoration(
                                hint: 'Nhập mật khẩu mới',
                                obscure: _obscureNewPass,
                                onToggle: () => setState(
                                  () => _obscureNewPass = !_obscureNewPass,
                                ),
                              ),
                            ),
                            if (pass.isNotEmpty) ...[
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  Expanded(
                                    child: Row(
                                      children: List.generate(3, (i) {
                                        return Expanded(
                                          child: Container(
                                            height: 5,
                                            margin: EdgeInsets.only(
                                              right: i == 2 ? 0 : 6,
                                            ),
                                            decoration: BoxDecoration(
                                              color: i < strength
                                                  ? strengthColor
                                                  : const Color(0xFFE2E8F0),
                                              borderRadius:
                                                  BorderRadius.circular(99),
                                            ),
                                          ),
                                        );
                                      }),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Text(
                                    strengthLabel,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: strengthColor,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                            const SizedBox(height: 16),
                            const Text(
                              'Xác nhận mật khẩu mới',
                              style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF1E293B),
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextField(
                              controller: _confirmPasswordController,
                              enabled: !_isLoading,
                              obscureText: _obscureConfirmPass,
                              textInputAction: TextInputAction.done,
                              onChanged: (_) => setState(() {
                                if (_errorMessage != null) _errorMessage = null;
                              }),
                              onSubmitted: (_) {
                                if (!_isLoading) _updatePassword();
                              },
                              decoration: _passwordDecoration(
                                hint: 'Nhập lại mật khẩu mới',
                                obscure: _obscureConfirmPass,
                                onToggle: () => setState(
                                  () => _obscureConfirmPass =
                                      !_obscureConfirmPass,
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(14),
                                border:
                                    Border.all(color: const Color(0xFFE2E8F0)),
                              ),
                              child: Column(
                                children: [
                                  _PasswordRuleRow(
                                    label: 'Tối thiểu 6 ký tự',
                                    passed: hasMinLength,
                                  ),
                                  const SizedBox(height: 6),
                                  _PasswordRuleRow(
                                    label: 'Mật khẩu xác nhận trùng khớp',
                                    passed: isMatched,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 24),
                            _GradientPrimaryButton(
                              text: 'Lưu mật khẩu mới',
                              icon: Icons.check_circle_outline_rounded,
                              isLoading: _isLoading,
                              onPressed: _isLoading ? null : _updatePassword,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// CÁC WIDGET DÙNG CHUNG CHO HEADER & UI
// ============================================================================
class _AuthHeroHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final int currentStep;
  final VoidCallback onBack;

  const _AuthHeroHeader({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.currentStep,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF3B5BFD),
            AppColors.base,
            Color(0xFF7C3AED),
          ],
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(36),
          bottomRight: Radius.circular(36),
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            top: -36,
            right: -24,
            child: Container(
              width: 150,
              height: 150,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.10),
              ),
            ),
          ),
          Positioned(
            bottom: 14,
            left: -40,
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.08),
              ),
            ),
          ),
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 62),
              child: Column(
                children: [
                  Row(
                    children: [
                      Material(
                        color: Colors.white.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(12),
                        child: InkWell(
                          onTap: onBack,
                          borderRadius: BorderRadius.circular(12),
                          child: const SizedBox(
                            width: 40,
                            height: 40,
                            child: Icon(
                              Icons.arrow_back_ios_new_rounded,
                              color: Colors.white,
                              size: 18,
                            ),
                          ),
                        ),
                      ),
                      const Spacer(),
                      _HeaderStepIndicator(currentStep: currentStep),
                      const Spacer(),
                      const SizedBox(width: 40),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Container(
                    width: 66,
                    height: 66,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.28),
                      ),
                    ),
                    child: Icon(icon, color: Colors.white, size: 32),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      subtitle,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.88),
                        fontSize: 13.5,
                        height: 1.45,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeaderStepIndicator extends StatelessWidget {
  final int currentStep;

  const _HeaderStepIndicator({required this.currentStep});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _dot(active: currentStep >= 1, done: currentStep > 1),
          const SizedBox(width: 6),
          Text(
            'Xác thực',
            style: TextStyle(
              color: Colors.white.withValues(alpha: currentStep == 1 ? 1 : 0.78),
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          Container(
            width: 18,
            height: 1.5,
            margin: const EdgeInsets.symmetric(horizontal: 8),
            color: Colors.white.withValues(alpha: 0.45),
          ),
          _dot(active: currentStep >= 2, done: false),
          const SizedBox(width: 6),
          Text(
            'Mật khẩu mới',
            style: TextStyle(
              color: Colors.white.withValues(alpha: currentStep == 2 ? 1 : 0.70),
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _dot({required bool active, required bool done}) {
    return Container(
      width: 16,
      height: 16,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: active ? Colors.white : Colors.white.withValues(alpha: 0.25),
      ),
      child: done
          ? const Icon(Icons.check, size: 11, color: Color(0xFF3B5BFD))
          : Center(
              child: Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: active ? const Color(0xFF3B5BFD) : Colors.transparent,
                ),
              ),
            ),
    );
  }
}

class _StepBadge extends StatelessWidget {
  final String number;
  final bool active;

  const _StepBadge({required this.number, required this.active});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 24,
      height: 24,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: active ? const Color(0xFF3B5BFD) : const Color(0xFFE2E8F0),
        shape: BoxShape.circle,
      ),
      child: Text(
        number,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w800,
          color: active ? Colors.white : const Color(0xFF64748B),
        ),
      ),
    );
  }
}

class _InlineFeedback extends StatelessWidget {
  final String text;
  final bool isError;

  const _InlineFeedback({required this.text, required this.isError});

  @override
  Widget build(BuildContext context) {
    final bg = isError ? const Color(0xFFFEF2F2) : const Color(0xFFF0FDF4);
    final border = isError ? const Color(0xFFFECACA) : const Color(0xFFBBF7D0);
    final fg = isError ? const Color(0xFFDC2626) : const Color(0xFF15803D);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            isError
                ? Icons.error_outline_rounded
                : Icons.check_circle_outline_rounded,
            size: 18,
            color: fg,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: fg,
                fontSize: 13,
                fontWeight: FontWeight.w600,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GradientPrimaryButton extends StatelessWidget {
  final String text;
  final IconData icon;
  final bool isLoading;
  final VoidCallback? onPressed;

  const _GradientPrimaryButton({
    required this.text,
    required this.icon,
    required this.isLoading,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 54,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF3B5BFD), AppColors.base, Color(0xFF7C3AED)],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.base.withValues(alpha: 0.30),
            blurRadius: 16,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          disabledBackgroundColor: Colors.transparent,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: isLoading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: Colors.white,
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    text,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(icon, size: 19),
                ],
              ),
      ),
    );
  }
}

class _PasswordRuleRow extends StatelessWidget {
  final String label;
  final bool passed;

  const _PasswordRuleRow({required this.label, required this.passed});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          passed ? Icons.check_circle_rounded : Icons.radio_button_unchecked,
          size: 16,
          color: passed ? const Color(0xFF16A34A) : const Color(0xFF94A3B8),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            color: passed ? const Color(0xFF15803D) : const Color(0xFF64748B),
          ),
        ),
      ],
    );
  }
}