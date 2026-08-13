// 本地持久化：服务器地址、访问口令
import 'package:shared_preferences/shared_preferences.dart';

class Prefs {
  static const _kBaseUrl = 'server_base_url';
  static const _kToken = 'server_token';
  static const _kIsEn = 'locale_is_en';

  static Future<({String baseUrl, String token, bool isEn})> load() async {
    final sp = await SharedPreferences.getInstance();
    return (
      baseUrl: sp.getString(_kBaseUrl) ?? '',
      token: sp.getString(_kToken) ?? '',
      isEn: sp.getBool(_kIsEn) ?? false,
    );
  }

  static Future<void> save({required String baseUrl, required String token}) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setString(_kBaseUrl, baseUrl.trim());
    await sp.setString(_kToken, token.trim());
  }

  static Future<void> saveLocale({required bool isEn}) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setBool(_kIsEn, isEn);
  }

  static Future<void> clear() async {
    final sp = await SharedPreferences.getInstance();
    await sp.remove(_kBaseUrl);
    await sp.remove(_kToken);
  }
}
