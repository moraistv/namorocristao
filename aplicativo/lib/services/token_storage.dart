import 'package:hive_flutter/hive_flutter.dart';
import 'package:mioamoreapp/helpers/constants.dart';

/// Guarda tokens e dados básicos da sessão no Hive.
class TokenStorage {
  TokenStorage._();

  static const _kAccess = "api_access_token";
  static const _kRefresh = "api_refresh_token";
  static const _kEmail = "api_user_email";
  static const _kUserId = "api_user_id";
  static const _kMyPhoto = "api_my_photo";

  static Box get _box => Hive.box(HiveConstants.hiveBox);

  static Future<void> saveSession({
    required String accessToken,
    required String refreshToken,
    required String email,
    String? userId,
  }) async {
    await _box.put(_kAccess, accessToken);
    await _box.put(_kRefresh, refreshToken);
    await _box.put(_kEmail, email);
    if (userId != null) await _box.put(_kUserId, userId);
  }

  /// Atualiza apenas os tokens (após refresh), mantendo email/userId.
  static Future<void> updateTokens(String accessToken, String refreshToken) async {
    await _box.put(_kAccess, accessToken);
    await _box.put(_kRefresh, refreshToken);
  }

  static String? get accessToken => _box.get(_kAccess) as String?;
  static String? get refreshToken => _box.get(_kRefresh) as String?;
  static String? get email => _box.get(_kEmail) as String?;
  static String? get userId => _box.get(_kUserId) as String?;
  static String? get myPhoto => _box.get(_kMyPhoto) as String?;
  static Future<void> setMyPhoto(String? url) async {
    if (url == null) {
      await _box.delete(_kMyPhoto);
    } else {
      await _box.put(_kMyPhoto, url);
    }
  }

  static bool get isLoggedIn =>
      (accessToken != null && accessToken!.isNotEmpty);

  static Future<void> clear() async {
    await _box.delete(_kAccess);
    await _box.delete(_kRefresh);
    await _box.delete(_kEmail);
    await _box.delete(_kUserId);
    await _box.delete(_kMyPhoto);
  }
}
