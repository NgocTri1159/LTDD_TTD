import 'dart:async';
import 'dart:math';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/account_model.dart';

class AdminAccountController {
  AdminAccountController._();
  static final AdminAccountController instance = AdminAccountController._();

  final SupabaseClient _supabase = Supabase.instance.client;

  String _generateUuidV4() {
    final rng = Random.secure();
    final bytes = List<int>.generate(16, (_) => rng.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    String hex(int b) => b.toRadixString(16).padLeft(2, '0');
    final h = bytes.map(hex).join();
    return '${h.substring(0, 8)}-${h.substring(8, 12)}-'
        '${h.substring(12, 16)}-${h.substring(16, 20)}-${h.substring(20)}';
  }

  Future<List<AccountModel>> fetchAccounts() async {
    dynamic data;
    try {
      data = await _supabase
          .from('profiles')
          .select()
          .order('created_at', ascending: false);
    } catch (_) {
      data = await _supabase.from('profiles').select();
    }

    final List<AccountModel> accounts = [];
    if (data is List) {
      for (final dynamic item in data) {
        if (item is Map<String, dynamic>) {
          accounts.add(AccountModel.fromMap(item));
        }
      }
    }
    return accounts;
  }

  Future<void> createAccount({
    required String fullName,
    required String avatarUrl,
    required String role,
    required int level,
    required String rank,
    required String bio,
  }) async {
    await _supabase.from('profiles').insert({
      'id': _generateUuidV4(),
      'full_name': fullName.trim().isEmpty ? 'PlayerNew' : fullName.trim(),
      'avatar_url': avatarUrl.trim(),
      'role': role,
      'level': level < 1 ? 1 : level,
      'rank': rank,
      'bio': bio.trim(),
    });
  }

  Future<void> updateAccount({
    required String id,
    required String fullName,
    required String avatarUrl,
    required String role,
    required int level,
    required String rank,
    required String bio,
  }) async {
    await _supabase.from('profiles').update({
      'full_name': fullName.trim().isEmpty ? 'Player' : fullName.trim(),
      'avatar_url': avatarUrl.trim(),
      'role': role,
      'level': level < 1 ? 1 : level,
      'rank': rank,
      'bio': bio.trim(),
    }).eq('id', id);
  }

  Future<void> deleteAccount(String id) async {
    await _supabase.from('profiles').delete().eq('id', id);
  }
}