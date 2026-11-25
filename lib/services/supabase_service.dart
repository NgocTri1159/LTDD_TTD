
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart';

class SupabaseService {
  static const String supabaseUrl =
      'https://hjtqxdnrnpudvjqaqiru.supabase.co';

  static const String supabasePublishableKey =
      'sb_publishable_adxCVKISmOYbN1aLR21gcg_AA8HAgi4';

  static Future<void> initialize() async {
    await Supabase.initialize(
      url: supabaseUrl,
      publishableKey: supabasePublishableKey,

      // Lấy Firebase ID Token của người dùng hiện tại
      accessToken: () async {
        final user = FirebaseAuth.instance.currentUser;

        if (user == null) {
          return null;
        }

        return await user.getIdToken();
      },
    );
  }

  
  static Future<void> syncUserProfile({
    required String hoTen,
  }) async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      throw Exception('Người dùng chưa đăng nhập Firebase');
    }

    final email = user.email;

    if (email == null || email.isEmpty) {
      throw Exception('Tài khoản không có email');
    }

    // Tạo hồ sơ mới, không sử dụng upsert
    await client.from('nguoi_dung').insert({
      'id': user.uid,
      'email': email,
      'ho_ten': hoTen,
    });
  }
  

  static Future<void> syncCurrentUserProfile() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      throw Exception('Chưa đăng nhập Firebase');
    }

    final email = user.email;

    if (email == null || email.isEmpty) {
      throw Exception('Không tìm thấy email');
    }

    // Kiểm tra hồ sơ đã tồn tại chưa
    final existing = await client
        .from('nguoi_dung')
        .select('id')
        .eq('id', user.uid)
        .maybeSingle();

    if (existing != null) {
      return;
    }

    // Tạo hồ sơ mới
    await client.from('nguoi_dung').insert({
      'id': user.uid,
      'email': email,
      'ho_ten': user.displayName ?? 'Người dùng',
    });
  }


  static SupabaseClient get client =>
      Supabase.instance.client;
}
