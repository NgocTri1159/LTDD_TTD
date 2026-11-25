import 'dart:io';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:firebase_auth/firebase_auth.dart';

class BackendService {
  static final String baseUrl = kIsWeb
      ? 'http://localhost:3000'
      : (Platform.isAndroid ? 'http://10.0.2.2:3000' : 'http://localhost:3000');

  // Private helper to send request with Firebase ID Token
  static Future<http.Response> _authorizedRequest(
    String method,
    String path, {
    Object? body,
    Map<String, String>? extraHeaders,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception('User not signed in');
    }

    final idToken = await user.getIdToken();
    if (idToken == null || idToken.isEmpty) {
      throw Exception('Unable to obtain Firebase ID Token');
    }

    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $idToken',
    };
    if (extraHeaders != null) headers.addAll(extraHeaders);

    final uri = Uri.parse('$baseUrl$path');
    final Future<http.Response> requestFuture;

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
        throw Exception('Unsupported HTTP method: $method');
    }

    return await requestFuture.timeout(const Duration(seconds: 15));
  }

  // Public wrappers
  static Future<http.Response> get(String path) =>
      _authorizedRequest('GET', path);

  static Future<http.Response> post(
    String path, {
    Object? body,
    Map<String, String>? extraHeaders,
  }) =>
      _authorizedRequest('POST', path, body: body, extraHeaders: extraHeaders);

  static Future<http.Response> put(
    String path, {
    Object? body,
    Map<String, String>? extraHeaders,
  }) =>
      _authorizedRequest('PUT', path, body: body, extraHeaders: extraHeaders);

  static Future<http.Response> patch(
    String path, {
    Object? body,
    Map<String, String>? extraHeaders,
  }) =>
      _authorizedRequest('PATCH', path, body: body, extraHeaders: extraHeaders);

  // Upload ảnh hoặc âm thanh lên Supabase thông qua Backend API
  static Future<Map<String, dynamic>> uploadFile({
    required Uint8List bytes,
    required String filename,
    required String mimeType,
  }) async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      throw Exception('User not signed in');
    }

    final idToken = await user.getIdToken();

    if (idToken == null || idToken.isEmpty) {
      throw Exception('Unable to obtain Firebase ID Token');
    }

    if (bytes.isEmpty) {
      throw Exception('File không có dữ liệu');
    }

    final uri = Uri.parse('$baseUrl/api/questions/upload');

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
      const Duration(seconds: 60),
    );

    final response = await http.Response.fromStream(streamedResponse);

    debugPrint('UPLOAD STATUS: ${response.statusCode}');
    debugPrint('UPLOAD RESPONSE: ${response.body}');

    final Map<String, dynamic> result;

    try {
      result = jsonDecode(response.body) as Map<String, dynamic>;
    } catch (_) {
      throw Exception('Phản hồi upload không hợp lệ');
    }

    if (response.statusCode != 201 || result['success'] != true) {
      throw Exception(
        result['message'] ?? 'Upload file thất bại',
      );
    }

    return Map<String, dynamic>.from(result['file'] as Map);
  }
  // Existing provisionRole, now using shared post helper
  static Future<void> provisionRole() async {
    final response = await post('/auth/provision-role');
    debugPrint('BACKEND STATUS: ${response.statusCode}');
    debugPrint('BACKEND RESPONSE: ${response.body}');

    final result = jsonDecode(response.body);
    if (response.statusCode != 200 || result['success'] != true) {
      throw Exception(result['message'] ?? 'KhÃ´ng thá»ƒ cáº¥p quyá»n tÃ i khoáº£n');
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
        throw Exception('TÃ i khoáº£n chÆ°a nháº­n Ä‘Æ°á»£c quyá»n authenticated');
      }

      debugPrint('CAP QUYEN THANH CONG!');
    }
  }

  // Method to check current user via backend
  static Future<void> checkCurrentUser() async {
    final response = await get('/api/auth/me');
    debugPrint('CHECK /api/auth/me STATUS: ${response.statusCode}');
    debugPrint('BODY: ${response.body}');
  }
}


