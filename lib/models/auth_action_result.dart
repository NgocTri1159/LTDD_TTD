/// Kết quả trả về của một thao tác xác thực.
/// Model này giúp Controller trả kết quả cho View mà không phụ thuộc BuildContext.
class AuthActionResult {
  final bool isSuccess;
  final String message;

  const AuthActionResult({
    required this.isSuccess,
    required this.message,
  });

  const AuthActionResult.success(String message)
      : this(isSuccess: true, message: message);

  const AuthActionResult.failure(String message)
      : this(isSuccess: false, message: message);
}
