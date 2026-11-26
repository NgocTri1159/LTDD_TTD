import 'package:material_ui/material_ui.dart';
import '../../controllers/auth_controller.dart';
import '../../screens/setting/change_password_screen.dart';
import 'register_view.dart';

class LoginView extends StatefulWidget {
  const LoginView({super.key});

  @override
  State<LoginView> createState() => _LoginViewState();
}

class _LoginViewState extends State<LoginView> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  final AuthController _authController = AuthController();
  bool _obscurePassword = true;
  String? _errorMessage;

  static const Color primaryPurple = Color(0xFF565CEB);
  static const Color cardLavender = Color(0xFFECEEFF);
  static const Color accentOrange = Color(0xFFF79E1B);
  static const Color darkText = Color(0xFF1E1E2C);
  static const Color pageBg = Color(0xFFF9FAFF);

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _authController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    setState(() => _errorMessage = null);

    final result = await _authController.login(
      email: _emailController.text,
      password: _passwordController.text,
    );

    if (!mounted) return;

    if (!result.isSuccess) {
      setState(() {
        _errorMessage = result.message.isNotEmpty
            ? result.message
            : 'Email hoặc mật khẩu không chính xác!';
      });
    } else {
      _showMessage(result.message);
    }
  }

  Future<void> _loginWithGoogle() async {
    setState(() => _errorMessage = null);

    final result = await _authController.loginWithGoogle();
    if (!mounted) return;

    if (!result.isSuccess) {
      setState(() {
        _errorMessage = result.message;
      });
    } else {
      _showMessage(result.message);
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFF2E7D32),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
      child: Align(
        alignment: Alignment.centerLeft,
        child: InkWell(
          onTap: () {
            if (Navigator.canPop(context)) {
              Navigator.pop(context);
            }
          },
          borderRadius: BorderRadius.circular(14),
          child: Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE3E6FA)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: const Icon(
              Icons.arrow_back_rounded,
              color: darkText,
              size: 20,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBrandLogo() {
    return Column(
      children: [
        Container(
          width: 82,
          height: 82,
          decoration: BoxDecoration(
            color: cardLavender,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 3),
            boxShadow: [
              BoxShadow(
                color: primaryPurple.withValues(alpha: 0.16),
                blurRadius: 18,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              const Icon(
                Icons.school_rounded,
                size: 42,
                color: primaryPurple,
              ),
              Positioned(
                right: 10,
                bottom: 10,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: accentOrange,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: const Icon(
                    Icons.question_mark_rounded,
                    size: 12,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        const Text(
          'QuizMaster',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.4,
            color: Color(0xFF282B78),
          ),
        ),
        const SizedBox(height: 2),
        const Text(
          'Đăng nhập để tiếp tục hành trình',
          style: TextStyle(
            fontSize: 13.5,
            color: Color(0xFF6E7191),
          ),
        ),
      ],
    );
  }

  InputDecoration _fieldDecoration({
    required String hint,
    required IconData icon,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Color(0xFF9EA2B8), fontSize: 14),
      prefixIcon: Icon(icon, color: primaryPurple, size: 20),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFE3E6FA)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: primaryPurple, width: 1.6),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: pageBg,
      body: SafeArea(
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minHeight: constraints.maxHeight),
                    child: IntrinsicHeight(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildTopBar(),
                          const SizedBox(height: 6),
                          _buildBrandLogo(),
                          const SizedBox(height: 16),

                          const Text(
                            'Đăng Nhập',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 23,
                              fontWeight: FontWeight.w800,
                              color: darkText,
                            ),
                          ),
                          const SizedBox(height: 18),

                          // Phần thân dưới với khối nền tím đặc trưng
                          Expanded(
                            child: Stack(
                              children: [
                                // Nền tím bo góc trên
                                Positioned.fill(
                                  top: 72,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      gradient: const LinearGradient(
                                        begin: Alignment.topCenter,
                                        end: Alignment.bottomCenter,
                                        colors: [
                                          Color(0xFF565CEB),
                                          Color(0xFF474DD6),
                                        ],
                                      ),
                                      borderRadius: const BorderRadius.vertical(
                                        top: Radius.circular(34),
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: primaryPurple
                                              .withValues(alpha: 0.22),
                                          blurRadius: 20,
                                          offset: const Offset(0, -4),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),

                                Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                    22,
                                    0,
                                    22,
                                    28,
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      // Khung card tím nhạt đè lên mép khối tím
                                      Container(
                                        padding: const EdgeInsets.all(16),
                                        decoration: BoxDecoration(
                                          color: cardLavender,
                                          borderRadius:
                                              BorderRadius.circular(22),
                                          border: Border.all(
                                            color: Colors.white,
                                            width: 2,
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color: const Color(0xFF1E1E2C)
                                                  .withValues(alpha: 0.10),
                                              blurRadius: 18,
                                              offset: const Offset(0, 8),
                                            ),
                                          ],
                                        ),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            TextField(
                                              controller: _emailController,
                                              keyboardType:
                                                  TextInputType.emailAddress,
                                              textInputAction:
                                                  TextInputAction.next,
                                              style: const TextStyle(
                                                fontSize: 14.5,
                                                color: darkText,
                                              ),
                                              decoration: _fieldDecoration(
                                                hint: 'Địa chỉ Email',
                                                icon: Icons.mail_outline_rounded,
                                              ),
                                            ),
                                            const SizedBox(height: 12),
                                            TextField(
                                              controller: _passwordController,
                                              obscureText: _obscurePassword,
                                              textInputAction:
                                                  TextInputAction.done,
                                              onSubmitted: (_) => _login(),
                                              style: const TextStyle(
                                                fontSize: 14.5,
                                                color: darkText,
                                              ),
                                              decoration: _fieldDecoration(
                                                hint: 'Mật khẩu',
                                                icon: Icons.lock_outline_rounded,
                                                suffixIcon: IconButton(
                                                  icon: Icon(
                                                    _obscurePassword
                                                        ? Icons
                                                            .visibility_off_outlined
                                                        : Icons
                                                            .visibility_outlined,
                                                    color:
                                                        const Color(0xFF8B90A8),
                                                    size: 20,
                                                  ),
                                                  onPressed: () {
                                                    setState(() {
                                                      _obscurePassword =
                                                          !_obscurePassword;
                                                    });
                                                  },
                                                ),
                                              ),
                                            ),
                                            if (_errorMessage != null) ...[
                                              const SizedBox(height: 10),
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                  horizontal: 10,
                                                  vertical: 8,
                                                ),
                                                decoration: BoxDecoration(
                                                  color:
                                                      const Color(0xFFFFEBEE),
                                                  borderRadius:
                                                      BorderRadius.circular(10),
                                                ),
                                                child: Row(
                                                  children: [
                                                    const Icon(
                                                      Icons
                                                          .error_outline_rounded,
                                                      color: Color(0xFFD32F2F),
                                                      size: 16,
                                                    ),
                                                    const SizedBox(width: 6),
                                                    Expanded(
                                                      child: Text(
                                                        _errorMessage!,
                                                        style: const TextStyle(
                                                          color:
                                                              Color(0xFFC62828),
                                                          fontSize: 12.5,
                                                          fontWeight:
                                                              FontWeight.w600,
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),

                                      const SizedBox(height: 20),

                                      // Nút Đăng nhập màu cam nổi bật trên nền tím
                                      AnimatedBuilder(
                                        animation: _authController,
                                        builder: (context, _) {
                                          return Container(
                                            height: 52,
                                            decoration: BoxDecoration(
                                              borderRadius:
                                                  BorderRadius.circular(16),
                                              boxShadow: _authController
                                                      .isLoading
                                                  ? []
                                                  : [
                                                      BoxShadow(
                                                        color: Colors.black
                                                            .withValues(
                                                                alpha: 0.16),
                                                        blurRadius: 12,
                                                        offset:
                                                            const Offset(0, 5),
                                                      ),
                                                    ],
                                            ),
                                            child: ElevatedButton(
                                              onPressed:
                                                  _authController.isLoading
                                                      ? null
                                                      : _login,
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: accentOrange,
                                                foregroundColor: Colors.white,
                                                disabledBackgroundColor:
                                                    accentOrange.withValues(
                                                        alpha: 0.6),
                                                elevation: 0,
                                                shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(16),
                                                ),
                                              ),
                                              child: _authController.isLoading
                                                  ? const SizedBox(
                                                      width: 22,
                                                      height: 22,
                                                      child:
                                                          CircularProgressIndicator(
                                                        color: Colors.white,
                                                        strokeWidth: 2.5,
                                                      ),
                                                    )
                                                  : const Text(
                                                      'Đăng nhập',
                                                      style: TextStyle(
                                                        fontSize: 16,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        letterSpacing: 0.3,
                                                      ),
                                                    ),
                                            ),
                                          );
                                        },
                                      ),

                                      const SizedBox(height: 16),

                                      // Dải phân cách mờ trên nền tím
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Divider(
                                              color: Colors.white
                                                  .withValues(alpha: 0.25),
                                              thickness: 1,
                                            ),
                                          ),
                                          Padding(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 12),
                                            child: Text(
                                              'Hoặc',
                                              style: TextStyle(
                                                color: Colors.white
                                                    .withValues(alpha: 0.8),
                                                fontSize: 12.5,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ),
                                          Expanded(
                                            child: Divider(
                                              color: Colors.white
                                                  .withValues(alpha: 0.25),
                                              thickness: 1,
                                            ),
                                          ),
                                        ],
                                      ),

                                      const SizedBox(height: 14),

                                      // Nút Google trắng với logo 4 màu chuẩn
                                      AnimatedBuilder(
                                        animation: _authController,
                                        builder: (context, _) {
                                          return SizedBox(
                                            height: 48,
                                            child: ElevatedButton(
                                              onPressed:
                                                  _authController.isLoading
                                                      ? null
                                                      : _loginWithGoogle,
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: Colors.white,
                                                foregroundColor: darkText,
                                                elevation: 0,
                                                shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(16),
                                                ),
                                              ),
                                              child: Row(
                                                mainAxisAlignment:
                                                    MainAxisAlignment.center,
                                                children: [
                                                  CustomPaint(
                                                    size: const Size(20, 20),
                                                    painter:
                                                        _GoogleLogoPainter(),
                                                  ),
                                                  const SizedBox(width: 12),
                                                  const Text(
                                                    'Tiếp tục với Google',
                                                    style: TextStyle(
                                                      fontSize: 14.5,
                                                      fontWeight:
                                                          FontWeight.w700,
                                                      color: darkText,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          );
                                        },
                                      ),

                                      const SizedBox(height: 10),

                                      // Quên mật khẩu
                                      Center(
                                        child: TextButton(
                                          onPressed: () {
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (_) =>
                                                    ChangePasswordScreen(
                                                  initialStep: 1,
                                                  initialEmail:
                                                      _emailController.text
                                                          .trim(),
                                                  isForgotPasswordMode: true,
                                                ),
                                              ),
                                            );
                                          },
                                          child: const Text(
                                            'Quên mật khẩu?',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 13.5,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                      ),

                                      const Spacer(),
                                      const SizedBox(height: 8),

                                      // Chuyển sang đăng ký
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Text(
                                            'Chưa có tài khoản? ',
                                            style: TextStyle(
                                              color: Colors.white
                                                  .withValues(alpha: 0.85),
                                              fontSize: 13.5,
                                            ),
                                          ),
                                          GestureDetector(
                                            onTap: () {
                                              Navigator.push(
                                                context,
                                                MaterialPageRoute(
                                                  builder: (_) =>
                                                      const RegisterView(),
                                                ),
                                              );
                                            },
                                            child: const Text(
                                              'Đăng ký',
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontSize: 13.5,
                                                fontWeight: FontWeight.bold,
                                                decoration:
                                                    TextDecoration.underline,
                                                decorationColor: Colors.white,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _GoogleLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width;
    final double h = size.height;
    final Offset center = Offset(w / 2, h / 2);
    final double strokeWidth = w * 0.21;
    final double radius = (w - strokeWidth) / 2;
    final Rect rect = Rect.fromCircle(center: center, radius: radius);

    const Color blue = Color(0xFF4285F4);
    const Color red = Color(0xFFEA4335);
    const Color yellow = Color(0xFFFBBC05);
    const Color green = Color(0xFF34A853);

    final Paint paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.butt;

    // 1. Vòng cung Đỏ (phía trên)
    paint.color = red;
    canvas.drawArc(rect, -2.42, 1.72, false, paint);

    // 2. Vòng cung Vàng (bên trái)
    paint.color = yellow;
    canvas.drawArc(rect, 2.45, 1.43, false, paint);

    // 3. Vòng cung Xanh lá (phía dưới)
    paint.color = green;
    canvas.drawArc(rect, 0.72, 1.75, false, paint);

    // 4. Vòng cung Xanh dương (góc dưới phải)
    paint.color = blue;
    canvas.drawArc(rect, -0.05, 0.80, false, paint);

    // 5. Thanh ngang màu Xanh dương của chữ G
    final Paint barPaint = Paint()
      ..color = blue
      ..style = PaintingStyle.fill;

    canvas.drawRect(
      Rect.fromLTWH(
        w * 0.50,
        h * 0.50 - (strokeWidth * 0.48),
        w * 0.48,
        strokeWidth * 0.96,
      ),
      barPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}