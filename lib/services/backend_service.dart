import 'dart:convert';
import 'dart:core';
import 'dart:core' as core;
import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

class BackendService {
  static final core.String baseUrl = kIsWeb
      ? 'http://localhost:3000'
      : (Platform.isAndroid ? 'http://10.0.2.2:3000' : 'http://localhost:3000');

  // Đợi Firebase Auth khôi phục phiên đăng nhập (tránh lỗi User not signed in khi F5 trên Web)
  static core.Future<User> _getAuthenticatedUser() async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      try {
        user = await FirebaseAuth.instance
            .authStateChanges()
            .firstWhere((u) => u != null)
            .timeout(const core.Duration(seconds: 3));
      } catch (_) {
        user = FirebaseAuth.instance.currentUser;
      }
    }

    if (user == null) {
      throw core.Exception('User not signed in');
    }
    return user;
  }

  // Private helper to send request with Firebase ID Token
  static core.Future<http.Response> _authorizedRequest(
    core.String method,
    core.String path, {
    core.Object? body,
    core.Map<core.String, core.String>? extraHeaders,
  }) async {
    final user = await _getAuthenticatedUser();

    final idToken = await user.getIdToken();
    if (idToken == null || idToken.isEmpty) {
      throw core.Exception('Unable to obtain Firebase ID Token');
    }

    final headers = <core.String, core.String>{
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $idToken',
    };
    if (extraHeaders != null) headers.addAll(extraHeaders);

    final uri = core.Uri.parse('$baseUrl$path');
    final core.Future<http.Response> requestFuture;

    switch (method.toUpperCase()) {
      case 'GET':
        requestFuture = http.get(uri, headers: headers);
        break;
      case 'POST':
        requestFuture = http.post(uri, headers: headers, body: body);
        break;
      case 'PUT':
        requestFuture = http.put(uri, headers: headers, body: body);
        break;
      case 'PATCH':
        requestFuture = http.patch(uri, headers: headers, body: body);
        break;
      default:
        throw core.Exception('Unsupported HTTP method: $method');
    }

    return await requestFuture.timeout(const core.Duration(seconds: 15));
  }

  // Public wrappers
  static core.Future<http.Response> get(core.String path) =>
      _authorizedRequest('GET', path);

  static core.Future<http.Response> post(
    core.String path, {
    core.Object? body,
    core.Map<core.String, core.String>? extraHeaders,
  }) =>
      _authorizedRequest('POST', path, body: body, extraHeaders: extraHeaders);

  static core.Future<http.Response> put(
    core.String path, {
    core.Object? body,
    core.Map<core.String, core.String>? extraHeaders,
  }) =>
      _authorizedRequest('PUT', path, body: body, extraHeaders: extraHeaders);

  static core.Future<http.Response> patch(
    core.String path, {
    core.Object? body,
    core.Map<core.String, core.String>? extraHeaders,
  }) =>
      _authorizedRequest('PATCH', path, body: body, extraHeaders: extraHeaders);

  // Upload ảnh hoặc âm thanh lên Supabase thông qua Backend API
  static core.Future<core.Map<core.String, dynamic>> uploadFile({
    required Uint8List bytes,
    required core.String filename,
    required core.String mimeType,
  }) async {
    final user = await _getAuthenticatedUser();

    final idToken = await user.getIdToken();
    if (idToken == null || idToken.isEmpty) {
      throw core.Exception('Unable to obtain Firebase ID Token');
    }

    if (bytes.isEmpty) {
      throw core.Exception('File không có dữ liệu');
    }

    final uri = core.Uri.parse('$baseUrl/api/questions/upload');
    final request = http.MultipartRequest('POST', uri);

    request.headers['Authorization'] = 'Bearer $idToken';
    request.files.add(
      http.MultipartFile.fromBytes(
        'file',
        bytes,
        filename: filename,
        contentType: MediaType.parse(mimeType),
      ),
    );

    final streamedResponse = await request.send().timeout(
      const core.Duration(seconds: 60),
    );

    final response = await http.Response.fromStream(streamedResponse);

    debugPrint('UPLOAD STATUS: ${response.statusCode}');
    debugPrint('UPLOAD RESPONSE: ${response.body}');

    final core.Map<core.String, dynamic> result;

    try {
      result = jsonDecode(response.body) as core.Map<core.String, dynamic>;
    } catch (_) {
      throw core.Exception('Phản hồi upload không hợp lệ');
    }

    if (response.statusCode != 201 || result['success'] != true) {
      throw core.Exception(
        result['message'] ?? 'Upload file thất bại',
      );
    }

    return core.Map<core.String, dynamic>.from(result['file'] as core.Map);
  }

  // Existing provisionRole, now using shared post helper
  static core.Future<void> provisionRole() async {
    final response = await post('/auth/provision-role');
    debugPrint('BACKEND STATUS: ${response.statusCode}');
    debugPrint('BACKEND RESPONSE: ${response.body}');

    final result = jsonDecode(response.body);
    if (response.statusCode != 200 || result['success'] != true) {
      throw core.Exception(result['message'] ?? 'Không thể cấp quyền tài khoản');
    }

    // Refresh token and verify claims
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await user.getIdToken(true);
      final tokenResult = await user.getIdTokenResult(true);

      debugPrint('========== KIEM TRA CUSTOM CLAIMS ==========');
      debugPrint('UID: ${user.uid}');
      debugPrint('CLAIMS: ${tokenResult.claims}');
      debugPrint('ROLE: ${tokenResult.claims?['role']}');
      debugPrint('============================================');

      if (tokenResult.claims?['role'] != 'authenticated') {
        throw core.Exception('Tài khoản chưa nhận được quyền authenticated');
      }

      debugPrint('CAP QUYEN THANH CONG!');
    }
  }

  // Method to check current user via backend
  static core.Future<void> checkCurrentUser() async {
    final response = await get('/api/auth/me');
    debugPrint('CHECK /api/auth/me STATUS: ${response.statusCode}');
    debugPrint('BODY: ${response.body}');
  }

  // =========================
  // QUÊN MẬT KHẨU QUA EMAIL OTP (KHÔNG CẦN TOKEN ĐĂNG NHẬP)
  // =========================
  static core.Future<void> sendResetOtp(core.String email) async {
    final response = await http
        .post(
          core.Uri.parse('$baseUrl/api/auth/send-reset-otp'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'email': email.trim()}),
        )
        .timeout(const core.Duration(seconds: 20));

    core.Map<core.String, dynamic> data = {};
    try {
      data = jsonDecode(response.body) as core.Map<core.String, dynamic>;
    } catch (_) {}

    if (response.statusCode != 200 || data['success'] != true) {
      throw core.Exception(data['message'] ?? 'Không thể gửi mã xác nhận.');
    }
  }

  static core.Future<void> verifyResetOtp({
    required core.String email,
    required core.String otp,
  }) async {
    final response = await http
        .post(
          core.Uri.parse('$baseUrl/api/auth/verify-reset-otp'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'email': email.trim(),
            'otp': otp.trim(),
          }),
        )
        .timeout(const core.Duration(seconds: 15));

    core.Map<core.String, dynamic> data = {};
    try {
      data = jsonDecode(response.body) as core.Map<core.String, dynamic>;
    } catch (_) {}

    if (response.statusCode != 200 || data['success'] != true) {
      throw core.Exception(data['message'] ?? 'Mã xác nhận không đúng.');
    }
  }

  static core.Future<void> resetPasswordWithOtp({
    required core.String email,
    required core.String otp,
    required core.String newPassword,
  }) async {
    final response = await http
        .post(
          core.Uri.parse('$baseUrl/api/auth/reset-password-with-otp'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'email': email.trim(),
            'otp': otp.trim(),
            'newPassword': newPassword,
          }),
        )
        .timeout(const core.Duration(seconds: 15));

    core.Map<core.String, dynamic> data = {};
    try {
      data = jsonDecode(response.body) as core.Map<core.String, dynamic>;
    } catch (_) {}

    if (response.statusCode != 200 || data['success'] != true) {
      throw core.Exception(data['message'] ?? 'Không thể đặt lại mật khẩu.');
    }
  }
}