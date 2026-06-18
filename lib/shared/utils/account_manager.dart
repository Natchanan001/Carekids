import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:carekids/shared/models/saved_account.dart';

class AccountManager {
  static const _storageKey = 'carekids_saved_accounts';

  static Future<List<SavedAccount>> getSavedAccounts() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    if (raw == null) return [];

    try {
      final list = (jsonDecode(raw) as List)
          .map((e) => SavedAccount.fromJson(e as Map<String, dynamic>))
          .toList();
      list.sort((a, b) => b.lastUsedAt.compareTo(a.lastUsedAt));
      return list;
    } catch (_) {
      return [];
    }
  }

  // 🌟 Upsert: ถ้ามี userId นี้อยู่แล้วจะอัปเดตทับ (refresh token จะถูก rotate ทุกครั้งที่ใช้)
  static Future<void> saveAccount(SavedAccount account) async {
    final accounts = await getSavedAccounts();
    accounts.removeWhere((a) => a.userId == account.userId);
    accounts.add(account);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _storageKey,
      jsonEncode(accounts.map((a) => a.toJson()).toList()),
    );
  }

  static Future<void> removeAccount(String userId) async {
    final accounts = await getSavedAccounts();
    accounts.removeWhere((a) => a.userId == userId);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _storageKey,
      jsonEncode(accounts.map((a) => a.toJson()).toList()),
    );
  }
}