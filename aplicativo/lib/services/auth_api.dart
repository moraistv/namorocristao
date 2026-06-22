import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:mioamoreapp/config/api_config.dart';
import 'package:mioamoreapp/services/token_storage.dart';

class AuthApiException implements Exception {
  final String message;
  AuthApiException(this.message);
  @override
  String toString() => message;
}

/// Resultado de um login bem-sucedido.
class AuthResult {
  final String userId;
  final String email;
  final String accessToken;
  final String refreshToken;
  final bool hasProfile;
  AuthResult({
    required this.userId,
    required this.email,
    required this.accessToken,
    required this.refreshToken,
    required this.hasProfile,
  });
}

class AuthApi {
  AuthApi._();

  static const _timeout = Duration(seconds: 15);

  static Uri _u(String path) => Uri.parse("${ApiConfig.baseUrl}$path");

  static Future<Map<String, dynamic>> _post(
      String path, Map<String, dynamic> body) async {
    late http.Response res;
    try {
      res = await http
          .post(
            _u(path),
            headers: {"Content-Type": "application/json"},
            body: jsonEncode(body),
          )
          .timeout(_timeout);
    } catch (e) {
      throw AuthApiException(
          "Não foi possível conectar à API. Verifique o servidor/rede.");
    }

    final Map<String, dynamic> json =
        res.body.isNotEmpty ? jsonDecode(res.body) : {};

    if (res.statusCode >= 200 && res.statusCode < 300) {
      return json;
    }
    final msg = (json["error"] ?? "Erro ${res.statusCode}").toString();
    throw AuthApiException(msg);
  }

  static AuthResult _toResult(Map<String, dynamic> json) {
    return AuthResult(
      userId: (json["user"]?["id"] ?? "").toString(),
      email: (json["user"]?["email"] ?? "").toString(),
      accessToken: (json["accessToken"] ?? "").toString(),
      refreshToken: (json["refreshToken"] ?? "").toString(),
      hasProfile: json["hasProfile"] == true,
    );
  }

  static Future<AuthResult> _persist(AuthResult r) async {
    await TokenStorage.saveSession(
      accessToken: r.accessToken,
      refreshToken: r.refreshToken,
      email: r.email,
      userId: r.userId,
    );
    return r;
  }

  static Future<AuthResult> register(String email, String password) async {
    final json = await _post("/auth/register", {
      "email": email,
      "password": password,
    });
    return _persist(_toResult(json));
  }

  static Future<AuthResult> login(String email, String password) async {
    final json = await _post("/auth/login", {
      "email": email,
      "password": password,
    });
    return _persist(_toResult(json));
  }

  static Future<void> requestCode(String email) async {
    await _post("/auth/request-code", {"email": email});
  }

  static Future<AuthResult> loginWithCode(String email, String code) async {
    final json = await _post("/auth/login-code", {
      "email": email,
      "code": code,
    });
    return _persist(_toResult(json));
  }

  /// Login/cadastro via Google (envia o idToken do Google para a nossa API).
  static Future<AuthResult> loginWithGoogle(String idToken) async {
    final json = await _post("/auth/google", {"idToken": idToken});
    return _persist(_toResult(json));
  }
}
