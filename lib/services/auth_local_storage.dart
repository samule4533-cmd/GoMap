import 'package:shared_preferences/shared_preferences.dart';

/// 로그인 화면의 "이메일 저장" 체크박스용 로컬 저장소.
/// 비밀번호는 저장하지 않는다.
class AuthLocalStorage {
  static const _emailKey = 'remembered_email';

  static Future<String?> getRememberedEmail() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_emailKey);
  }

  static Future<void> saveEmail(String email) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_emailKey, email);
  }

  static Future<void> clearEmail() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_emailKey);
  }
}
